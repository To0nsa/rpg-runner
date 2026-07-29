import 'package:runner_core/collision/terrain/terrain_compiler.dart';
import 'package:runner_core/collision/terrain/terrain_edge_index.dart';
import 'package:runner_core/collision/terrain/terrain_numeric.dart';
import 'package:runner_core/collision/terrain/terrain_polygon.dart';
import 'package:runner_core/enemies/enemy_catalog.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/navigation/terrain_placement_query.dart';
import 'package:runner_core/navigation/terrain_spawn_placement.dart';
import 'package:runner_core/navigation/terrain_surface_extractor.dart';
import 'package:runner_core/navigation/terrain_surface_spatial_index.dart';
import 'package:runner_core/players/characters/eloise.dart';
import 'package:runner_core/players/player_catalog.dart';
import 'package:runner_core/players/player_tuning.dart';
import 'package:runner_core/snapshots/enums.dart';

/// Builds the canonical Section 20 placement records used across processes.
List<String> buildTerrainSpawnPlacementSignature({
  bool reverseInputOrder = false,
}) {
  final inputs = <TerrainPolygonInput>[
    _polygon('floor', const <(double, double)>[
      (0, 300),
      (800, 300),
      (800, 500),
      (0, 500),
    ]),
    _polygon('slope', const <(double, double)>[
      (100, 220),
      (300, 100),
      (300, 260),
      (100, 260),
    ]),
    _polygon('one_way', const <(double, double)>[
      (400, 180),
      (520, 180),
      (520, 190),
      (400, 190),
    ], collisionMode: TerrainCollisionMode.oneWay),
  ];
  final geometry = const TerrainCompiler().compile(
    reverseInputOrder ? inputs.reversed : inputs,
    geometryVersion: 20,
  );
  final surfaces = const TerrainSurfaceExtractor().extract(geometry);
  final resolver = TerrainSpawnPlacementResolver(
    placementQuery: TerrainPlacementQuery(
      geometry: geometry,
      terrainIndex: TerrainEdgeIndex(edges: geometry.edges),
      surfaceIndex: TerrainSurfaceSpatialIndex(surfaceSet: surfaces),
    ),
  );
  final slope = surfaces.surfaces.singleWhere(
    (surface) => surface.id.shapeId == 'slope',
  );

  const catalog = EnemyCatalog();
  final movement = MovementTuningDerived.from(
    eloiseCharacter.tuning.movement,
    tickHz: 60,
  );
  final player = PlayerCatalogDerived.from(
    eloiseCharacter.catalog,
    movement: movement,
    resources: ResourceTuningDerived.from(eloiseCharacter.tuning.resource),
  ).archetype;

  final grounded = resolver.resolve(
    TerrainSpawnPlacementRequest(
      profile: TerrainEnemySpawnPlacementProfile.fromCatalog(
        catalog: catalog,
        enemyId: EnemyId.hashash,
        facing: Facing.left,
      ),
      desiredBodyCenter: TerrainPoint.fromWorld(200, 0),
      supportSelection: TerrainSpawnSupportSelection.ground,
      intendedSupportEdgeId: slope.id,
    ),
  );
  final item = resolver.resolve(
    TerrainSpawnPlacementRequest(
      profile: TerrainItemSpawnPlacementProfile.fromWorld(
        itemKind: TerrainSpawnItemKind.collectible,
        width: 16,
        height: 16,
        supportClearance: 10,
        noSpawnMargin: 2,
        traversalProfile: player.terrainTraversalProfile,
      ),
      desiredBodyCenter: TerrainPoint.fromWorld(460, 0),
      supportSelection: TerrainSpawnSupportSelection.highestSurfaceAtX,
    ),
  );
  final flying = resolver.resolve(
    TerrainSpawnPlacementRequest(
      profile: TerrainEnemySpawnPlacementProfile.fromCatalog(
        catalog: catalog,
        enemyId: EnemyId.unocoDemon,
        facing: Facing.left,
      ),
      desiredBodyCenter: TerrainPoint.fromWorld(700, 120),
      supportSelection: TerrainSpawnSupportSelection.none,
    ),
  );
  final deferred = resolver.resolve(
    TerrainSpawnPlacementRequest(
      profile: TerrainEnemySpawnPlacementProfile.fromCatalog(
        catalog: catalog,
        enemyId: EnemyId.hashash,
        facing: Facing.left,
      ),
      desiredBodyCenter: TerrainPoint.fromWorld(200, 0),
      supportSelection: TerrainSpawnSupportSelection.deferredEdge,
      intendedSupportEdgeId: slope.id,
      requestedSupportYTicks: slope.yAtXTicks(_ticks(200)),
    ),
  );
  return <String>[
    grounded.diagnostic,
    item.diagnostic,
    flying.diagnostic,
    deferred.diagnostic,
  ];
}

TerrainPolygonInput _polygon(
  String shapeId,
  List<(double, double)> vertices, {
  TerrainCollisionMode collisionMode = TerrainCollisionMode.solid,
}) => TerrainPolygonInput.fromWorld(
  sourcePath: 'test/$shapeId.json',
  identity: TerrainSourceIdentity(
    chunkIndex: 0,
    chunkKey: 'spawn-signature',
    shapeId: shapeId,
  ),
  vertices: vertices,
  collisionMode: collisionMode,
);

int _ticks(double world) => physicsCoordinateToTicks(world);
