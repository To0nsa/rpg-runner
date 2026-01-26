import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_runner/core/abilities/ability_def.dart';
import 'package:rpg_runner/core/combat/damage.dart';
import 'package:rpg_runner/core/combat/middleware/sword_parry_middleware.dart';
import 'package:rpg_runner/core/ecs/entity_factory.dart';
import 'package:rpg_runner/core/ecs/systems/active_ability_phase_system.dart';
import 'package:rpg_runner/core/ecs/systems/damage_middleware_system.dart';
import 'package:rpg_runner/core/ecs/stores/damage_queue_store.dart';
import 'package:rpg_runner/core/ecs/world.dart';
import 'package:rpg_runner/core/events/game_event.dart';
import 'package:rpg_runner/core/ecs/stores/body_store.dart';
import 'package:rpg_runner/core/ecs/stores/collider_aabb_store.dart';
import 'package:rpg_runner/core/ecs/stores/health_store.dart';
import 'package:rpg_runner/core/ecs/stores/mana_store.dart';
import 'package:rpg_runner/core/ecs/stores/stamina_store.dart';
import 'package:rpg_runner/core/snapshots/enums.dart';

void main() {
  test('SwordParryMiddleware cancels first hit and consumes per activation', () {
    final world = EcsWorld();
    final player = EntityFactory(world).createPlayer(
      posX: 0,
      posY: 0,
      velX: 0,
      velY: 0,
      facing: Facing.right,
      grounded: true,
      body: const BodyDef(isKinematic: true, useGravity: false),
      collider: const ColliderAabbDef(halfX: 8, halfY: 8),
      health: const HealthDef(hp: 10000, hpMax: 10000, regenPerSecond100: 0),
      mana: const ManaDef(mana: 0, manaMax: 0, regenPerSecond100: 0),
      stamina: const StaminaDef(stamina: 0, staminaMax: 0, regenPerSecond100: 0),
    );

    final enemy = world.createEntity();
    world.health.add(
      enemy,
      const HealthDef(hp: 5000, hpMax: 5000, regenPerSecond100: 0),
    );

    world.activeAbility.set(
      player,
      id: 'eloise.sword_parry',
      slot: AbilitySlot.primary,
      commitTick: 10,
      windupTicks: 4,
      activeTicks: 14,
      recoveryTicks: 4,
      facingDir: Facing.right,
    );

    final phaseSystem = ActiveAbilityPhaseSystem();
    phaseSystem.step(world, currentTick: 14);

    world.damageQueue.add(
      DamageRequest(
        target: player,
        amount100: 1000,
        source: enemy,
        sourceKind: DeathSourceKind.meleeHitbox,
      ),
    );
    world.damageQueue.add(
      DamageRequest(
        target: player,
        amount100: 500,
        source: enemy,
        sourceKind: DeathSourceKind.meleeHitbox,
      ),
    );

    final middleware = DamageMiddlewareSystem(
      middlewares: [SwordParryMiddleware()],
    );
    middleware.step(world, currentTick: 14);

    expect(world.damageQueue.length, equals(3));
    expect(world.damageQueue.flags[0] & DamageQueueFlags.canceled, equals(1));
    expect(world.damageQueue.flags[1] & DamageQueueFlags.canceled, equals(0));
    expect(world.parryConsume.consumedStartTick.single, equals(10));
    expect(world.damageQueue.target.last, equals(enemy));
    expect(world.damageQueue.amount100.last, equals(600));
  });
}
