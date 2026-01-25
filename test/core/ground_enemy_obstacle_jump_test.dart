import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_runner/core/collision/static_world_geometry.dart';
import 'package:rpg_runner/core/collision/static_world_geometry_index.dart';
import 'package:rpg_runner/core/enemies/enemy_id.dart';
import 'package:rpg_runner/core/ecs/stores/body_store.dart';
import 'package:rpg_runner/core/ecs/stores/collider_aabb_store.dart';
import 'package:rpg_runner/core/ecs/stores/health_store.dart';
import 'package:rpg_runner/core/ecs/stores/mana_store.dart';
import 'package:rpg_runner/core/ecs/stores/stamina_store.dart';
import 'package:rpg_runner/core/ecs/spatial/grid_index_2d.dart';
import 'package:rpg_runner/core/ecs/systems/collision_system.dart';
import 'package:rpg_runner/core/ecs/systems/enemy_engagement_system.dart';
import 'package:rpg_runner/core/ecs/systems/ground_enemy_locomotion_system.dart';
import 'package:rpg_runner/core/ecs/systems/enemy_navigation_system.dart';
import 'package:rpg_runner/core/ecs/systems/gravity_system.dart';
import 'package:rpg_runner/core/ecs/world.dart';
import 'package:rpg_runner/core/navigation/utils/jump_template.dart';
import 'package:rpg_runner/core/navigation/surface_extractor.dart';
import 'package:rpg_runner/core/navigation/surface_graph_builder.dart';
import 'package:rpg_runner/core/navigation/surface_navigator.dart';
import 'package:rpg_runner/core/navigation/surface_pathfinder.dart';
import 'package:rpg_runner/core/snapshots/enums.dart';
import 'package:rpg_runner/core/tuning/ground_enemy_tuning.dart';
import 'package:rpg_runner/core/players/player_tuning.dart';
import 'package:rpg_runner/core/tuning/physics_tuning.dart';
import 'package:rpg_runner/core/ecs/entity_factory.dart';

void main() {
  test('ground enemy jumps over a wall obstacle on the ground', () {
    final world = EcsWorld();

    const groundTopY = 100.0;
    const enemyHalf = 8.0;
    const wallMinX = 40.0;
    const wallMaxX = 60.0;

    final player = world.createEntity();
    world.transform.add(
      player,
      posX: 160.0,
      posY: groundTopY - enemyHalf,
      velX: 0.0,
      velY: 0.0,
    );
    world.colliderAabb.add(
      player,
      const ColliderAabbDef(halfX: enemyHalf, halfY: enemyHalf),
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
      enemyId: EnemyId.groundEnemy,
      posX: 0.0,
      posY: groundTopY - enemyHalf,
      velX: 0.0,
      velY: 0.0,
      facing: Facing.right,
      body: const BodyDef(
        isKinematic: false,
        useGravity: true,
        gravityScale: 1.0,
        maxVelY: 9999,
      ),
      collider: const ColliderAabbDef(halfX: enemyHalf, halfY: enemyHalf),
      health: const HealthDef(hp: 1000, hpMax: 1000, regenPerSecond100: 0),
      mana: const ManaDef(mana: 0, manaMax: 0, regenPerSecond100: 0),
      stamina: const StaminaDef(stamina: 0, staminaMax: 0, regenPerSecond100: 0),
    );

    const geometry = StaticWorldGeometry(
      groundPlane: StaticGroundPlane(topY: groundTopY),
      solids: <StaticSolid>[
        // Wall obstacle: blocks horizontal motion, but has no walkable top. This
        // forces a same-ground jump rather than a "step onto the obstacle".
        StaticSolid(
          minX: wallMinX,
          minY: groundTopY - 40.0,
          maxX: wallMaxX,
          maxY: groundTopY,
          sides: StaticSolid.sideLeft | StaticSolid.sideRight,
          oneWayTop: false,
          chunkIndex: 0,
          localSolidIndex: 0,
        ),
      ],
    );
    final staticWorld = StaticWorldGeometryIndex.from(geometry);

    final movement = MovementTuningDerived.from(
      const MovementTuning(),
      tickHz: 10,
    );
    const physics = PhysicsTuning(gravityY: 200.0);

    final collision = CollisionSystem();
    final gravity = GravitySystem();

    final graphBuilder = SurfaceGraphBuilder(
      surfaceGrid: GridIndex2D(cellSize: 32),
      extractor: SurfaceExtractor(groundPadding: 200.0),
    );
    final jumpTemplate = JumpReachabilityTemplate.build(
      JumpProfile(
        jumpSpeed: 300.0,
        gravityY: physics.gravityY,
        maxAirTicks: 80,
        airSpeedX: 200.0,
        dtSeconds: movement.dtSeconds,
        agentHalfWidth: enemyHalf,
      ),
    );
    final graphResult = graphBuilder.build(
      geometry: geometry,
      jumpTemplate: jumpTemplate,
    );

    final pathfinder = SurfacePathfinder(
      maxExpandedNodes: 128,
      runSpeedX: 200.0,
      edgePenaltySeconds: 0.05,
    );
    final navigationSystem = EnemyNavigationSystem(
      surfaceNavigator: SurfaceNavigator(
        pathfinder: pathfinder,
        repathCooldownTicks: 5,
        takeoffEps: 6.0,
      ),
    );
    final engagementSystem = EnemyEngagementSystem(
      groundEnemyTuning: GroundEnemyTuningDerived.from(
        const GroundEnemyTuning(
          locomotion: GroundEnemyLocomotionTuning(
            speedX: 200.0,
            stopDistanceX: 6.0,
            jumpSpeed: 300.0,
          ),
        ),
        tickHz: 10,
      ),
    );
    final locomotionSystem = GroundEnemyLocomotionSystem(
      groundEnemyTuning: GroundEnemyTuningDerived.from(
        const GroundEnemyTuning(
          locomotion: GroundEnemyLocomotionTuning(
            speedX: 200.0,
            stopDistanceX: 6.0,
            jumpSpeed: 300.0,
          ),
        ),
        tickHz: 10,
      ),
    );
    navigationSystem.setSurfaceGraph(
      graph: graphResult.graph,
      spatialIndex: graphResult.spatialIndex,
      graphVersion: 1,
    );
    locomotionSystem.setSurfaceGraph(graph: graphResult.graph);

    var jumped = false;
    var clearedObstacle = false;
    for (var tick = 0; tick < 250; tick += 1) {
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

      final ci = world.collision.indexOf(enemy);
      final grounded = world.collision.grounded[ci];
      if (!grounded) jumped = true;

      final ti = world.transform.indexOf(enemy);
      final ex = world.transform.posX[ti];
      final ey = world.transform.posY[ti];
      if (ex > wallMaxX + enemyHalf &&
          grounded &&
          (ey - (groundTopY - enemyHalf)).abs() < 1.0) {
        clearedObstacle = true;
        break;
      }
    }

    expect(jumped, isTrue);
    expect(clearedObstacle, isTrue);
  });
}
