import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:mongo_dart/mongo_dart.dart';
import 'package:path/path.dart' as path;
import 'package:unpub/unpub.dart' as unpub;

const notExistingPacakge = 'not_existing_package';
final baseDir = path.absolute('unpub-packages');
const pubHostedUrl = 'http://localhost:4000';
final baseUri = Uri.parse(pubHostedUrl);

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

  final server = await app.serve('0.0.0.0', 4000);
  return server;
}

Future<http.Response> getVersions(String package) {
  package = Uri.encodeComponent(package);
  return http.get(baseUri.resolve('/api/packages/$package'));
}

Future<http.Response> getSpecificVersion(String package, String version) {
  package = Uri.encodeComponent(package);
  version = Uri.encodeComponent(version);
  return http.get(baseUri.resolve('/api/packages/$package/versions/$version'));
}

Future<ProcessResult> pubPublish(String name, String version) {
  return Process.run('dart', ['pub', 'publish', '--force'],
      workingDirectory: path.absolute('test/fixtures', name, version),
      environment: {'PUB_HOSTED_URL': pubHostedUrl});
}

Future<ProcessResult> pubUploader(String name, String operation, String email) {
  assert(['add', 'remove'].contains(operation), 'operation error');

  return Process.run('dart', ['pub', 'uploader', operation, email],
      workingDirectory: path.absolute('test/fixtures', name, '0.0.1'),
      environment: {'PUB_HOSTED_URL': pubHostedUrl});
}
