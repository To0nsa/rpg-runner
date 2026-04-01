import 'dart:ui' show Size;

import 'package:path/path.dart' as p;

/// Stores atlas image sizes keyed by source path and resets when workspace
/// root changes to avoid cross-workspace stale cache usage.
class WorkspaceScopedSizeCache {
  String? _workspacePath;
  final Map<String, Size> _sizesBySourcePath = <String, Size>{};

  void ensureWorkspace(String workspacePath) {
    final normalizedWorkspacePath = p.normalize(workspacePath);
    if (_workspacePath == normalizedWorkspacePath) {
      return;
    }
    _workspacePath = normalizedWorkspacePath;
    _sizesBySourcePath.clear();
  }

  bool containsKey(String sourcePath) =>
      _sizesBySourcePath.containsKey(sourcePath);

  Size? operator [](String sourcePath) => _sizesBySourcePath[sourcePath];

  void operator []=(String sourcePath, Size size) {
    _sizesBySourcePath[sourcePath] = size;
  }

  Map<String, Size> snapshot() {
    return Map<String, Size>.unmodifiable(_sizesBySourcePath);
  }
}
