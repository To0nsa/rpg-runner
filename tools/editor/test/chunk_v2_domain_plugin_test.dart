import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:runner_editor/src/chunks/chunk_domain_models.dart';
import 'package:runner_editor/src/chunks/chunk_domain_plugin.dart';
import 'package:runner_editor/src/chunks/chunk_v2_composition_commit.dart';
import 'package:runner_editor/src/chunks/chunk_v2_file_codec.dart';
import 'package:runner_editor/src/chunks/chunk_v2_file_data.dart';
import 'package:runner_editor/src/chunks/chunk_v2_metadata_commit.dart';
import 'package:runner_editor/src/chunks/chunk_v2_staging_models.dart';
import 'package:runner_editor/src/levels/level_domain_models.dart';
import 'package:runner_editor/src/domain/authoring_types.dart';
import 'package:runner_editor/src/prefabs/models/models.dart';
import 'package:runner_editor/src/terrain_authoring/terrain_polygon_interaction.dart';
import 'package:runner_editor/src/terrain_authoring/terrain_source_models.dart';
import 'package:runner_editor/src/workspace/editor_workspace.dart';

void main() {
  test('staged command commits once and builds one canonical pending diff', () {
    final plugin = ChunkDomainPlugin();
    final before = <TerrainSourceShapeDef>[_rectangle(top: 20)];
    final after = <TerrainSourceShapeDef>[_rectangle(top: 18)];
    final document = _document(before);

    expect(plugin.validate(document), isEmpty);
    final edited = plugin.applyEdit(
      document,
      AuthoringCommand(
        kind: ChunkDomainPlugin.commitChunkPolygonCommandKind,
        payload: <String, Object?>{
          'chunkKey': 'forest_target',
          'commit': _commit(before: before, after: after),
        },
      ),
    );

    expect(edited, isA<ChunkV2StagingDocument>());
    final next = edited as ChunkV2StagingDocument;
    expect(next, isNot(same(document)));
    expect(document.chunks.single.revision, 4);
    expect(next.chunks.single.revision, 5);
    expect(next.chunks.single.collisionShapes, after);
    expect(next.changedChunkKeys, <String>['forest_target']);

    final pending = plugin.describePendingChanges(
      EditorWorkspace(rootPath: Directory.current.path),
      document: next,
    );
    expect(pending.changedItemIds, <String>['forest_target']);
    expect(pending.fileDiffs, hasLength(1));
    expect(pending.fileDiffs.single.relativePath, 'chunks/forest_target.json');
    expect(pending.fileDiffs.single.unifiedDiff, contains('"revision": 5'));
    expect(pending.fileDiffs.single.unifiedDiff, contains('collisionShapes'));
  });

  test(
    'invalid stale malformed missing-owner and no-op commands keep identity',
    () {
      final plugin = ChunkDomainPlugin();
      final before = <TerrainSourceShapeDef>[_rectangle(top: 20)];
      final document = _document(before);
      final invalid = plugin.applyEdit(
        document,
        AuthoringCommand(
          kind: ChunkDomainPlugin.commitChunkPolygonCommandKind,
          payload: <String, Object?>{
            'chunkKey': 'forest_target',
            'commit': _commit(
              before: before,
              after: <TerrainSourceShapeDef>[_rectangle(left: -2, top: 20)],
            ),
          },
        ),
      );
      final stale = plugin.applyEdit(
        document,
        AuthoringCommand(
          kind: ChunkDomainPlugin.commitChunkPolygonCommandKind,
          payload: <String, Object?>{
            'chunkKey': 'forest_target',
            'commit': _commit(
              before: <TerrainSourceShapeDef>[_rectangle(top: 22)],
              after: before,
            ),
          },
        ),
      );
      final malformed = plugin.applyEdit(
        document,
        AuthoringCommand(
          kind: ChunkDomainPlugin.commitChunkPolygonCommandKind,
          payload: const <String, Object?>{'chunkKey': 'forest_target'},
        ),
      );
      final missingOwner = plugin.applyEdit(
        document,
        AuthoringCommand(
          kind: ChunkDomainPlugin.commitChunkPolygonCommandKind,
          payload: <String, Object?>{
            'chunkKey': 'missing',
            'commit': _commit(before: before, after: before),
          },
        ),
      );
      final noOp = plugin.applyEdit(
        document,
        AuthoringCommand(
          kind: ChunkDomainPlugin.commitChunkPolygonCommandKind,
          payload: <String, Object?>{
            'chunkKey': 'forest_target',
            'commit': _commit(before: before, after: before),
          },
        ),
      );

      expect(invalid, same(document));
      expect(stale, same(document));
      expect(malformed, same(document));
      expect(missingOwner, same(document));
      expect(noOp, same(document));
    },
  );

  test(
    'typed staged edit remains protected by the source-write lock',
    () async {
      final root = Directory.systemTemp.createTempSync('chunk_v2_plugin_');
      addTearDown(() => root.deleteSync(recursive: true));
      final plugin = ChunkDomainPlugin();
      final before = <TerrainSourceShapeDef>[_rectangle(top: 20)];
      final changed = plugin.applyEdit(
        _document(before),
        AuthoringCommand(
          kind: ChunkDomainPlugin.commitChunkPolygonCommandKind,
          payload: <String, Object?>{
            'chunkKey': 'forest_target',
            'commit': _commit(
              before: before,
              after: <TerrainSourceShapeDef>[_rectangle(top: 18)],
            ),
          },
        ),
      );

      await expectLater(
        plugin.exportToRepo(
          EditorWorkspace(rootPath: root.path),
          document: changed,
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('chunk_v2_source_write_disabled'),
          ),
        ),
      );
      expect(root.listSync(recursive: true), isEmpty);
    },
  );

  test(
    'typed metadata commit changes only editable fields and revision once',
    () {
      final plugin = ChunkDomainPlugin();
      final document = _document(<TerrainSourceShapeDef>[_rectangle(top: 20)]);
      final before = document.chunks.single;
      final edited =
          plugin.applyEdit(
                document,
                AuthoringCommand(
                  kind: ChunkDomainPlugin.commitChunkMetadataCommandKind,
                  payload: <String, Object?>{
                    'chunkKey': before.chunkKey,
                    'commit': ChunkV2MetadataCommit(
                      before: ChunkV2MetadataSnapshot.fromChunk(before),
                      after: ChunkV2MetadataSnapshot(
                        status: chunkStatusDeprecated,
                        levelId: before.levelId,
                        difficulty: chunkDifficultyHard,
                        assemblyGroupId: before.assemblyGroupId,
                        tags: const <String>['boss', 'forest'],
                        groundBandZIndex: 3,
                      ),
                    ),
                  },
                ),
              )
              as ChunkV2StagingDocument;

      final after = edited.chunks.single;
      expect(after.revision, before.revision + 1);
      expect(after.status, chunkStatusDeprecated);
      expect(after.difficulty, chunkDifficultyHard);
      expect(after.tags, <String>['boss', 'forest']);
      expect(after.groundBandZIndex, 3);
      expect(after.chunkKey, before.chunkKey);
      expect(after.id, before.id);
      expect(after.tileSize, before.tileSize);
      expect(after.width, before.width);
      expect(after.height, before.height);
      expect(after.tileLayers, before.tileLayers);
      expect(after.prefabs, before.prefabs);
      expect(after.markers, before.markers);
      expect(after.collisionShapes, before.collisionShapes);
      expect(edited.changedChunkKeys, <String>['forest_target']);

      final pending = plugin.describePendingChanges(
        EditorWorkspace(rootPath: Directory.current.path),
        document: edited,
      );
      expect(pending.changedItemIds, <String>['forest_target']);
      expect(pending.fileDiffs, hasLength(1));
      expect(
        pending.fileDiffs.single.relativePath,
        'chunks/forest_target.json',
      );
      expect(
        pending.fileDiffs.single.unifiedDiff,
        contains('"status": "deprecated"'),
      );
      expect(
        pending.fileDiffs.single.unifiedDiff,
        contains('"groundBandZIndex": 3'),
      );
    },
  );

  test('stale noncanonical and invalid metadata commits keep identity', () {
    final plugin = ChunkDomainPlugin();
    final document = _document(<TerrainSourceShapeDef>[_rectangle(top: 20)]);
    final current = document.chunks.single;

    ChunkV2MetadataCommit command({
      ChunkV2MetadataSnapshot? before,
      required ChunkV2MetadataSnapshot after,
    }) => ChunkV2MetadataCommit(
      before: before ?? ChunkV2MetadataSnapshot.fromChunk(current),
      after: after,
    );

    AuthoringDocument apply(ChunkV2MetadataCommit commit) => plugin.applyEdit(
      document,
      AuthoringCommand(
        kind: ChunkDomainPlugin.commitChunkMetadataCommandKind,
        payload: <String, Object?>{
          'chunkKey': current.chunkKey,
          'commit': commit,
        },
      ),
    );

    final validAfter = ChunkV2MetadataSnapshot(
      status: current.status,
      levelId: current.levelId,
      difficulty: chunkDifficultyHard,
      assemblyGroupId: current.assemblyGroupId,
      tags: current.tags,
      groundBandZIndex: current.groundBandZIndex,
    );
    final staleBefore = ChunkV2MetadataSnapshot(
      status: current.status,
      levelId: current.levelId,
      difficulty: chunkDifficultyEasy,
      assemblyGroupId: current.assemblyGroupId,
      tags: current.tags,
      groundBandZIndex: current.groundBandZIndex,
    );
    final noncanonical = ChunkV2MetadataSnapshot(
      status: current.status,
      levelId: current.levelId,
      difficulty: current.difficulty,
      assemblyGroupId: current.assemblyGroupId,
      tags: const <String>['forest', 'boss'],
      groundBandZIndex: current.groundBandZIndex,
    );
    final invalidLevel = ChunkV2MetadataSnapshot(
      status: current.status,
      levelId: 'missing',
      difficulty: current.difficulty,
      assemblyGroupId: current.assemblyGroupId,
      tags: current.tags,
      groundBandZIndex: current.groundBandZIndex,
    );

    expect(
      apply(command(before: staleBefore, after: validAfter)),
      same(document),
    );
    expect(apply(command(after: noncanonical)), same(document));
    expect(apply(command(after: invalidLevel)), same(document));
    expect(
      apply(command(after: ChunkV2MetadataSnapshot.fromChunk(current))),
      same(document),
    );
  });

  test(
    'typed composition commit validates retained authoring and protects terrain',
    () {
      final plugin = ChunkDomainPlugin();
      final document = _document(<TerrainSourceShapeDef>[_rectangle(top: 20)]);
      final before = document.chunks.single;
      final commit = ChunkV2CompositionCommit(
        before: ChunkV2CompositionSnapshot.fromChunk(before),
        after: ChunkV2CompositionSnapshot(
          tileLayers: const <TileLayerDef>[TileLayerDef(id: 'foreground')],
          prefabs: const <PlacedPrefabDef>[
            PlacedPrefabDef(
              prefabId: 'shrub',
              prefabKey: 'prefab_shrub',
              x: 40,
              y: 20,
            ),
          ],
          markers: const <PlacedMarkerDef>[
            PlacedMarkerDef(markerId: 'grojib', x: 50, y: 20),
          ],
        ),
      );
      final policyResult = const ChunkV2CompositionCommitPolicy().apply(
        document: document,
        chunkIndex: 0,
        commit: commit,
      );
      expect(
        policyResult.issues.map((issue) => '${issue.code}: ${issue.message}'),
        isEmpty,
      );
      expect(policyResult.accepted, isTrue);
      final edited =
          plugin.applyEdit(
                document,
                AuthoringCommand(
                  kind: ChunkDomainPlugin.commitChunkCompositionCommandKind,
                  payload: <String, Object?>{
                    'chunkKey': before.chunkKey,
                    'commit': commit,
                  },
                ),
              )
              as ChunkV2StagingDocument;

      final after = edited.chunks.single;
      expect(after.revision, before.revision + 1);
      expect(after.tileLayers.single.id, 'foreground');
      expect(after.prefabs.single.prefabKey, 'prefab_shrub');
      expect(after.markers.single.markerId, 'grojib');
      expect(after.chunkKey, before.chunkKey);
      expect(after.id, before.id);
      expect(after.status, before.status);
      expect(after.levelId, before.levelId);
      expect(after.difficulty, before.difficulty);
      expect(after.tags, before.tags);
      expect(after.groundBandZIndex, before.groundBandZIndex);
      expect(after.collisionShapes, before.collisionShapes);
      expect(plugin.validate(edited), isEmpty);

      final pending = plugin.describePendingChanges(
        EditorWorkspace(rootPath: Directory.current.path),
        document: edited,
      );
      expect(pending.changedItemIds, <String>['forest_target']);
      expect(pending.fileDiffs, hasLength(1));
      expect(pending.fileDiffs.single.unifiedDiff, contains('prefab_shrub'));
      expect(pending.fileDiffs.single.unifiedDiff, contains('grojib'));
    },
  );

  test('stale noncanonical and invalid composition commits keep identity', () {
    final plugin = ChunkDomainPlugin();
    final document = _document(<TerrainSourceShapeDef>[_rectangle(top: 20)]);
    final current = document.chunks.single;
    final currentSnapshot = ChunkV2CompositionSnapshot.fromChunk(current);

    AuthoringDocument apply(ChunkV2CompositionCommit commit) =>
        plugin.applyEdit(
          document,
          AuthoringCommand(
            kind: ChunkDomainPlugin.commitChunkCompositionCommandKind,
            payload: <String, Object?>{
              'chunkKey': current.chunkKey,
              'commit': commit,
            },
          ),
        );

    final stale = ChunkV2CompositionSnapshot(
      tileLayers: const <TileLayerDef>[TileLayerDef(id: 'stale')],
      prefabs: current.prefabs,
      markers: current.markers,
    );
    final noncanonical = ChunkV2CompositionSnapshot(
      tileLayers: const <TileLayerDef>[
        TileLayerDef(id: 'z'),
        TileLayerDef(id: 'a'),
      ],
      prefabs: current.prefabs,
      markers: current.markers,
    );
    final invalidMarker = ChunkV2CompositionSnapshot(
      tileLayers: current.tileLayers,
      prefabs: current.prefabs,
      markers: const <PlacedMarkerDef>[
        PlacedMarkerDef(markerId: 'unknown', x: 50, y: 20),
      ],
    );
    final invalidPlacement = ChunkV2CompositionSnapshot(
      tileLayers: current.tileLayers,
      prefabs: const <PlacedPrefabDef>[
        PlacedPrefabDef(prefabId: 'missing', x: 40, y: 20),
      ],
      markers: current.markers,
    );

    expect(
      apply(ChunkV2CompositionCommit(before: stale, after: noncanonical)),
      same(document),
    );
    expect(
      apply(
        ChunkV2CompositionCommit(before: currentSnapshot, after: noncanonical),
      ),
      same(document),
    );
    expect(
      apply(
        ChunkV2CompositionCommit(
          before: currentSnapshot,
          after: invalidPlacement,
        ),
      ),
      same(document),
    );
    expect(
      apply(
        ChunkV2CompositionCommit(before: currentSnapshot, after: invalidMarker),
      ),
      same(document),
    );
    expect(
      apply(
        ChunkV2CompositionCommit(
          before: currentSnapshot,
          after: currentSnapshot,
        ),
      ),
      same(document),
    );
  });
}

ChunkV2StagingDocument _document(
  Iterable<TerrainSourceShapeDef> collisionShapes,
) {
  final chunk = ChunkV2FileData(
    chunkKey: 'forest_target',
    id: 'forest_target',
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
    collisionShapes: collisionShapes,
  );
  return ChunkV2StagingDocument(
    chunks: <ChunkV2FileData>[chunk],
    sourcePathByChunkKey: const <String, String>{
      'forest_target': 'chunks/forest_target.json',
    },
    baselineContentsByChunkKey: <String, String>{
      'forest_target': ChunkV2FileCodec.encode(chunk),
    },
    prefabData: PrefabV3FileData(
      slices: const <AtlasSliceDef>[],
      prefabs: <PrefabV3Def>[
        PrefabV3Def(
          prefabKey: 'prefab_shrub',
          id: 'shrub',
          revision: 1,
          status: PrefabStatus.active,
          kind: PrefabKind.decoration,
          visualSource: const PrefabVisualSource.atlasSlice('shrub_slice'),
          anchorXPx: 0,
          anchorYPx: 0,
          collisionShapes: const <TerrainSourceShapeDef>[],
          tags: const <String>[],
        ),
      ],
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

TerrainPolygonInteractionCommit _commit({
  required Iterable<TerrainSourceShapeDef> before,
  required Iterable<TerrainSourceShapeDef> after,
}) => TerrainPolygonInteractionCommit(
  beforeShapes: before,
  afterShapes: after,
  beforeSelection: null,
  afterSelection: null,
);

TerrainSourceShapeDef _rectangle({int left = 0, required int top}) =>
    TerrainSourceShapeDef(
      shapeId: 'ground',
      vertices: <TerrainSourceVertexDef>[
        TerrainSourceVertexDef(xHalfPixels: left, yHalfPixels: top),
        TerrainSourceVertexDef(xHalfPixels: 200, yHalfPixels: top),
        const TerrainSourceVertexDef(xHalfPixels: 200, yHalfPixels: 100),
        TerrainSourceVertexDef(xHalfPixels: left, yHalfPixels: 100),
      ],
    );
