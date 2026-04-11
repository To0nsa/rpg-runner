import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'editor_workspace.dart';

/// Shared file IO helpers for editor stores that write repository-backed
/// authoring content.
final class WorkspaceFileIo {
  WorkspaceFileIo._();

  static String toWorkspaceRelativePath(
    EditorWorkspace workspace,
    String absolutePath,
  ) {
    final normalizedAbsolute = p.normalize(absolutePath);
    final normalizedRoot = p.normalize(workspace.rootPath);
    if (p.isWithin(normalizedRoot, normalizedAbsolute)) {
      return p.normalize(p.relative(normalizedAbsolute, from: normalizedRoot));
    }
    return normalizedAbsolute;
  }

  static String fingerprint(String input) {
    const int offsetBasis = 0x811C9DC5;
    const int prime = 0x01000193;
    var hash = offsetBasis;
    final bytes = utf8.encode(input);
    for (final value in bytes) {
      hash ^= value;
      hash = (hash * prime) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  static void atomicWrite(File targetFile, String content) {
    final parent = targetFile.parent;
    if (!parent.existsSync()) {
      parent.createSync(recursive: true);
    }

    final tempFile = File('${targetFile.path}.tmp');
    final backupFile = File('${targetFile.path}.bak.tmp');
    final hadOriginal = targetFile.existsSync();

    if (tempFile.existsSync()) {
      tempFile.deleteSync();
    }
    if (backupFile.existsSync()) {
      backupFile.deleteSync();
    }

    tempFile.writeAsStringSync(content);
    try {
      if (hadOriginal) {
        targetFile.renameSync(backupFile.path);
      }
      tempFile.renameSync(targetFile.path);
      if (backupFile.existsSync()) {
        backupFile.deleteSync();
      }
    } on Object {
      if (tempFile.existsSync()) {
        tempFile.deleteSync();
      }
      if (backupFile.existsSync()) {
        if (targetFile.existsSync()) {
          targetFile.deleteSync();
        }
        backupFile.renameSync(targetFile.path);
      }
      rethrow;
    }
  }
}
