import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_runner/core/accessories/accessory_catalog.dart';
import 'package:rpg_runner/core/accessories/accessory_def.dart';
import 'package:rpg_runner/core/accessories/accessory_id.dart';
import 'package:rpg_runner/core/abilities/ability_def.dart' show WeaponType;
import 'package:rpg_runner/core/ecs/stores/combat/equipped_loadout_store.dart';
import 'package:rpg_runner/core/projectiles/projectile_id.dart';
import 'package:rpg_runner/core/projectiles/projectile_item_catalog.dart';
import 'package:rpg_runner/core/projectiles/projectile_item_def.dart';
import 'package:rpg_runner/core/spells/spell_book_catalog.dart';
import 'package:rpg_runner/core/spells/spell_book_def.dart';
import 'package:rpg_runner/core/spells/spell_book_id.dart';
import 'package:rpg_runner/core/combat/damage_type.dart';
import 'package:rpg_runner/core/stats/character_stats_resolver.dart';
import 'package:rpg_runner/core/weapons/weapon_catalog.dart';
import 'package:rpg_runner/core/weapons/weapon_category.dart';
import 'package:rpg_runner/core/weapons/weapon_def.dart';
import 'package:rpg_runner/core/weapons/weapon_id.dart';
import 'package:rpg_runner/core/stats/gear_stat_bonuses.dart';

void main() {
  test('cooldown reduction is capped and scales cooldown ticks', () {
    final resolver = CharacterStatsResolver(
      weapons: const _FlatWeaponCatalog(),
      projectileItems: const _FlatProjectileItemCatalog(),
      spellBooks: const _FlatSpellBookCatalog(),
      accessories: const _HighCdrAccessoryCatalog(),
    );

    final stats = resolver.resolveEquipped(
      mask: LoadoutSlotMask.mainHand,
      mainWeaponId: WeaponId.basicSword,
      offhandWeaponId: WeaponId.basicShield,
      projectileId: ProjectileId.throwingKnife,
      spellBookId: SpellBookId.basicSpellBook,
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
      projectileItems: const _FlatProjectileItemCatalog(),
      spellBooks: const _FlatSpellBookCatalog(),
      accessories: const _FlatAccessoryCatalog(),
    );

    final stats = resolver.resolveEquipped(
      mask: LoadoutSlotMask.mainHand | LoadoutSlotMask.offHand,
      mainWeaponId: WeaponId.woodenSword,
      offhandWeaponId: WeaponId.basicShield,
      projectileId: ProjectileId.throwingKnife,
      spellBookId: SpellBookId.basicSpellBook,
      accessoryId: AccessoryId.speedBoots,
    );

    expect(stats.powerBonusBp, equals(100));
  });

  test('resource bonuses scale max pools deterministically', () {
    final resolver = CharacterStatsResolver(
      weapons: const _FlatWeaponCatalog(),
      projectileItems: const _FlatProjectileItemCatalog(),
      spellBooks: const _FlatSpellBookCatalog(),
      accessories: const _ResourceAccessoryCatalog(),
    );

    final stats = resolver.resolveEquipped(
      mask: LoadoutSlotMask.mainHand,
      mainWeaponId: WeaponId.basicSword,
      offhandWeaponId: WeaponId.basicShield,
      projectileId: ProjectileId.throwingKnife,
      spellBookId: SpellBookId.basicSpellBook,
      accessoryId: AccessoryId.goldenRing,
    );

    expect(stats.applyHealthMaxBonus(10000), equals(10200));
    expect(stats.applyManaMaxBonus(10000), equals(10300));
    expect(stats.applyStaminaMaxBonus(10000), equals(10400));
  });

  test('global offensive bonuses are capped and applied deterministically', () {
    final resolver = CharacterStatsResolver(
      weapons: const _FlatWeaponCatalog(),
      projectileItems: const _FlatProjectileItemCatalog(),
      spellBooks: const _FlatSpellBookCatalog(),
      accessories: const _GlobalOffenseAccessoryCatalog(),
    );

    final stats = resolver.resolveEquipped(
      mask: LoadoutSlotMask.mainHand,
      mainWeaponId: WeaponId.basicSword,
      offhandWeaponId: WeaponId.basicShield,
      projectileId: ProjectileId.throwingKnife,
      spellBookId: SpellBookId.basicSpellBook,
      accessoryId: AccessoryId.speedBoots,
    );

    expect(
      stats.globalPowerBonusBp,
      equals(CharacterStatCaps.maxGlobalPowerBp),
    );
    expect(
      stats.globalCritChanceBonusBp,
      equals(CharacterStatCaps.maxGlobalCritChanceBp),
    );
    expect(stats.applyGlobalPower(1000), equals(2000));
  });

  test('typed gear resistance clamps and converts to incoming modifier', () {
    final resolver = CharacterStatsResolver(
      weapons: const _FlatWeaponCatalog(),
      projectileItems: const _FlatProjectileItemCatalog(),
      spellBooks: const _FlatSpellBookCatalog(),
      accessories: const _TypedResistanceAccessoryCatalog(),
    );

    final stats = resolver.resolveEquipped(
      mask: LoadoutSlotMask.mainHand,
      mainWeaponId: WeaponId.basicSword,
      offhandWeaponId: WeaponId.basicShield,
      projectileId: ProjectileId.throwingKnife,
      spellBookId: SpellBookId.basicSpellBook,
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
      stats.acidResistanceBp,
      equals(CharacterStatCaps.maxTypedResistanceBp),
    );
    expect(
      stats.incomingDamageModBpForDamageType(DamageType.fire),
      equals(-CharacterStatCaps.maxTypedResistanceBp),
    );
    expect(
      stats.incomingDamageModBpForDamageType(DamageType.ice),
      equals(-CharacterStatCaps.minTypedResistanceBp),
    );
    expect(
      stats.incomingDamageModBpForDamageType(DamageType.acid),
      equals(-CharacterStatCaps.maxTypedResistanceBp),
    );
  });
}

class _FlatWeaponCatalog extends WeaponCatalog {
  const _FlatWeaponCatalog();

  @override
  WeaponDef get(WeaponId id) {
    return const WeaponDef(
      id: WeaponId.basicSword,
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
      case WeaponId.woodenSword:
        return const WeaponDef(
          id: WeaponId.woodenSword,
          category: WeaponCategory.primary,
          weaponType: WeaponType.oneHandedSword,
          stats: GearStatBonuses(powerBonusBp: 100),
          isTwoHanded: true,
        );
      case WeaponId.basicShield:
        return const WeaponDef(
          id: WeaponId.basicShield,
          category: WeaponCategory.offHand,
          weaponType: WeaponType.shield,
          stats: GearStatBonuses(powerBonusBp: 900),
        );
      default:
        return const WeaponDef(
          id: WeaponId.basicSword,
          category: WeaponCategory.primary,
          weaponType: WeaponType.oneHandedSword,
          stats: GearStatBonuses(),
        );
    }
  }
}

class _FlatProjectileItemCatalog extends ProjectileItemCatalog {
  const _FlatProjectileItemCatalog();

  @override
  ProjectileItemDef get(ProjectileId id) {
    return const ProjectileItemDef(
      id: ProjectileId.throwingKnife,
      weaponType: WeaponType.throwingWeapon,
      speedUnitsPerSecond: 900.0,
      lifetimeSeconds: 1.2,
      colliderSizeX: 14.0,
      colliderSizeY: 6.0,
      stats: GearStatBonuses(),
    );
  }
}

class _FlatSpellBookCatalog extends SpellBookCatalog {
  const _FlatSpellBookCatalog();

  @override
  SpellBookDef get(SpellBookId id) {
    return const SpellBookDef(
      id: SpellBookId.basicSpellBook,
      weaponType: WeaponType.projectileSpell,
      stats: GearStatBonuses(),
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
      ),
    );
  }
}

class _GlobalOffenseAccessoryCatalog extends AccessoryCatalog {
  const _GlobalOffenseAccessoryCatalog();

  @override
  AccessoryDef get(AccessoryId id) {
    return const AccessoryDef(
      id: AccessoryId.speedBoots,
      stats: GearStatBonuses(
        globalPowerBonusBp: 12000,
        globalCritChanceBonusBp: 7000,
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
        acidResistanceBp: 9000,
      ),
    );
  }
}
