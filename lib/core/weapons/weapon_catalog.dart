import '../abilities/ability_def.dart' show AbilityTag, WeaponType;
import 'weapon_category.dart';
import 'weapon_def.dart';
import 'weapon_id.dart';
import 'weapon_stats.dart';

/// Lookup table for weapon definitions.
///
/// Similar to [ProjectileItemCatalog], but for melee weapons.
class WeaponCatalog {
  const WeaponCatalog();

  WeaponDef get(WeaponId id) {
    switch (id) {
      case WeaponId.woodenSword:
        return const WeaponDef(
          id: WeaponId.woodenSword,
          category: WeaponCategory.primary,
          weaponType: WeaponType.oneHandedSword,
          grantedAbilityTags: {AbilityTag.melee, AbilityTag.physical},
          stats: WeaponStats(powerBonusBp: -100), // -1% Damage
        );
      case WeaponId.basicSword:
        return const WeaponDef(
          id: WeaponId.basicSword,
          category: WeaponCategory.primary,
          weaponType: WeaponType.oneHandedSword,
          grantedAbilityTags: {AbilityTag.melee, AbilityTag.physical},
          stats: WeaponStats(powerBonusBp: 100), // +1% Damage
        );
      case WeaponId.solidSword:
        return const WeaponDef(
          id: WeaponId.solidSword,
          category: WeaponCategory.primary,
          weaponType: WeaponType.oneHandedSword,
          grantedAbilityTags: {AbilityTag.melee, AbilityTag.physical},
          stats: WeaponStats(powerBonusBp: 200), // +2% Damage
        );
      case WeaponId.woodenShield:
        return const WeaponDef(
          id: WeaponId.woodenShield,
          category: WeaponCategory.offHand,
          weaponType: WeaponType.shield,
          grantedAbilityTags: {AbilityTag.buff, AbilityTag.physical},
          stats: WeaponStats(powerBonusBp: -100), // -1% Damage
        );
      case WeaponId.basicShield:
        return const WeaponDef(
          id: WeaponId.basicShield,
          category: WeaponCategory.offHand,
          weaponType: WeaponType.shield,
          grantedAbilityTags: {AbilityTag.buff, AbilityTag.physical},
          stats: WeaponStats(powerBonusBp: 100), // +1% Damage (existing)
        );
      case WeaponId.solidShield:
        return const WeaponDef(
          id: WeaponId.solidShield,
          category: WeaponCategory.offHand,
          weaponType: WeaponType.shield,
          grantedAbilityTags: {AbilityTag.buff, AbilityTag.physical},
          stats: WeaponStats(powerBonusBp: 200), // +2% Damage
        );
    }
  }

  WeaponDef? tryGet(WeaponId id) {
    try {
      return get(id);
    } catch (_) {
      return null;
    }
  }
}
