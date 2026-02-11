import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_runner/core/ecs/stores/body_store.dart';
import 'package:rpg_runner/core/ecs/stores/collider_aabb_store.dart';
import 'package:rpg_runner/core/ecs/stores/health_store.dart';
import 'package:rpg_runner/core/ecs/stores/mana_store.dart';
import 'package:rpg_runner/core/ecs/stores/stamina_store.dart';
import 'package:rpg_runner/core/ecs/systems/gravity_system.dart';
import 'package:rpg_runner/core/ecs/systems/mobility_system.dart';
import 'package:rpg_runner/core/ecs/world.dart';
import 'package:rpg_runner/core/abilities/ability_def.dart';
import 'package:rpg_runner/core/snapshots/enums.dart';
import 'package:rpg_runner/core/players/player_tuning.dart';
import 'package:rpg_runner/core/tuning/physics_tuning.dart';
import 'package:rpg_runner/core/ecs/entity_factory.dart';
import 'package:rpg_runner/core/ecs/stores/mobility_intent_store.dart';

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
      health: const HealthDef(hp: 10000, hpMax: 10000, regenPerSecond100: 0),
      mana: const ManaDef(mana: 0, manaMax: 0, regenPerSecond100: 0),
      stamina: const StaminaDef(
        stamina: 10000,
        staminaMax: 10000,
        regenPerSecond100: 0,
      ),
    );

    final tuning = MovementTuningDerived.from(
      const MovementTuning(),
      tickHz: 10,
    );
    const physics = PhysicsTuning(gravityY: 100);

    GravitySystem().step(world, tuning, physics: physics);

    expect(
      world.transform.velY[world.transform.indexOf(player)],
      closeTo(10.0, 1e-9),
    );
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
      health: const HealthDef(hp: 10000, hpMax: 10000, regenPerSecond100: 0),
      mana: const ManaDef(mana: 0, manaMax: 0, regenPerSecond100: 0),
      stamina: const StaminaDef(
        stamina: 10000,
        staminaMax: 10000,
        regenPerSecond100: 0,
      ),
    );

    final tuning = MovementTuningDerived.from(
      const MovementTuning(),
      tickHz: 10,
    );
    const physics = PhysicsTuning(gravityY: 100);

    world.gravityControl.setSuppressForTicks(player, 1);

    final gravity = GravitySystem();
    gravity.step(world, tuning, physics: physics);
    expect(
      world.transform.velY[world.transform.indexOf(player)],
      closeTo(0.0, 1e-9),
    );

    gravity.step(world, tuning, physics: physics);
    expect(
      world.transform.velY[world.transform.indexOf(player)],
      closeTo(10.0, 1e-9),
    );
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
      health: const HealthDef(hp: 10000, hpMax: 10000, regenPerSecond100: 0),
      mana: const ManaDef(mana: 0, manaMax: 0, regenPerSecond100: 0),
      stamina: const StaminaDef(
        stamina: 10000,
        staminaMax: 10000,
        regenPerSecond100: 0,
      ),
    );

    final tuning = MovementTuningDerived.from(
      const MovementTuning(
        dashDurationSeconds: 0.20,
        dashCooldownSeconds: 99.0,
      ),
      tickHz: 10,
    );
    const physics = PhysicsTuning(gravityY: 100);

    final mobility = MobilitySystem();
    final gravity = GravitySystem();

    // Tick 1: start dash; gravity should be suppressed.
    world.mobilityIntent.set(
      player,
      MobilityIntentDef(
        abilityId: 'eloise.dash',
        slot: AbilitySlot.mobility,
        dirX: 1.0,
        dirY: 0.0,
        speedScaleBp: 10000,
        commitTick: 0,
        windupTicks: 0,
        activeTicks: tuning.dashDurationTicks,
        recoveryTicks: 0,
        cooldownTicks: tuning.dashCooldownTicks,
        cooldownGroupId: CooldownGroup.mobility,
        staminaCost100: 0,
        tick: 0,
      ),
    );
    mobility.step(world, tuning, currentTick: 0);
    gravity.step(world, tuning, physics: physics);
    expect(
      world.transform.velY[world.transform.indexOf(player)],
      closeTo(0.0, 1e-9),
    );

    // Tick 2: dash active; gravity still suppressed.
    mobility.step(world, tuning, currentTick: 1);
    gravity.step(world, tuning, physics: physics);
    expect(
      world.transform.velY[world.transform.indexOf(player)],
      closeTo(0.0, 1e-9),
    );

    // Tick 3: dash ended; gravity resumes.
    mobility.step(world, tuning, currentTick: 2);
    gravity.step(world, tuning, physics: physics);
    expect(
      world.transform.velY[world.transform.indexOf(player)],
      closeTo(10.0, 1e-9),
    );
  });
}
