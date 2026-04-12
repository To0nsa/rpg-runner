import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:runner_editor/src/workspace/editor_workspace.dart';
import 'package:runner_editor/src/workspace/level_context_resolver.dart';

void main() {
  test(
    'extractLevelVisualThemeIds reads authored mapping from level_defs.json',
    () {
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
      "visualThemeId": "field",
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
      "visualThemeId": "forest",
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
        expect(extractLevelVisualThemeIds(workspace), const <String, String>{
          'field': 'field',
          'forest': 'forest',
        });
      } finally {
        root.deleteSync(recursive: true);
      }
    },
  );

  test('extractLevelChunkThemeGroups resolves default + authored groups', () {
    final root = Directory.systemTemp.createTempSync('level_context_groups_');
    try {
      _writeFile(root.path, 'assets/authoring/level/level_defs.json', '''
{
  "schemaVersion": 1,
  "levels": [
    {
      "levelId": "field",
      "revision": 1,
      "displayName": "Field",
      "visualThemeId": "field",
      "chunkThemeGroups": ["village", "default", "cemetery"],
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
      "visualThemeId": "forest",
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
      expect(extractLevelChunkThemeGroups(workspace), const <String, List<String>>{
        'field': <String>['default', 'cemetery', 'village'],
        'forest': <String>['default'],
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
