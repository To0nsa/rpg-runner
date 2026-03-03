import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_runner/core/accessories/accessory_catalog.dart';
import 'package:rpg_runner/core/accessories/accessory_def.dart';
import 'package:rpg_runner/core/accessories/accessory_id.dart';
import 'package:rpg_runner/core/abilities/ability_def.dart' show WeaponType;
import 'package:rpg_runner/core/combat/damage_type.dart';
import 'package:rpg_runner/core/ecs/stores/combat/equipped_loadout_store.dart';
import 'package:rpg_runner/core/spellBook/spell_book_catalog.dart';
import 'package:rpg_runner/core/spellBook/spell_book_def.dart';
import 'package:rpg_runner/core/spellBook/spell_book_id.dart';
import 'package:rpg_runner/core/stats/character_stats_resolver.dart';
import 'package:rpg_runner/core/stats/gear_stat_bonuses.dart';
import 'package:rpg_runner/core/weapons/weapon_catalog.dart';
import 'package:rpg_runner/core/weapons/weapon_category.dart';
import 'package:rpg_runner/core/weapons/weapon_def.dart';
import 'package:rpg_runner/core/weapons/weapon_id.dart';

void main() {
  test('cooldown reduction is capped and scales cooldown ticks', () {
    final resolver = CharacterStatsResolver(
      weapons: const _FlatWeaponCatalog(),
      spellBooks: const _FlatSpellBookCatalog(),
      accessories: const _HighCdrAccessoryCatalog(),
    );

    final stats = resolver.resolveEquipped(
      mask: LoadoutSlotMask.mainHand,
      mainWeaponId: WeaponId.plainsteel,
      offhandWeaponId: WeaponId.roadguard,
      spellBookId: SpellBookId.apprenticePrimer,
      accessoryId: AccessoryId.speedBoots,
    );

    expect(
      stats.cooldownReductionBp,
      equals(CharacterStatCaps.maxCooldownReductionBp),
    );
    expect(stats.applyCooldownReduction(9), equals(5));
  });

  test('two-handed main weapon excludes offhand stat contribution', () {
    final resolver = CharacterStatsResolver(
      weapons: const _TwoHandedWeaponCatalog(),
      spellBooks: const _FlatSpellBookCatalog(),
      accessories: const _FlatAccessoryCatalog(),
    );

    final stats = resolver.resolveEquipped(
      mask: LoadoutSlotMask.mainHand | LoadoutSlotMask.offHand,
      mainWeaponId: WeaponId.plainsteel,
      offhandWeaponId: WeaponId.roadguard,
      spellBookId: SpellBookId.apprenticePrimer,
      accessoryId: AccessoryId.speedBoots,
    );

    expect(stats.globalPowerBonusBp, equals(100));
  });

  test('resource bonuses scale max pools deterministically', () {
    final resolver = CharacterStatsResolver(
      weapons: const _FlatWeaponCatalog(),
      spellBooks: const _FlatSpellBookCatalog(),
      accessories: const _ResourceAccessoryCatalog(),
    );

    final stats = resolver.resolveEquipped(
      mask: LoadoutSlotMask.mainHand,
      mainWeaponId: WeaponId.plainsteel,
      offhandWeaponId: WeaponId.roadguard,
      spellBookId: SpellBookId.apprenticePrimer,
      accessoryId: AccessoryId.goldenRing,
    );

    expect(stats.applyHealthMaxBonus(10000), equals(10200));
    expect(stats.applyManaMaxBonus(10000), equals(10300));
    expect(stats.applyStaminaMaxBonus(10000), equals(10400));
    expect(stats.applyHealthRegenBonus(10000), equals(10500));
    expect(stats.applyManaRegenBonus(10000), equals(10600));
    expect(stats.applyStaminaRegenBonus(10000), equals(10700));
  });

  test('spellbook stats contribute when projectile slot is enabled', () {
    final resolver = CharacterStatsResolver(
      weapons: const _FlatWeaponCatalog(),
      spellBooks: const _PowerSpellBookCatalog(),
      accessories: const _FlatAccessoryCatalog(),
    );

    final withoutProjectileMask = resolver.resolveEquipped(
      mask: LoadoutSlotMask.mainHand,
      mainWeaponId: WeaponId.plainsteel,
      offhandWeaponId: WeaponId.roadguard,
      spellBookId: SpellBookId.apprenticePrimer,
      accessoryId: AccessoryId.speedBoots,
    );
    final withProjectileMask = resolver.resolveEquipped(
      mask: LoadoutSlotMask.mainHand | LoadoutSlotMask.projectile,
      mainWeaponId: WeaponId.plainsteel,
      offhandWeaponId: WeaponId.roadguard,
      spellBookId: SpellBookId.apprenticePrimer,
      accessoryId: AccessoryId.speedBoots,
    );

    expect(withoutProjectileMask.globalPowerBonusBp, equals(0));
    expect(withProjectileMask.globalPowerBonusBp, equals(500));
  });

  test('typed resistance clamps and converts to incoming modifier', () {
    final resolver = CharacterStatsResolver(
      weapons: const _FlatWeaponCatalog(),
      spellBooks: const _FlatSpellBookCatalog(),
      accessories: const _TypedResistanceAccessoryCatalog(),
    );

    final stats = resolver.resolveEquipped(
      mask: LoadoutSlotMask.mainHand,
      mainWeaponId: WeaponId.plainsteel,
      offhandWeaponId: WeaponId.roadguard,
      spellBookId: SpellBookId.apprenticePrimer,
      accessoryId: AccessoryId.speedBoots,
    );

    expect(
      stats.fireResistanceBp,
      equals(CharacterStatCaps.maxTypedResistanceBp),
    );
    expect(
      stats.iceResistanceBp,
      equals(CharacterStatCaps.minTypedResistanceBp),
    );
    expect(
      stats.incomingDamageModBpForDamageType(DamageType.fire),
      equals(-CharacterStatCaps.maxTypedResistanceBp),
    );
    expect(
      stats.incomingDamageModBpForDamageType(DamageType.ice),
      equals(-CharacterStatCaps.minTypedResistanceBp),
    );
  });
}

class _FlatWeaponCatalog extends WeaponCatalog {
  const _FlatWeaponCatalog();

  @override
  WeaponDef get(WeaponId id) {
    return const WeaponDef(
      id: WeaponId.plainsteel,
      category: WeaponCategory.primary,
      weaponType: WeaponType.oneHandedSword,
      stats: GearStatBonuses(),
    );
  }
}

class _TwoHandedWeaponCatalog extends WeaponCatalog {
  const _TwoHandedWeaponCatalog();

  @override
  WeaponDef get(WeaponId id) {
    switch (id) {
      case WeaponId.plainsteel:
        return const WeaponDef(
          id: WeaponId.plainsteel,
          category: WeaponCategory.primary,
          weaponType: WeaponType.oneHandedSword,
          stats: GearStatBonuses(globalPowerBonusBp: 100),
          isTwoHanded: true,
        );
      case WeaponId.roadguard:
        return const WeaponDef(
          id: WeaponId.roadguard,
          category: WeaponCategory.offHand,
          weaponType: WeaponType.shield,
          stats: GearStatBonuses(globalPowerBonusBp: 900),
        );
      default:
        return const WeaponDef(
          id: WeaponId.plainsteel,
          category: WeaponCategory.primary,
          weaponType: WeaponType.oneHandedSword,
          stats: GearStatBonuses(),
        );
    }
  }
}

class _FlatSpellBookCatalog extends SpellBookCatalog {
  const _FlatSpellBookCatalog();

  @override
  SpellBookDef get(SpellBookId id) {
    return const SpellBookDef(
      id: SpellBookId.apprenticePrimer,
      weaponType: WeaponType.spell,
      stats: GearStatBonuses(),
    );
  }
}

class _PowerSpellBookCatalog extends SpellBookCatalog {
  const _PowerSpellBookCatalog();

  @override
  SpellBookDef get(SpellBookId id) {
    return const SpellBookDef(
      id: SpellBookId.apprenticePrimer,
      weaponType: WeaponType.spell,
      stats: GearStatBonuses(globalPowerBonusBp: 500),
    );
  }
}

class _FlatAccessoryCatalog extends AccessoryCatalog {
  const _FlatAccessoryCatalog();

  @override
  AccessoryDef get(AccessoryId id) {
    return const AccessoryDef(
      id: AccessoryId.speedBoots,
      stats: GearStatBonuses(),
    );
  }
}

class _HighCdrAccessoryCatalog extends AccessoryCatalog {
  const _HighCdrAccessoryCatalog();

  @override
  AccessoryDef get(AccessoryId id) {
    return const AccessoryDef(
      id: AccessoryId.speedBoots,
      stats: GearStatBonuses(cooldownReductionBp: 8000),
    );
  }
}

class _ResourceAccessoryCatalog extends AccessoryCatalog {
  const _ResourceAccessoryCatalog();

  @override
  AccessoryDef get(AccessoryId id) {
    return const AccessoryDef(
      id: AccessoryId.goldenRing,
      stats: GearStatBonuses(
        healthBonusBp: 200,
        manaBonusBp: 300,
        staminaBonusBp: 400,
        healthRegenBonusBp: 500,
        manaRegenBonusBp: 600,
        staminaRegenBonusBp: 700,
      ),
    );
  }
}

class _TypedResistanceAccessoryCatalog extends AccessoryCatalog {
  const _TypedResistanceAccessoryCatalog();

  @override
  AccessoryDef get(AccessoryId id) {
    return const AccessoryDef(
      id: AccessoryId.speedBoots,
      stats: GearStatBonuses(
        fireResistanceBp: 9000,
        iceResistanceBp: -9500,
      ),
    );
  }
}
