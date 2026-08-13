import 'package:flutter_test/flutter_test.dart';
import 'package:runner_core/collision/terrain/terrain_edge_id.dart';
import 'package:runner_editor/src/app/pages/chunkCreator/v2/chunk_scene_coordinator.dart';
import 'package:runner_editor/src/chunks/chunk_domain_models.dart';
import 'package:runner_editor/src/chunks/chunk_v2_file_data.dart';
import 'package:runner_editor/src/terrain_authoring/terrain_polygon_interaction.dart';

void main() {
  test('coordinates one explicit input domain and typed selection', () {
    final coordinator = ChunkSceneCoordinator();
    final chunk = _chunk();
    final prefab = buildChunkPlacedPrefabSelections(chunk.prefabs).single;
    final marker = buildChunkPlacedMarkerSelections(chunk.markers).single;

    expect(coordinator.domain, ChunkSceneDomain.terrain);
    coordinator.selectTerrain(TerrainPolygonSelection.shape('ground'));
    expect(coordinator.selection, isA<ChunkTerrainSceneSelection>());

    coordinator.selectPrefab(prefab);
    expect(coordinator.domain, ChunkSceneDomain.prefabs);
    expect(coordinator.selectedPrefabKey, prefab.selectionKey);
    expect(coordinator.selectedMarkerKey, isNull);

    coordinator.selectMarker(marker);
    expect(coordinator.domain, ChunkSceneDomain.markers);
    expect(coordinator.selectedMarkerKey, marker.selectionKey);

    final edgeId = TerrainEdgeId(
      chunkIndex: 0,
      chunkKey: chunk.chunkKey,
      shapeId: 'ground',
      localEdgeIndex: 0,
    );
    coordinator.setCompiledEdgeInspection(true);
    coordinator.selectCompiledEdge(edgeId);
    expect(coordinator.domain, ChunkSceneDomain.compiledEdgeInspection);
    expect(coordinator.sourceDomain, ChunkSceneDomain.markers);
    expect(coordinator.selectedCompiledEdgeId, edgeId);

    coordinator.setCompiledEdgeInspection(false);
    expect(coordinator.domain, ChunkSceneDomain.markers);
    expect(coordinator.selection, isNull);
  });

  test('owner binding and source reconciliation cannot retain stale keys', () {
    final coordinator = ChunkSceneCoordinator();
    final chunk = _chunk();
    final prefab = buildChunkPlacedPrefabSelections(chunk.prefabs).single;

    coordinator.selectPrefab(prefab);
    coordinator.reconcileComposition(chunk);
    expect(coordinator.selectedPrefabKey, prefab.selectionKey);

    coordinator.reconcileComposition(_chunk(prefabs: const []));
    expect(coordinator.selection, isNull);
    expect(coordinator.domain, ChunkSceneDomain.prefabs);

    coordinator.selectMarker(
      buildChunkPlacedMarkerSelections(chunk.markers).single,
    );
    coordinator.bindOwner();
    expect(coordinator.domain, ChunkSceneDomain.terrain);
    expect(coordinator.selection, isNull);
  });

  test(
    'overlapping marker hit testing uses reverse canonical source order',
    () {
      const markers = <PlacedMarkerDef>[
        PlacedMarkerDef(markerId: 'grojib', x: 20, y: 30, salt: 1),
        PlacedMarkerDef(markerId: 'grojib', x: 20, y: 30, salt: 2),
      ];

      final hit = hitTestChunkMarkerSelection(
        markers: markers,
        worldX: 20,
        worldY: 30,
        radiusWorld: 4,
      );

      expect(hit?.sourceIndex, 1);
      expect(hit?.selectionKey, 'grojib|20|30|1');
      expect(
        hitTestChunkMarkerSelection(
          markers: markers,
          worldX: 50,
          worldY: 50,
          radiusWorld: 4,
        ),
        isNull,
      );
    },
  );
}

ChunkV2FileData _chunk({
  List<PlacedPrefabDef> prefabs = const <PlacedPrefabDef>[
    PlacedPrefabDef(prefabId: 'rock', prefabKey: 'rock', x: 16, y: 32),
  ],
}) => ChunkV2FileData(
  chunkKey: 'forest',
  id: 'forest',
  revision: 1,
  status: chunkStatusActive,
  levelId: 'forest',
  tileSize: 16,
  width: 320,
  height: 180,
  difficulty: chunkDifficultyNormal,
  assemblyGroupId: defaultChunkAssemblyGroupId,
  tags: const <String>[],
  tileLayers: const <TileLayerDef>[],
  prefabs: prefabs,
  markers: const <PlacedMarkerDef>[
    PlacedMarkerDef(markerId: 'grojib', x: 48, y: 64),
  ],
  groundBandZIndex: 0,
  collisionShapes: const [],
);
