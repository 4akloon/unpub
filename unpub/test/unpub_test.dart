import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:http/http.dart' as http;
import 'package:mongo_dart/mongo_dart.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';
import 'package:unpub/src/utils.dart';
import 'package:unpub/unpub.dart';

import 'utils.dart';

Map<String, dynamic> _versionAt(Map<String, dynamic> meta, int index) {
  final versions = meta['versions']! as List<Object?>;
  return Map<String, dynamic>.from(versions[index]! as Map);
}

void main() {
  final Db db = Db('mongodb://localhost:27017/dart_pub_test');
  late HttpServer server;

  setUpAll(() async {
    await db.open();
  });

  Future<Map<String, dynamic>> readMeta(String name) async {
    final res =
        await db.collection(packageCollection).findOne(where.eq('name', name));
    res!.remove('_id'); // TODO: null
    return res;
  }

  final Map<String, String> pubspecCache = {};

  Future<String?> readFile(
      String package, String version, String filename) async {
    final key = package + version + filename;
    if (pubspecCache[key] == null) {
      final filePath = path.absolute('test/fixtures', package, version, filename);
      pubspecCache[key] = await File(filePath).readAsString();
    }
    return pubspecCache[key];
  }

  Future<void> cleanUpDb() async {
    await db.dropCollection(packageCollection);
    await db.dropCollection(statsCollection);
  }

  tearDownAll(() async {
    await db.close();
  });

  group('publish', () {
    setUpAll(() async {
      await cleanUpDb();
      server = await createServer(email0);
    });

    tearDownAll(() async {
      await server.close();
    });

    test('fresh', () async {
      const version = '0.0.1';

      final result = await pubPublish(package0, version);
      expect(result.stderr, '');

      final meta = await readMeta(package0);

      expect(meta['name'], package0);
      expect(meta['uploaders'], [email0]);
      expect(meta['private'], true);
      expect(meta['createdAt'], isA<DateTime>());
      expect(meta['updatedAt'], isA<DateTime>());
      expect(meta['versions'], isList);
      expect(meta['versions'], hasLength(1));

      final item = _versionAt(meta, 0);
      expect(item['createdAt'], isA<DateTime>());
      item.remove('createdAt');
      expect(
        const DeepCollectionEquality().equals(item, {
          'version': version,
          'pubspecYaml': await readFile(package0, version, 'pubspec.yaml'),
          'pubspec':
              loadYamlAsMap(await readFile(package0, version, 'pubspec.yaml')),
          'readme': await readFile(package0, version, 'README.md'),
          'changelog': await readFile(package0, version, 'CHANGELOG.md'),
          'uploader': email0,
        }),
        true,
      );
    });

    test('existing package', () async {
      const version = '0.0.3';

      final result = await pubPublish(package0, version);
      expect(result.stderr, '');

      final meta = await readMeta(package0);

      expect(meta['name'], package0);
      expect(meta['uploaders'], [email0]);
      expect(meta['versions'], isList);
      expect(meta['versions'], hasLength(2));
      expect(_versionAt(meta, 0)['version'], '0.0.1');
      expect(_versionAt(meta, 1)['version'], version);
    });

    test('duplicated version', () async {
      final result = await pubPublish(package0, '0.0.3');
      expect(result.stderr, contains('version invalid'));
    });

    test('no readme and changelog', () async {
      const version = '1.0.0-noreadme';
      await pubPublish(package0, version);

      final meta = await readMeta(package0);

      expect(meta['name'], package0);
      expect(meta['uploaders'], [email0]);
      expect(meta['versions'], isList);
      expect(meta['versions'], hasLength(3));
      expect(_versionAt(meta, 0)['version'], '0.0.1');
      expect(_versionAt(meta, 1)['version'], '0.0.3');

      final item = _versionAt(meta, 2);
      expect(item['createdAt'], isA<DateTime>());
      item.remove('createdAt');
      expect(
        const DeepCollectionEquality().equals(item, {
          'version': version,
          'pubspecYaml': await readFile(package0, version, 'pubspec.yaml'),
          'pubspec':
              loadYamlAsMap(await readFile(package0, version, 'pubspec.yaml')),
          'uploader': email0,
        }),
        true,
      );
    });
  });

  group('get versions', () {
    setUpAll(() async {
      await cleanUpDb();
      server = await createServer(email0);
      await pubPublish(package0, '0.0.1');
      await pubPublish(package0, '0.0.2');
    });

    tearDownAll(() async {
      await server.close();
    });

    test('existing at local', () async {
      final res = await getVersions(package0);
      expect(res.statusCode, HttpStatus.ok);

      final body = json.decode(res.body) as Map<String, dynamic>;
      expect(
        const DeepCollectionEquality().equals(body, {
          'name': 'package_0',
          'latest': {
            'archive_url':
                '$pubHostedUrl/packages/package_0/versions/0.0.2.tar.gz',
            'pubspec': loadYamlAsMap(
                await readFile('package_0', '0.0.2', 'pubspec.yaml')),
            'version': '0.0.2'
          },
          'versions': [
            {
              'archive_url':
                  '$pubHostedUrl/packages/package_0/versions/0.0.1.tar.gz',
              'pubspec': loadYamlAsMap(
                  await readFile('package_0', '0.0.1', 'pubspec.yaml')),
              'version': '0.0.1'
            },
            {
              'archive_url':
                  '$pubHostedUrl/packages/package_0/versions/0.0.2.tar.gz',
              'pubspec': loadYamlAsMap(
                  await readFile('package_0', '0.0.2', 'pubspec.yaml')),
              'version': '0.0.2'
            }
          ]
        }),
        true,
      );
    });

    test('existing at remote', () async {
      const name = 'http';
      final res = await getVersions(name);
      expect(res.statusCode, HttpStatus.ok);

      final body = json.decode(res.body) as Map<String, dynamic>;
      expect(body['name'], name);
    });

    test('not existing', () async {
      final res = await getVersions(notExistingPacakge);
      expect(res.statusCode, HttpStatus.notFound);
    });
  });

  group('get specific version', () {
    setUpAll(() async {
      await cleanUpDb();
      server = await createServer(email0);
      await pubPublish(package0, '0.0.1');
      await pubPublish(package0, '0.0.3+1');
    });

    tearDownAll(() async {
      await server.close();
    });

    test('existing at local', () async {
      final res = await getSpecificVersion(package0, '0.0.1');
      expect(res.statusCode, HttpStatus.ok);

      final body = json.decode(res.body) as Map<String, dynamic>;
      expect(
        const DeepCollectionEquality().equals(body, {
          'archive_url':
              '$pubHostedUrl/packages/package_0/versions/0.0.1.tar.gz',
          'pubspec': loadYamlAsMap(
              await readFile('package_0', '0.0.1', 'pubspec.yaml')),
          'version': '0.0.1'
        }),
        true,
      );
    });

    test('decode version correctly', () async {
      final res = await getSpecificVersion(package0, '0.0.3+1');
      expect(res.statusCode, HttpStatus.ok);

      final body = json.decode(res.body) as Map<String, dynamic>;
      expect(
        const DeepCollectionEquality().equals(body, {
          'archive_url':
              '$pubHostedUrl/packages/package_0/versions/0.0.3+1.tar.gz',
          'pubspec': loadYamlAsMap(
              await readFile('package_0', '0.0.3+1', 'pubspec.yaml')),
          'version': '0.0.3+1'
        }),
        true,
      );
    });

    test('not existing version at local', () async {
      final res = await getSpecificVersion(package0, '0.0.2');
      expect(res.statusCode, HttpStatus.notFound);
    });

    test('existing at remote', () async {
      final res = await getSpecificVersion('http', '0.12.0+2');
      expect(res.statusCode, HttpStatus.ok);

      final body = json.decode(res.body) as Map<String, dynamic>;
      expect(body['version'], '0.12.0+2');
    });

    test('not existing', () async {
      final res = await getSpecificVersion(notExistingPacakge, '0.0.1');
      expect(res.statusCode, HttpStatus.notFound);
    });
  });

  group('uploader', () {
    setUpAll(() async {
      await cleanUpDb();
      server = await createServer(email0);
      await pubPublish(package0, '0.0.1');
    });

    tearDownAll(() async {
      await server.close();
    });

    group('add', () {
      test('already exists', () async {
        final result = await pubUploader(package0, 'add', email0);
        expect(result.stderr, contains('email already exists'));

        final meta = await readMeta(package0);
        expect(meta['uploaders'], unorderedEquals([email0]));
      });

      test('success', () async {
        var result = await pubUploader(package0, 'add', email1);
        expect(result.stderr, '');

        var meta = await readMeta(package0);
        expect(meta['uploaders'], unorderedEquals([email0, email1]));

        result = await pubUploader(package0, 'add', email2);
        expect(result.stderr, '');

        meta = await readMeta(package0);
        expect(meta['uploaders'], unorderedEquals([email0, email1, email2]));
      });
    });

    group('remove', () {
      test('not in uploader', () async {
        final result = await pubUploader(package0, 'remove', email3);
        expect(result.stderr, contains('email not uploader'));

        final meta = await readMeta(package0);
        expect(meta['uploaders'], unorderedEquals([email0, email1, email2]));
      });

      test('success', () async {
        var result = await pubUploader(package0, 'remove', email2);
        expect(result.stderr, '');

        var meta = await readMeta(package0);
        expect(meta['uploaders'], unorderedEquals([email0, email1]));

        result = await pubUploader(package0, 'remove', email1);
        expect(result.stderr, '');

        meta = await readMeta(package0);
        expect(meta['uploaders'], unorderedEquals([email0]));
      });
    });

    group('permission', () {
      setUpAll(() async {
        await server.close();
        server = await createServer(email1);
      });

      tearDownAll(() async {
        await server.close();
      });

      test('add', () async {
        final result = await pubUploader(package0, 'add', email0);
        expect(result.stderr, contains('no permission'));
      });

      test('remove', () async {
        final result = await pubUploader(package0, 'remove', email0);
        expect(result.stderr, contains('no permission'));
      });
    });
  });

  group('badge', () {
    setUpAll(() async {
      await cleanUpDb();
      server = await createServer(email0);
      await pubPublish(package0, '0.0.1');
    });

    tearDownAll(() async {
      await server.close();
    });

    group('v', () {
      test('<1.0.0', () async {
        final res = await http.Client().send(
            http.Request('GET', baseUri.resolve('/badge/v/$package0'))
              ..followRedirects = false);
        expect(res.statusCode, HttpStatus.found);
        expect(res.headers[HttpHeaders.locationHeader],
            'https://img.shields.io/static/v1?label=unpub&message=0.0.1&color=orange');
      });

      test('>=1.0.0', () async {
        await pubPublish(package0, '1.0.0');

        final res = await http.Client().send(
            http.Request('GET', baseUri.resolve('/badge/v/$package0'))
              ..followRedirects = false);
        expect(res.statusCode, HttpStatus.found);
        expect(res.headers[HttpHeaders.locationHeader],
            'https://img.shields.io/static/v1?label=unpub&message=1.0.0&color=blue');
      });

      test('package not exists', () async {
        final res =
            await http.get(baseUri.resolve('/badge/v/$notExistingPacakge'));
        expect(res.statusCode, HttpStatus.notFound);
      });
    });

    group('d', () {
      test('correct download count', () async {
        final res = await http.Client().send(
            http.Request('GET', baseUri.resolve('/badge/d/$package0'))
              ..followRedirects = false);
        expect(res.statusCode, HttpStatus.found);
        expect(res.headers[HttpHeaders.locationHeader],
            'https://img.shields.io/static/v1?label=downloads&message=0&color=blue');
      });

      test('package not exists', () async {
        final res =
            await http.get(baseUri.resolve('/badge/d/$notExistingPacakge'));
        expect(res.statusCode, HttpStatus.notFound);
      });
    });
  });
}
