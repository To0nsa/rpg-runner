import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:runner_editor/src/domain/authoring_types.dart';
import 'package:runner_editor/src/levels/level_domain_models.dart';
import 'package:runner_editor/src/levels/level_domain_plugin.dart';
import 'package:runner_editor/src/workspace/editor_workspace.dart';

void main() {
  test(
    'plugin load/build scene keeps level order and active selection coherent',
    () async {
      final fixtureRoot = await _createFixtureWorkspace();
      try {
        final workspace = EditorWorkspace(rootPath: fixtureRoot.path);
        final plugin = LevelDomainPlugin();

        final loaded =
            await plugin.loadFromRepo(workspace) as LevelDefsDocument;
        final scene = plugin.buildEditableScene(loaded) as LevelScene;

        expect(scene.activeLevelId, 'forest');
        expect(
          scene.levels.map((level) => level.levelId).toList(growable: false),
          <String>['forest', 'field'],
        );
        expect(scene.authoredChunkCountsByLevelId['forest'], 1);
        expect(plugin.validate(loaded), isEmpty);

        final switched =
            plugin.applyEdit(
                  loaded,
                  AuthoringCommand(
                    kind: 'set_active_level',
                    payload: const <String, Object?>{'levelId': 'field'},
                  ),
                )
                as LevelDefsDocument;
        expect(switched.activeLevelId, 'field');
      } finally {
        fixtureRoot.deleteSync(recursive: true);
      }
    },
  );

  test(
    'plugin pending changes and export direct write are deterministic',
    () async {
      final fixtureRoot = await _createFixtureWorkspace();
      try {
        final workspace = EditorWorkspace(rootPath: fixtureRoot.path);
        final plugin = LevelDomainPlugin();
        final loaded =
            await plugin.loadFromRepo(workspace) as LevelDefsDocument;

        final edited =
            plugin.applyEdit(
                  loaded,
                  AuthoringCommand(
                    kind: 'update_level',
                    payload: const <String, Object?>{
                      'levelId': 'field',
                      'displayName': 'Field Updated',
                      'themeId': 'forest',
                    },
                  ),
                )
                as LevelDefsDocument;
        final pending = plugin.describePendingChanges(
          workspace,
          document: edited,
        );
        expect(pending.hasChanges, isTrue);
        expect(pending.changedItemIds, contains('field'));
        expect(pending.fileDiffs.single.relativePath, levelDefsSourcePath);

        final issueCodes = plugin
            .validate(edited)
            .map((issue) => issue.code)
            .toList();
        expect(
          issueCodes,
          isEmpty,
          reason: 'Expected exportable level document.',
        );

        final export = await plugin.exportToRepo(workspace, document: edited);
        expect(export.applied, isTrue);
        expect(export.artifacts.single.title, 'level_summary.md');

        final saved = File(
          p.join(fixtureRoot.path, levelDefsSourcePath),
        ).readAsStringSync();
        expect(saved, contains('"displayName": "Field Updated"'));
        expect(saved, contains('"themeId": "forest"'));
        expect(saved.endsWith('\n'), isTrue);
      } finally {
        fixtureRoot.deleteSync(recursive: true);
      }
    },
  );

  test('plugin export fails deterministically on source drift', () async {
    final fixtureRoot = await _createFixtureWorkspace();
    try {
      final workspace = EditorWorkspace(rootPath: fixtureRoot.path);
      final plugin = LevelDomainPlugin();
      final loaded = await plugin.loadFromRepo(workspace) as LevelDefsDocument;

      final edited =
          plugin.applyEdit(
                loaded,
                AuthoringCommand(
                  kind: 'update_level',
                  payload: const <String, Object?>{
                    'levelId': 'field',
                    'displayName': 'Field Drifted',
                  },
                ),
              )
              as LevelDefsDocument;

      final defsPath = p.join(fixtureRoot.path, levelDefsSourcePath);
      File(defsPath).writeAsStringSync(
        File(defsPath).readAsStringSync().replaceFirst(
          '"displayName": "Field"',
          '"displayName": "Changed Externally"',
        ),
      );

      await expectLater(
        plugin.exportToRepo(workspace, document: edited),
        throwsA(isA<StateError>()),
      );
    } finally {
      fixtureRoot.deleteSync(recursive: true);
    }
  });
}

Future<Directory> _createFixtureWorkspace() async {
  final root = await Directory.systemTemp.createTemp('level_plugin_fixture_');
  _writeFile(root.path, levelDefsSourcePath, '''
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
    '{"levelId":"field"}\n',
  );
  _writeFile(
    root.path,
    'assets/authoring/level/chunks/forest/chunk_forest_001.json',
    '{"levelId":"forest"}\n',
  );
  return root;
}

void _writeFile(String rootPath, String relativePath, String content) {
  final absolutePath = p.join(rootPath, relativePath);
  final file = File(absolutePath);
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(content.trimLeft());
}
