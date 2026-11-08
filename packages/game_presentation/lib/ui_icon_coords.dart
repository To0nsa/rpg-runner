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
  return switch (id) {
    WeaponId.hunterBlade => const UiWeaponIconSpec.image(
      '${_willowIconBasePath}blades/hunter_blade.png',
    ),
    WeaponId.hunterNotchknife => const UiWeaponIconSpec.image(
      '${_willowIconBasePath}blades/notchknife.png',
    ),
    WeaponId.hunterHookblade => const UiWeaponIconSpec.image(
      '${_willowIconBasePath}blades/hookblade.png',
    ),
    WeaponId.hunterCausticEdge => const UiWeaponIconSpec.image(
      '${_willowIconBasePath}blades/caustic_edge.png',
    ),
    WeaponId.hunterCinderpoint => const UiWeaponIconSpec.image(
      '${_willowIconBasePath}blades/cinderpoint.png',
    ),
    WeaponId.hunterSappingBlade => const UiWeaponIconSpec.image(
      '${_willowIconBasePath}blades/sapping_blade.png',
    ),
    WeaponId.hunterPursuitBlade => const UiWeaponIconSpec.image(
      '${_willowIconBasePath}blades/pursuit_blade.png',
    ),
    WeaponId.hunterLastWord => const UiWeaponIconSpec.image(
      '${_willowIconBasePath}blades/last_word.png',
    ),
    WeaponId.hunterBombKit => const UiWeaponIconSpec.image(
      '${_willowIconBasePath}bomb_kits/bomb_kit.png',
    ),
    WeaponId.hunterSplinterRig => const UiWeaponIconSpec.image(
      '${_willowIconBasePath}bomb_kits/splinter_rig.png',
    ),
    WeaponId.hunterPitchRig => const UiWeaponIconSpec.image(
      '${_willowIconBasePath}bomb_kits/pitch_rig.png',
    ),
    WeaponId.hunterSnareRig => const UiWeaponIconSpec.image(
      '${_willowIconBasePath}bomb_kits/snare_rig.png',
    ),
    WeaponId.hunterEtchingRig => const UiWeaponIconSpec.image(
      '${_willowIconBasePath}bomb_kits/etching_rig.png',
    ),
    WeaponId.hunterSapperHarness => const UiWeaponIconSpec.image(
      '${_willowIconBasePath}bomb_kits/sapper_harness.png',
    ),
    WeaponId.hunterKilnwrapRig => const UiWeaponIconSpec.image(
      '${_willowIconBasePath}bomb_kits/kilnwrap_rig.png',
    ),
    WeaponId.hunterSealedRig => const UiWeaponIconSpec.image(
      '${_willowIconBasePath}bomb_kits/sealed_rig.png',
    ),
    WeaponId.hunterStormwrapRig => const UiWeaponIconSpec.image(
      '${_willowIconBasePath}bomb_kits/stormwrap_rig.png',
    ),
    WeaponId.hunterBacktrailRig => const UiWeaponIconSpec.image(
      '${_willowIconBasePath}bomb_kits/backtrail_rig.png',
    ),
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
    WeaponId.roadguard => const UiWeaponIconSpec.image(
      '${_shieldIconBasePath}roadguard.png',
    ),
    WeaponId.thornbark => const UiWeaponIconSpec.image(
      '${_shieldIconBasePath}thornbark.png',
    ),
    WeaponId.cinderWard => const UiWeaponIconSpec.image(
      '${_shieldIconBasePath}cinderward.png',
    ),
    WeaponId.tideguardShell => const UiWeaponIconSpec.image(
      '${_shieldIconBasePath}tideguardShell.png',
    ),
    WeaponId.frostlockBuckler => const UiWeaponIconSpec.image(
      '${_shieldIconBasePath}frostlockBuckler.png',
    ),
    WeaponId.ironBastion => const UiWeaponIconSpec.image(
      '${_shieldIconBasePath}ironBastion.png',
    ),
    WeaponId.stormAegis => const UiWeaponIconSpec.image(
      '${_shieldIconBasePath}stormAegis.png',
    ),
    WeaponId.nullPrism => const UiWeaponIconSpec.image(
      '${_shieldIconBasePath}nullPrism.png',
    ),
    WeaponId.warbannerGuard => const UiWeaponIconSpec.image(
      '${_shieldIconBasePath}warbannerGuard.png',
    ),
    WeaponId.oathwallRelic => const UiWeaponIconSpec.image(
      '${_shieldIconBasePath}oathwallRelic.png',
    ),
  };
}

UiIconCoords? uiIconCoordsForWeapon(WeaponId id) {
  return uiIconSpecForWeapon(id).coords;
}

UiIconCoords? uiIconCoordsForSpellBook(SpellBookId id) {
  return switch (id) {
    SpellBookId.hunterFieldKit ||
    SpellBookId.hunterLongtrailPack ||
    SpellBookId.hunterMarksmanRoll ||
    SpellBookId.hunterQuickAccessSatchel ||
    SpellBookId.hunterReserveBandolier ||
    SpellBookId.hunterTrackerPouch ||
    SpellBookId.hunterSurveyorCase ||
    SpellBookId.hunterQuarryKit => null,
    SpellBookId.apprenticePrimer => const UiIconCoords(13, 0),
    SpellBookId.bastionCodex => const UiIconCoords(13, 1),
    SpellBookId.emberGrimoire => const UiIconCoords(13, 2),
    SpellBookId.tideAlmanac => const UiIconCoords(13, 3),
    SpellBookId.hexboundLexicon => const UiIconCoords(13, 4),
    SpellBookId.galeFolio => const UiIconCoords(13, 5),
    SpellBookId.nullTestament => const UiIconCoords(13, 6),
    SpellBookId.crownOfFocus => const UiIconCoords(13, 7),
  };
}

/// Dedicated field-kit artwork; spellbooks continue to use the atlas.
String? uiImageAssetPathForSpellBook(SpellBookId id) => switch (id) {
  SpellBookId.hunterFieldKit =>
    '${_willowIconBasePath}field_kits/field_kit.png',
  SpellBookId.hunterLongtrailPack =>
    '${_willowIconBasePath}field_kits/longtrail_pack.png',
  SpellBookId.hunterMarksmanRoll =>
    '${_willowIconBasePath}field_kits/marksman_roll.png',
  SpellBookId.hunterQuickAccessSatchel =>
    '${_willowIconBasePath}field_kits/quick_access_satchel.png',
  SpellBookId.hunterReserveBandolier =>
    '${_willowIconBasePath}field_kits/reserve_bandolier.png',
  SpellBookId.hunterTrackerPouch =>
    '${_willowIconBasePath}field_kits/tracker_pouch.png',
  SpellBookId.hunterSurveyorCase =>
    '${_willowIconBasePath}field_kits/surveyor_case.png',
  SpellBookId.hunterQuarryKit =>
    '${_willowIconBasePath}field_kits/quarry_kit.png',
  _ => null,
};

/// Inventory weapon illustrations, independent of projectile flight effects.
String? uiImageAssetPathForProjectile(ProjectileId id) => switch (id) {
  ProjectileId.hunterPistol => '${_willowIconBasePath}ranged/pistol.png',
  ProjectileId.hunterCrossbow => '${_willowIconBasePath}ranged/crossbow.png',
  ProjectileId.hunterShotgun => '${_willowIconBasePath}ranged/shotgun.png',
  ProjectileId.hunterRoadsidePistol =>
    '${_willowIconBasePath}ranged/roadside_pistol.png',
  ProjectileId.hunterLongbarrelPistol =>
    '${_willowIconBasePath}ranged/longbarrel_pistol.png',
  ProjectileId.hunterLongwatchCrossbow =>
    '${_willowIconBasePath}ranged/longwatch_crossbow.png',
  ProjectileId.hunterHeavyLimbCrossbow =>
    '${_willowIconBasePath}ranged/heavy_limb_crossbow.png',
  ProjectileId.hunterBrushgun => '${_willowIconBasePath}ranged/brushgun.png',
  _ => null,
};

UiIconCoords? uiIconCoordsForAccessory(AccessoryId id) {
  return switch (id) {
    AccessoryId.speedBoots => const UiIconCoords(8, 2),
    AccessoryId.goldenRing => const UiIconCoords(8, 4),
    AccessoryId.teethNecklace => const UiIconCoords(8, 8),
    AccessoryId.diamondRing => const UiIconCoords(8, 5),
    AccessoryId.ironBoots => const UiIconCoords(8, 3),
    AccessoryId.oathBeads => const UiIconCoords(8, 7),
    AccessoryId.resilienceCape => const UiIconCoords(7, 14),
    AccessoryId.strengthBelt => const UiIconCoords(7, 15),
  };
}

const UiIconCoords swapGearIconCoords = UiIconCoords(2, 6);
