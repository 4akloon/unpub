import 'dart:io';

import 'package:args/args.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:path/path.dart' as path;
import 'package:unpub/unpub.dart' as unpub;

Future<void> main(List<String> args) async {
  final parser = ArgParser();
  parser.addOption('host', abbr: 'h', defaultsTo: '0.0.0.0');
  parser.addOption('port', abbr: 'p', defaultsTo: '4000');
  parser.addOption(
    'database',
    abbr: 'd',
    defaultsTo: 'mongodb://localhost:27017/dart_pub',
  );
  parser.addOption('proxy-origin', abbr: 'o', defaultsTo: '');

  final results = parser.parse(args);

  final host = results['host'] as String;
  final portStr =
      Platform.environment['JASPR_SERVER_PORT'] ?? results['port'] as String;
  final port = int.parse(portStr);
  final dbUri = results['database'] as String;
  final proxyOrigin = results['proxy-origin'] as String;

  final db = Db(dbUri);
  try {
    await db.open();
  } on ConnectionException {
    stderr.writeln('Could not connect to MongoDB at $dbUri');
    stderr.writeln('Start local MongoDB with: make dev-deps');
    exit(1);
  }

  // Adjust path since it's running inside unpub_web?
  // Wait, if it's running in unpub_web, unpub-packages should probably be in root
  final baseDir = path.absolute('../unpub-packages');

  final app = unpub.App(
    metaStore: unpub.MongoStore(db),
    packageStore: unpub.FileStore(baseDir),
    proxyOrigin: proxyOrigin.trim().isEmpty ? null : Uri.parse(proxyOrigin),
    overrideUploaderEmail: Platform.environment['UPLOADER_EMAIL'],
  );

  try {
    final server = await app.serve(host, port);
    print('Serving at http://${server.address.host}:${server.port}');
  } on SocketException catch (error) {
    if (error.osError?.errorCode == 48) {
      stderr.writeln('Port $port is already in use.');
      stderr.writeln(
        'Try another port: dart run bin/unpub.server.dart -p ${port + 1}',
      );
    }
    rethrow;
  }
}
