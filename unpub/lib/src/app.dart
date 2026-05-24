import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:collection/collection.dart' show IterableExtension;
import 'package:googleapis/oauth2/v2.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:pub_semver/pub_semver.dart' as semver;
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:unpub/src/meta_store.dart';
import 'package:unpub/src/models.dart';
import 'package:unpub/src/package_store.dart';
import 'package:unpub_api/models.dart';
import 'package:unpub_web/server.dart' as web;
import 'package:unpub_web/static_assets.dart' as web_assets;

import 'utils.dart';

part 'app.g.dart';

class App {
  static const proxyOriginHeader = 'proxy-origin';

  /// meta information store
  final MetaStore metaStore;

  /// package(tarball) store
  final PackageStore packageStore;

  /// upstream url, default: https://pub.dev
  final String upstream;

  /// http(s) proxy to call googleapis (to get uploader email)
  final String? googleapisProxy;
  final String? overrideUploaderEmail;

  /// A forward proxy uri
  final Uri? proxyOrigin;

  /// validate if the package can be published
  ///
  /// for more details, see: https://github.com/bytedance/unpub#package-validator
  final Future<void> Function(Map<String, dynamic> pubspec, String uploaderEmail)? uploadValidator;

  App({
    required this.metaStore,
    required this.packageStore,
    this.upstream = 'https://pub.dev',
    this.googleapisProxy,
    this.overrideUploaderEmail,
    this.uploadValidator,
    Uri? proxyOrigin,
    @Deprecated('Use proxyOrigin instead')
    // ignore: non_constant_identifier_names
    Uri? proxy_origin,
  }) : proxyOrigin = proxyOrigin ?? proxy_origin;

  static shelf.Response _okWithJson(Map<String, dynamic> data) => shelf.Response.ok(
    json.encode(data),
    headers: {HttpHeaders.contentTypeHeader: ContentType.json.mimeType, 'Access-Control-Allow-Origin': '*'},
  );

  static shelf.Response _successMessage(String message) => _okWithJson({
    'success': {'message': message},
  });

  static shelf.Response _badRequest(String message, {int status = HttpStatus.badRequest}) => shelf.Response(
    status,
    headers: {HttpHeaders.contentTypeHeader: ContentType.json.mimeType},
    body: json.encode({
      'error': {'message': message},
    }),
  );

  http.Client? _googleapisClient;

  String _resolveUrl(shelf.Request req, String reference) {
    if (proxyOrigin != null) {
      return proxyOrigin!.resolve(reference).toString();
    }
    final String? proxyOriginInHeader = req.headers[proxyOriginHeader];
    if (proxyOriginInHeader != null) {
      return Uri.parse(proxyOriginInHeader).resolve(reference).toString();
    }
    return req.requestedUri.resolve(reference).toString();
  }

  Future<String> _getUploaderEmail(shelf.Request req) async {
    if (overrideUploaderEmail != null) return overrideUploaderEmail!;

    final authHeader = req.headers[HttpHeaders.authorizationHeader];
    if (authHeader == null) throw Exception('missing authorization header');

    final token = authHeader.split(' ').last;

    if (_googleapisClient == null) {
      if (googleapisProxy != null) {
        _googleapisClient = IOClient(
          HttpClient()
            ..findProxy = (url) =>
                HttpClient.findProxyFromEnvironment(url, environment: {'https_proxy': googleapisProxy!}),
        );
      } else {
        _googleapisClient = http.Client();
      }
    }

    final info = await Oauth2Api(_googleapisClient!).tokeninfo(accessToken: token);
    if (info.email == null) throw Exception('fail to get google account email');
    return info.email!;
  }

  Future<HttpServer> serve([String host = '0.0.0.0', int port = 4000]) async {
    final staticHandler = web_assets.staticAssetsHandler();
    late shelf.Handler webHandler;

    FutureOr<shelf.Response> dispatchHandler(shelf.Request request) async {
      final apiResponse = await router.call(request);
      if (apiResponse.statusCode != 404 || _isBackendPath(request.url.path)) {
        return apiResponse;
      }

      final staticResponse = await staticHandler(request);
      if (staticResponse.statusCode != 404) {
        return staticResponse;
      }

      return webHandler(request);
    }

    final handler = const shelf.Pipeline()
        .addMiddleware(corsHeaders())
        .addMiddleware(shelf.logRequests())
        .addHandler(dispatchHandler);
    final server = await shelf_io.serve(handler, host, port);
    webHandler = web.buildHandler(apiBaseUrl: 'http://127.0.0.1:${server.port}');
    return server;
  }

  static bool _isBackendPath(String path) {
    final segments = path.startsWith('/') ? path.substring(1).split('/') : path.split('/');
    if (segments.isEmpty || segments.first.isEmpty) {
      return false;
    }
    return switch (segments.first) {
      'api' || 'webapi' || 'badge' => true,
      'packages' => segments.length >= 2 && (segments.last.endsWith('.tar.gz') || segments.last.endsWith('.json')),
      _ => false,
    };
  }

  Map<String, dynamic> _versionToJson(UnpubVersion item, shelf.Request req) {
    final name = item.pubspec['name'] as String;
    final version = item.version;
    return {
      'archive_url': _resolveUrl(req, '/packages/$name/versions/$version.tar.gz'),
      'pubspec': item.pubspec,
      'version': version,
    };
  }

  bool isPubClient(shelf.Request req) {
    final ua = req.headers[HttpHeaders.userAgentHeader];
    print(ua);
    return ua != null && ua.toLowerCase().contains('dart pub');
  }

  Router get router => _$AppRouter(this);

  @Route.get('/api/packages/<name>')
  Future<shelf.Response> getVersions(shelf.Request req, String name) async {
    final package = await metaStore.queryPackage(name);

    if (package == null) {
      return shelf.Response.found(Uri.parse(upstream).resolve('/api/packages/$name').toString());
    }

    package.versions.sort((a, b) {
      return semver.Version.prioritize(semver.Version.parse(a.version), semver.Version.parse(b.version));
    });

    final versionMaps = package.versions.map((item) => _versionToJson(item, req)).toList();

    return _okWithJson({
      'name': name,
      'latest': versionMaps.last, // TODO: Exclude pre release
      'versions': versionMaps,
    });
  }

  @Route.get('/api/packages/<name>/versions/<version>')
  Future<shelf.Response> getVersion(shelf.Request req, String name, String version) async {
    // Important: + -> %2B, should be decoded here
    try {
      version = Uri.decodeComponent(version);
    } catch (err) {
      print(err);
    }

    final package = await metaStore.queryPackage(name);
    if (package == null) {
      return shelf.Response.found(Uri.parse(upstream).resolve('/api/packages/$name/versions/$version').toString());
    }

    final packageVersion = package.versions.firstWhereOrNull((item) => item.version == version);
    if (packageVersion == null) {
      return shelf.Response.notFound('Not Found');
    }

    return _okWithJson(_versionToJson(packageVersion, req));
  }

  @Route.get('/packages/<name>/versions/<version>.tar.gz')
  Future<shelf.Response> download(shelf.Request req, String name, String version) async {
    final package = await metaStore.queryPackage(name);
    if (package == null) {
      return shelf.Response.found(Uri.parse(upstream).resolve('/packages/$name/versions/$version.tar.gz').toString());
    }

    if (isPubClient(req)) {
      metaStore.increaseDownloads(name, version);
    }

    if (packageStore.supportsDownloadUrl) {
      return shelf.Response.found(await packageStore.downloadUrl(name, version));
    } else {
      return shelf.Response.ok(
        packageStore.download(name, version),
        headers: {HttpHeaders.contentTypeHeader: ContentType.binary.mimeType},
      );
    }
  }

  @Route.get('/api/packages/versions/new')
  Future<shelf.Response> getUploadUrl(shelf.Request req) async {
    return _okWithJson({
      'url': _resolveUrl(req, '/api/packages/versions/newUpload').toString(),
      'fields': {},
    });
  }

  @Route.post('/api/packages/versions/newUpload')
  Future<shelf.Response> upload(shelf.Request req) async {
    try {
      final uploader = await _getUploaderEmail(req);

      final contentType = req.headers['content-type'];
      if (contentType == null) throw Exception('invalid content type');

      final mediaType = MediaType.parse(contentType);
      final boundary = mediaType.parameters['boundary'];
      if (boundary == null) throw Exception('invalid boundary');

      final transformer = MimeMultipartTransformer(boundary);
      MimeMultipart? fileData;

      // The map below makes the runtime type checker happy.
      // https://github.com/dart-lang/pub-dev/blob/19033f8154ca1f597ef5495acbc84a2bb368f16d/app/lib/fake/server/fake_storage_server.dart#L74
      final stream = req.read().map((a) => a).transform(transformer);
      await for (final part in stream) {
        if (fileData != null) continue;
        fileData = part;
      }

      final bb = await fileData!.fold(BytesBuilder(copy: false), (BytesBuilder byteBuilder, d) => byteBuilder..add(d));
      final tarballBytes = bb.takeBytes();
      final tarBytes = const GZipDecoder().decodeBytes(tarballBytes);
      final archive = TarDecoder().decodeBytes(tarBytes);
      ArchiveFile? pubspecArchiveFile;
      ArchiveFile? readmeFile;
      ArchiveFile? changelogFile;

      for (final file in archive.files) {
        if (file.name == 'pubspec.yaml') {
          pubspecArchiveFile = file;
          continue;
        }
        if (file.name.toLowerCase() == 'readme.md') {
          readmeFile = file;
          continue;
        }
        if (file.name.toLowerCase() == 'changelog.md') {
          changelogFile = file;
          continue;
        }
      }

      if (pubspecArchiveFile == null) {
        throw Exception('Did not find any pubspec.yaml file in upload. Aborting.');
      }

      final pubspecYaml = utf8.decode(pubspecArchiveFile.content);
      final pubspec = loadYamlAsMap(pubspecYaml)!;

      if (uploadValidator != null) {
        await uploadValidator!(pubspec, uploader);
      }

      // TODO: null
      final name = pubspec['name'] as String;
      final version = pubspec['version'] as String;

      final package = await metaStore.queryPackage(name);

      // Package already exists
      if (package != null) {
        if (!package.private) {
          throw Exception('$name is not a private package. Please upload it to https://pub.dev');
        }

        // Check uploaders
        if (package.uploaders?.contains(uploader) == false) {
          throw Exception('$uploader is not an uploader of $name');
        }

        // Check duplicated version
        final duplicated = package.versions.firstWhereOrNull((item) => version == item.version);
        if (duplicated != null) {
          throw Exception('version invalid: $name@$version already exists.');
        }
      }

      // Upload package tarball to storage
      await packageStore.upload(name, version, tarballBytes);

      String? readme;
      String? changelog;
      if (readmeFile != null) {
        readme = utf8.decode(readmeFile.content);
      }
      if (changelogFile != null) {
        changelog = utf8.decode(changelogFile.content);
      }

      // Write package meta to database
      final unpubVersion = UnpubVersion(
        version,
        pubspec,
        pubspecYaml,
        uploader,
        readme,
        changelog,
        DateTime.now(),
      );
      await metaStore.addVersion(name, unpubVersion);

      // TODO: Upload docs
      return shelf.Response.found(_resolveUrl(req, '/api/packages/versions/newUploadFinish'));
    } catch (err) {
      return shelf.Response.found(_resolveUrl(req, '/api/packages/versions/newUploadFinish?error=$err'));
    }
  }

  @Route.get('/api/packages/versions/newUploadFinish')
  Future<shelf.Response> uploadFinish(shelf.Request req) async {
    final error = req.requestedUri.queryParameters['error'];
    if (error != null) {
      return _badRequest(error);
    }
    return _successMessage('Successfully uploaded package.');
  }

  @Route.post('/api/packages/<name>/uploaders')
  Future<shelf.Response> addUploader(shelf.Request req, String name) async {
    final body = await req.readAsString();
    final email = Uri.splitQueryString(body)['email']!; // TODO: null
    final operatorEmail = await _getUploaderEmail(req);
    final package = await metaStore.queryPackage(name);

    if (package?.uploaders?.contains(operatorEmail) == false) {
      return _badRequest('no permission', status: HttpStatus.forbidden);
    }
    if (package?.uploaders?.contains(email) == true) {
      return _badRequest('email already exists');
    }

    await metaStore.addUploader(name, email);
    return _successMessage('uploader added');
  }

  @Route.delete('/api/packages/<name>/uploaders/<email>')
  Future<shelf.Response> removeUploader(shelf.Request req, String name, String email) async {
    email = Uri.decodeComponent(email);
    final operatorEmail = await _getUploaderEmail(req);
    final package = await metaStore.queryPackage(name);

    // TODO: null
    if (package?.uploaders?.contains(operatorEmail) == false) {
      return _badRequest('no permission', status: HttpStatus.forbidden);
    }
    if (package?.uploaders?.contains(email) == false) {
      return _badRequest('email not uploader');
    }

    await metaStore.removeUploader(name, email);
    return _successMessage('uploader removed');
  }

  @Route.get('/webapi/packages')
  Future<shelf.Response> getPackages(shelf.Request req) async {
    final params = req.requestedUri.queryParameters;
    final size = int.tryParse(params['size'] ?? '') ?? 10;
    final page = int.tryParse(params['page'] ?? '') ?? 0;
    final sort = params['sort'] ?? 'download';
    final q = params['q'];

    String? keyword;
    String? uploader;
    String? dependency;

    if (q == null) {
    } else if (q.startsWith('email:')) {
      uploader = q.substring(6).trim();
    } else if (q.startsWith('dependency:')) {
      dependency = q.substring(11).trim();
    } else {
      keyword = q;
    }

    final result = await metaStore.queryPackages(
      size: size,
      page: page,
      sort: sort,
      keyword: keyword,
      uploader: uploader,
      dependency: dependency,
    );

    final data = ListApi(result.count, [
      for (final package in result.packages)
        ListApiPackage(
          package.name,
          package.versions.last.pubspec['description'] as String?,
          getPackageTags(package.versions.last.pubspec),
          package.versions.last.version,
          package.updatedAt,
        ),
    ]);

    return _okWithJson({'data': data.toJson()});
  }

  @Route.get('/packages/<name>.json')
  Future<shelf.Response> getPackageVersions(shelf.Request req, String name) async {
    final package = await metaStore.queryPackage(name);
    if (package == null) {
      return _badRequest('package not exists', status: HttpStatus.notFound);
    }

    final versions = package.versions.map((v) => v.version).toList();
    versions.sort((a, b) {
      return semver.Version.prioritize(semver.Version.parse(b), semver.Version.parse(a));
    });

    return _okWithJson({
      'name': name,
      'versions': versions,
    });
  }

  @Route.get('/webapi/package/<name>/<version>')
  Future<shelf.Response> getPackageDetail(shelf.Request req, String name, String version) async {
    final package = await metaStore.queryPackage(name);
    if (package == null) {
      return _okWithJson({'error': 'package not exists'});
    }

    UnpubVersion? packageVersion;
    if (version == 'latest') {
      packageVersion = package.versions.last;
    } else {
      packageVersion = package.versions.firstWhereOrNull((item) => item.version == version);
    }
    if (packageVersion == null) {
      return _okWithJson({'error': 'version not exists'});
    }

    final versions = package.versions.map((v) => DetailViewVersion(v.version, v.createdAt)).toList();
    versions.sort((a, b) {
      return semver.Version.prioritize(semver.Version.parse(b.version), semver.Version.parse(a.version));
    });

    final pubspec = packageVersion.pubspec;
    List<String?> authors;
    if (pubspec['author'] != null) {
      authors = RegExp('<(.*?)>').allMatches(pubspec['author']).map((match) => match.group(1)).toList();
    } else if (pubspec['authors'] != null) {
      authors = (pubspec['authors'] as List).map((author) => RegExp('<(.*?)>').firstMatch(author)!.group(1)).toList();
    } else {
      authors = [];
    }

    final depMap = (pubspec['dependencies'] as Map? ?? {}).cast<String, String>();

    final data = WebapiDetailView(
      package.name,
      packageVersion.version,
      packageVersion.pubspec['description'] ?? '',
      packageVersion.pubspec['homepage'] ?? '',
      package.uploaders ?? [],
      packageVersion.createdAt,
      packageVersion.readme,
      packageVersion.changelog,
      versions,
      authors,
      depMap.keys.toList(),
      getPackageTags(packageVersion.pubspec),
    );

    return _okWithJson({'data': data.toJson()});
  }

  String _getBadgeUrl(String label, String message, String color, Map<String, String> queryParameters) {
    final badgeUri = Uri.parse('https://img.shields.io/static/v1');
    return Uri(
      scheme: badgeUri.scheme,
      host: badgeUri.host,
      path: badgeUri.path,
      queryParameters: {
        'label': label,
        'message': message,
        'color': color,
        ...queryParameters,
      },
    ).toString();
  }

  @Route.get('/badge/<type>/<name>')
  Future<shelf.Response> badge(shelf.Request req, String type, String name) async {
    final queryParameters = req.requestedUri.queryParameters;
    final package = await metaStore.queryPackage(name);
    if (package == null) {
      return shelf.Response.notFound('Not found');
    }

    switch (type) {
      case 'v':
        final latest = semver.Version.primary(package.versions.map((pv) => semver.Version.parse(pv.version)).toList());

        final color = latest.major == 0 ? 'orange' : 'blue';

        return shelf.Response.found(_getBadgeUrl('unpub', latest.toString(), color, queryParameters));
      case 'd':
        return shelf.Response.found(_getBadgeUrl('downloads', package.download.toString(), 'blue', queryParameters));
      default:
        return shelf.Response.notFound('Not found');
    }
  }
}
