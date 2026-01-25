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
import 'package:rpg_runner/core/navigation/types/surface_graph.dart';
import 'package:rpg_runner/core/navigation/surface_graph_builder.dart';
import 'package:rpg_runner/core/navigation/surface_navigator.dart';
import 'package:rpg_runner/core/navigation/surface_pathfinder.dart';
import 'package:rpg_runner/core/snapshots/enums.dart';
import 'package:rpg_runner/core/tuning/ground_enemy_tuning.dart';
import 'package:rpg_runner/core/players/player_tuning.dart';
import 'package:rpg_runner/core/tuning/physics_tuning.dart';
import 'package:rpg_runner/core/ecs/entity_factory.dart';

void main() {
  test('ground enemy can drop off a platform to reach a player below', () {
    final world = EcsWorld();

    const groundTopY = 100.0;
    const platformTopY = 60.0;
    const platformMinX = 0.0;
    const platformMaxX = 80.0;
    const enemyHalf = 8.0;
    const stopDistanceX = 6.0;

    final player = world.createEntity();
    world.transform.add(
      player,
      posX: 200.0,
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
      posX: 40.0,
      posY: platformTopY - enemyHalf,
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
    final navIndex = world.surfaceNav.indexOf(enemy);
    final enemyIndex = world.enemy.indexOf(enemy);
    final intentIndex = world.navIntent.indexOf(enemy);

    final geometry = StaticWorldGeometry(
      groundPlane: const StaticGroundPlane(topY: groundTopY),
      solids: const <StaticSolid>[
        StaticSolid(
          minX: platformMinX,
          minY: platformTopY,
          maxX: platformMaxX,
          maxY: platformTopY + 16.0,
          sides: StaticSolid.sideTop,
          oneWayTop: true,
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
      maxExpandedNodes: 64,
      runSpeedX: 200.0,
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
            stopDistanceX: stopDistanceX,
            jumpSpeed: 300.0,
            // Make stopping very "snappy" so a missing drop-commit signal causes
            // the enemy to stop short of the ledge instead of coasting off.
            decelX: 5000.0,
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
            stopDistanceX: stopDistanceX,
            jumpSpeed: 300.0,
            // Make stopping very "snappy" so a missing drop-commit signal causes
            // the enemy to stop short of the ledge instead of coasting off.
            decelX: 5000.0,
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

    var groundedOnPlatformTicks = 0;
    var sawDropEdgeActive = false;
    var assertedCommitMovement = false;
    double? firstAirborneX;

    var dropped = false;
    var reachedGround = false;
    for (var tick = 0; tick < 200; tick += 1) {
      navigationSystem.step(world, player: player, currentTick: tick);
      engagementSystem.step(world, player: player, currentTick: tick);
      locomotionSystem.step(
        world,
        player: player,
        dtSeconds: movement.dtSeconds,
        currentTick: tick,
      );

      // Assert intent effects BEFORE gravity/collision integrate this tick.
      // This is where a missing drop-commit signal would cause the enemy to
      // stop short near the takeoff point.
      final tiBeforePhysics = world.transform.indexOf(enemy);
      final posXBeforePhysics = world.transform.posX[tiBeforePhysics];
      final posYBeforePhysics = world.transform.posY[tiBeforePhysics];
      final velXBeforePhysics = world.transform.velX[tiBeforePhysics];
      final ciBeforePhysics = world.collision.indexOf(enemy);
      final groundedBeforePhysics = world.collision.grounded[ciBeforePhysics];

      final activeEdgeIndex = world.surfaceNav.activeEdgeIndex[navIndex];
      final executingDrop = activeEdgeIndex >= 0 &&
          graphResult.graph.edges[activeEdgeIndex].kind == SurfaceEdgeKind.drop;
      if (executingDrop) {
        sawDropEdgeActive = true;
      }

      final onPlatformYBeforePhysics =
          (posYBeforePhysics - (platformTopY - enemyHalf)).abs() < 1.0;
      if (executingDrop &&
          groundedBeforePhysics &&
          onPlatformYBeforePhysics &&
          posXBeforePhysics > platformMaxX - stopDistanceX) {
        expect(velXBeforePhysics, greaterThan(0.0));
        assertedCommitMovement = true;
      }

      if (executingDrop && !groundedBeforePhysics) {
        final commitMoveDirX = world.navIntent.commitMoveDirX[intentIndex];
        expect(commitMoveDirX, isNot(0));
        expect(
          world.enemy.facing[enemyIndex],
          commitMoveDirX > 0 ? Facing.right : Facing.left,
        );
        expect(velXBeforePhysics * commitMoveDirX, greaterThan(0.0));
      }

      gravity.step(world, movement, physics: physics);
      collision.step(world, movement, staticWorld: staticWorld);

      final ti = world.transform.indexOf(enemy);
      final posX = world.transform.posX[ti];
      final posY = world.transform.posY[ti];

      final ci = world.collision.indexOf(enemy);
      final grounded = world.collision.grounded[ci];
      if (!grounded) {
        dropped = true;
        firstAirborneX ??= posX;
      }

      final onPlatformY = (posY - (platformTopY - enemyHalf)).abs() < 1.0;
      if (grounded && onPlatformY) {
        groundedOnPlatformTicks += 1;
      } else if (grounded) {
        final onGroundY = (posY - (groundTopY - enemyHalf)).abs() < 1.0;
        if (onGroundY) {
          reachedGround = true;
          break;
        }
      }
    }

    expect(groundedOnPlatformTicks, greaterThanOrEqualTo(2));
    expect(sawDropEdgeActive, isTrue);
    expect(assertedCommitMovement, isTrue);
    expect(firstAirborneX, isNotNull);
    expect(firstAirborneX!, greaterThan(platformMaxX));

    expect(dropped, isTrue);
    expect(reachedGround, isTrue);
  });
}
