import 'dart:io';

import 'package:path/path.dart' as p;

class EditorWorkspace {
  EditorWorkspace({required String rootPath})
    : rootPath = _normalizeWorkspaceRoot(rootPath);

  final String rootPath;

  String resolve(String relativePath) {
    return p.normalize(p.join(rootPath, relativePath));
  }

  bool fileExists(String relativePath) {
    return File(resolve(relativePath)).existsSync();
  }

  String fileName(String relativePath) {
    return p.basename(resolve(relativePath));
  }

  static String _normalizeWorkspaceRoot(String rawPath) {
    final candidate = p.normalize(rawPath);
    var current = candidate;
    while (true) {
      if (_looksLikeRepoRoot(current)) {
        return current;
      }
      final parent = p.dirname(current);
      if (parent == current) {
        return candidate;
      }
      current = parent;
    }
  }

  static bool _looksLikeRepoRoot(String path) {
    final enemyCatalog = File(
      p.join(
        path,
        'packages',
        'runner_core',
        'lib',
        'enemies',
        'enemy_catalog.dart',
      ),
    );
    final projectileCatalog = File(
      p.join(
        path,
        'packages',
        'runner_core',
        'lib',
        'projectiles',
        'projectile_catalog.dart',
      ),
    );
    return enemyCatalog.existsSync() && projectileCatalog.existsSync();
  }
}
