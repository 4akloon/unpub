import 'dart:io';

/// Copies the Jaspr client hydration bundle to [web/main.client.dart.js].
///
/// The bundle is produced by `build_runner` via `build_web_compilers` into
/// `.dart_tool/build/generated/<package>/web/main.client.dart.js`.
Future<void> main(List<String> args) async {
  const generatedPath = '.dart_tool/build/generated/unpub_web/web/main.client.dart.js';
  const outputPath = 'web/main.client.dart.js';

  final generated = File(generatedPath);
  if (!generated.existsSync()) {
    stderr.writeln('Missing $generatedPath — run `dart run build_runner build` first.');
    exit(1);
  }

  await generated.copy(outputPath);
  stdout.writeln('Copied $generatedPath -> $outputPath');
}
