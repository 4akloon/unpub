import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:mongo_dart/mongo_dart.dart';
import 'package:path/path.dart' as path;
import 'package:unpub/unpub.dart' as unpub;

const notExistingPacakge = 'not_existing_package';
final baseDir = path.absolute('unpub-packages');

late String pubHostedUrl;
late Uri baseUri;

const package0 = 'package_0';
const package1 = 'package_1';
const email0 = 'email0@example.com';
const email1 = 'email1@example.com';
const email2 = 'email2@example.com';
const email3 = 'email3@example.com';

Future<HttpServer> createServer(String opEmail) async {
  final db = Db('mongodb://localhost:27017/dart_pub_test');
  await db.open();
  final mongoStore = unpub.MongoStore(db);

  final app = unpub.App(
    metaStore: mongoStore,
    packageStore: unpub.FileStore(baseDir),
    overrideUploaderEmail: opEmail,
  );

  final server = await app.serve('127.0.0.1', 0);
  pubHostedUrl = 'http://127.0.0.1:${server.port}';
  baseUri = Uri.parse(pubHostedUrl);
  return server;
}

Future<http.Response> getVersions(String package) {
  final encodedPackage = Uri.encodeComponent(package);
  return http.get(baseUri.resolve('/api/packages/$encodedPackage'));
}

Future<http.Response> getSpecificVersion(String package, String version) {
  final encodedPackage = Uri.encodeComponent(package);
  final encodedVersion = Uri.encodeComponent(version);
  return http.get(baseUri.resolve('/api/packages/$encodedPackage/versions/$encodedVersion'));
}

Future<ProcessResult> pubPublish(String name, String version) {
  return Process.run(
    'dart',
    ['pub', 'publish', '--force'],
    workingDirectory: path.absolute('test/fixtures', name, version),
    environment: {'PUB_HOSTED_URL': pubHostedUrl},
  );
}

String apiErrorMessage(http.Response response) {
  try {
    final body = json.decode(response.body) as Map<String, dynamic>;
    final error = body['error'];
    if (error is Map) {
      return error['message'] as String? ?? response.body;
    }
  } catch (_) {}
  return response.body;
}

Future<http.Response> addUploader(String name, String email) {
  return http.post(
    baseUri.resolve('/api/packages/${Uri.encodeComponent(name)}/uploaders'),
    body: {'email': email},
  );
}

Future<http.Response> addUploaderRaw(String name, {String? body}) {
  return http.post(
    baseUri.resolve('/api/packages/${Uri.encodeComponent(name)}/uploaders'),
    body: body,
    headers: {HttpHeaders.contentTypeHeader: 'application/x-www-form-urlencoded'},
  );
}

Future<http.Response> removeUploader(String name, String email) {
  return http.delete(
    baseUri.resolve(
      '/api/packages/${Uri.encodeComponent(name)}/uploaders/${Uri.encodeComponent(email)}',
    ),
  );
}
