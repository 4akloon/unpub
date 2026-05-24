import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:shelf/shelf.dart';
import 'package:shelf_static/shelf_static.dart';

/// Resolves directories containing Jaspr web assets (source and build output).
List<String> resolveWebAssetDirectories() {
  final cwd = Directory.current.path;
  final candidates = <String>[
    path.normalize(path.join(cwd, 'unpub_web', 'web')),
    path.normalize(path.join(cwd, 'web')),
    path.normalize(
      path.join(
        cwd,
        'unpub_web',
        '.dart_tool',
        'build',
        'generated',
        'unpub_web',
        'web',
      ),
    ),
    path.normalize(
      path.join(
        cwd,
        '.dart_tool',
        'build',
        'generated',
        'unpub_web',
        'web',
      ),
    ),
  ];

  return candidates.where((candidate) => Directory(candidate).existsSync()).toList();
}

/// Serves Jaspr static assets (`styles.css`, `main.clients.dart.js`, etc.).
Handler staticAssetsHandler() {
  final directories = resolveWebAssetDirectories();
  final handlers = directories.map(createStaticHandler).toList();

  return (Request request) async {
    for (final handler in handlers) {
      final response = await handler(request);
      if (response.statusCode != 404) {
        return response;
      }
    }
    return Response.notFound('Not found');
  };
}
