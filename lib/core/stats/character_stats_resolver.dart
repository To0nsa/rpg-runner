import '../accessories/accessory_catalog.dart';
import '../accessories/accessory_id.dart';
import '../ecs/stores/combat/equipped_loadout_store.dart';
import '../projectiles/projectile_item_catalog.dart';
import '../projectiles/projectile_item_id.dart';
import '../spells/spell_book_catalog.dart';
import '../spells/spell_book_id.dart';
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

  static const int maxMoveSpeedBp = 5000;
  static const int minMoveSpeedBp = -9000;

  static const int maxCooldownReductionBp = 5000;
  static const int minCooldownReductionBp = -5000;

  static const int maxCritChanceBp = 6000;

  static const int minResourceBonusBp = -9000;
  static const int maxResourceBonusBp = 20000;
}

/// Immutable, clamped stat bundle used by runtime systems.
class ResolvedCharacterStats {
  const ResolvedCharacterStats({required this.bonuses});

  final GearStatBonuses bonuses;

  int get healthBonusBp => bonuses.healthBonusBp;
  int get manaBonusBp => bonuses.manaBonusBp;
  int get staminaBonusBp => bonuses.staminaBonusBp;
  int get defenseBonusBp => bonuses.defenseBonusBp;
  int get powerBonusBp => bonuses.powerBonusBp;
  int get moveSpeedBonusBp => bonuses.moveSpeedBonusBp;
  int get cooldownReductionBp => bonuses.cooldownReductionBp;
  int get critChanceBonusBp => bonuses.critChanceBonusBp;

  double get moveSpeedMultiplier => (bpScale + moveSpeedBonusBp) / bpScale;

  int applyHealthMaxBonus(int base100) => applyBp(base100, healthBonusBp);
  int applyManaMaxBonus(int base100) => applyBp(base100, manaBonusBp);
  int applyStaminaMaxBonus(int base100) => applyBp(base100, staminaBonusBp);

  /// Applies global incoming damage reduction (defense) only.
  int applyDefense(int incomingDamage100) {
    final next = applyBp(incomingDamage100, -defenseBonusBp);
    return next < 0 ? 0 : next;
  }

  /// Applies global outgoing damage scaling (power) only.
  int applyPower(int outgoingDamage100) {
    final next = applyBp(outgoingDamage100, powerBonusBp);
    return next < 0 ? 0 : next;
  }

  int applyCooldownReduction(int baseTicks) {
    if (baseTicks <= 0) return 0;
    final effectiveScaleBp = bpScale - cooldownReductionBp;
    final scaled =
        (baseTicks * effectiveScaleBp + bpScale - 1) ~/ bpScale; // ceil div
    if (scaled < 0) return 0;
    return scaled;
  }
}

/// Pure resolver that maps equipped items to runtime-ready stat totals.
///
/// This is intentionally Core-only and deterministic. It has no UI/runtime
/// side effects and can be reused by both gameplay systems and UI presenters.
class CharacterStatsResolver {
  const CharacterStatsResolver({
    this.weapons = const WeaponCatalog(),
    this.projectileItems = const ProjectileItemCatalog(),
    this.spellBooks = const SpellBookCatalog(),
    this.accessories = const AccessoryCatalog(),
  });

  final WeaponCatalog weapons;
  final ProjectileItemCatalog projectileItems;
  final SpellBookCatalog spellBooks;
  final AccessoryCatalog accessories;

  ResolvedCharacterStats resolveLoadout(EquippedLoadoutDef loadout) {
    return resolveEquipped(
      mask: loadout.mask,
      mainWeaponId: loadout.mainWeaponId,
      offhandWeaponId: loadout.offhandWeaponId,
      projectileItemId: loadout.projectileItemId,
      spellBookId: loadout.spellBookId,
      accessoryId: loadout.accessoryId,
    );
  }

  ResolvedCharacterStats resolveEquipped({
    required int mask,
    required WeaponId mainWeaponId,
    required WeaponId offhandWeaponId,
    required ProjectileItemId projectileItemId,
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
      total += projectileItems.get(projectileItemId).stats;
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
