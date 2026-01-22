import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_runner/core/ecs/stores/body_store.dart';
import 'package:rpg_runner/core/ecs/stores/collider_aabb_store.dart';
import 'package:rpg_runner/core/ecs/stores/health_store.dart';
import 'package:rpg_runner/core/ecs/stores/mana_store.dart';
import 'package:rpg_runner/core/ecs/stores/stamina_store.dart';
import 'package:rpg_runner/core/ecs/systems/gravity_system.dart';
import 'package:rpg_runner/core/ecs/systems/player_movement_system.dart';
import 'package:rpg_runner/core/ecs/world.dart';
import 'package:rpg_runner/core/snapshots/enums.dart';
import 'package:rpg_runner/core/players/player_tuning.dart';
import 'package:rpg_runner/core/tuning/physics_tuning.dart';
import 'package:rpg_runner/core/ecs/entity_factory.dart';

void main() {
  test('GravitySystem applies gravity when enabled and not suppressed', () {
    final world = EcsWorld();
    final player = EntityFactory(world).createPlayer(
      posX: 0,
      posY: 0,
      velX: 0,
      velY: 0,
      facing: Facing.right,
      grounded: true,
      body: const BodyDef(
        isKinematic: false,
        useGravity: true,
        gravityScale: 1.0,
        maxVelY: 9999,
      ),
      collider: const ColliderAabbDef(halfX: 8, halfY: 8),
      health: const HealthDef(hp: 100, hpMax: 100, regenPerSecond: 0),
      mana: const ManaDef(mana: 0, manaMax: 0, regenPerSecond: 0),
      stamina: const StaminaDef(stamina: 100, staminaMax: 100, regenPerSecond: 0),
    );

    final tuning = MovementTuningDerived.from(
      const MovementTuning(),
      tickHz: 10,
    );
    const physics = PhysicsTuning(gravityY: 100);

    GravitySystem().step(world, tuning, physics: physics);

    expect(world.transform.velY[world.transform.indexOf(player)], closeTo(10.0, 1e-9));
  });

  test('GravitySystem skips gravity while suppressed and resumes after', () {
    final world = EcsWorld();
    final player = EntityFactory(world).createPlayer(
      posX: 0,
      posY: 0,
      velX: 0,
      velY: 0,
      facing: Facing.right,
      grounded: true,
      body: const BodyDef(
        isKinematic: false,
        useGravity: true,
        gravityScale: 1.0,
        maxVelY: 9999,
      ),
      collider: const ColliderAabbDef(halfX: 8, halfY: 8),
      health: const HealthDef(hp: 100, hpMax: 100, regenPerSecond: 0),
      mana: const ManaDef(mana: 0, manaMax: 0, regenPerSecond: 0),
      stamina: const StaminaDef(stamina: 100, staminaMax: 100, regenPerSecond: 0),
    );

    final tuning = MovementTuningDerived.from(
      const MovementTuning(),
      tickHz: 10,
    );
    const physics = PhysicsTuning(gravityY: 100);

    world.gravityControl.setSuppressForTicks(player, 1);

    final gravity = GravitySystem();
    gravity.step(world, tuning, physics: physics);
    expect(world.transform.velY[world.transform.indexOf(player)], closeTo(0.0, 1e-9));

    gravity.step(world, tuning, physics: physics);
    expect(world.transform.velY[world.transform.indexOf(player)], closeTo(10.0, 1e-9));
  });

  test('Player dash suppresses gravity for dash duration', () {
    final world = EcsWorld();
    final player = EntityFactory(world).createPlayer(
      posX: 0,
      posY: 0,
      velX: 0,
      velY: 0,
      facing: Facing.right,
      grounded: true,
      body: const BodyDef(
        isKinematic: false,
        useGravity: true,
        gravityScale: 1.0,
        maxVelY: 9999,
      ),
      collider: const ColliderAabbDef(halfX: 8, halfY: 8),
      health: const HealthDef(hp: 100, hpMax: 100, regenPerSecond: 0),
      mana: const ManaDef(mana: 0, manaMax: 0, regenPerSecond: 0),
      stamina: const StaminaDef(stamina: 100, staminaMax: 100, regenPerSecond: 0),
    );

    final tuning = MovementTuningDerived.from(
      const MovementTuning(
        dashDurationSeconds: 0.20,
        dashCooldownSeconds: 99.0,
      ),
      tickHz: 10,
    );
    const physics = PhysicsTuning(gravityY: 100);

    final movement = PlayerMovementSystem();
    final gravity = GravitySystem();

    final ii = world.playerInput.indexOf(player);

    // Tick 1: start dash; gravity should be suppressed.
    world.playerInput.moveAxis[ii] = 1.0;
    world.playerInput.dashPressed[ii] = true;
    movement.step(world, tuning, resources: const ResourceTuning(), currentTick: 0);
    gravity.step(world, tuning, physics: physics);
    expect(world.transform.velY[world.transform.indexOf(player)], closeTo(0.0, 1e-9));

    // Tick 2: dash active; gravity still suppressed.
    world.playerInput.moveAxis[ii] = 0.0;
    world.playerInput.dashPressed[ii] = false;
    movement.step(world, tuning, resources: const ResourceTuning(), currentTick: 0);
    gravity.step(world, tuning, physics: physics);
    expect(world.transform.velY[world.transform.indexOf(player)], closeTo(0.0, 1e-9));

    // Tick 3: dash ended; gravity resumes.
    movement.step(world, tuning, resources: const ResourceTuning(), currentTick: 0);
    gravity.step(world, tuning, physics: physics);
    expect(world.transform.velY[world.transform.indexOf(player)], closeTo(10.0, 1e-9));
  });
}
