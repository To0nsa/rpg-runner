import 'package:path/path.dart' as p;

/// Resolves repo-relative editor paths against one workspace root.
///
/// Plugins and stores use this helper instead of joining paths ad hoc so the
/// editor has one consistent workspace-boundary check for repository writes and
/// reads.
///
/// This helper deliberately enforces a lexical path boundary only. It rejects
/// absolute paths and `..` traversals that escape [rootPath], but it does not
/// attempt canonical filesystem identity checks for symlinks or junctions.
///
/// Callers are expected to sanitize UI text before reaching this layer. This
/// class treats the provided path string as an intentional repository-relative
/// path, not as free-form user input to clean up.
class EditorWorkspace {
  EditorWorkspace({required String rootPath})
    : rootPath = p.normalize(p.absolute(rootPath));

  /// Normalized absolute workspace root used as the only allowed path base.
  final String rootPath;

  /// Resolves one relative path inside [rootPath].
  ///
  /// Returns the normalized absolute target path and throws when the input is
  /// absolute or escapes the workspace root.
  String resolve(String relativePath) {
    final normalizedInput = p.normalize(relativePath);
    if (normalizedInput.isEmpty || normalizedInput == '.') {
      // Some workflows address the workspace root itself instead of a child
      // file or directory.
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

  /// Returns whether [absolutePath] is lexically contained by [rootPath].
  ///
  /// This is intentionally a path-based check only; it does not resolve
  /// symlinks or junctions before deciding containment.
  bool _isWithinRoot(String absolutePath) {
    final normalizedAbsolute = p.normalize(p.absolute(absolutePath));
    return normalizedAbsolute == rootPath ||
        p.isWithin(rootPath, normalizedAbsolute);
  }
}
