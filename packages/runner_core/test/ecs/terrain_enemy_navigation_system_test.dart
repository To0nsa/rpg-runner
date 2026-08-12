import 'package:runner_core/collision/terrain/terrain_compiler.dart';
import 'package:runner_core/collision/terrain/terrain_geometry.dart';
import 'package:runner_core/collision/terrain/terrain_numeric.dart';
import 'package:runner_core/collision/terrain/terrain_polygon.dart';
import 'package:runner_core/ecs/entity_factory.dart';
import 'package:runner_core/ecs/stores/health_store.dart';
import 'package:runner_core/ecs/stores/mana_store.dart';
import 'package:runner_core/ecs/stores/stamina_store.dart';
import 'package:runner_core/ecs/systems/ground_enemy_locomotion_system.dart';
import 'package:runner_core/ecs/systems/terrain_enemy_navigation_system.dart';
import 'package:runner_core/ecs/world.dart';
import 'package:runner_core/enemies/enemy_catalog.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/navigation/terrain_placement_query.dart';
import 'package:runner_core/navigation/terrain_runtime_bundle.dart';
import 'package:runner_core/navigation/terrain_surface_navigator.dart';
import 'package:runner_core/navigation/terrain_surface_pathfinder.dart';
import 'package:runner_core/navigation/types/terrain_navigation_surface.dart';
import 'package:runner_core/navigation/types/terrain_surface_graph.dart';
import 'package:runner_core/players/characters/eloise.dart';
import 'package:runner_core/players/player_tuning.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/tuning/ground_enemy_tuning.dart';
import 'package:runner_core/tuning/physics_tuning.dart';
import 'package:test/test.dart';

void main() {
  group('terrain enemy navigation system', () {
    test(
      'routes same-chain pursuit and invalidates state by bundle version',
      () {
        var bundle = _bundle(_floorGeometry(version: 1));
        final fixture = _worldOnGraph(
          bundle,
          enemyBodyX: 100 * terrainPhysicsTicksPerWorldUnit,
          playerBodyX: 400 * terrainPhysicsTicksPerWorldUnit,
        );
        final system = _system(() => bundle);

        system.step(fixture.world, player: fixture.player, currentTick: 1);

        final intentIndex = fixture.world.navIntent.indexOf(fixture.enemy);
        final navIndex = fixture.world.surfaceNav.indexOf(fixture.enemy);
        expect(fixture.world.navIntent.hasPlan[intentIndex], isTrue);
        expect(
          fixture.world.navIntent.desiredX[intentIndex],
          closeTo(400, 1e-9),
        );
        expect(
          fixture.world.surfaceNav.terrainState[navIndex].bundleVersion,
          1,
        );
        expect(system.lastNavigatedEnemyCount, 1);

        final staleState = fixture.world.surfaceNav.terrainState[navIndex]
          ..activeEdgeIndex = 0
          ..pathCursor = 1
          ..pathEdges.add(0);
        bundle = _bundle(_floorGeometry(version: 2));
        _setSupport(
          fixture.world,
          entity: fixture.player,
          bundle: bundle,
          graph: bundle.grojibGraph,
          surface: bundle.surfaceSet.surfaces.single,
          desiredBodyXTicks: 400 * terrainPhysicsTicksPerWorldUnit,
        );
        _setSupport(
          fixture.world,
          entity: fixture.enemy,
          bundle: bundle,
          graph: bundle.grojibGraph,
          surface: bundle.surfaceSet.surfaces.single,
          desiredBodyXTicks: 100 * terrainPhysicsTicksPerWorldUnit,
        );

        system.step(fixture.world, player: fixture.player, currentTick: 2);

        expect(staleState.bundleVersion, 2);
        expect(staleState.activeEdgeIndex, -1);
        expect(staleState.pathEdges, isEmpty);
      },
    );

    test('publishes jump timing for terrain-backed locomotion', () {
      final bundle = _bundle(_jumpGeometry());
      final graph = bundle.grojibGraph;
      final jumpEdgeIndex = graph.edges.indexWhere(
        (edge) => edge.kind == TerrainSurfaceEdgeKind.jump,
      );
      expect(jumpEdgeIndex, isNonNegative);
      final sourceIndex = _sourceIndexForEdge(graph, jumpEdgeIndex);
      final edge = graph.edges[jumpEdgeIndex];
      final fixture = _worldOnGraph(
        bundle,
        enemySurface: graph.surfaces[sourceIndex],
        playerSurface: graph.surfaces[edge.to],
        enemyBodyX: edge.takeoffPoint.xTicks,
        playerBodyX: edge.landingPoint.xTicks,
      );
      final system = _system(() => bundle);

      system.step(fixture.world, player: fixture.player, currentTick: 1);

      final intentIndex = fixture.world.navIntent.indexOf(fixture.enemy);
      expect(fixture.world.navIntent.jumpNow[intentIndex], isTrue);
      expect(fixture.world.navIntent.hasPlan[intentIndex], isTrue);
      expect(
        fixture.world.navIntent.hasActiveJumpTraversal[intentIndex],
        isTrue,
      );
      expect(
        fixture.world.navIntent.activeJumpTravelTicks[intentIndex],
        edge.travelTicks,
      );

      final movement = MovementTuningDerived.from(
        eloiseCharacter.tuning.movement,
        tickHz: 60,
      );
      final locomotion = GroundEnemyLocomotionSystem(
        groundEnemyTuning: GroundEnemyTuningDerived.from(
          const GroundEnemyTuning(),
          tickHz: 60,
        ),
      );
      locomotion.step(
        fixture.world,
        player: fixture.player,
        dtSeconds: movement.dtSeconds,
        currentTick: 1,
      );

      final transformIndex = fixture.world.transform.indexOf(fixture.enemy);
      expect(fixture.world.transform.velY[transformIndex], lessThan(0));
      expect(
        fixture.world.transform.velX[transformIndex] * edge.commitDirectionX,
        greaterThan(0),
      );
      expect(
        fixture.world.terrainContact.grounded[fixture.world.terrainContact
            .indexOf(fixture.enemy)],
        isFalse,
      );
    });
  });
}

TerrainEnemyNavigationSystem _system(TerrainRuntimeBundle Function() bundle) =>
    TerrainEnemyNavigationSystem(
      runtimeBundle: bundle,
      navigator: TerrainSurfaceNavigator(
        pathfinder: TerrainSurfacePathfinder(maxExpandedNodes: 128),
      ),
      physics: const PhysicsTuning(),
      dtSeconds: 1 / 60,
    );

({EcsWorld world, int player, int enemy}) _worldOnGraph(
  TerrainRuntimeBundle bundle, {
  TerrainNavigationSurface? enemySurface,
  TerrainNavigationSurface? playerSurface,
  required int enemyBodyX,
  required int playerBodyX,
}) {
  final world = EcsWorld(seed: 7);
  const catalog = EnemyCatalog();
  final contact = catalog.terrainContactProfile(EnemyId.grojib);
  final archetype = catalog.get(EnemyId.grojib);
  final player = world.createEntity();
  world.transform.add(player, posX: 0, posY: 0, velX: 0, velY: 0);
  world.body.add(player, archetype.body);
  world.worldContactCapsule.add(player, contact.capsule);
  world.terrainTraversalProfile.add(player, contact.traversal);
  world.terrainContact.add(player);

  final enemy = EntityFactory(world).createEnemy(
    enemyId: EnemyId.grojib,
    posX: 0,
    posY: 0,
    velX: 0,
    velY: 0,
    facing: Facing.right,
    body: archetype.body,
    collider: archetype.collider,
    health: const HealthDef(hp: 100, hpMax: 100, regenPerSecond100: 0),
    mana: const ManaDef(mana: 0, manaMax: 0, regenPerSecond100: 0),
    stamina: const StaminaDef(stamina: 0, staminaMax: 0, regenPerSecond100: 0),
  );
  world.worldContactCapsule.add(enemy, contact.capsule);
  world.terrainTraversalProfile.add(enemy, contact.traversal);
  world.terrainContact.add(enemy);

  _setSupport(
    world,
    entity: player,
    bundle: bundle,
    graph: bundle.grojibGraph,
    surface: playerSurface ?? bundle.surfaceSet.surfaces.single,
    desiredBodyXTicks: playerBodyX,
  );
  _setSupport(
    world,
    entity: enemy,
    bundle: bundle,
    graph: bundle.grojibGraph,
    surface: enemySurface ?? bundle.surfaceSet.surfaces.single,
    desiredBodyXTicks: enemyBodyX,
  );
  return (world: world, player: player, enemy: enemy);
}

void _setSupport(
  EcsWorld world, {
  required int entity,
  required TerrainRuntimeBundle bundle,
  required TerrainSurfaceGraph graph,
  required TerrainNavigationSurface surface,
  required int desiredBodyXTicks,
}) {
  final profile = graph.buildProfile;
  final capsule = profile.capsuleForDirection(1);
  final capsuleX = desiredBodyXTicks + capsule.resolvedOffsetXTicks;
  final supportY = surface.yAtXTicks(
    capsuleX.clamp(surface.xMinTicks, surface.xMaxTicks),
  );
  final query = TerrainPlacementQuery(
    geometry: bundle.geometry,
    terrainIndex: bundle.edgeIndex,
    surfaceIndex: bundle.surfaceIndex,
  );
  final placement = query.resolveGrounded(
    TerrainGroundPlacementRequest(
      desiredBodyCenterXTicks: desiredBodyXTicks,
      minimumSupportYTicks: supportY,
      maximumSupportYTicks: supportY,
      capsule: capsule,
      traversalProfile: profile.traversalProfile,
      supportRequirement: profile.supportRequirement,
      intendedSupportEdgeId: surface.id,
      allowSameSupportClamp: true,
      expectedGeometryVersion: bundle.version,
    ),
  );
  expect(placement.isValid, isTrue, reason: placement.validity.name);
  final body = placement.bodyCenter!;
  final transformIndex = world.transform.indexOf(entity);
  world.transform.posX[transformIndex] =
      body.xTicks / terrainPhysicsTicksPerWorldUnit;
  world.transform.posY[transformIndex] =
      body.yTicks / terrainPhysicsTicksPerWorldUnit;
  world.terrainContact.setSupport(
    entity,
    edge: bundle.geometry.edgeById[surface.id]!,
    pointXTicks: placement.supportPoint!.xTicks,
    pointYTicks: placement.supportPoint!.yTicks,
    geometryVersion: bundle.version,
    currentTick: 0,
  );
}

int _sourceIndexForEdge(TerrainSurfaceGraph graph, int edgeIndex) {
  for (var source = 0; source < graph.surfaces.length; source++) {
    if (edgeIndex >= graph.edgeOffsets[source] &&
        edgeIndex < graph.edgeOffsets[source + 1]) {
      return source;
    }
  }
  throw StateError('Jump edge has no CSR source row.');
}

TerrainRuntimeBundle _bundle(TerrainGeometry geometry) =>
    TerrainRuntimeBundle.build(
      geometry: geometry,
      groundEnemyProfiles: buildDefaultGroundEnemyTerrainGraphProfiles(),
    );

TerrainGeometry _floorGeometry({required int version}) =>
    const TerrainCompiler().compile(<TerrainPolygonInput>[
      TerrainPolygonInput.fromWorld(
        sourcePath: 'test/navigation-floor',
        identity: TerrainSourceIdentity(
          chunkIndex: 0,
          chunkKey: 'test',
          shapeId: 'floor',
        ),
        vertices: <(double, double)>[
          (0, 100),
          (600, 100),
          (600, 160),
          (0, 160),
        ],
      ),
    ], geometryVersion: version);

TerrainGeometry _jumpGeometry() => const TerrainCompiler().compile(
  <TerrainPolygonInput>[
    TerrainPolygonInput.fromWorld(
      sourcePath: 'test/navigation-jump-left',
      identity: TerrainSourceIdentity(
        chunkIndex: 0,
        chunkKey: 'test',
        shapeId: 'left',
      ),
      vertices: <(double, double)>[(0, 180), (220, 180), (220, 240), (0, 240)],
    ),
    TerrainPolygonInput.fromWorld(
      sourcePath: 'test/navigation-jump-right',
      identity: TerrainSourceIdentity(
        chunkIndex: 0,
        chunkKey: 'test',
        shapeId: 'right',
      ),
      vertices: <(double, double)>[
        (300, 180),
        (560, 180),
        (560, 240),
        (300, 240),
      ],
    ),
  ],
  geometryVersion: 1,
);
