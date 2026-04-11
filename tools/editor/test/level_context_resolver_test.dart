import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:runner_editor/src/workspace/editor_workspace.dart';
import 'package:runner_editor/src/workspace/level_context_resolver.dart';

void main() {
  test('extractLevelThemeIds reads authored mapping from level_defs.json', () {
    final root = Directory.systemTemp.createTempSync('level_context_');
    try {
      _writeFile(root.path, 'assets/authoring/level/level_defs.json', '''
{
  "schemaVersion": 1,
  "levels": [
    {
      "levelId": "field",
      "revision": 1,
      "displayName": "Field",
      "themeId": "field",
      "cameraCenterY": 135,
      "groundTopY": 224,
      "earlyPatternChunks": 3,
      "easyPatternChunks": 0,
      "normalPatternChunks": 0,
      "noEnemyChunks": 3,
      "enumOrdinal": 20,
      "status": "active"
    },
    {
      "levelId": "forest",
      "revision": 1,
      "displayName": "Forest",
      "themeId": "forest",
      "cameraCenterY": 135,
      "groundTopY": 224,
      "earlyPatternChunks": 3,
      "easyPatternChunks": 0,
      "normalPatternChunks": 0,
      "noEnemyChunks": 3,
      "enumOrdinal": 10,
      "status": "active"
    }
  ]
}
''');

      final workspace = EditorWorkspace(rootPath: root.path);
      expect(extractLevelThemeIds(workspace), const <String, String>{
        'field': 'field',
        'forest': 'forest',
      });
    } finally {
      root.deleteSync(recursive: true);
    }
  });
}

void _writeFile(String rootPath, String relativePath, String content) {
  final file = File(p.join(rootPath, relativePath));
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(content.trimLeft());
}
