import '../abilities/ability_catalog.dart';
import '../abilities/ability_def.dart';
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
  /// Source compilers may ask about a new identity before its enum is generated.
  /// The same family policy serves authored previews and runtime equipment.
  static bool allowsFamily(
    PlayerCharacterId id,
    GearSlot slot,
    WeaponType? family,
  ) {
    final catalog = PlayerCharacterRegistry.resolve(id).catalog;
    return switch (slot) {
      GearSlot.mainWeapon =>
        family == const WeaponCatalog().get(catalog.weaponId).weaponType,
      GearSlot.offhandWeapon =>
        family == const WeaponCatalog().get(catalog.offhandWeaponId).weaponType,
      GearSlot.spellBook =>
        family == const SpellBookCatalog().get(catalog.spellBookId).weaponType,
      GearSlot.accessory => true,
    };
  }

  static bool allowsProjectileFamily(PlayerCharacterId id, WeaponType family) {
    final ability = AbilityCatalog.shared.resolve(
      PlayerCharacterRegistry.resolve(id).catalog.abilityProjectileId,
    )!;
    return ability.requiredWeaponTypes.isEmpty ||
        ability.requiredWeaponTypes.contains(family);
  }

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
    const weapons = WeaponCatalog();
    const books = SpellBookCatalog();
    return switch (slot) {
      GearSlot.mainWeapon =>
        item is WeaponId &&
            allowsFamily(id, slot, weapons.tryGet(item)?.weaponType),
      GearSlot.offhandWeapon =>
        item is WeaponId &&
            allowsFamily(id, slot, weapons.tryGet(item)?.weaponType),
      GearSlot.spellBook =>
        item is SpellBookId &&
            allowsFamily(id, slot, books.tryGet(item)?.weaponType),
      GearSlot.accessory => true,
    };
  }

  static bool allowsProjectile(PlayerCharacterId id, ProjectileId projectile) {
    if (!playerEquippableProjectileIds.contains(projectile)) return false;
    final type = const ProjectileCatalog().tryGet(projectile)?.weaponType;
    return type != null && allowsProjectileFamily(id, type);
  }
}
