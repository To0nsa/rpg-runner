import '../../core/accessories/accessory_catalog.dart';
import '../../core/accessories/accessory_id.dart';
import '../../core/meta/gear_slot.dart';
import '../../core/projectiles/projectile_item_catalog.dart';
import '../../core/projectiles/projectile_item_id.dart';
import '../../core/spells/spell_book_catalog.dart';
import '../../core/spells/spell_book_id.dart';
import '../../core/weapons/weapon_catalog.dart';
import '../../core/weapons/weapon_id.dart';

const WeaponCatalog _weaponCatalog = WeaponCatalog();
const ProjectileItemCatalog _projectileItemCatalog = ProjectileItemCatalog();
const SpellBookCatalog _spellBookCatalog = SpellBookCatalog();
const AccessoryCatalog _accessoryCatalog = AccessoryCatalog();

/// Returns the display text for a gear item shown in UI.
///
/// This is intentionally centralized so we can swap to localized lookups later
/// without rewriting all UI call sites.
String gearDisplayNameForSlot(GearSlot slot, Object id) {
  return switch (slot) {
    GearSlot.mainWeapon ||
    GearSlot.offhandWeapon => _weaponCatalog.get(id as WeaponId).displayName,
    GearSlot.throwingWeapon =>
      _projectileItemCatalog.get(id as ProjectileItemId).displayName,
    GearSlot.spellBook => _spellBookCatalog.get(id as SpellBookId).displayName,
    GearSlot.accessory => _accessoryCatalog.get(id as AccessoryId).displayName,
  };
}

/// Returns a short description for a gear item shown in UI.
///
/// This mirrors [gearDisplayNameForSlot] so UI can add tooltips/details later
/// without bypassing the catalog source of truth.
String gearDescriptionForSlot(GearSlot slot, Object id) {
  return switch (slot) {
    GearSlot.mainWeapon ||
    GearSlot.offhandWeapon => _weaponCatalog.get(id as WeaponId).description,
    GearSlot.throwingWeapon =>
      _projectileItemCatalog.get(id as ProjectileItemId).description,
    GearSlot.spellBook => _spellBookCatalog.get(id as SpellBookId).description,
    GearSlot.accessory => _accessoryCatalog.get(id as AccessoryId).description,
  };
}
