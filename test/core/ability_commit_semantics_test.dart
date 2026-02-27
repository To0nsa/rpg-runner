import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/core/abilities/ability_catalog.dart';
import 'package:rpg_runner/core/abilities/ability_def.dart';
import 'package:rpg_runner/core/accessories/accessory_catalog.dart';
import 'package:rpg_runner/core/snapshots/enums.dart';
import 'package:rpg_runner/core/ecs/stores/collider_aabb_store.dart';
import 'package:rpg_runner/core/ecs/stores/combat/equipped_loadout_store.dart';
import 'package:rpg_runner/core/ecs/stores/health_store.dart';
import 'package:rpg_runner/core/ecs/stores/stamina_store.dart';
import 'package:rpg_runner/core/ecs/systems/ability_activation_system.dart';
import 'package:rpg_runner/core/ecs/world.dart';
import 'package:rpg_runner/core/projectiles/projectile_catalog.dart';
import 'package:rpg_runner/core/spellBook/spell_book_catalog.dart';
import 'package:rpg_runner/core/weapons/weapon_catalog.dart';
import 'package:rpg_runner/core/weapons/weapon_id.dart';

// Mocks
class MockAbilities extends AbilityCatalog {
  const MockAbilities();

  @override
  AbilityDef? resolve(AbilityKey key) {
    if (key == 'test_melee') {
      return AbilityDef(
        id: 'test_melee',
        category: AbilityCategory.melee,
        allowedSlots: {AbilitySlot.primary},
        targetingModel: TargetingModel.directional,
        inputLifecycle: AbilityInputLifecycle.tap,
        windupTicks: 5,
        activeTicks: 5,
        recoveryTicks: 5,
        defaultCost: AbilityResourceCost(staminaCost100: 200),
        cooldownTicks: 10,
        animKey: AnimKey.strike,
        baseDamage: 100,
        hitDelivery: MeleeHitDelivery(
          sizeX: 10,
          sizeY: 10,
          offsetX: 0,
          offsetY: 0,
          hitPolicy: HitPolicy.oncePerTarget,
        ),
      );
    }
    if (key == 'test_blood_melee') {
      return AbilityDef(
        id: 'test_blood_melee',
        category: AbilityCategory.melee,
        allowedSlots: {AbilitySlot.primary},
        targetingModel: TargetingModel.directional,
        inputLifecycle: AbilityInputLifecycle.tap,
        windupTicks: 5,
        activeTicks: 5,
        recoveryTicks: 5,
        defaultCost: AbilityResourceCost(healthCost100: 499),
        cooldownTicks: 10,
        animKey: AnimKey.strike,
        baseDamage: 100,
        hitDelivery: MeleeHitDelivery(
          sizeX: 10,
          sizeY: 10,
          offsetX: 0,
          offsetY: 0,
          hitPolicy: HitPolicy.oncePerTarget,
        ),
      );
    }
    if (key == 'test_blood_melee_lethal') {
      return AbilityDef(
        id: 'test_blood_melee_lethal',
        category: AbilityCategory.melee,
        allowedSlots: {AbilitySlot.primary},
        targetingModel: TargetingModel.directional,
        inputLifecycle: AbilityInputLifecycle.tap,
        windupTicks: 5,
        activeTicks: 5,
        recoveryTicks: 5,
        defaultCost: AbilityResourceCost(healthCost100: 500),
        cooldownTicks: 10,
        animKey: AnimKey.strike,
        baseDamage: 100,
        hitDelivery: MeleeHitDelivery(
          sizeX: 10,
          sizeY: 10,
          offsetX: 0,
          offsetY: 0,
          hitPolicy: HitPolicy.oncePerTarget,
        ),
      );
    }
    return super.resolve(key);
  }
}

void main() {
  group('Ability Commit Semantics', () {
    test('Full Ability Commit Flow', () {
      final world = EcsWorld();
      final system = AbilityActivationSystem(
        tickHz: 60,
        inputBufferTicks: 10,
        abilities: const MockAbilities(),
        weapons: const WeaponCatalog(),
        projectiles: const ProjectileCatalog(),
        spellBooks: const SpellBookCatalog(),
        accessories: const AccessoryCatalog(),
      );

      final player = world.createEntity();

      // Setup Stores
      world.equippedLoadout.add(player);
      world.playerInput.add(player);
      // CORRECTED: Pass required facing argument
      world.movement.add(player, facing: Facing.right);
      world.abilityInputBuffer.add(player);
      world.stamina.add(
        player,
        const StaminaDef(stamina: 1000, staminaMax: 1000, regenPerSecond100: 0),
      );
      world.cooldown.add(player);
      world.activeAbility.add(player);
      world.meleeIntent.add(player);
      world.colliderAabb.add(
        player,
        const ColliderAabbDef(halfX: 10, halfY: 10),
      );
      // Added SelfIntent for completeness if needed (though only melee/projectile used by test_melee)
      // Melee ability does NOT require SelfIntent.

      // Setup Loadout
      final li = world.equippedLoadout.indexOf(player);
      world.equippedLoadout.mask[li] |= LoadoutSlotMask.mainHand;
      world.equippedLoadout.mainWeaponId[li] = WeaponId.plainsteel;
      world.equippedLoadout.abilityPrimaryId[li] = 'test_melee';

      // Simulate Input
      final ii = world.playerInput.indexOf(player);
      world.playerInput.strikePressed[ii] = true;

      // Execute Step
      system.step(world, player: player, currentTick: 100);

      // Verify Assertions
      // Stamina Cost 200 deducted from 1000 -> 800
      expect(world.stamina.stamina[world.stamina.indexOf(player)], equals(800));

      // Active Ability
      expect(world.activeAbility.has(player), isTrue);
      final ai = world.activeAbility.indexOf(player);
      expect(world.activeAbility.abilityId[ai], equals('test_melee'));
      expect(world.activeAbility.startTick[ai], equals(100));

      // Intent
      expect(world.meleeIntent.has(player), isTrue);
      final mi = world.meleeIntent.indexOf(player);
      expect(world.meleeIntent.commitTick[mi], equals(100));
    });

    test('Health cost commit is non-lethal and clamps to 1 HP minimum', () {
      final world = EcsWorld();
      final system = AbilityActivationSystem(
        tickHz: 60,
        inputBufferTicks: 10,
        abilities: const MockAbilities(),
        weapons: const WeaponCatalog(),
        projectiles: const ProjectileCatalog(),
        spellBooks: const SpellBookCatalog(),
        accessories: const AccessoryCatalog(),
      );

      final player = world.createEntity();
      world.equippedLoadout.add(player);
      world.playerInput.add(player);
      world.movement.add(player, facing: Facing.right);
      world.abilityInputBuffer.add(player);
      world.health.add(
        player,
        const HealthDef(hp: 500, hpMax: 500, regenPerSecond100: 0),
      );
      world.stamina.add(
        player,
        const StaminaDef(stamina: 0, staminaMax: 0, regenPerSecond100: 0),
      );
      world.cooldown.add(player);
      world.activeAbility.add(player);
      world.meleeIntent.add(player);
      world.colliderAabb.add(
        player,
        const ColliderAabbDef(halfX: 10, halfY: 10),
      );

      final li = world.equippedLoadout.indexOf(player);
      world.equippedLoadout.mask[li] |= LoadoutSlotMask.mainHand;
      world.equippedLoadout.mainWeaponId[li] = WeaponId.plainsteel;
      world.equippedLoadout.abilityPrimaryId[li] = 'test_blood_melee';

      final ii = world.playerInput.indexOf(player);
      world.playerInput.strikePressed[ii] = true;
      system.step(world, player: player, currentTick: 100);

      expect(world.health.hp[world.health.indexOf(player)], equals(1));
      expect(world.activeAbility.has(player), isTrue);
    });

    test('Lethal health cost blocks commit and leaves HP unchanged', () {
      final world = EcsWorld();
      final system = AbilityActivationSystem(
        tickHz: 60,
        inputBufferTicks: 10,
        abilities: const MockAbilities(),
        weapons: const WeaponCatalog(),
        projectiles: const ProjectileCatalog(),
        spellBooks: const SpellBookCatalog(),
        accessories: const AccessoryCatalog(),
      );

      final player = world.createEntity();
      world.equippedLoadout.add(player);
      world.playerInput.add(player);
      world.movement.add(player, facing: Facing.right);
      world.abilityInputBuffer.add(player);
      world.health.add(
        player,
        const HealthDef(hp: 500, hpMax: 500, regenPerSecond100: 0),
      );
      world.stamina.add(
        player,
        const StaminaDef(stamina: 0, staminaMax: 0, regenPerSecond100: 0),
      );
      world.cooldown.add(player);
      world.activeAbility.add(player);
      world.meleeIntent.add(player);
      world.colliderAabb.add(
        player,
        const ColliderAabbDef(halfX: 10, halfY: 10),
      );

      final li = world.equippedLoadout.indexOf(player);
      world.equippedLoadout.mask[li] |= LoadoutSlotMask.mainHand;
      world.equippedLoadout.mainWeaponId[li] = WeaponId.plainsteel;
      world.equippedLoadout.abilityPrimaryId[li] = 'test_blood_melee_lethal';

      final ii = world.playerInput.indexOf(player);
      world.playerInput.strikePressed[ii] = true;
      system.step(world, player: player, currentTick: 100);

      expect(world.health.hp[world.health.indexOf(player)], equals(500));
      expect(world.activeAbility.hasActiveAbility(player), isFalse);
    });
  });
}
