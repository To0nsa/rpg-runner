import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:runner_editor/src/chunks/chunk_domain_models.dart';
import 'package:runner_editor/src/chunks/chunk_domain_plugin.dart';
import 'package:runner_editor/src/chunks/chunk_store.dart';
import 'package:runner_editor/src/chunks/chunk_v2_file_codec.dart';
import 'package:runner_editor/src/chunks/chunk_v2_file_data.dart';
import 'package:runner_editor/src/chunks/chunk_v2_staging_models.dart';
import 'package:runner_editor/src/levels/level_domain_models.dart';
import 'package:runner_editor/src/prefabs/models/models.dart';
import 'package:runner_editor/src/workspace/editor_workspace.dart';

void main() {
  test(
    'v2 save plan is clean or describes one canonical managed-path move',
    () {
      const store = ChunkStore();
      final document = _document();

      expect(store.buildV2StagingSavePlan(document: document).writes, isEmpty);

      final renamed = document.chunks.single.copyWith(
        id: 'forest_renamed',
        revision: 5,
      );
      final edited = document.copyWith(
        chunks: <ChunkV2FileData>[renamed],
        changedChunkKeys: <String>[renamed.chunkKey],
      );
      final plan = store.buildV2StagingSavePlan(document: edited);

      expect(plan.writes, hasLength(1));
      expect(plan.changedChunkKeys, <String>['forest_original']);
      expect(
        plan.writes.single.relativePath.replaceAll('\\', '/'),
        '${ChunkStore.chunksDirectoryPath}/forest/forest_renamed.json',
      );
      expect(
        plan.writes.single.previousRelativePath?.replaceAll('\\', '/'),
        '${ChunkStore.chunksDirectoryPath}/forest/forest_original.json',
      );
      expect(plan.writes.single.beforeContent, isNotNull);
      expect(plan.writes.single.afterContent, contains('"revision": 5'));

      final pending = ChunkDomainPlugin().describePendingChanges(
        EditorWorkspace(rootPath: Directory.current.path),
        document: edited,
      );
      expect(
        pending.fileDiffs.single.unifiedDiff,
        contains(
          'diff --git a/${ChunkStore.chunksDirectoryPath}/forest/'
          'forest_original.json b/${ChunkStore.chunksDirectoryPath}/forest/'
          'forest_renamed.json',
        ),
      );
    },
  );

  test('v2 save plan models explicit creation and baseline deletion', () {
    const store = ChunkStore();
    final document = _document();
    final created = document.chunks.single.copyWith(
      chunkKey: 'forest_created',
      id: 'forest_created',
      revision: 1,
    );
    final createdPath =
        '${ChunkStore.chunksDirectoryPath}/forest/forest_created.json';
    final edited = document.copyWith(
      chunks: <ChunkV2FileData>[created],
      sourcePathByChunkKey: <String, String>{
        ...document.sourcePathByChunkKey,
        created.chunkKey: createdPath,
      },
      createdChunkKeys: <String>[created.chunkKey],
      changedChunkKeys: <String>[created.chunkKey, 'forest_original'],
    );
    final plan = store.buildV2StagingSavePlan(document: edited);

    expect(plan.writes, hasLength(2));
    final creation = plan.writes.singleWhere(
      (write) => write.chunkKey == created.chunkKey,
    );
    final deletion = plan.writes.singleWhere(
      (write) => write.chunkKey == 'forest_original',
    );
    expect(creation.beforeContent, isNull);
    expect(creation.deleteFile, isFalse);
    expect(creation.relativePath.replaceAll('\\', '/'), createdPath);
    expect(deletion.deleteFile, isTrue);
    expect(deletion.beforeContent, isNotNull);
    expect(deletion.afterContent, isEmpty);
  });

  test('v2 save plan rejects missing baselines and source-path reuse', () {
    const store = ChunkStore();
    final document = _document();
    final existing = document.chunks.single;

    expect(
      () => store.buildV2StagingSavePlan(
        document: document.copyWith(
          baselineContentsByChunkKey: const <String, String>{},
        ),
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('chunk_v2_source_baseline_missing'),
        ),
      ),
    );

    expect(
      () => store.buildV2StagingSavePlan(
        document: document.copyWith(
          sourcePathByChunkKey: const <String, String>{
            'forest_original': '../outside.json',
          },
        ),
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('chunk_v2_source_path_outside_workspace'),
        ),
      ),
    );

    final replacement = existing.copyWith(
      chunkKey: 'forest_replacement',
      revision: 1,
    );
    final reusedPath = document.sourcePathByChunkKey[existing.chunkKey]!;
    expect(
      () => store.buildV2StagingSavePlan(
        document: document.copyWith(
          chunks: <ChunkV2FileData>[replacement],
          sourcePathByChunkKey: <String, String>{
            ...document.sourcePathByChunkKey,
            replacement.chunkKey: reusedPath,
          },
          createdChunkKeys: <String>[replacement.chunkKey],
        ),
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('chunk_v2_deleted_source_path_reused'),
        ),
      ),
    );
  });
}

ChunkV2StagingDocument _document() {
  final chunk = ChunkV2FileData(
    chunkKey: 'forest_original',
    id: 'forest_original',
    revision: 4,
    status: chunkStatusActive,
    levelId: 'forest',
    tileSize: 16,
    width: 100,
    height: 50,
    difficulty: chunkDifficultyNormal,
    assemblyGroupId: defaultChunkAssemblyGroupId,
    tags: const <String>['forest'],
    tileLayers: const <TileLayerDef>[],
    prefabs: const <PlacedPrefabDef>[],
    markers: const <PlacedMarkerDef>[],
    groundBandZIndex: 0,
    collisionShapes: const [],
  );
  final sourcePath =
      '${ChunkStore.chunksDirectoryPath}/forest/forest_original.json';
  return ChunkV2StagingDocument(
    chunks: <ChunkV2FileData>[chunk],
    sourcePathByChunkKey: <String, String>{chunk.chunkKey: sourcePath},
    baselineContentsByChunkKey: <String, String>{
      chunk.chunkKey: ChunkV2FileCodec.encode(chunk),
    },
    prefabData: PrefabV3FileData(
      slices: const <AtlasSliceDef>[],
      prefabs: const <PrefabV3Def>[],
    ),
    tileData: PrefabTileFileData(
      tileSlices: const <AtlasSliceDef>[],
      platformModules: const <TileModuleDef>[],
    ),
    visualBoundsByPrefabKey: const {},
    groundTopYByLevelId: const <String, double>{'forest': 10},
    levels: const <LevelDef>[_forestLevel],
    availableLevelIds: const <String>['forest'],
    activeLevelId: 'forest',
  );
}

const LevelDef _forestLevel = LevelDef(
  levelId: 'forest',
  revision: 1,
  displayName: 'Forest',
  visualThemeId: 'forest',
  cameraCenterY: 25,
  groundTopY: 10,
  earlyPatternChunks: 0,
  easyPatternChunks: 0,
  normalPatternChunks: 0,
  noEnemyChunks: 0,
  enumOrdinal: 1,
  status: levelStatusActive,
);
