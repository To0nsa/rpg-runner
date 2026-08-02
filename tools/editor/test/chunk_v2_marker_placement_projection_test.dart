import 'package:flutter_test/flutter_test.dart';
import 'package:runner_core/collision/terrain/terrain_compiler.dart';
import 'package:runner_core/collision/terrain/terrain_numeric.dart';
import 'package:runner_core/collision/terrain/terrain_polygon.dart';
import 'package:runner_core/navigation/terrain_placement_query.dart';
import 'package:runner_editor/src/chunks/chunk_domain_models.dart';
import 'package:runner_editor/src/chunks/chunk_v2_actor_terrain_projection.dart';
import 'package:runner_editor/src/chunks/chunk_v2_collision_expansion.dart';
import 'package:runner_editor/src/chunks/chunk_v2_file_data.dart';
import 'package:runner_editor/src/chunks/chunk_v2_marker_placement_projection.dart';

void main() {
  test('preserves authored marker intent and delegates placement to Core', () {
    const markers = <PlacedMarkerDef>[
      PlacedMarkerDef(
        markerId: 'unocoDemon',
        x: 300,
        y: 12,
        chancePercent: 50,
        salt: 7,
      ),
      PlacedMarkerDef(markerId: 'grojib', x: 50, y: 44, salt: 2),
      PlacedMarkerDef(
        markerId: 'derf',
        x: 140,
        y: 20,
        placement: markerPlacementObstacleTop,
      ),
      PlacedMarkerDef(
        markerId: 'grojib',
        x: 140,
        y: 32,
        chancePercent: 25,
        salt: 9,
        placement: markerPlacementHighestSurfaceAtX,
      ),
      PlacedMarkerDef(
        markerId: 'grojib',
        x: 360,
        y: 28,
        placement: markerPlacementObstacleTop,
      ),
      PlacedMarkerDef(markerId: 'hashash', x: 240, y: 16, salt: 4),
      PlacedMarkerDef(
        markerId: 'grojib',
        x: 80,
        y: 48,
        chancePercent: 0,
        salt: 5,
      ),
    ];
    final chunk = _chunk(markers);
    final actorTerrain = ChunkV2ActorTerrainProjection.build(_expansion());
    final projection = ChunkV2MarkerPlacementProjection.build(
      chunk: chunk,
      actorTerrain: actorTerrain,
      levelGroundTopY: 200,
    );

    expect(
      projection.outcomes.map((outcome) => outcome.marker.markerId),
      markers.map((marker) => marker.markerId),
    );
    expect(
      projection.outcomes.map((outcome) => outcome.marker.salt),
      markers.map((marker) => marker.salt),
    );
    expect(
      projection.outcomes.map((outcome) => outcome.selectionKey).toSet(),
      buildChunkPlacedMarkerSelections(
        markers,
      ).map((selection) => selection.selectionKey).toSet(),
    );

    final unoco = projection.outcomes[0];
    expect(
      unoco.disposition,
      ChunkV2MarkerPlacementDisposition.conditionalAccepted,
    );
    expect(unoco.result!.accepted, isTrue);
    expect(
      unoco.result!.requestedBodyCenter.yTicks,
      50 * terrainPhysicsTicksPerWorldUnit,
    );
    expect(
      unoco.result!.requestedBodyCenter.yTicks,
      isNot(unoco.marker.y * terrainPhysicsTicksPerWorldUnit),
    );

    final ground = projection.outcomes[1];
    expect(
      ground.disposition,
      ChunkV2MarkerPlacementDisposition.guaranteedAccepted,
    );
    expect(ground.intendedSurface!.id.placementKey, isNull);
    expect(ground.result!.supportPoint!.yTicks, _ticks(200));

    final derf = projection.outcomes[2];
    expect(
      derf.disposition,
      ChunkV2MarkerPlacementDisposition.guaranteedAccepted,
    );
    expect(derf.intendedSurface!.id.placementKey, 'prefab_obstacle');
    expect(derf.result!.supportPoint!.yTicks, _ticks(100));

    final highest = projection.outcomes[3];
    expect(
      highest.disposition,
      ChunkV2MarkerPlacementDisposition.conditionalAccepted,
    );
    expect(highest.intendedSurface!.id.placementKey, 'prefab_obstacle');
    expect(highest.result!.supportPoint!.yTicks, _ticks(100));

    final missingObstacle = projection.outcomes[4];
    expect(
      missingObstacle.disposition,
      ChunkV2MarkerPlacementDisposition.guaranteedRejected,
    );
    expect(
      missingObstacle.result!.validity,
      TerrainPlacementValidity.intendedSupportMissing,
    );

    expect(
      projection.outcomes[5].disposition,
      ChunkV2MarkerPlacementDisposition.deferredGuaranteed,
    );
    expect(projection.outcomes[5].result, isNull);
    expect(
      projection.outcomes[6].disposition,
      ChunkV2MarkerPlacementDisposition.disabled,
    );
    expect(projection.outcomes[6].result, isNull);
  });

  test('reports exact Core rejection for an undersized Derf perch', () {
    final projection = ChunkV2MarkerPlacementProjection.build(
      chunk: _chunk(const <PlacedMarkerDef>[
        PlacedMarkerDef(
          markerId: 'derf',
          x: 212,
          y: 20,
          placement: markerPlacementObstacleTop,
        ),
      ]),
      actorTerrain: ChunkV2ActorTerrainProjection.build(_expansion()),
      levelGroundTopY: 200,
    );

    final outcome = projection.outcomes.single;
    expect(
      outcome.disposition,
      ChunkV2MarkerPlacementDisposition.guaranteedRejected,
    );
    expect(outcome.intendedSurface!.id.placementKey, 'prefab_narrow');
    expect(
      outcome.result!.validity,
      TerrainPlacementValidity.insufficientSupportWidth,
    );
    expect(outcome.result!.diagnostic, contains('slope=0'));
  });

  test('malformed marker and missing level context never reach Core', () {
    final projection = ChunkV2MarkerPlacementProjection.build(
      chunk: _chunk(const <PlacedMarkerDef>[
        PlacedMarkerDef(
          markerId: 'unknown',
          x: -1,
          y: 401,
          chancePercent: 101,
          salt: -1,
          placement: 'unsupported',
        ),
      ]),
      actorTerrain: ChunkV2ActorTerrainProjection.build(_expansion()),
      levelGroundTopY: null,
    );

    final outcome = projection.outcomes.single;
    expect(outcome.disposition, ChunkV2MarkerPlacementDisposition.malformed);
    expect(outcome.result, isNull);
    expect(outcome.malformedCodes, <String>[
      'unknown_enemy_marker_id',
      'marker_invalid_placement',
      'marker_x_out_of_bounds',
      'marker_y_out_of_bounds',
      'marker_chance_out_of_range',
      'marker_salt_negative',
      'marker_level_ground_context_missing',
    ]);
  });
}

ChunkV2FileData _chunk(Iterable<PlacedMarkerDef> markers) => ChunkV2FileData(
  chunkKey: 'test_chunk',
  id: 'test_chunk',
  revision: 1,
  status: chunkStatusActive,
  levelId: 'forest',
  tileSize: 16,
  width: 400,
  height: 400,
  difficulty: chunkDifficultyNormal,
  assemblyGroupId: defaultChunkAssemblyGroupId,
  tags: const <String>['forest'],
  tileLayers: const <TileLayerDef>[],
  prefabs: const <PlacedPrefabDef>[],
  markers: markers,
  groundBandZIndex: 0,
  collisionShapes: const [],
);

ChunkV2CollisionExpansion _expansion() {
  final geometry = const TerrainCompiler().compile(<TerrainPolygonInput>[
    _rectangle('ground', left: 0, top: 200, right: 400, bottom: 260),
    _rectangle(
      'obstacle',
      left: 100,
      top: 100,
      right: 180,
      bottom: 160,
      placementKey: 'prefab_obstacle',
    ),
    _rectangle(
      'narrow',
      left: 200,
      top: 100,
      right: 224,
      bottom: 160,
      placementKey: 'prefab_narrow',
    ),
  ], geometryVersion: 11);
  return ChunkV2CollisionExpansion(
    chunkKey: 'test_chunk',
    geometry: geometry,
    directShapeCount: 1,
    expandedPrefabShapes: const <ChunkV2ExpandedPrefabShape>[],
  );
}

TerrainPolygonInput _rectangle(
  String shapeId, {
  required double left,
  required double top,
  required double right,
  required double bottom,
  String? placementKey,
}) => TerrainPolygonInput.fromWorld(
  sourcePath: 'test/$shapeId.json',
  identity: TerrainSourceIdentity(
    chunkIndex: 0,
    chunkKey: 'test_chunk',
    placementKey: placementKey,
    shapeId: shapeId,
  ),
  vertices: <(double, double)>[
    (left, top),
    (right, top),
    (right, bottom),
    (left, bottom),
  ],
);

int _ticks(double value) => physicsCoordinateToTicks(value);
