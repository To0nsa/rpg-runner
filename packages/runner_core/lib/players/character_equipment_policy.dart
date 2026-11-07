import '../abilities/ability_catalog.dart';
import '../meta/equipped_gear.dart';
import '../meta/gear_slot.dart';
import '../meta/meta_defaults.dart';
import '../projectiles/projectile_catalog.dart';
import '../projectiles/projectile_id.dart';
import '../spellBook/spell_book_catalog.dart';
import '../spellBook/spell_book_id.dart';
import '../weapons/weapon_catalog.dart';
import '../weapons/weapon_id.dart';
import 'player_character_definition.dart';
import 'player_character_registry.dart';

/// Character families gate equipment independently from account ownership.
abstract final class CharacterEquipmentPolicy {
  static EquippedGear defaults(PlayerCharacterId id) {
    final catalog = PlayerCharacterRegistry.resolve(id).catalog;
    return EquippedGear(
      mainWeaponId: catalog.weaponId,
      offhandWeaponId: catalog.offhandWeaponId,
      spellBookId: catalog.spellBookId,
      accessoryId: MetaDefaults.accessoryId,
    );
  }

  static bool allowsGear(PlayerCharacterId id, GearSlot slot, Object item) {
    final catalog = PlayerCharacterRegistry.resolve(id).catalog;
    const weapons = WeaponCatalog();
    const books = SpellBookCatalog();
    return switch (slot) {
      GearSlot.mainWeapon =>
        item is WeaponId &&
            weapons.tryGet(item)?.weaponType ==
                weapons.get(catalog.weaponId).weaponType,
      GearSlot.offhandWeapon =>
        item is WeaponId &&
            weapons.tryGet(item)?.weaponType ==
                weapons.get(catalog.offhandWeaponId).weaponType,
      GearSlot.spellBook =>
        item is SpellBookId &&
            books.tryGet(item)?.weaponType ==
                books.get(catalog.spellBookId).weaponType,
      GearSlot.accessory => true,
    };
  }

  static bool allowsProjectile(PlayerCharacterId id, ProjectileId projectile) {
    if (!playerEquippableProjectileIds.contains(projectile)) return false;
    final ability = AbilityCatalog.shared.resolve(
      PlayerCharacterRegistry.resolve(id).catalog.abilityProjectileId,
    )!;
    final type = const ProjectileCatalog().tryGet(projectile)?.weaponType;
    return type != null &&
        (ability.requiredWeaponTypes.isEmpty ||
            ability.requiredWeaponTypes.contains(type));
  }
}
