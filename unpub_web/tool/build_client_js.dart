import 'dart:io';

/// Builds the Jaspr client hydration bundle into [web/main.clients.dart.js].
Future<void> main(List<String> args) async {
  final result = await Process.run(
    'dart',
    [
      'compile',
      'js',
      'web/main.clients.dart',
      '-o',
      'web/main.clients.dart.js',
    ],
    runInShell: true,
  );

  stdout.write(result.stdout);
  stderr.write(result.stderr);

  if (result.exitCode != 0) {
    exit(result.exitCode);
  }
}
