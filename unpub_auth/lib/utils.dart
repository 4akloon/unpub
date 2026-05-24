import 'dart:io';
import 'package:http_multi_server/http_multi_server.dart';
import 'package:path/path.dart' as path;

// ignore: avoid_classes_with_only_static_members
class Utils {
  static final credentialsFilePath =
      path.join(Utils.dartConfigDir, 'unpub-credentials.json');

  /// The location for dart-specific configuration.
  static final String dartConfigDir = () {
    String? configDir;
    if (Platform.isLinux) {
      configDir = Platform.environment['XDG_CONFIG_HOME'] ??
          path.join(Platform.environment['HOME']!, '.config');
    } else if (Platform.isWindows) {
      configDir = Platform.environment['APPDATA']!;
    } else if (Platform.isMacOS) {
      configDir = path.join(
          Platform.environment['HOME']!, 'Library', 'Application Support');
    } else {
      configDir = path.join(Platform.environment['HOME'] ?? '', '.config');
    }
    final p = path.join(configDir, 'unpub-auth');
    Directory(p).createSync();
    return p;
  }();

  static Future<HttpServer> bindServer(String host, int port) async {
    final server = host == 'localhost'
        ? await HttpMultiServer.loopback(port)
        : await HttpServer.bind(host, port);
    server.autoCompress = true;
    return server;
  }

  static Map<String, String> queryToMap(String queryList) {
    final map = <String, String>{};
    for (final pair in queryList.split('&')) {
      final split = _split(pair, '=');
      if (split.isEmpty) continue;
      final key = _urlDecode(split[0]);
      final value = split.length > 1 ? _urlDecode(split[1]) : '';
      map[key] = value;
    }
    return map;
  }

  static String _urlDecode(String encoded) =>
      Uri.decodeComponent(encoded.replaceAll('+', ' '));

  static List<String> _split(String toSplit, String pattern) {
    if (toSplit.isEmpty) return <String>[];

    final index = toSplit.indexOf(pattern);
    if (index == -1) return [toSplit];
    return [
      toSplit.substring(0, index),
      toSplit.substring(index + pattern.length)
    ];
  }

  static void stdoutPrint(Object? object) => stdout.write(object);
}
