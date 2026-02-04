import '../accessories/accessory_id.dart';
import '../projectiles/projectile_item_id.dart';
import '../spells/spell_book_id.dart';
import '../weapons/weapon_id.dart';
import 'equipped_gear.dart';

class MetaDefaults {
  const MetaDefaults._();

  static const WeaponId mainWeaponId = WeaponId.woodenSword;
  static const WeaponId offhandWeaponId = WeaponId.woodenShield;
  static const ProjectileItemId throwingWeaponId =
      ProjectileItemId.throwingKnife;
  static const SpellBookId spellBookId = SpellBookId.basicSpellBook;
  static const AccessoryId accessoryId = AccessoryId.speedBoots;

  static const EquippedGear equippedGear = EquippedGear(
    mainWeaponId: mainWeaponId,
    offhandWeaponId: offhandWeaponId,
    throwingWeaponId: throwingWeaponId,
    spellBookId: spellBookId,
    accessoryId: accessoryId,
  );
}
