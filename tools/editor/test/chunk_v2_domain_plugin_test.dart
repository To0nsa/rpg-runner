import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:runner_editor/src/chunks/chunk_domain_models.dart';
import 'package:runner_editor/src/chunks/chunk_domain_plugin.dart';
import 'package:runner_editor/src/chunks/chunk_v2_file_codec.dart';
import 'package:runner_editor/src/chunks/chunk_v2_file_data.dart';
import 'package:runner_editor/src/chunks/chunk_v2_staging_models.dart';
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
      prefabs: const <PrefabV3Def>[],
    ),
    tileData: PrefabTileFileData(
      tileSlices: const <AtlasSliceDef>[],
      platformModules: const <TileModuleDef>[],
    ),
    visualBoundsByPrefabKey: const {},
    availableLevelIds: const <String>['forest'],
    activeLevelId: 'forest',
  );
}

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
