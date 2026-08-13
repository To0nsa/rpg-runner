import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import 'editor_workspace.dart';

/// One repository PNG and its dimensions when its header is valid.
final class RepositoryPngImage {
  const RepositoryPngImage({
    required this.relativePath,
    required this.width,
    required this.height,
  });

  final String relativePath;
  final int? width;
  final int? height;

  bool get hasValidDimensions => width != null && height != null;
}

/// Shared repository PNG discovery and header metadata reader.
///
/// Domain plugins choose the roots they own. Paths are returned with forward
/// slashes and deterministic ordering, while image contents remain untouched.
final class RepositoryPngCatalog {
  const RepositoryPngCatalog();

  Future<List<RepositoryPngImage>> discover(
    EditorWorkspace workspace, {
    required Iterable<String> roots,
  }) async {
    final paths = await _discoverPaths(workspace, roots: roots);
    final images = <RepositoryPngImage>[];
    for (final relativePath in paths) {
      final dimensions = await readDimensions(
        File(workspace.resolve(relativePath)),
      );
      images.add(
        RepositoryPngImage(
          relativePath: relativePath,
          width: dimensions?.width,
          height: dimensions?.height,
        ),
      );
    }
    return List<RepositoryPngImage>.unmodifiable(images);
  }

  /// Synchronous counterpart for Flutter widget tests running under fake time.
  List<RepositoryPngImage> discoverSync(
    EditorWorkspace workspace, {
    required Iterable<String> roots,
  }) {
    final paths = _discoverPathsSync(workspace, roots: roots);
    return List<RepositoryPngImage>.unmodifiable(<RepositoryPngImage>[
      for (final relativePath in paths)
        _imageWithSyncDimensions(workspace, relativePath),
    ]);
  }

  Future<RepositoryImageDimensions?> readDimensions(File file) async {
    if (!await file.exists()) return null;
    final handle = await file.open(mode: FileMode.read);
    try {
      return _dimensionsFromHeader(await handle.read(24));
    } finally {
      await handle.close();
    }
  }

  RepositoryImageDimensions? readDimensionsSync(File file) {
    if (!file.existsSync()) return null;
    final handle = file.openSync(mode: FileMode.read);
    try {
      return _dimensionsFromHeader(handle.readSync(24));
    } finally {
      handle.closeSync();
    }
  }

  Future<List<String>> _discoverPaths(
    EditorWorkspace workspace, {
    required Iterable<String> roots,
  }) async {
    final paths = <String>{};
    for (final root in roots) {
      final directory = Directory(workspace.resolve(root));
      if (!await directory.exists()) continue;
      await for (final entity in directory.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is File &&
            p.extension(entity.path).toLowerCase() == '.png') {
          paths.add(_relativePath(workspace, entity.path));
        }
      }
    }
    return paths.toList(growable: false)..sort();
  }

  List<String> _discoverPathsSync(
    EditorWorkspace workspace, {
    required Iterable<String> roots,
  }) {
    final paths = <String>{};
    for (final root in roots) {
      final directory = Directory(workspace.resolve(root));
      if (!directory.existsSync()) continue;
      for (final entity in directory.listSync(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is File &&
            p.extension(entity.path).toLowerCase() == '.png') {
          paths.add(_relativePath(workspace, entity.path));
        }
      }
    }
    return paths.toList(growable: false)..sort();
  }

  RepositoryPngImage _imageWithSyncDimensions(
    EditorWorkspace workspace,
    String relativePath,
  ) {
    final dimensions = readDimensionsSync(
      File(workspace.resolve(relativePath)),
    );
    return RepositoryPngImage(
      relativePath: relativePath,
      width: dimensions?.width,
      height: dimensions?.height,
    );
  }

  String _relativePath(EditorWorkspace workspace, String absolutePath) => p
      .normalize(p.relative(absolutePath, from: workspace.rootPath))
      .replaceAll('\\', '/');

  RepositoryImageDimensions? _dimensionsFromHeader(Uint8List bytes) {
    if (bytes.length < 24 || !_hasPngSignature(bytes)) return null;
    final width = _readUint32BigEndian(bytes, 16);
    final height = _readUint32BigEndian(bytes, 20);
    if (width <= 0 || height <= 0) return null;
    return RepositoryImageDimensions(width: width, height: height);
  }

  bool _hasPngSignature(Uint8List bytes) {
    const signature = <int>[137, 80, 78, 71, 13, 10, 26, 10];
    for (var index = 0; index < signature.length; index += 1) {
      if (bytes[index] != signature[index]) return false;
    }
    return true;
  }

  int _readUint32BigEndian(Uint8List bytes, int offset) =>
      (bytes[offset] << 24) |
      (bytes[offset + 1] << 16) |
      (bytes[offset + 2] << 8) |
      bytes[offset + 3];
}

/// Positive PNG dimensions read from its IHDR header.
final class RepositoryImageDimensions {
  const RepositoryImageDimensions({required this.width, required this.height});

  final int width;
  final int height;
}
