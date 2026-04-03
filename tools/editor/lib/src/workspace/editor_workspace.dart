import 'dart:io';

import 'package:path/path.dart' as p;

class EditorWorkspace {
  EditorWorkspace({required String rootPath})
    : rootPath = p.normalize(p.absolute(rootPath));

  final String rootPath;

  String resolve(String relativePath) {
    final normalizedInput = p.normalize(relativePath.trim());
    if (normalizedInput.isEmpty || normalizedInput == '.') {
      return rootPath;
    }
    if (p.isAbsolute(normalizedInput)) {
      throw ArgumentError.value(
        relativePath,
        'relativePath',
        'Absolute paths are not allowed.',
      );
    }

    final resolved = p.normalize(p.join(rootPath, normalizedInput));
    if (!_isWithinRoot(resolved)) {
      throw ArgumentError.value(
        relativePath,
        'relativePath',
        'Path escapes workspace root.',
      );
    }
    return resolved;
  }

  bool fileExists(String relativePath) {
    return File(resolve(relativePath)).existsSync();
  }

  String fileName(String relativePath) {
    return p.basename(resolve(relativePath));
  }

  bool containsPath(String absoluteOrRelativePath) {
    final normalizedPath = p.isAbsolute(absoluteOrRelativePath)
        ? p.normalize(p.absolute(absoluteOrRelativePath))
        : p.normalize(p.join(rootPath, absoluteOrRelativePath));
    return _isWithinRoot(normalizedPath);
  }

  String toWorkspaceRelativePath(String absolutePath) {
    final normalizedAbsolute = p.normalize(p.absolute(absolutePath));
    if (!_isWithinRoot(normalizedAbsolute)) {
      throw ArgumentError.value(
        absolutePath,
        'absolutePath',
        'Path is outside workspace root.',
      );
    }
    return p.normalize(p.relative(normalizedAbsolute, from: rootPath));
  }

  bool _isWithinRoot(String absolutePath) {
    final normalizedAbsolute = p.normalize(p.absolute(absolutePath));
    return normalizedAbsolute == rootPath ||
        p.isWithin(rootPath, normalizedAbsolute);
  }
}
