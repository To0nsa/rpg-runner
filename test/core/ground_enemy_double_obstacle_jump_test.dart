import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_runner/core/collision/static_world_geometry_index.dart';
import 'package:rpg_runner/core/enemies/enemy_catalog.dart';
import 'package:rpg_runner/core/enemies/enemy_id.dart';
import 'package:rpg_runner/core/ecs/entity_factory.dart';
import 'package:rpg_runner/core/ecs/spatial/grid_index_2d.dart';
import 'package:rpg_runner/core/ecs/stores/body_store.dart';
import 'package:rpg_runner/core/ecs/stores/collider_aabb_store.dart';
import 'package:rpg_runner/core/ecs/stores/health_store.dart';
import 'package:rpg_runner/core/ecs/stores/mana_store.dart';
import 'package:rpg_runner/core/ecs/stores/stamina_store.dart';
import 'package:rpg_runner/core/ecs/systems/collision_system.dart';
import 'package:rpg_runner/core/ecs/systems/enemy_engagement_system.dart';
import 'package:rpg_runner/core/ecs/systems/enemy_navigation_system.dart';
import 'package:rpg_runner/core/ecs/systems/gravity_system.dart';
import 'package:rpg_runner/core/ecs/systems/ground_enemy_locomotion_system.dart';
import 'package:rpg_runner/core/ecs/world.dart';
import 'package:rpg_runner/core/navigation/surface_graph_builder.dart';
import 'package:rpg_runner/core/navigation/surface_navigator.dart';
import 'package:rpg_runner/core/navigation/surface_pathfinder.dart';
import 'package:rpg_runner/core/navigation/utils/jump_template.dart';
import 'package:rpg_runner/core/players/player_tuning.dart';
import 'package:rpg_runner/core/snapshots/enums.dart';
import 'package:rpg_runner/core/track/chunk_builder.dart';
import 'package:rpg_runner/core/track/chunk_pattern.dart';
import 'package:rpg_runner/core/tuning/ground_enemy_tuning.dart';
import 'package:rpg_runner/core/tuning/physics_tuning.dart';

void main() {
  test('ground enemy clears double-block obstacle sequence', () {
    const pattern = ChunkPattern(
      name: 'double-blocks',
      obstacles: <ObstacleRel>[
        ObstacleRel(x: 160.0, width: 32.0, height: 48.0),
        ObstacleRel(x: 288.0, width: 48.0, height: 64.0),
      ],
    );
    const groundTopY = 220.0;
    const chunkWidth = 600.0;
    const gridSnap = 16.0;
    const secondObstacleMaxX = 336.0;
    const playerX = 366.0;

    final solids = buildSolids(
      pattern,
      chunkStartX: 0.0,
      chunkIndex: 0,
      groundTopY: groundTopY,
      chunkWidth: chunkWidth,
      gridSnap: gridSnap,
    );
    final ground = buildGroundSegments(
      pattern,
      chunkStartX: 0.0,
      chunkIndex: 0,
      groundTopY: groundTopY,
      chunkWidth: chunkWidth,
      gridSnap: gridSnap,
    );
    final geometry = StaticWorldGeometry(
      groundPlane: const StaticGroundPlane(topY: groundTopY),
      groundSegments: List<StaticGroundSegment>.unmodifiable(ground.segments),
      groundGaps: List<StaticGroundGap>.unmodifiable(ground.gaps),
      solids: List<StaticSolid>.unmodifiable(solids),
    );

    final world = EcsWorld();
    const enemyCatalog = EnemyCatalog();
    final grojib = enemyCatalog.get(EnemyId.grojib);

    final player = world.createEntity();
    world.transform.add(
      player,
      posX: playerX,
      posY: groundTopY - 20.0,
      velX: 0.0,
      velY: 0.0,
    );
    world.colliderAabb.add(
      player,
      const ColliderAabbDef(halfX: 20.0, halfY: 20.0),
    );
    world.body.add(
      player,
      const BodyDef(
        isKinematic: false,
        useGravity: true,
        gravityScale: 1.0,
        maxVelY: 9999,
      ),
    );
    world.collision.add(player);
    world.collision.grounded[world.collision.indexOf(player)] = true;

    final enemy = EntityFactory(world).createEnemy(
      enemyId: EnemyId.grojib,
      posX: 40.0,
      posY: groundTopY - (grojib.collider.offsetY + grojib.collider.halfY),
      velX: 0.0,
      velY: 0.0,
      facing: Facing.right,
      body: grojib.body,
      collider: grojib.collider,
      health: const HealthDef(hp: 1000, hpMax: 1000, regenPerSecond100: 0),
      mana: const ManaDef(mana: 0, manaMax: 0, regenPerSecond100: 0),
      stamina: const StaminaDef(
        stamina: 0,
        staminaMax: 0,
        regenPerSecond100: 0,
      ),
    );

    final enemyAabb = world.colliderAabb.indexOf(enemy);
    final enemyHalfX = world.colliderAabb.halfX[enemyAabb];
    final enemyHalfY = world.colliderAabb.halfY[enemyAabb];
    final enemyOffsetY = world.colliderAabb.offsetY[enemyAabb];
    final groundY = groundTopY - (enemyOffsetY + enemyHalfY);

    final staticWorld = StaticWorldGeometryIndex.from(geometry);
    final movement = MovementTuningDerived.from(
      const MovementTuning(),
      tickHz: 60,
    );
    const physics = PhysicsTuning();
    final collision = CollisionSystem();
    final gravity = GravitySystem();

    final graphBuilder = SurfaceGraphBuilder(
      surfaceGrid: GridIndex2D(cellSize: 32),
    );
    final jumpTemplate = JumpReachabilityTemplate.build(
      JumpProfile(
        jumpSpeed: 500.0,
        gravityY: physics.gravityY,
        maxAirTicks: 120,
        airSpeedX: 300.0,
        dtSeconds: movement.dtSeconds,
        agentHalfWidth: enemyHalfX,
        agentHalfHeight: enemyHalfY,
        collideCeilings: !grojib.body.ignoreCeilings,
        collideLeftWalls: (grojib.body.sideMask & BodyDef.sideLeft) != 0,
        collideRightWalls: (grojib.body.sideMask & BodyDef.sideRight) != 0,
      ),
    );
    final graphResult = graphBuilder.build(
      geometry: geometry,
      jumpTemplate: jumpTemplate,
    );

    final pathfinder = SurfacePathfinder(
      maxExpandedNodes: 256,
      runSpeedX: 300.0,
      edgePenaltySeconds: 0.05,
    );
    final navigationSystem = EnemyNavigationSystem(
      surfaceNavigator: SurfaceNavigator(
        pathfinder: pathfinder,
        repathCooldownTicks: 5,
        takeoffEps: 6.0,
      ),
    );
    final tuning = GroundEnemyTuningDerived.from(
      const GroundEnemyTuning(),
      tickHz: 60,
    );
    final engagementSystem = EnemyEngagementSystem(groundEnemyTuning: tuning);
    final locomotionSystem = GroundEnemyLocomotionSystem(
      groundEnemyTuning: tuning,
    );
    navigationSystem.setSurfaceGraph(
      graph: graphResult.graph,
      spatialIndex: graphResult.spatialIndex,
      graphVersion: 1,
    );
    locomotionSystem.setSurfaceGraph(graph: graphResult.graph);

    var clearedSecondObstacle = false;
    for (var tick = 0; tick < 500; tick += 1) {
      navigationSystem.step(world, player: player, currentTick: tick);
      engagementSystem.step(world, player: player, currentTick: tick);
      locomotionSystem.step(
        world,
        player: player,
        dtSeconds: movement.dtSeconds,
        currentTick: tick,
      );
      gravity.step(world, movement, physics: physics);
      collision.step(world, movement, staticWorld: staticWorld);

      final ti = world.transform.indexOf(enemy);
      final ci = world.collision.indexOf(enemy);
      final ex = world.transform.posX[ti];
      final ey = world.transform.posY[ti];
      final grounded = world.collision.grounded[ci];
      if (ex > secondObstacleMaxX + enemyHalfX &&
          grounded &&
          (ey - groundY).abs() < 2.0) {
        clearedSecondObstacle = true;
        break;
      }
    }

    expect(clearedSecondObstacle, isTrue);
  });
}
