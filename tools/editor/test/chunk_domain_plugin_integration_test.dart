import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:runner_editor/src/chunks/chunk_domain_models.dart';
import 'package:runner_editor/src/chunks/chunk_domain_plugin.dart';
import 'package:runner_editor/src/domain/authoring_types.dart';
import 'package:runner_editor/src/workspace/editor_workspace.dart';

void main() {
  test(
    'plugin load/build scene scopes chunks to active level context',
    () async {
      final fixtureRoot = await _createFixtureWorkspace();
      try {
        final workspace = EditorWorkspace(rootPath: fixtureRoot.path);
        final plugin = ChunkDomainPlugin();

        final loaded = await plugin.loadFromRepo(workspace) as ChunkDocument;
        final scene = plugin.buildEditableScene(loaded) as ChunkScene;

        expect(scene.availableLevelIds, <String>['field', 'forest']);
        expect(scene.activeLevelId, 'field');
        expect(scene.chunks, hasLength(1));
        expect(scene.chunks.single.id, 'chunk_a');
        expect(
          scene.sourcePathByChunkKey['chunk_field_001']?.replaceAll('\\', '/'),
          'assets/authoring/level/chunks/chunk_field_001.json',
        );
        expect(
          scene.sourcePathByChunkKey.containsKey('chunk_forest_001'),
          isFalse,
        );
        expect(plugin.validate(loaded), isEmpty);

        final switched =
            plugin.applyEdit(
                  loaded,
                  const AuthoringCommand(
                    kind: 'set_active_level',
                    payload: <String, Object?>{'levelId': 'forest'},
                  ),
                )
                as ChunkDocument;
        expect(switched.activeLevelId, 'forest');
        final switchedScene = plugin.buildEditableScene(switched) as ChunkScene;
        expect(switchedScene.chunks, hasLength(1));
        expect(switchedScene.chunks.single.id, 'chunk_forest');
        final switchedCodes = plugin
            .validate(switched)
            .map((i) => i.code)
            .toSet();
        expect(switchedCodes.contains('active_level_mismatch'), isFalse);

        final rejected =
            plugin.applyEdit(
                  switched,
                  const AuthoringCommand(
                    kind: 'set_active_level',
                    payload: <String, Object?>{'levelId': 'unknown'},
                  ),
                )
                as ChunkDocument;
        expect(rejected.activeLevelId, 'forest');
        final rejectedCodes = plugin
            .validate(rejected)
            .map((i) => i.code)
            .toSet();
        expect(rejectedCodes, contains('set_active_level_invalid'));
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
        final plugin = ChunkDomainPlugin();
        final loaded = await plugin.loadFromRepo(workspace) as ChunkDocument;

        final edited =
            plugin.applyEdit(
                  loaded,
                  const AuthoringCommand(
                    kind: 'update_chunk_metadata',
                    payload: <String, Object?>{
                      'chunkKey': 'chunk_field_001',
                      'tags': 'zzz, aaa',
                    },
                  ),
                )
                as ChunkDocument;
        final pending = plugin.describePendingChanges(
          workspace,
          document: edited,
        );
        expect(pending.hasChanges, isTrue);
        expect(pending.changedEntryIds, contains('chunk_field_001'));
        expect(pending.fileDiffs.single.relativePath, endsWith('.json'));

        final issueCodes = plugin.validate(edited).map((i) => i.code).toList();
        expect(
          issueCodes,
          isEmpty,
          reason:
              'Expected edited chunk document to be exportable: $issueCodes',
        );

        final export = await plugin.exportToRepo(workspace, document: edited);
        expect(export.applied, isTrue);
        expect(export.artifacts, isNotEmpty);
        expect(export.artifacts.single.title, 'chunk_summary.md');

        final chunkPath = p.join(
          fixtureRoot.path,
          'assets/authoring/level/chunks/chunk_field_001.json',
        );
        final saved =
            jsonDecode(File(chunkPath).readAsStringSync())
                as Map<String, Object?>;
        expect(saved['tags'], <String>['aaa', 'zzz']);
        expect(File(chunkPath).readAsStringSync().endsWith('\n'), isTrue);
      } finally {
        fixtureRoot.deleteSync(recursive: true);
      }
    },
  );

  test('plugin export fails deterministically on source drift', () async {
    final fixtureRoot = await _createFixtureWorkspace();
    try {
      final workspace = EditorWorkspace(rootPath: fixtureRoot.path);
      final plugin = ChunkDomainPlugin();
      final loaded = await plugin.loadFromRepo(workspace) as ChunkDocument;

      final edited =
          plugin.applyEdit(
                loaded,
                const AuthoringCommand(
                  kind: 'update_chunk_metadata',
                  payload: <String, Object?>{
                    'chunkKey': 'chunk_field_001',
                    'tags': 'drifted',
                  },
                ),
              )
              as ChunkDocument;

      final chunkPath = p.join(
        fixtureRoot.path,
        'assets/authoring/level/chunks/chunk_field_001.json',
      );
      File(chunkPath).writeAsStringSync(
        File(chunkPath).readAsStringSync().replaceFirst(
          '"id": "chunk_a"',
          '"id": "externally_changed"',
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
  final root = await Directory.systemTemp.createTemp('chunk_plugin_fixture_');
  _writeFile(root.path, 'assets/authoring/level/level_defs.json', '''
{
  "levels": [
    {"id": "field"},
    {"id": "forest"}
  ]
}
''');
  _writeFile(root.path, 'packages/runner_core/lib/levels/level_id.dart', '''
enum LevelId { forest, field }
''');
  _writeFile(root.path, 'packages/runner_core/lib/tuning/track_tuning.dart', '''
class TrackTuning {
  const TrackTuning({
    this.chunkWidth = 600.0,
    this.gridSnap = 16.0,
  });

  final double chunkWidth;
  final double gridSnap;
}
''');
  _writeFile(
    root.path,
    'assets/authoring/level/chunks/chunk_field_001.json',
    '''
{
  "schemaVersion": 1,
  "chunkKey": "chunk_field_001",
  "id": "chunk_a",
  "revision": 1,
  "status": "active",
  "levelId": "field",
  "tileSize": 16,
  "width": 600,
  "height": 160,
  "entrySocket": "in",
  "exitSocket": "out",
  "difficulty": "normal",
  "tags": ["base"],
  "tileLayers": [],
  "prefabs": [],
  "markers": [],
  "groundProfile": {"kind": "flat", "topY": 0},
  "groundGaps": []
}
''',
  );
  _writeFile(
    root.path,
    'assets/authoring/level/chunks/chunk_forest_001.json',
    '''
{
  "schemaVersion": 1,
  "chunkKey": "chunk_forest_001",
  "id": "chunk_forest",
  "revision": 1,
  "status": "active",
  "levelId": "forest",
  "tileSize": 16,
  "width": 600,
  "height": 160,
  "entrySocket": "in",
  "exitSocket": "out",
  "difficulty": "normal",
  "tags": ["forest"],
  "tileLayers": [],
  "prefabs": [],
  "markers": [],
  "groundProfile": {"kind": "flat", "topY": 0},
  "groundGaps": []
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
