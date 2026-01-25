import '../abilities/ability_def.dart' show AbilityTag, WeaponType;
import '../combat/status/status.dart';
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
      case WeaponId.basicSword:
        return const WeaponDef(
          id: WeaponId.basicSword,
          category: WeaponCategory.primary,
          weaponType: WeaponType.oneHandedSword,
          grantedAbilityTags: {AbilityTag.melee, AbilityTag.physical},
          statusProfileId: StatusProfileId.meleeBleed,
        );
      case WeaponId.goldenSword:
        return const WeaponDef(
          id: WeaponId.goldenSword,
          category: WeaponCategory.primary,
          weaponType: WeaponType.oneHandedSword,
          grantedAbilityTags: {AbilityTag.melee, AbilityTag.physical},
          statusProfileId: StatusProfileId.meleeBleed,
          stats: WeaponStats(powerBonusBp: 2000), // +20% Damage
        );
      case WeaponId.basicShield:
        return const WeaponDef(
          id: WeaponId.basicShield,
          category: WeaponCategory.offHand,
          weaponType: WeaponType.shield,
          grantedAbilityTags: {AbilityTag.buff, AbilityTag.physical},
          statusProfileId: StatusProfileId.stunOnHit,
          stats: WeaponStats(powerBonusBp: 500),
        );
      case WeaponId.goldenShield:
        return const WeaponDef(
          id: WeaponId.goldenShield,
          category: WeaponCategory.offHand,
          weaponType: WeaponType.shield,
          grantedAbilityTags: {AbilityTag.buff, AbilityTag.physical},
          statusProfileId: StatusProfileId.stunOnHit,
          stats: WeaponStats(powerBonusBp: 1000),
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
