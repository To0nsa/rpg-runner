import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_runner/core/abilities/ability_catalog.dart';
import 'package:rpg_runner/core/abilities/ability_def.dart';
import 'package:rpg_runner/core/accessories/accessory_catalog.dart';
import 'package:rpg_runner/core/ecs/stores/collider_aabb_store.dart';
import 'package:rpg_runner/core/ecs/stores/combat/equipped_loadout_store.dart';
import 'package:rpg_runner/core/ecs/stores/stamina_store.dart';
import 'package:rpg_runner/core/ecs/systems/ability_activation_system.dart';
import 'package:rpg_runner/core/ecs/world.dart';
import 'package:rpg_runner/core/projectiles/projectile_catalog.dart';
import 'package:rpg_runner/core/snapshots/enums.dart';
import 'package:rpg_runner/core/spellBook/spell_book_catalog.dart';
import 'package:rpg_runner/core/weapons/weapon_catalog.dart';
import 'package:rpg_runner/core/weapons/weapon_id.dart';

class _ChargeMeleeAbilities extends AbilityCatalog {
  const _ChargeMeleeAbilities();

  @override
  AbilityDef? resolve(AbilityKey key) {
    if (key == 'test.melee_charge') {
      return AbilityDef(
        id: 'test.melee_charge',
        category: AbilityCategory.melee,
        allowedSlots: {AbilitySlot.primary},
        targetingModel: TargetingModel.directional,
        inputLifecycle: AbilityInputLifecycle.holdRelease,
        hitDelivery: MeleeHitDelivery(
          sizeX: 20,
          sizeY: 20,
          offsetX: 0,
          offsetY: 0,
          hitPolicy: HitPolicy.oncePerTarget,
        ),
        windupTicks: 4,
        activeTicks: 4,
        recoveryTicks: 4,
        cooldownTicks: 10,
        animKey: AnimKey.strike,
        payloadSource: AbilityPayloadSource.primaryWeapon,
        chargeProfile: AbilityChargeProfile(
          tiers: <AbilityChargeTierDef>[
            AbilityChargeTierDef(minHoldTicks60: 0, damageScaleBp: 10000),
            AbilityChargeTierDef(minHoldTicks60: 8, damageScaleBp: 15000),
          ],
        ),
        baseDamage: 100,
      );
    }
    return super.resolve(key);
  }
}

void main() {
  test('melee charge profile scales damage from authoritative hold ticks', () {
    (int damage100, double halfX) resolveMeleeIntent({
      required int chargeTicks,
    }) {
      final world = EcsWorld();
      final system = AbilityActivationSystem(
        tickHz: 60,
        inputBufferTicks: 8,
        abilities: const _ChargeMeleeAbilities(),
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
      world.abilityCharge.add(player);
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

      final li = world.equippedLoadout.indexOf(player);
      world.equippedLoadout.mask[li] |= LoadoutSlotMask.mainHand;
      world.equippedLoadout.mainWeaponId[li] = WeaponId.basicSword;
      world.equippedLoadout.abilityPrimaryId[li] = 'test.melee_charge';

      final chargeIndex = world.abilityCharge.indexOf(player);
      final slotOffset = world.abilityCharge.slotOffsetForDenseIndex(
        chargeIndex,
        AbilitySlot.primary,
      );
      world.abilityCharge.releasedHoldTicksBySlot[slotOffset] = chargeTicks;
      world.abilityCharge.releasedTickBySlot[slotOffset] = 100;

      final ii = world.playerInput.indexOf(player);
      world.playerInput.strikePressed[ii] = true;

      system.step(world, player: player, currentTick: 100);
      final mi = world.meleeIntent.indexOf(player);
      return (world.meleeIntent.damage100[mi], world.meleeIntent.halfX[mi]);
    }

    final tap = resolveMeleeIntent(chargeTicks: 0);
    final charged = resolveMeleeIntent(chargeTicks: 10);

    expect(charged.$1, greaterThan(tap.$1));
    expect(charged.$2, closeTo(tap.$2, 1e-9));
  });
}
