import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_runner/core/abilities/ability_catalog.dart';
import 'package:rpg_runner/core/abilities/ability_def.dart';
import 'package:rpg_runner/core/ecs/entity_factory.dart';
import 'package:rpg_runner/core/ecs/stores/body_store.dart';
import 'package:rpg_runner/core/ecs/stores/collider_aabb_store.dart';
import 'package:rpg_runner/core/ecs/stores/combat/equipped_loadout_store.dart';
import 'package:rpg_runner/core/ecs/stores/health_store.dart';
import 'package:rpg_runner/core/ecs/stores/mana_store.dart';
import 'package:rpg_runner/core/ecs/stores/stamina_store.dart';
import 'package:rpg_runner/core/ecs/systems/ability_activation_system.dart';
import 'package:rpg_runner/core/ecs/world.dart';
import 'package:rpg_runner/core/projectiles/projectile_item_catalog.dart';
import 'package:rpg_runner/core/spells/spell_book_catalog.dart';
import 'package:rpg_runner/core/snapshots/enums.dart';
import 'package:rpg_runner/core/weapons/weapon_catalog.dart';
import 'package:rpg_runner/core/weapons/weapon_id.dart';

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

    // Setup Loadout to map Primary -> eloise.sword_parry
    final li = world.equippedLoadout.indexOf(player);
    world.equippedLoadout.mask[li] |= LoadoutSlotMask.mainHand;
    world.equippedLoadout.abilityPrimaryId[li] = 'eloise.sword_parry';

    // Simulate input
    final pi = world.playerInput.indexOf(player);
    world.playerInput.strikePressed[pi] = true;

    // Ensure movement and intents are present (added by factory)

    final system = AbilityActivationSystem(
      tickHz: 60,
      inputBufferTicks: 10,
      abilities: const AbilityCatalog(),
      weapons: const WeaponCatalog(), // Mock/Defaults?
      projectileItems: const ProjectileItemCatalog(),
      spellBooks: const SpellBookCatalog(),
    );

    // Mock WeaponCatalog/AbilityCatalog imports might be needed if they are complex.
    // However, 'eloise.sword_parry' is in default AbilityCatalog.
    // 'basic_sword' might be needed if loadout requires it.
    world.equippedLoadout.mainWeaponId[li] =
        WeaponId.basicSword; // Just in case

    // Step
    system.step(world, player: player, currentTick: 5);

    // Verify
    expect(world.activeAbility.has(player), isTrue);
    final ai = world.activeAbility.indexOf(player);
    expect(world.activeAbility.abilityId[ai], equals('eloise.sword_parry'));

    // Cost 700 stamina -> 300 left
    expect(world.stamina.stamina[world.stamina.indexOf(player)], equals(300));

    // Cooldown 30 ticks
    expect(
      world.cooldown.getTicksLeft(player, CooldownGroup.primary),
      equals(30),
    );
  });
}
