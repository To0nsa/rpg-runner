import 'item_icon_ids.dart';
import 'items.generated.dart';

import 'package:runner_core/accessories/accessory_id.dart';
import 'package:runner_core/projectiles/projectile_id.dart';
import 'package:runner_core/spellBook/spell_book_id.dart';
import 'package:runner_core/weapons/weapon_id.dart';

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
  const UiWeaponIconSpec.empty()
    : coords = null,
      spriteAssetPath = null,
      imageAssetPath = null,
      tilePx = 32;

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

const String _swordUiSpritePath =
    'assets/images/icons/gear-icons/sword/transparentIcons.png';
const String _shieldIconBasePath = 'assets/images/icons/gear-icons/shields/';
const String _willowIconBasePath = 'assets/images/icons/gear-icons/willow/';

/// Full weapon icon mapping for loadout and gear picker UI.
UiWeaponIconSpec uiIconSpecForWeapon(WeaponId id) {
  return canonicalWeaponIconSpec(itemIconForWeapon(id));
}

UiWeaponIconSpec canonicalWeaponIconSpec(CanonicalWeaponIcon icon) {
  return switch (icon) {
    CanonicalWeaponIcon.hunterBlade => const UiWeaponIconSpec.image(
      '${_willowIconBasePath}blades/hunter_blade.png',
    ),
    CanonicalWeaponIcon.hunterNotchknife => const UiWeaponIconSpec.image(
      '${_willowIconBasePath}blades/notchknife.png',
    ),
    CanonicalWeaponIcon.hunterHookblade => const UiWeaponIconSpec.image(
      '${_willowIconBasePath}blades/hookblade.png',
    ),
    CanonicalWeaponIcon.hunterCausticEdge => const UiWeaponIconSpec.image(
      '${_willowIconBasePath}blades/caustic_edge.png',
    ),
    CanonicalWeaponIcon.hunterCinderpoint => const UiWeaponIconSpec.image(
      '${_willowIconBasePath}blades/cinderpoint.png',
    ),
    CanonicalWeaponIcon.hunterSappingBlade => const UiWeaponIconSpec.image(
      '${_willowIconBasePath}blades/sapping_blade.png',
    ),
    CanonicalWeaponIcon.hunterPursuitBlade => const UiWeaponIconSpec.image(
      '${_willowIconBasePath}blades/pursuit_blade.png',
    ),
    CanonicalWeaponIcon.hunterLastWord => const UiWeaponIconSpec.image(
      '${_willowIconBasePath}blades/last_word.png',
    ),
    CanonicalWeaponIcon.hunterBombKit => const UiWeaponIconSpec.image(
      '${_willowIconBasePath}bomb_kits/bomb_kit.png',
    ),
    CanonicalWeaponIcon.hunterSplinterRig => const UiWeaponIconSpec.image(
      '${_willowIconBasePath}bomb_kits/splinter_rig.png',
    ),
    CanonicalWeaponIcon.hunterPitchRig => const UiWeaponIconSpec.image(
      '${_willowIconBasePath}bomb_kits/pitch_rig.png',
    ),
    CanonicalWeaponIcon.hunterSnareRig => const UiWeaponIconSpec.image(
      '${_willowIconBasePath}bomb_kits/snare_rig.png',
    ),
    CanonicalWeaponIcon.hunterEtchingRig => const UiWeaponIconSpec.image(
      '${_willowIconBasePath}bomb_kits/etching_rig.png',
    ),
    CanonicalWeaponIcon.hunterSapperHarness => const UiWeaponIconSpec.image(
      '${_willowIconBasePath}bomb_kits/sapper_harness.png',
    ),
    CanonicalWeaponIcon.hunterKilnwrapRig => const UiWeaponIconSpec.image(
      '${_willowIconBasePath}bomb_kits/kilnwrap_rig.png',
    ),
    CanonicalWeaponIcon.hunterSealedRig => const UiWeaponIconSpec.image(
      '${_willowIconBasePath}bomb_kits/sealed_rig.png',
    ),
    CanonicalWeaponIcon.hunterStormwrapRig => const UiWeaponIconSpec.image(
      '${_willowIconBasePath}bomb_kits/stormwrap_rig.png',
    ),
    CanonicalWeaponIcon.hunterBacktrailRig => const UiWeaponIconSpec.image(
      '${_willowIconBasePath}bomb_kits/backtrail_rig.png',
    ),
    CanonicalWeaponIcon.plainsteel => const UiWeaponIconSpec.sprite(
      coords: UiIconCoords(5, 1),
      spriteAssetPath: _swordUiSpritePath,
    ),
    CanonicalWeaponIcon.waspfang => const UiWeaponIconSpec.image(
      'assets/images/icons/gear-icons/sword/waspfang.png',
    ),
    CanonicalWeaponIcon.cinderedge => const UiWeaponIconSpec.sprite(
      coords: UiIconCoords(5, 7),
      spriteAssetPath: _swordUiSpritePath,
    ),
    CanonicalWeaponIcon.basiliskKiss => const UiWeaponIconSpec.sprite(
      coords: UiIconCoords(5, 0),
      spriteAssetPath: _swordUiSpritePath,
    ),
    CanonicalWeaponIcon.frostbrand => const UiWeaponIconSpec.sprite(
      coords: UiIconCoords(5, 2),
      spriteAssetPath: _swordUiSpritePath,
    ),
    CanonicalWeaponIcon.stormneedle => const UiWeaponIconSpec.sprite(
      coords: UiIconCoords(5, 3),
      spriteAssetPath: _swordUiSpritePath,
    ),
    CanonicalWeaponIcon.nullblade => const UiWeaponIconSpec.sprite(
      coords: UiIconCoords(5, 5),
      spriteAssetPath: _swordUiSpritePath,
    ),
    CanonicalWeaponIcon.sunlitVow => const UiWeaponIconSpec.sprite(
      coords: UiIconCoords(5, 4),
      spriteAssetPath: _swordUiSpritePath,
    ),
    CanonicalWeaponIcon.roadguard => const UiWeaponIconSpec.image(
      '${_shieldIconBasePath}roadguard.png',
    ),
    CanonicalWeaponIcon.thornbark => const UiWeaponIconSpec.image(
      '${_shieldIconBasePath}thornbark.png',
    ),
    CanonicalWeaponIcon.cinderWard => const UiWeaponIconSpec.image(
      '${_shieldIconBasePath}cinderward.png',
    ),
    CanonicalWeaponIcon.tideguardShell => const UiWeaponIconSpec.image(
      '${_shieldIconBasePath}tideguardShell.png',
    ),
    CanonicalWeaponIcon.frostlockBuckler => const UiWeaponIconSpec.image(
      '${_shieldIconBasePath}frostlockBuckler.png',
    ),
    CanonicalWeaponIcon.ironBastion => const UiWeaponIconSpec.image(
      '${_shieldIconBasePath}ironBastion.png',
    ),
    CanonicalWeaponIcon.stormAegis => const UiWeaponIconSpec.image(
      '${_shieldIconBasePath}stormAegis.png',
    ),
    CanonicalWeaponIcon.nullPrism => const UiWeaponIconSpec.image(
      '${_shieldIconBasePath}nullPrism.png',
    ),
    CanonicalWeaponIcon.warbannerGuard => const UiWeaponIconSpec.image(
      '${_shieldIconBasePath}warbannerGuard.png',
    ),
    CanonicalWeaponIcon.oathwallRelic => const UiWeaponIconSpec.image(
      '${_shieldIconBasePath}oathwallRelic.png',
    ),
  };
}

UiIconCoords? uiIconCoordsForWeapon(WeaponId id) {
  return uiIconSpecForWeapon(id).coords;
}

UiIconCoords? uiIconCoordsForSpellBook(SpellBookId id) {
  return canonicalSpellBookIconCoords(itemIconForSpellBook(id));
}

UiIconCoords? canonicalSpellBookIconCoords(CanonicalSpellBookIcon icon) {
  return switch (icon) {
    CanonicalSpellBookIcon.hunterFieldKit ||
    CanonicalSpellBookIcon.hunterLongtrailPack ||
    CanonicalSpellBookIcon.hunterMarksmanRoll ||
    CanonicalSpellBookIcon.hunterQuickAccessSatchel ||
    CanonicalSpellBookIcon.hunterReserveBandolier ||
    CanonicalSpellBookIcon.hunterTrackerPouch ||
    CanonicalSpellBookIcon.hunterSurveyorCase ||
    CanonicalSpellBookIcon.hunterQuarryKit => null,
    CanonicalSpellBookIcon.apprenticePrimer => const UiIconCoords(13, 0),
    CanonicalSpellBookIcon.bastionCodex => const UiIconCoords(13, 1),
    CanonicalSpellBookIcon.emberGrimoire => const UiIconCoords(13, 2),
    CanonicalSpellBookIcon.tideAlmanac => const UiIconCoords(13, 3),
    CanonicalSpellBookIcon.hexboundLexicon => const UiIconCoords(13, 4),
    CanonicalSpellBookIcon.galeFolio => const UiIconCoords(13, 5),
    CanonicalSpellBookIcon.nullTestament => const UiIconCoords(13, 6),
    CanonicalSpellBookIcon.crownOfFocus => const UiIconCoords(13, 7),
  };
}

/// Dedicated field-kit artwork; spellbooks continue to use the atlas.
String? uiImageAssetPathForSpellBook(SpellBookId id) =>
    canonicalSpellBookImage(itemIconForSpellBook(id));
String? canonicalSpellBookImage(CanonicalSpellBookIcon? icon) => switch (icon) {
  CanonicalSpellBookIcon.hunterFieldKit =>
    '${_willowIconBasePath}field_kits/field_kit.png',
  CanonicalSpellBookIcon.hunterLongtrailPack =>
    '${_willowIconBasePath}field_kits/longtrail_pack.png',
  CanonicalSpellBookIcon.hunterMarksmanRoll =>
    '${_willowIconBasePath}field_kits/marksman_roll.png',
  CanonicalSpellBookIcon.hunterQuickAccessSatchel =>
    '${_willowIconBasePath}field_kits/quick_access_satchel.png',
  CanonicalSpellBookIcon.hunterReserveBandolier =>
    '${_willowIconBasePath}field_kits/reserve_bandolier.png',
  CanonicalSpellBookIcon.hunterTrackerPouch =>
    '${_willowIconBasePath}field_kits/tracker_pouch.png',
  CanonicalSpellBookIcon.hunterSurveyorCase =>
    '${_willowIconBasePath}field_kits/surveyor_case.png',
  CanonicalSpellBookIcon.hunterQuarryKit =>
    '${_willowIconBasePath}field_kits/quarry_kit.png',
  _ => null,
};

/// Inventory weapon illustrations, independent of projectile flight effects.
String? uiImageAssetPathForProjectile(ProjectileId id) =>
    canonicalProjectileImage(itemIconForProjectile(id));
String? canonicalProjectileImage(CanonicalProjectileIcon? icon) =>
    switch (icon) {
      CanonicalProjectileIcon.hunterPistol =>
        '${_willowIconBasePath}ranged/pistol.png',
      CanonicalProjectileIcon.hunterCrossbow =>
        '${_willowIconBasePath}ranged/crossbow.png',
      CanonicalProjectileIcon.hunterShotgun =>
        '${_willowIconBasePath}ranged/shotgun.png',
      CanonicalProjectileIcon.hunterRoadsidePistol =>
        '${_willowIconBasePath}ranged/roadside_pistol.png',
      CanonicalProjectileIcon.hunterLongbarrelPistol =>
        '${_willowIconBasePath}ranged/longbarrel_pistol.png',
      CanonicalProjectileIcon.hunterLongwatchCrossbow =>
        '${_willowIconBasePath}ranged/longwatch_crossbow.png',
      CanonicalProjectileIcon.hunterHeavyLimbCrossbow =>
        '${_willowIconBasePath}ranged/heavy_limb_crossbow.png',
      CanonicalProjectileIcon.hunterBrushgun =>
        '${_willowIconBasePath}ranged/brushgun.png',
      _ => null,
    };

UiIconCoords? uiIconCoordsForAccessory(AccessoryId id) {
  return canonicalAccessoryIconCoords(itemIconForAccessory(id));
}

UiIconCoords? canonicalAccessoryIconCoords(CanonicalAccessoryIcon icon) {
  return switch (icon) {
    CanonicalAccessoryIcon.speedBoots => const UiIconCoords(8, 2),
    CanonicalAccessoryIcon.goldenRing => const UiIconCoords(8, 4),
    CanonicalAccessoryIcon.teethNecklace => const UiIconCoords(8, 8),
    CanonicalAccessoryIcon.diamondRing => const UiIconCoords(8, 5),
    CanonicalAccessoryIcon.ironBoots => const UiIconCoords(8, 3),
    CanonicalAccessoryIcon.oathBeads => const UiIconCoords(8, 7),
    CanonicalAccessoryIcon.resilienceCape => const UiIconCoords(7, 14),
    CanonicalAccessoryIcon.strengthBelt => const UiIconCoords(7, 15),
  };
}

const UiIconCoords swapGearIconCoords = UiIconCoords(2, 6);
