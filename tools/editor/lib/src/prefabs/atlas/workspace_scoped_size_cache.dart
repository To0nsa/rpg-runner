import 'dart:ui' show Size;

import 'package:path/path.dart' as p;

/// Stores atlas image sizes keyed by source path and resets when workspace
/// root changes to avoid cross-workspace stale cache usage.
class WorkspaceScopedSizeCache {
  String? _workspacePath;
  final Map<String, Size> _sizesBySourcePath = <String, Size>{};

  /// Switches cache scope to [workspacePath], clearing data on change.
  void ensureWorkspace(String workspacePath) {
    final normalizedWorkspacePath = _normalizePathForCache(workspacePath);
    if (_workspacePath == normalizedWorkspacePath) {
      return;
    }
    _workspacePath = normalizedWorkspacePath;
    _sizesBySourcePath.clear();
  }

  /// Returns whether a normalized source path already has a cached size.
  bool containsKey(String sourcePath) {
    final normalizedSourcePath = _normalizePathForCache(sourcePath);
    return _sizesBySourcePath.containsKey(normalizedSourcePath);
  }

  /// Reads a cached size for [sourcePath] after path normalization.
  Size? operator [](String sourcePath) {
    final normalizedSourcePath = _normalizePathForCache(sourcePath);
    return _sizesBySourcePath[normalizedSourcePath];
  }

  /// Stores a size for [sourcePath] after path normalization.
  void operator []=(String sourcePath, Size size) {
    final normalizedSourcePath = _normalizePathForCache(sourcePath);
    _sizesBySourcePath[normalizedSourcePath] = size;
  }

  /// Exposes an immutable snapshot for validation consumers.
  Map<String, Size> snapshot() {
    return Map<String, Size>.unmodifiable(_sizesBySourcePath);
  }

  /// Normalizes path separators and casing so key lookups are stable across
  /// OS-specific path styles.
  String _normalizePathForCache(String rawPath) {
    final normalized = p.normalize(rawPath);
    if (p.context.style == p.Style.windows) {
      return normalized.toLowerCase();
    }
    return normalized;
  }
}
