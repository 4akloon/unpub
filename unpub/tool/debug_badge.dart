import 'package:http/http.dart' as http;
import 'package:mongo_dart/mongo_dart.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:unpub/unpub.dart' as unpub;

Future<void> main() async {
  final db = Db('mongodb://localhost:27017/dart_pub_test');
  await db.open();
  final app = unpub.App(
    metaStore: unpub.MongoStore(db),
    packageStore: unpub.FileStore('unpub-packages'),
    overrideUploaderEmail: 'test@test.com',
  );

  Future<shelf.Response> inner(shelf.Request request) async {
    print('path="${request.url.path}" segments=${request.url.pathSegments}');
    return app.router.call(request);
  }

  final server = await shelf_io.serve(inner, '127.0.0.1', 0);
  final res = await http.get(Uri.parse('http://127.0.0.1:${server.port}/badge/v/not_existing_package'));
  print('status: ${res.statusCode}');
  await server.close();
  await db.close();
}
