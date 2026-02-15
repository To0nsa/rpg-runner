import '../accessories/accessory_catalog.dart';
import '../accessories/accessory_id.dart';
import '../combat/damage_type.dart';
import '../ecs/stores/combat/equipped_loadout_store.dart';
import '../projectiles/projectile_catalog.dart';
import '../projectiles/projectile_id.dart';
import '../spellBook/spell_book_catalog.dart';
import '../spellBook/spell_book_id.dart';
import '../util/fixed_math.dart';
import '../weapons/weapon_catalog.dart';
import '../weapons/weapon_id.dart';
import 'gear_stat_bonuses.dart';

/// Clamp values for the V1 character stat model.
class CharacterStatCaps {
  const CharacterStatCaps._();

  static const int maxDefenseBp = 7500;
  static const int minDefenseBp = -9000;

  static const int maxPowerBp = 10000;
  static const int minPowerBp = -9000;

  static const int maxGlobalPowerBp = 10000;
  static const int minGlobalPowerBp = -9000;

  static const int maxMoveSpeedBp = 5000;
  static const int minMoveSpeedBp = -9000;

  static const int maxCooldownReductionBp = 5000;
  static const int minCooldownReductionBp = -5000;

  static const int maxCritChanceBp = 6000;
  static const int maxGlobalCritChanceBp = 6000;

  static const int minResourceBonusBp = -9000;
  static const int maxResourceBonusBp = 20000;

  static const int minTypedResistanceBp = -9000;
  static const int maxTypedResistanceBp = 7500;
}

/// Immutable, clamped stat bundle used by runtime systems.
class ResolvedCharacterStats {
  const ResolvedCharacterStats({required this.bonuses});

  final GearStatBonuses bonuses;

  int get healthBonusBp => bonuses.healthBonusBp;
  int get manaBonusBp => bonuses.manaBonusBp;
  int get staminaBonusBp => bonuses.staminaBonusBp;
  int get defenseBonusBp => bonuses.defenseBonusBp;
  int get globalPowerBonusBp => bonuses.globalPowerBonusBp;
  int get globalCritChanceBonusBp => bonuses.globalCritChanceBonusBp;
  int get powerBonusBp => bonuses.powerBonusBp;
  int get moveSpeedBonusBp => bonuses.moveSpeedBonusBp;
  int get cooldownReductionBp => bonuses.cooldownReductionBp;
  int get critChanceBonusBp => bonuses.critChanceBonusBp;
  int get physicalResistanceBp => bonuses.physicalResistanceBp;
  int get fireResistanceBp => bonuses.fireResistanceBp;
  int get iceResistanceBp => bonuses.iceResistanceBp;
  int get thunderResistanceBp => bonuses.thunderResistanceBp;
  int get acidResistanceBp => bonuses.acidResistanceBp;
  int get darkResistanceBp => bonuses.darkResistanceBp;
  int get bleedResistanceBp => bonuses.bleedResistanceBp;
  int get earthResistanceBp => bonuses.earthResistanceBp;
  int get holyResistanceBp => bonuses.holyResistanceBp;

  double get moveSpeedMultiplier => (bpScale + moveSpeedBonusBp) / bpScale;

  int applyHealthMaxBonus(int base100) => applyBp(base100, healthBonusBp);
  int applyManaMaxBonus(int base100) => applyBp(base100, manaBonusBp);
  int applyStaminaMaxBonus(int base100) => applyBp(base100, staminaBonusBp);

  /// Applies global incoming damage reduction (defense) only.
  int applyDefense(int incomingDamage100) {
    final next = applyBp(incomingDamage100, -defenseBonusBp);
    return next < 0 ? 0 : next;
  }

  /// Applies global outgoing damage scaling only.
  int applyGlobalPower(int outgoingDamage100) {
    final next = applyBp(outgoingDamage100, globalPowerBonusBp);
    return next < 0 ? 0 : next;
  }

  /// Backward-compatible alias for global outgoing power scaling.
  int applyPower(int outgoingDamage100) {
    return applyGlobalPower(outgoingDamage100);
  }

  int applyCooldownReduction(int baseTicks) {
    if (baseTicks <= 0) return 0;
    final effectiveScaleBp = bpScale - cooldownReductionBp;
    final scaled =
        (baseTicks * effectiveScaleBp + bpScale - 1) ~/ bpScale; // ceil div
    if (scaled < 0) return 0;
    return scaled;
  }

  /// Returns typed resistance in basis points where positive means mitigation.
  int resistanceBpForDamageType(DamageType type) {
    switch (type) {
      case DamageType.physical:
        return physicalResistanceBp;
      case DamageType.fire:
        return fireResistanceBp;
      case DamageType.ice:
        return iceResistanceBp;
      case DamageType.thunder:
        return thunderResistanceBp;
      case DamageType.acid:
        return acidResistanceBp;
      case DamageType.dark:
        return darkResistanceBp;
      case DamageType.bleed:
        return bleedResistanceBp;
      case DamageType.earth:
        return earthResistanceBp;
      case DamageType.holy:
        return holyResistanceBp;
    }
  }

  /// Returns incoming-damage modifier bp compatible with DamageResistanceStore.
  /// Positive resistance reduces incoming damage, so sign is inverted.
  int incomingDamageModBpForDamageType(DamageType type) {
    return -resistanceBpForDamageType(type);
  }
}

/// Pure resolver that maps equipped items to runtime-ready stat totals.
///
/// This is intentionally Core-only and deterministic. It has no UI/runtime
/// side effects and can be reused by both gameplay systems and UI presenters.
class CharacterStatsResolver {
  const CharacterStatsResolver({
    this.weapons = const WeaponCatalog(),
    this.projectiles = const ProjectileCatalog(),
    this.spellBooks = const SpellBookCatalog(),
    this.accessories = const AccessoryCatalog(),
  });

  final WeaponCatalog weapons;
  final ProjectileCatalog projectiles;
  final SpellBookCatalog spellBooks;
  final AccessoryCatalog accessories;

  ResolvedCharacterStats resolveLoadout(EquippedLoadoutDef loadout) {
    return resolveEquipped(
      mask: loadout.mask,
      mainWeaponId: loadout.mainWeaponId,
      offhandWeaponId: loadout.offhandWeaponId,
      projectileId: loadout.projectileId,
      spellBookId: loadout.spellBookId,
      accessoryId: loadout.accessoryId,
    );
  }

  ResolvedCharacterStats resolveEquipped({
    required int mask,
    required WeaponId mainWeaponId,
    required WeaponId offhandWeaponId,
    required ProjectileId projectileId,
    required SpellBookId spellBookId,
    required AccessoryId accessoryId,
  }) {
    final mainWeapon = weapons.get(mainWeaponId);
    GearStatBonuses total = mainWeapon.stats;

    final hasOffhand = (mask & LoadoutSlotMask.offHand) != 0;
    if (hasOffhand && !mainWeapon.isTwoHanded) {
      total += weapons.get(offhandWeaponId).stats;
    }

    final hasProjectile = (mask & LoadoutSlotMask.projectile) != 0;
    if (hasProjectile) {
      total += projectiles.get(projectileId).stats;
      total += spellBooks.get(spellBookId).stats;
    }

    total += accessories.get(accessoryId).stats;

    return ResolvedCharacterStats(bonuses: _clamp(total));
  }

  GearStatBonuses _clamp(GearStatBonuses input) {
    return GearStatBonuses(
      healthBonusBp: _clampInt(
        input.healthBonusBp,
        CharacterStatCaps.minResourceBonusBp,
        CharacterStatCaps.maxResourceBonusBp,
      ),
      manaBonusBp: _clampInt(
        input.manaBonusBp,
        CharacterStatCaps.minResourceBonusBp,
        CharacterStatCaps.maxResourceBonusBp,
      ),
      staminaBonusBp: _clampInt(
        input.staminaBonusBp,
        CharacterStatCaps.minResourceBonusBp,
        CharacterStatCaps.maxResourceBonusBp,
      ),
      defenseBonusBp: _clampInt(
        input.defenseBonusBp,
        CharacterStatCaps.minDefenseBp,
        CharacterStatCaps.maxDefenseBp,
      ),
      globalPowerBonusBp: _clampInt(
        input.globalPowerBonusBp,
        CharacterStatCaps.minGlobalPowerBp,
        CharacterStatCaps.maxGlobalPowerBp,
      ),
      globalCritChanceBonusBp: _clampInt(
        input.globalCritChanceBonusBp,
        0,
        CharacterStatCaps.maxGlobalCritChanceBp,
      ),
      powerBonusBp: _clampInt(
        input.powerBonusBp,
        CharacterStatCaps.minPowerBp,
        CharacterStatCaps.maxPowerBp,
      ),
      moveSpeedBonusBp: _clampInt(
        input.moveSpeedBonusBp,
        CharacterStatCaps.minMoveSpeedBp,
        CharacterStatCaps.maxMoveSpeedBp,
      ),
      cooldownReductionBp: _clampInt(
        input.cooldownReductionBp,
        CharacterStatCaps.minCooldownReductionBp,
        CharacterStatCaps.maxCooldownReductionBp,
      ),
      critChanceBonusBp: _clampInt(
        input.critChanceBonusBp,
        0,
        CharacterStatCaps.maxCritChanceBp,
      ),
      physicalResistanceBp: _clampInt(
        input.physicalResistanceBp,
        CharacterStatCaps.minTypedResistanceBp,
        CharacterStatCaps.maxTypedResistanceBp,
      ),
      fireResistanceBp: _clampInt(
        input.fireResistanceBp,
        CharacterStatCaps.minTypedResistanceBp,
        CharacterStatCaps.maxTypedResistanceBp,
      ),
      iceResistanceBp: _clampInt(
        input.iceResistanceBp,
        CharacterStatCaps.minTypedResistanceBp,
        CharacterStatCaps.maxTypedResistanceBp,
      ),
      thunderResistanceBp: _clampInt(
        input.thunderResistanceBp,
        CharacterStatCaps.minTypedResistanceBp,
        CharacterStatCaps.maxTypedResistanceBp,
      ),
      acidResistanceBp: _clampInt(
        input.acidResistanceBp,
        CharacterStatCaps.minTypedResistanceBp,
        CharacterStatCaps.maxTypedResistanceBp,
      ),
      darkResistanceBp: _clampInt(
        input.darkResistanceBp,
        CharacterStatCaps.minTypedResistanceBp,
        CharacterStatCaps.maxTypedResistanceBp,
      ),
      bleedResistanceBp: _clampInt(
        input.bleedResistanceBp,
        CharacterStatCaps.minTypedResistanceBp,
        CharacterStatCaps.maxTypedResistanceBp,
      ),
      earthResistanceBp: _clampInt(
        input.earthResistanceBp,
        CharacterStatCaps.minTypedResistanceBp,
        CharacterStatCaps.maxTypedResistanceBp,
      ),
      holyResistanceBp: _clampInt(
        input.holyResistanceBp,
        CharacterStatCaps.minTypedResistanceBp,
        CharacterStatCaps.maxTypedResistanceBp,
      ),
      critDamageBonusBp: input.critDamageBonusBp,
      rangeScalarPercent: input.rangeScalarPercent,
    );
  }

  int _clampInt(int value, int minValue, int maxValue) {
    if (value < minValue) return minValue;
    if (value > maxValue) return maxValue;
    return value;
  }
}
