import '../../core/accessories/accessory_id.dart';
import '../../core/spellBook/spell_book_id.dart';
import '../../core/weapons/weapon_id.dart';

class UiIconCoords {
  const UiIconCoords(this.row, this.col);

  final int row;
  final int col;
}

/// Icon descriptor for weapon ids.
///
/// A weapon icon can come from a sprite sheet ([coords] + [spriteAssetPath]) or
/// a dedicated raster asset ([imageAssetPath]).
class UiWeaponIconSpec {
  const UiWeaponIconSpec.sprite({
    required this.coords,
    required this.spriteAssetPath,
    this.tilePx = 32,
  }) : imageAssetPath = null;

  const UiWeaponIconSpec.image(this.imageAssetPath)
    : coords = null,
      spriteAssetPath = null,
      tilePx = 32;

  final UiIconCoords? coords;
  final String? spriteAssetPath;
  final String? imageAssetPath;
  final int tilePx;
}

const String _defaultUiSpritePath = 'assets/images/icons/transparentIcons.png';
const String _swordUiSpritePath =
    'assets/images/icons/gear-icons/sword/transparentIcons.png';

/// Full weapon icon mapping for loadout and gear picker UI.
UiWeaponIconSpec uiIconSpecForWeapon(WeaponId id) {
  return switch (id) {
    WeaponId.plainsteel => const UiWeaponIconSpec.sprite(
      coords: UiIconCoords(5, 1),
      spriteAssetPath: _swordUiSpritePath,
    ),
    WeaponId.waspfang => const UiWeaponIconSpec.image(
      'assets/images/icons/gear-icons/sword/waspfang.png',
    ),
    WeaponId.cinderedge => const UiWeaponIconSpec.sprite(
      coords: UiIconCoords(5, 7),
      spriteAssetPath: _swordUiSpritePath,
    ),
    WeaponId.basiliskKiss => const UiWeaponIconSpec.sprite(
      coords: UiIconCoords(5, 0),
      spriteAssetPath: _swordUiSpritePath,
    ),
    WeaponId.frostbrand => const UiWeaponIconSpec.sprite(
      coords: UiIconCoords(5, 2),
      spriteAssetPath: _swordUiSpritePath,
    ),
    WeaponId.stormneedle => const UiWeaponIconSpec.sprite(
      coords: UiIconCoords(5, 3),
      spriteAssetPath: _swordUiSpritePath,
    ),
    WeaponId.nullblade => const UiWeaponIconSpec.sprite(
      coords: UiIconCoords(5, 5),
      spriteAssetPath: _swordUiSpritePath,
    ),
    WeaponId.sunlitVow => const UiWeaponIconSpec.sprite(
      coords: UiIconCoords(5, 4),
      spriteAssetPath: _swordUiSpritePath,
    ),
    WeaponId.graveglass => const UiWeaponIconSpec.image(
      'assets/images/icons/gear-icons/sword/graveglass.png',
    ),
    WeaponId.duelistsOath => const UiWeaponIconSpec.image(
      'assets/images/icons/gear-icons/sword/duelistsOath.png',
    ),
    WeaponId.woodenShield => const UiWeaponIconSpec.sprite(
      coords: UiIconCoords(6, 0),
      spriteAssetPath: _defaultUiSpritePath,
    ),
    WeaponId.basicShield => const UiWeaponIconSpec.sprite(
      coords: UiIconCoords(6, 1),
      spriteAssetPath: _defaultUiSpritePath,
    ),
    WeaponId.solidShield => const UiWeaponIconSpec.sprite(
      coords: UiIconCoords(6, 2),
      spriteAssetPath: _defaultUiSpritePath,
    ),
  };
}

UiIconCoords? uiIconCoordsForWeapon(WeaponId id) {
  return uiIconSpecForWeapon(id).coords;
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
