import '../../core/accessories/accessory_id.dart';
import '../../core/spells/spell_book_id.dart';
import '../../core/weapons/weapon_id.dart';

class UiIconCoords {
  const UiIconCoords(this.row, this.col);

  final int row;
  final int col;
}

UiIconCoords? uiIconCoordsForWeapon(WeaponId id) {
  return switch (id) {
    WeaponId.woodenSword => const UiIconCoords(5, 0),
    WeaponId.basicSword => const UiIconCoords(5, 1),
    WeaponId.solidSword => const UiIconCoords(5, 2),
    WeaponId.woodenShield => const UiIconCoords(6, 0),
    WeaponId.basicShield => const UiIconCoords(6, 1),
    WeaponId.solidShield => const UiIconCoords(6, 2),
  };
}

UiIconCoords? uiIconCoordsForSpellBook(SpellBookId id) {
  return switch (id) {
    SpellBookId.basicSpellBook => const UiIconCoords(13, 0),
    SpellBookId.solidSpellBook => const UiIconCoords(13, 1),
    SpellBookId.epicSpellBook => const UiIconCoords(13, 2),
  };
}

UiIconCoords? uiIconCoordsForAccessory(AccessoryId id) {
  return switch (id) {
    AccessoryId.speedBoots => const UiIconCoords(8, 2),
    AccessoryId.goldenRing => const UiIconCoords(8, 4),
    AccessoryId.teethNecklace => const UiIconCoords(8, 8),
  };
}

const UiIconCoords swapGearIconCoords = UiIconCoords(2, 6);
