import '../combat/status/status.dart';
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
          statusProfileId: StatusProfileId.meleeBleed,
        );
      case WeaponId.goldenSword:
        return const WeaponDef(
          id: WeaponId.goldenSword,
          statusProfileId: StatusProfileId.meleeBleed,
        );
      case WeaponId.basicShield:
        return const WeaponDef(
          id: WeaponId.basicShield,
          statusProfileId: StatusProfileId.stunOnHit,
        );
      case WeaponId.goldenShield:
        return const WeaponDef(
          id: WeaponId.goldenShield,
          statusProfileId: StatusProfileId.stunOnHit,
        );
    }
  }
}

