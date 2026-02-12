import '../accessories/accessory_id.dart';
import '../projectiles/projectile_id.dart';
import '../spells/spell_book_id.dart';
import '../weapons/weapon_id.dart';
import 'equipped_gear.dart';

/// Default gear IDs used for new profiles and normalization fallback.
///
/// Keep these IDs valid and unlocked in baseline inventory rules.
class MetaDefaults {
  const MetaDefaults._();

  /// Default main-hand weapon.
  static const WeaponId mainWeaponId = WeaponId.woodenSword;

  /// Default off-hand weapon.
  static const WeaponId offhandWeaponId = WeaponId.woodenShield;

  /// Default throwing weapon.
  static const ProjectileId throwingWeaponId = ProjectileId.throwingKnife;

  /// Default spellbook.
  static const SpellBookId spellBookId = SpellBookId.basicSpellBook;

  /// Default accessory.
  static const AccessoryId accessoryId = AccessoryId.speedBoots;

  /// Canonical default equipped set.
  static const EquippedGear equippedGear = EquippedGear(
    mainWeaponId: mainWeaponId,
    offhandWeaponId: offhandWeaponId,
    throwingWeaponId: throwingWeaponId,
    spellBookId: spellBookId,
    accessoryId: accessoryId,
  );
}
