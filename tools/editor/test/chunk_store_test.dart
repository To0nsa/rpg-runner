import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:runner_editor/src/chunks/chunk_domain_models.dart';
import 'package:runner_editor/src/chunks/chunk_store.dart';
import 'package:runner_editor/src/workspace/editor_workspace.dart';

void main() {
  test('load/save round-trips chunk data deterministically', () async {
    final fixtureRoot = await _createFixtureWorkspace();
    try {
      final workspace = EditorWorkspace(rootPath: fixtureRoot.path);
      const store = ChunkStore();
      final loaded = await store.load(
        workspace,
        preferredActiveLevelId: 'field',
      );

      expect(loaded.chunks, hasLength(1));
      expect(
        loaded.availableLevelIds,
        containsAll(<String>['field', 'forest']),
      );
      expect(loaded.activeLevelId, 'field');
      expect(loaded.runtimeGridSnap, 16.0);
      expect(loaded.runtimeChunkWidth, 600.0);

      final editedChunk = loaded.chunks.single.copyWith(
        tags: const <String>['zzz', 'aaa'],
      );
      final edited = loaded.copyWith(chunks: <LevelChunkDef>[editedChunk]);
      final savePlan = store.buildSavePlan(workspace, document: edited);

      expect(savePlan.hasChanges, isTrue);
      await store.save(workspace, document: edited, savePlan: savePlan);

      final chunkPath = p.join(
        fixtureRoot.path,
        'assets/authoring/level/chunks/chunk_field_001.json',
      );
      final savedJson = jsonDecode(File(chunkPath).readAsStringSync());
      expect(savedJson, isA<Map<String, Object?>>());
      final savedMap = savedJson as Map<String, Object?>;
      expect(savedMap['chunkKey'], 'chunk_field_001');
      expect(savedMap['tags'], <String>['aaa', 'zzz']);
    } finally {
      fixtureRoot.deleteSync(recursive: true);
    }
  });

  test('save fails when source drift is detected', () async {
    final fixtureRoot = await _createFixtureWorkspace();
    try {
      final workspace = EditorWorkspace(rootPath: fixtureRoot.path);
      const store = ChunkStore();
      final loaded = await store.load(
        workspace,
        preferredActiveLevelId: 'field',
      );
      final editedChunk = loaded.chunks.single.copyWith(
        tags: const <String>['changed'],
      );
      final edited = loaded.copyWith(chunks: <LevelChunkDef>[editedChunk]);
      final savePlan = store.buildSavePlan(workspace, document: edited);

      final chunkPath = p.join(
        fixtureRoot.path,
        'assets/authoring/level/chunks/chunk_field_001.json',
      );
      File(chunkPath).writeAsStringSync(
        File(
          chunkPath,
        ).readAsStringSync().replaceFirst('"id": "chunk_a"', '"id": "drifted"'),
      );

      await expectLater(
        store.save(workspace, document: edited, savePlan: savePlan),
        throwsA(isA<StateError>()),
      );
    } finally {
      fixtureRoot.deleteSync(recursive: true);
    }
  });

  test('load reports malformed payload arrays and malformed ground contracts', () async {
    final fixtureRoot = await _createMalformedFixtureWorkspace();
    try {
      final workspace = EditorWorkspace(rootPath: fixtureRoot.path);
      const store = ChunkStore();
      final loaded = await store.load(
        workspace,
        preferredActiveLevelId: 'field',
      );

      expect(loaded.chunks, hasLength(1));
      final codes = loaded.loadIssues.map((issue) => issue.code).toSet();
      expect(codes, contains('malformed_tags_payload_arrays'));
      expect(codes, contains('invalid_ground_profile'));
      expect(codes, contains('malformed_ground_gaps_entries'));
    } finally {
      fixtureRoot.deleteSync(recursive: true);
    }
  });

  test('save plan rejects case-insensitive filename collisions', () async {
    final fixtureRoot = await _createFixtureWorkspace();
    try {
      final workspace = EditorWorkspace(rootPath: fixtureRoot.path);
      const store = ChunkStore();
      const chunkA = LevelChunkDef(
        chunkKey: 'chunk_a',
        id: 'chunk_a',
        revision: 1,
        schemaVersion: 1,
        levelId: 'field',
        tileSize: 16,
        width: 600,
        height: 160,
        entrySocket: 'in',
        exitSocket: 'out',
        difficulty: chunkDifficultyNormal,
        tags: <String>['a'],
        groundProfile: GroundProfileDef(kind: groundProfileKindFlat, topY: 0),
      );
      const chunkB = LevelChunkDef(
        chunkKey: 'CHUNK_A',
        id: 'chunk_b',
        revision: 1,
        schemaVersion: 1,
        levelId: 'field',
        tileSize: 16,
        width: 600,
        height: 160,
        entrySocket: 'in',
        exitSocket: 'out',
        difficulty: chunkDifficultyNormal,
        tags: <String>['b'],
        groundProfile: GroundProfileDef(kind: groundProfileKindFlat, topY: 0),
      );
      const document = ChunkDocument(
        chunks: <LevelChunkDef>[chunkA, chunkB],
        baselineByChunkKey: <String, ChunkSourceBaseline>{},
        availableLevelIds: <String>['field'],
        activeLevelId: 'field',
        levelOptionSource: 'test',
        runtimeGridSnap: 16.0,
        runtimeChunkWidth: 600.0,
      );

      expect(
        () => store.buildSavePlan(workspace, document: document),
        throwsA(isA<StateError>()),
      );
    } finally {
      fixtureRoot.deleteSync(recursive: true);
    }
  });
}

Future<Directory> _createFixtureWorkspace() async {
  final root = await Directory.systemTemp.createTemp('chunk_store_fixture_');
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
  return root;
}

Future<Directory> _createMalformedFixtureWorkspace() async {
  final root = await Directory.systemTemp.createTemp(
    'chunk_store_malformed_fixture_',
  );
  _writeFile(root.path, 'packages/runner_core/lib/levels/level_id.dart', '''
enum LevelId { field }
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
    'assets/authoring/level/chunks/chunk_field_bad.json',
    '''
{
  "schemaVersion": 1,
  "chunkKey": "chunk_field_bad",
  "id": "chunk_bad",
  "revision": 1,
  "status": "active",
  "levelId": "field",
  "tileSize": 16,
  "width": 600,
  "height": 160,
  "entrySocket": "in",
  "exitSocket": "out",
  "difficulty": "normal",
  "tags": "bad",
  "tileLayers": [],
  "prefabs": [],
  "markers": [],
  "groundProfile": "flat",
  "groundGaps": "bad"
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
