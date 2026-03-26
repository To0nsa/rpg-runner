import 'dart:io';

import 'package:path/path.dart' as p;

class EditorWorkspace {
  EditorWorkspace({required String rootPath})
    : rootPath = p.normalize(rootPath);

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
}
