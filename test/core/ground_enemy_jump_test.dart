import 'package:flutter_test/flutter_test.dart';

import 'package:walkscape_runner/core/collision/static_world_geometry.dart';
import 'package:walkscape_runner/core/collision/static_world_geometry_index.dart';
import 'package:walkscape_runner/core/enemies/enemy_id.dart';
import 'package:walkscape_runner/core/ecs/stores/body_store.dart';
import 'package:walkscape_runner/core/ecs/stores/collider_aabb_store.dart';
import 'package:walkscape_runner/core/ecs/stores/health_store.dart';
import 'package:walkscape_runner/core/ecs/stores/mana_store.dart';
import 'package:walkscape_runner/core/ecs/stores/stamina_store.dart';
import 'package:walkscape_runner/core/ecs/systems/collision_system.dart';
import 'package:walkscape_runner/core/ecs/systems/enemy_system.dart';
import 'package:walkscape_runner/core/ecs/systems/gravity_system.dart';
import 'package:walkscape_runner/core/ecs/world.dart';
import 'package:walkscape_runner/core/snapshots/enums.dart';
import 'package:walkscape_runner/core/tuning/v0_flying_enemy_tuning.dart';
import 'package:walkscape_runner/core/tuning/v0_ground_enemy_tuning.dart';
import 'package:walkscape_runner/core/tuning/v0_movement_tuning.dart';
import 'package:walkscape_runner/core/tuning/v0_physics_tuning.dart';

void main() {
  test('ground enemy jumps after being blocked by an obstacle wall', () {
    final world = EcsWorld();

    const groundTopY = 100.0;
    const enemyHalf = 8.0;

    final player = world.createEntity();
    world.transform.add(
      player,
      posX: 100.0,
      posY: groundTopY - enemyHalf,
      velX: 0.0,
      velY: 0.0,
    );

    final enemy = world.createEnemy(
      enemyId: EnemyId.groundEnemy,
      posX: 0.0,
      posY: groundTopY - enemyHalf,
      velX: 100.0,
      velY: 0.0,
      facing: Facing.right,
      body: const BodyDef(
        isKinematic: false,
        useGravity: true,
        gravityScale: 1.0,
        maxVelY: 9999,
      ),
      collider: const ColliderAabbDef(halfX: enemyHalf, halfY: enemyHalf),
      health: const HealthDef(hp: 10, hpMax: 10, regenPerSecond: 0),
      mana: const ManaDef(mana: 0, manaMax: 0, regenPerSecond: 0),
      stamina: const StaminaDef(stamina: 0, staminaMax: 0, regenPerSecond: 0),
    );

    // Place a wall at x=10 that the enemy will cross into on the first tick.
    final geometry = StaticWorldGeometry(
      groundPlane: const StaticGroundPlane(topY: groundTopY),
      solids: const <StaticSolid>[
        StaticSolid(
          minX: 10.0,
          minY: 0.0,
          maxX: 20.0,
          maxY: 200.0,
          sides: StaticSolid.sideAll,
          oneWayTop: false,
        ),
      ],
    );
    final staticWorld = StaticWorldGeometryIndex.from(geometry);

    final movement = V0MovementTuningDerived.from(
      const V0MovementTuning(),
      tickHz: 10,
    );
    const physics = V0PhysicsTuning(gravityY: 100.0);

    final collision = CollisionSystem();
    final gravity = GravitySystem();

    // Tick 1 (physics): apply gravity and collide into the wall + ground.
    gravity.step(world, movement, physics: physics);
    collision.step(world, movement, staticWorld: staticWorld);

    final ci = world.collision.indexOf(enemy);
    expect(world.collision.grounded[ci], isTrue);
    expect(world.collision.hitRight[ci], isTrue);

    // Tick 2 (AI): should observe previous tick's wall hit and jump.
    final system = EnemySystem(
      flyingEnemyTuning: V0FlyingEnemyTuningDerived.from(
        const V0FlyingEnemyTuning(),
        tickHz: 10,
      ),
      groundEnemyTuning: V0GroundEnemyTuningDerived.from(
        const V0GroundEnemyTuning(
          groundEnemyJumpSpeed: 300.0,
          groundEnemyJumpCooldownSeconds: 1.0,
        ),
        tickHz: 10,
      ),
    );

    system.stepSteering(
      world,
      player: player,
      groundTopY: groundTopY,
      dtSeconds: movement.dtSeconds,
    );

    expect(world.transform.velY[world.transform.indexOf(enemy)], closeTo(-300.0, 1e-9));
  });
}
