import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_runner/core/abilities/ability_def.dart';
import 'package:rpg_runner/core/ecs/entity_factory.dart';
import 'package:rpg_runner/core/ecs/stores/body_store.dart';
import 'package:rpg_runner/core/ecs/stores/collider_aabb_store.dart';
import 'package:rpg_runner/core/ecs/stores/health_store.dart';
import 'package:rpg_runner/core/ecs/stores/mana_store.dart';
import 'package:rpg_runner/core/ecs/stores/self_intent_store.dart';
import 'package:rpg_runner/core/ecs/stores/stamina_store.dart';
import 'package:rpg_runner/core/ecs/systems/self_ability_system.dart';
import 'package:rpg_runner/core/ecs/world.dart';
import 'package:rpg_runner/core/snapshots/enums.dart';

void main() {
  test('SelfAbilitySystem commits and consumes resources', () {
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
      mana: const ManaDef(mana: 1000, manaMax: 1000, regenPerSecond100: 0),
      stamina: const StaminaDef(
        stamina: 1000,
        staminaMax: 1000,
        regenPerSecond100: 0,
      ),
    );

    world.selfIntent.set(
      player,
      SelfIntentDef(
        abilityId: 'eloise.sword_parry',
        slot: AbilitySlot.primary,
        commitTick: 5,
        windupTicks: 4,
        activeTicks: 14,
        recoveryTicks: 4,
        cooldownTicks: 30,
        cooldownGroupId: CooldownGroup.primary,
        staminaCost100: 700,
        manaCost100: 0,
        tick: 9,
      ),
    );

    final system = SelfAbilitySystem();
    system.step(world, currentTick: 5);

    final ai = world.activeAbility.indexOf(player);
    expect(world.activeAbility.abilityId[ai], equals('eloise.sword_parry'));
    expect(
      world.cooldown.getTicksLeft(player, CooldownGroup.primary),
      equals(30),
    );
    expect(world.stamina.stamina[world.stamina.indexOf(player)], equals(300));
  });
}
