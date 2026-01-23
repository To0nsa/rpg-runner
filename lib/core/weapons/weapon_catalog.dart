import '../abilities/ability_def.dart' show AbilityTag;
import '../combat/status/status.dart';
import 'weapon_category.dart';
import 'weapon_def.dart';
import 'weapon_id.dart';

/// Lookup table for weapon definitions.
///
/// Similar to [SpellCatalog], but for melee weapons.
class WeaponCatalog {
  const WeaponCatalog();

  WeaponDef get(WeaponId id) {
    switch (id) {
      case WeaponId.basicSword:
        return const WeaponDef(
          id: WeaponId.basicSword,
          category: WeaponCategory.primary,
          grantedAbilityTags: {AbilityTag.melee, AbilityTag.physical},
          statusProfileId: StatusProfileId.meleeBleed,
        );
      case WeaponId.goldenSword:
        return const WeaponDef(
          id: WeaponId.goldenSword,
          category: WeaponCategory.primary,
          grantedAbilityTags: {AbilityTag.melee, AbilityTag.physical},
          statusProfileId: StatusProfileId.meleeBleed,
        );
      case WeaponId.basicShield:
        return const WeaponDef(
          id: WeaponId.basicShield,
          category: WeaponCategory.offHand,
          grantedAbilityTags: {AbilityTag.buff, AbilityTag.physical},
          statusProfileId: StatusProfileId.stunOnHit,
        );
      case WeaponId.goldenShield:
        return const WeaponDef(
          id: WeaponId.goldenShield,
          category: WeaponCategory.offHand,
          grantedAbilityTags: {AbilityTag.buff, AbilityTag.physical},
          statusProfileId: StatusProfileId.stunOnHit,
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
