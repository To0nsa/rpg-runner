import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:runner_editor/src/workspace/editor_workspace.dart';
import 'package:runner_editor/src/workspace/repository_png_catalog.dart';

void main() {
  test('discovers sorted unique PNG paths and reads valid dimensions', () {
    final root = Directory.systemTemp.createTempSync('png_catalog_');
    addTearDown(() => root.deleteSync(recursive: true));
    final imageDirectory = Directory(
      '${root.path}${Platform.pathSeparator}assets${Platform.pathSeparator}images',
    )..createSync(recursive: true);
    File(
      '${imageDirectory.path}${Platform.pathSeparator}b.PNG',
    ).writeAsBytesSync(_pngHeader(width: 64, height: 32));
    File(
      '${imageDirectory.path}${Platform.pathSeparator}a.png',
    ).writeAsBytesSync(<int>[1, 2, 3]);
    File(
      '${imageDirectory.path}${Platform.pathSeparator}ignored.jpg',
    ).writeAsBytesSync(<int>[1, 2, 3]);

    final images = const RepositoryPngCatalog().discoverSync(
      EditorWorkspace(rootPath: root.path),
      roots: const <String>['assets', 'assets/images'],
    );

    expect(images.map((image) => image.relativePath), <String>[
      'assets/images/a.png',
      'assets/images/b.PNG',
    ]);
    expect(images.first.hasValidDimensions, isFalse);
    expect((images.last.width, images.last.height), (64, 32));
  });
}

List<int> _pngHeader({required int width, required int height}) {
  final bytes = List<int>.filled(24, 0);
  bytes.setRange(0, 8, const <int>[137, 80, 78, 71, 13, 10, 26, 10]);
  void writeUint32(int offset, int value) {
    bytes[offset] = (value >> 24) & 0xFF;
    bytes[offset + 1] = (value >> 16) & 0xFF;
    bytes[offset + 2] = (value >> 8) & 0xFF;
    bytes[offset + 3] = value & 0xFF;
  }

  writeUint32(16, width);
  writeUint32(20, height);
  return bytes;
}
