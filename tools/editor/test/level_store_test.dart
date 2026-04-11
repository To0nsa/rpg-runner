import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:runner_editor/src/levels/level_store.dart';
import 'package:runner_editor/src/workspace/editor_workspace.dart';

void main() {
  test('load/save round-trips level defs deterministically', () async {
    final fixtureRoot = await _createFixtureWorkspace();
    try {
      final workspace = EditorWorkspace(rootPath: fixtureRoot.path);
      const store = LevelStore();
      final loaded = await store.load(
        workspace,
        preferredActiveLevelId: 'field',
      );

      expect(loaded.levels, hasLength(2));
      expect(loaded.activeLevelId, 'field');
      expect(loaded.availableParallaxThemeIds, <String>['field', 'forest']);
      expect(loaded.authoredChunkCountsByLevelId['field'], 1);

      final edited = loaded.copyWith(
        levels: loaded.levels
            .map(
              (level) => level.levelId == 'field'
                  ? level.copyWith(
                      displayName: 'Sunny Field',
                      themeId: 'forest',
                      revision: level.revision + 1,
                    )
                  : level,
            )
            .toList(growable: false),
      );
      final savePlan = store.buildSavePlan(workspace, document: edited);

      expect(savePlan.hasChanges, isTrue);
      expect(savePlan.changedLevelIds, contains('field'));
      await store.save(workspace, document: edited, savePlan: savePlan);

      final savedRaw = File(
        p.join(fixtureRoot.path, LevelStore.defsPath),
      ).readAsStringSync();
      expect(savedRaw.endsWith('\n'), isTrue);
      expect(savedRaw, contains('"displayName": "Sunny Field"'));
      expect(savedRaw, contains('"themeId": "forest"'));

      final reloaded = await store.load(
        workspace,
        preferredActiveLevelId: 'field',
      );
      final field = reloaded.levels.firstWhere(
        (level) => level.levelId == 'field',
      );
      expect(field.displayName, 'Sunny Field');
      expect(field.themeId, 'forest');
    } finally {
      fixtureRoot.deleteSync(recursive: true);
    }
  });

  test('save fails when source drift is detected', () async {
    final fixtureRoot = await _createFixtureWorkspace();
    try {
      final workspace = EditorWorkspace(rootPath: fixtureRoot.path);
      const store = LevelStore();
      final loaded = await store.load(
        workspace,
        preferredActiveLevelId: 'field',
      );
      final edited = loaded.copyWith(
        levels: loaded.levels
            .map(
              (level) => level.levelId == 'field'
                  ? level.copyWith(revision: level.revision + 1)
                  : level,
            )
            .toList(growable: false),
      );
      final savePlan = store.buildSavePlan(workspace, document: edited);

      File(
        p.join(fixtureRoot.path, LevelStore.defsPath),
      ).writeAsStringSync('{}\n');

      await expectLater(
        store.save(workspace, document: edited, savePlan: savePlan),
        throwsA(isA<StateError>()),
      );
    } finally {
      fixtureRoot.deleteSync(recursive: true);
    }
  });
}

Future<Directory> _createFixtureWorkspace() async {
  final root = await Directory.systemTemp.createTemp('level_store_fixture_');
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
  _writeFile(root.path, 'assets/authoring/level/parallax_defs.json', '''
{
  "schemaVersion": 1,
  "themes": [
    {
      "themeId": "field",
      "revision": 1,
      "groundMaterialAssetPath": "assets/images/parallax/field/ground.png",
      "layers": []
    },
    {
      "themeId": "forest",
      "revision": 1,
      "groundMaterialAssetPath": "assets/images/parallax/forest/ground.png",
      "layers": []
    }
  ]
}
''');
  _writeFile(
    root.path,
    'assets/authoring/level/chunks/field/chunk_field_001.json',
    '''
{
  "levelId": "field"
}
''',
  );
  return root;
}

void _writeFile(String rootPath, String relativePath, String content) {
  final absolutePath = p.join(rootPath, relativePath);
  final file = File(absolutePath);
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(content.trimLeft());
}
