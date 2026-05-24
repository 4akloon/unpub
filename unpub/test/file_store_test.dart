import 'dart:io';

import 'package:chunked_stream/chunked_stream.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';
import 'package:unpub/unpub.dart' as unpub;

// test gzip data
const testPkgData = [
  0x8b, 0x1f, 0x00, 0x08, 0x00, 0x00, 0x00, 0x00, 0x03, //
  0x02, 0x00, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 //
];

void main() {
  test('upload-download-default-path', () async {
    final baseDir = setupFixture('upload-download-default-path');
    final store = unpub.FileStore(baseDir.path);
    await store.upload('test_package', '1.0.0', testPkgData);
    final pkg2 = await readByteStream(store.download('test_package', '1.0.0'));
    expect(pkg2, testPkgData);
    expect(
        File(path.join(baseDir.path, 'test_package-1.0.0.tar.gz')).existsSync(),
        isTrue);
  });

  test('upload-download-custom-path', () async {
    final baseDir = setupFixture('upload-download-custom-path');
    final store = unpub.FileStore(baseDir.path, getFilePath: newFilePathFunc());
    await store.upload('test_package', '1.0.0', testPkgData);
    final pkg2 = await readByteStream(store.download('test_package', '1.0.0'));
    expect(pkg2, testPkgData);
    expect(
        File(path.join(baseDir.path, 'packages', 't', 'te', 'test_package',
                'versions', 'test_package-1.0.0.tar.gz'))
            .existsSync(),
        isTrue);
  });
}

String Function(String, String) newFilePathFunc() {
  return (String package, String version) {
    final grp = package[0];
    final subgrp = package.substring(0, 2);
    return path.join('packages', grp, subgrp, package, 'versions',
        '$package-$version.tar.gz');
  };
}

Directory setupFixture(final String name) {
  final baseDir =
      Directory(path.absolute('test', 'fixtures', 'file_store', name));
  if (baseDir.existsSync()) {
    baseDir.deleteSync(recursive: true);
  }
  baseDir.createSync();
  return baseDir;
}
