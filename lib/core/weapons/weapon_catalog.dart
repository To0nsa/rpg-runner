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
          displayName: 'Wooden Sword',
          description: 'A worn training blade with modest reach.',
          category: WeaponCategory.primary,
          weaponType: WeaponType.oneHandedSword,
          grantedAbilityTags: {AbilityTag.melee, AbilityTag.physical},
          stats: WeaponStats(powerBonusBp: -100), // -1% Damage
        );
      case WeaponId.basicSword:
        return const WeaponDef(
          id: WeaponId.basicSword,
          displayName: 'Basic Sword',
          description: 'A balanced steel sword for reliable melee strikes.',
          category: WeaponCategory.primary,
          weaponType: WeaponType.oneHandedSword,
          grantedAbilityTags: {AbilityTag.melee, AbilityTag.physical},
          stats: WeaponStats(powerBonusBp: 100), // +1% Damage
        );
      case WeaponId.solidSword:
        return const WeaponDef(
          id: WeaponId.solidSword,
          displayName: 'Solid Sword',
          description: 'A heavier blade tuned for stronger direct hits.',
          category: WeaponCategory.primary,
          weaponType: WeaponType.oneHandedSword,
          grantedAbilityTags: {AbilityTag.melee, AbilityTag.physical},
          stats: WeaponStats(powerBonusBp: 200), // +2% Damage
        );
      case WeaponId.woodenShield:
        return const WeaponDef(
          id: WeaponId.woodenShield,
          displayName: 'Wooden Shield',
          description: 'A light starter shield for basic protection.',
          category: WeaponCategory.offHand,
          weaponType: WeaponType.shield,
          grantedAbilityTags: {AbilityTag.buff, AbilityTag.physical},
          stats: WeaponStats(powerBonusBp: -100), // -1% Damage
        );
      case WeaponId.basicShield:
        return const WeaponDef(
          id: WeaponId.basicShield,
          displayName: 'Basic Shield',
          description: 'A reinforced shield that improves combat stance.',
          category: WeaponCategory.offHand,
          weaponType: WeaponType.shield,
          grantedAbilityTags: {AbilityTag.buff, AbilityTag.physical},
          stats: WeaponStats(powerBonusBp: 100), // +1% Damage (existing)
        );
      case WeaponId.solidShield:
        return const WeaponDef(
          id: WeaponId.solidShield,
          displayName: 'Solid Shield',
          description:
              'A sturdy shield built for sustained front-line defense.',
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
