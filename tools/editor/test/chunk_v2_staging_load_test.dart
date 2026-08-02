import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:runner_editor/src/chunks/chunk_domain_models.dart';
import 'package:runner_editor/src/chunks/chunk_domain_plugin.dart';
import 'package:runner_editor/src/chunks/chunk_store.dart';
import 'package:runner_editor/src/chunks/chunk_v2_file_codec.dart';
import 'package:runner_editor/src/chunks/chunk_v2_file_data.dart';
import 'package:runner_editor/src/chunks/chunk_v2_staging_models.dart';
import 'package:runner_editor/src/levels/level_domain_models.dart';
import 'package:runner_editor/src/levels/level_store.dart';
import 'package:runner_editor/src/prefabs/models/models.dart';
import 'package:runner_editor/src/prefabs/store/prefab_store.dart';
import 'package:runner_editor/src/prefabs/store/prefab_tile_file_codec.dart';
import 'package:runner_editor/src/prefabs/store/prefab_v3_file_codec.dart';
import 'package:runner_editor/src/terrain_authoring/terrain_source_models.dart';
import 'package:runner_editor/src/workspace/editor_workspace.dart';

void main() {
  const store = ChunkStore();

  test(
    'explicit staging load composes strict future source and stays read-only',
    () async {
      final fixture = _V2Fixture.create();
      addTearDown(fixture.dispose);
      final plugin = ChunkDomainPlugin();
      final before = fixture.snapshot();

      final storeLoad = await store.loadV2Staging(fixture.workspace);
      expect(storeLoad.sources, hasLength(1));
      expect(storeLoad.sources.single.data.chunkKey, 'forest_test');
      expect(
        storeLoad.sources.single.sourcePath.replaceAll('\\', '/'),
        endsWith('chunks/forest/forest_test.json'),
      );
      expect(storeLoad.sources.single.baselineContents, fixture.chunkContents);

      final document = await plugin.loadV2StagingFromRepo(fixture.workspace);
      expect(document.chunks, hasLength(1));
      expect(document.prefabData.prefabs, isEmpty);
      expect(document.tileData.platformModules, isEmpty);
      expect(document.availableLevelIds, <String>['forest']);
      expect(document.activeLevelId, 'forest');
      expect(document.levels.single.levelId, 'forest');
      expect(document.groundTopYByLevelId, <String, double>{'forest': 224});
      expect(document.visualBoundsByPrefabKey, isEmpty);
      expect(plugin.validate(document), isEmpty);
      final scene = plugin.buildEditableScene(document) as ChunkV2StagingScene;
      expect(scene.seamAnalysis.transitions, hasLength(3));
      expect(scene.seamAnalysis.seams, hasLength(3));
      expect(
        scene.seamAnalysis.seams.every((seam) => seam.comparison.isCompatible),
        isTrue,
      );
      expect(
        plugin
            .describePendingChanges(fixture.workspace, document: document)
            .hasChanges,
        isFalse,
      );

      final result = await plugin.exportToRepo(
        fixture.workspace,
        document: document,
      );
      expect(result.applied, isFalse);
      expect(result.artifacts.single.content, contains('changedFiles: 0'));
      expect(fixture.snapshot(), before);
      expect(() => document.chunks.clear(), throwsUnsupportedError);
      expect(() => document.levels.clear(), throwsUnsupportedError);
      expect(
        () => document.sourcePathByChunkKey.clear(),
        throwsUnsupportedError,
      );
    },
  );

  test('changed staging export fails before any filesystem mutation', () async {
    final fixture = _V2Fixture.create();
    addTearDown(fixture.dispose);
    final plugin = ChunkDomainPlugin();
    final clean = await plugin.loadV2StagingFromRepo(fixture.workspace);
    final changedChunk = clean.chunks.single.copyWith(revision: 2);
    final changed = clean.copyWith(
      chunks: <ChunkV2FileData>[changedChunk],
      changedChunkKeys: const <String>['forest_test'],
    );
    final before = fixture.snapshot();

    final pending = plugin.describePendingChanges(
      fixture.workspace,
      document: changed,
    );
    expect(pending.changedItemIds, <String>['forest_test']);
    expect(pending.fileDiffs, hasLength(1));
    expect(pending.fileDiffs.single.unifiedDiff, contains('"revision": 2'));

    await expectLater(
      plugin.exportToRepo(fixture.workspace, document: changed),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('chunk_v2_source_write_disabled'),
        ),
      ),
    );
    expect(fixture.snapshot(), before);
  });

  test(
    'staging validation reports direct bounds and prefab references',
    () async {
      final fixture = _V2Fixture.create();
      addTearDown(fixture.dispose);
      final plugin = ChunkDomainPlugin();
      final clean = await plugin.loadV2StagingFromRepo(fixture.workspace);
      final invalidChunk = clean.chunks.single.copyWith(
        prefabs: const <PlacedPrefabDef>[
          PlacedPrefabDef(prefabId: 'missing', x: 20, y: 20),
        ],
        collisionShapes: <TerrainSourceShapeDef>[
          _rectangle('ground', left: -2, right: 20, bottom: 20),
        ],
        markers: const <PlacedMarkerDef>[
          PlacedMarkerDef(
            markerId: 'unknown',
            x: -1,
            y: 271,
            chancePercent: 101,
            salt: -1,
            placement: 'unsupported',
          ),
        ],
      );
      final invalid = clean.copyWith(
        chunks: <ChunkV2FileData>[invalidChunk],
        groundTopYByLevelId: const <String, double>{},
      );

      final codes = plugin.validate(invalid).map((issue) => issue.code).toSet();
      expect(codes, contains('chunk_collision_shape_out_of_bounds'));
      expect(codes, contains('unknown_prefab_reference'));
      expect(codes, contains('unknown_enemy_marker_id'));
      expect(codes, contains('marker_invalid_placement'));
      expect(codes, contains('marker_x_out_of_bounds'));
      expect(codes, contains('marker_y_out_of_bounds'));
      expect(codes, contains('marker_chance_out_of_range'));
      expect(codes, contains('marker_salt_negative'));
      expect(codes, contains('marker_level_ground_context_missing'));
    },
  );

  test(
    'normal load remains legacy and explicit staging rejects chunk v1',
    () async {
      final root = Directory.systemTemp.createTempSync('chunk_v1_normal_load_');
      addTearDown(() => root.deleteSync(recursive: true));
      final chunkFile = File(
        p.join(
          root.path,
          ChunkStore.chunksDirectoryPath,
          'forest',
          'legacy.json',
        ),
      )..createSync(recursive: true);
      chunkFile.writeAsStringSync(
        '${const JsonEncoder.withIndent(' ').convert(_legacyChunkJson())}\n',
      );
      final workspace = EditorWorkspace(rootPath: root.path);
      final plugin = ChunkDomainPlugin();

      final normal = await plugin.loadFromRepo(workspace);
      expect(normal, isA<ChunkDocument>());
      expect((normal as ChunkDocument).chunks.single.schemaVersion, 1);
      await expectLater(
        store.loadV2Staging(workspace),
        throwsA(isA<FormatException>()),
      );
    },
  );

  test('strict staging rejects case-colliding chunk keys', () async {
    final fixture = _V2Fixture.create();
    addTearDown(fixture.dispose);
    final duplicate = fixture.data.copyWith(
      chunkKey: 'FOREST_TEST',
      id: 'forest_duplicate',
    );
    File(
        p.join(
          fixture.root.path,
          ChunkStore.chunksDirectoryPath,
          'forest',
          'duplicate.json',
        ),
      )
      ..createSync(recursive: true)
      ..writeAsStringSync(ChunkV2FileCodec.encode(duplicate));

    await expectLater(
      store.loadV2Staging(fixture.workspace),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('chunk_v2_duplicate_chunk_key'),
        ),
      ),
    );
  });
}

final class _V2Fixture {
  _V2Fixture._({
    required this.root,
    required this.data,
    required this.chunkContents,
  });

  factory _V2Fixture.create() {
    final root = Directory.systemTemp.createTempSync('chunk_v2_staging_');
    final data = ChunkV2FileData(
      chunkKey: 'forest_test',
      id: 'forest_test',
      revision: 1,
      status: chunkStatusActive,
      levelId: 'forest',
      tileSize: 16,
      width: 600,
      height: 270,
      difficulty: chunkDifficultyEarly,
      assemblyGroupId: defaultChunkAssemblyGroupId,
      tags: const <String>['forest'],
      tileLayers: const <TileLayerDef>[],
      prefabs: const <PlacedPrefabDef>[],
      markers: const <PlacedMarkerDef>[],
      groundBandZIndex: 0,
      collisionShapes: <TerrainSourceShapeDef>[
        _rectangle('ground', left: 0, right: 1200, bottom: 540),
      ],
    );
    final chunkContents = ChunkV2FileCodec.encode(data);
    File(
        p.join(
          root.path,
          ChunkStore.chunksDirectoryPath,
          'forest',
          'forest_test.json',
        ),
      )
      ..createSync(recursive: true)
      ..writeAsStringSync(chunkContents);
    File(p.join(root.path, PrefabStore.prefabDefsPath))
      ..createSync(recursive: true)
      ..writeAsStringSync(
        PrefabV3FileCodec.encode(
          PrefabV3FileData(
            slices: const <AtlasSliceDef>[],
            prefabs: const <PrefabV3Def>[],
          ),
        ),
      );
    File(p.join(root.path, PrefabStore.tileDefsPath))
      ..createSync(recursive: true)
      ..writeAsStringSync(
        PrefabTileFileCodec.encode(
          PrefabTileFileData(
            tileSlices: const <AtlasSliceDef>[],
            platformModules: const <TileModuleDef>[],
          ),
        ),
      );
    File(p.join(root.path, LevelStore.defsPath))
      ..createSync(recursive: true)
      ..writeAsStringSync(
        renderCanonicalLevelDefsJson(const <LevelDef>[
          LevelDef(
            levelId: 'forest',
            revision: 1,
            displayName: 'Forest',
            visualThemeId: 'forest',
            cameraCenterY: 135,
            groundTopY: 224,
            earlyPatternChunks: 3,
            easyPatternChunks: 0,
            normalPatternChunks: 0,
            noEnemyChunks: 3,
            enumOrdinal: 10,
            status: levelStatusActive,
          ),
        ]),
      );
    return _V2Fixture._(root: root, data: data, chunkContents: chunkContents);
  }

  final Directory root;
  final ChunkV2FileData data;
  final String chunkContents;

  EditorWorkspace get workspace => EditorWorkspace(rootPath: root.path);

  Map<String, List<int>> snapshot() => <String, List<int>>{
    for (final file
        in root.listSync(recursive: true).whereType<File>().toList()
          ..sort((left, right) => left.path.compareTo(right.path)))
      p.relative(file.path, from: root.path): file.readAsBytesSync(),
  };

  void dispose() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  }
}

TerrainSourceShapeDef _rectangle(
  String shapeId, {
  required int left,
  required int right,
  int top = 0,
  required int bottom,
}) => TerrainSourceShapeDef(
  shapeId: shapeId,
  vertices: <TerrainSourceVertexDef>[
    TerrainSourceVertexDef(xHalfPixels: left, yHalfPixels: top),
    TerrainSourceVertexDef(xHalfPixels: right, yHalfPixels: top),
    TerrainSourceVertexDef(xHalfPixels: right, yHalfPixels: bottom),
    TerrainSourceVertexDef(xHalfPixels: left, yHalfPixels: bottom),
  ],
);

Map<String, Object?> _legacyChunkJson() => <String, Object?>{
  'schemaVersion': 1,
  'chunkKey': 'forest_legacy',
  'id': 'forest_legacy',
  'revision': 1,
  'status': 'active',
  'levelId': 'forest',
  'tileSize': 16,
  'width': 600,
  'height': 270,
  'difficulty': 'early',
  'assemblyGroupId': 'default',
  'tags': <String>['forest'],
  'tileLayers': <Object?>[],
  'prefabs': <Object?>[],
  'markers': <Object?>[],
  'groundProfile': <String, Object?>{'kind': 'flat', 'topY': 224},
  'groundGaps': <Object?>[],
};
