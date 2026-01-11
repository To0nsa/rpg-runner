import 'package:flutter_test/flutter_test.dart';

import 'package:walkscape_runner/core/collision/static_world_geometry.dart';
import 'package:walkscape_runner/core/collision/static_world_geometry_index.dart';
import 'package:walkscape_runner/core/enemies/enemy_catalog.dart';
import 'package:walkscape_runner/core/enemies/enemy_id.dart';
import 'package:walkscape_runner/core/ecs/stores/body_store.dart';
import 'package:walkscape_runner/core/ecs/stores/collider_aabb_store.dart';
import 'package:walkscape_runner/core/ecs/stores/health_store.dart';
import 'package:walkscape_runner/core/ecs/stores/mana_store.dart';
import 'package:walkscape_runner/core/ecs/stores/stamina_store.dart';
import 'package:walkscape_runner/core/ecs/spatial/grid_index_2d.dart';
import 'package:walkscape_runner/core/ecs/systems/collision_system.dart';
import 'package:walkscape_runner/core/ecs/systems/enemy_system.dart';
import 'package:walkscape_runner/core/ecs/systems/gravity_system.dart';
import 'package:walkscape_runner/core/ecs/world.dart';
import 'package:walkscape_runner/core/navigation/utils/jump_template.dart';
import 'package:walkscape_runner/core/navigation/surface_graph_builder.dart';
import 'package:walkscape_runner/core/navigation/surface_navigator.dart';
import 'package:walkscape_runner/core/navigation/surface_pathfinder.dart';
import 'package:walkscape_runner/core/projectiles/projectile_catalog.dart';
import 'package:walkscape_runner/core/snapshots/enums.dart';
import 'package:walkscape_runner/core/spells/spell_catalog.dart';
import 'package:walkscape_runner/core/tuning/flying_enemy_tuning.dart';
import 'package:walkscape_runner/core/tuning/ground_enemy_tuning.dart';
import 'package:walkscape_runner/core/players/player_tuning.dart';
import 'package:walkscape_runner/core/tuning/physics_tuning.dart';
import 'package:walkscape_runner/core/ecs/entity_factory.dart';

void main() {
  test('ground enemy ignores ceilings and can still jump to a higher platform', () {
    final world = EcsWorld();

    const groundTopY = 100.0;
    const platformTopY = 60.0;
    const ceilingBottomY = 80.0;
    const enemyHalf = 8.0;

    final player = world.createEntity();
    world.transform.add(
      player,
      posX: 160.0,
      posY: platformTopY - enemyHalf,
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
        ignoreCeilings: true,
        gravityScale: 1.0,
        maxVelY: 9999,
      ),
      collider: const ColliderAabbDef(halfX: enemyHalf, halfY: enemyHalf),
      health: const HealthDef(hp: 10, hpMax: 10, regenPerSecond: 0),
      mana: const ManaDef(mana: 0, manaMax: 0, regenPerSecond: 0),
      stamina: const StaminaDef(stamina: 0, staminaMax: 0, regenPerSecond: 0),
    );

    final geometry = StaticWorldGeometry(
      groundPlane: const StaticGroundPlane(topY: groundTopY),
      solids: const <StaticSolid>[
        StaticSolid(
          minX: 120.0,
          minY: platformTopY,
          maxX: 220.0,
          maxY: platformTopY + 16.0,
          sides: StaticSolid.sideTop,
          oneWayTop: true,
          chunkIndex: 0,
          localSolidIndex: 0,
        ),
        // A ceiling slab whose bottom face would normally cancel upward motion.
        StaticSolid(
          minX: -50.0,
          minY: ceilingBottomY - 10.0,
          maxX: 120.0,
          maxY: ceilingBottomY,
          sides: StaticSolid.sideBottom,
          oneWayTop: false,
          chunkIndex: 0,
          localSolidIndex: 1,
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
    final system = EnemySystem(
      unocoDemonTuning: UnocoDemonTuningDerived.from(
        const UnocoDemonTuning(),
        tickHz: 10,
      ),
      groundEnemyTuning: GroundEnemyTuningDerived.from(
        const GroundEnemyTuning(
          groundEnemySpeedX: 200.0,
          groundEnemyStopDistanceX: 6.0,
          groundEnemyJumpSpeed: 300.0,
        ),
        tickHz: 10,
      ),
      surfaceNavigator: SurfaceNavigator(
        pathfinder: pathfinder,
        repathCooldownTicks: 5,
        takeoffEps: 6.0,
      ),
      enemyCatalog: const EnemyCatalog(),
      spells: const SpellCatalog(),
      projectiles: ProjectileCatalogDerived.from(
        const ProjectileCatalog(),
        tickHz: 10,
      ),
    );
    system.setSurfaceGraph(
      graph: graphResult.graph,
      spatialIndex: graphResult.spatialIndex,
      graphVersion: 1,
    );

    var reached = false;
    for (var tick = 0; tick < 180; tick += 1) {
      system.stepSteering(
        world,
        player: player,
        groundTopY: groundTopY,
        dtSeconds: movement.dtSeconds,
      );
      gravity.step(world, movement, physics: physics);
      collision.step(world, movement, staticWorld: staticWorld);

      final ti = world.transform.indexOf(enemy);
      final ci = world.collision.indexOf(enemy);
      if (world.collision.grounded[ci]) {
        final posY = world.transform.posY[ti];
        if ((posY - (platformTopY - enemyHalf)).abs() < 1.0) {
          reached = true;
          break;
        }
      }
    }

    expect(reached, isTrue);
  });
}
