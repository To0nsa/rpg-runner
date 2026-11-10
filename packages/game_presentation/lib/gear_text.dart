import 'package:intl/intl.dart';
import 'package:runner_core/accessories/accessory_id.dart';
import 'package:runner_core/combat/damage_type.dart';
import 'package:runner_core/combat/status/status.dart';
import 'package:runner_core/meta/gear_slot.dart';
import 'package:runner_core/projectiles/projectile_id.dart';
import 'package:runner_core/projectiles/projectile_catalog.dart';
import 'package:runner_core/projectiles/projectile_item_def.dart';
import 'package:runner_core/spellBook/spell_book_id.dart';
import 'package:runner_core/weapons/weapon_id.dart';
import 'package:runner_core/weapons/weapon_proc.dart';

import 'game_localization.dart';

/// Localized catalog identity; exhaustive mapping makes new enum values explicit.
String weaponDisplayName(WeaponId id, {required GameLocalizations strings}) =>
    switch (id) {
      WeaponId.plainsteel => strings.weaponPlainsteelName,
      WeaponId.waspfang => strings.weaponWaspfangName,
      WeaponId.cinderedge => strings.weaponCinderedgeName,
      WeaponId.basiliskKiss => strings.weaponBasiliskKissName,
      WeaponId.frostbrand => strings.weaponFrostbrandName,
      WeaponId.stormneedle => strings.weaponStormneedleName,
      WeaponId.nullblade => strings.weaponNullbladeName,
      WeaponId.sunlitVow => strings.weaponSunlitVowName,
      WeaponId.roadguard => strings.weaponRoadguardName,
      WeaponId.thornbark => strings.weaponThornbarkName,
      WeaponId.cinderWard => strings.weaponCinderWardName,
      WeaponId.tideguardShell => strings.weaponTideguardShellName,
      WeaponId.frostlockBuckler => strings.weaponFrostlockBucklerName,
      WeaponId.ironBastion => strings.weaponIronBastionName,
      WeaponId.stormAegis => strings.weaponStormAegisName,
      WeaponId.nullPrism => strings.weaponNullPrismName,
      WeaponId.warbannerGuard => strings.weaponWarbannerGuardName,
      WeaponId.oathwallRelic => strings.weaponOathwallRelicName,
      WeaponId.hunterBlade => strings.weaponHunterBladeName,
      WeaponId.hunterBombKit => strings.weaponHunterBombKitName,
      WeaponId.hunterNotchknife => strings.weaponHunterNotchknifeName,
      WeaponId.hunterHookblade => strings.weaponHunterHookbladeName,
      WeaponId.hunterCausticEdge => strings.weaponHunterCausticEdgeName,
      WeaponId.hunterCinderpoint => strings.weaponHunterCinderpointName,
      WeaponId.hunterSappingBlade => strings.weaponHunterSappingBladeName,
      WeaponId.hunterPursuitBlade => strings.weaponHunterPursuitBladeName,
      WeaponId.hunterLastWord => strings.weaponHunterLastWordName,
      WeaponId.hunterSplinterRig => strings.weaponHunterSplinterRigName,
      WeaponId.hunterPitchRig => strings.weaponHunterPitchRigName,
      WeaponId.hunterSnareRig => strings.weaponHunterSnareRigName,
      WeaponId.hunterEtchingRig => strings.weaponHunterEtchingRigName,
      WeaponId.hunterSapperHarness => strings.weaponHunterSapperHarnessName,
      WeaponId.hunterKilnwrapRig => strings.weaponHunterKilnwrapRigName,
      WeaponId.hunterSealedRig => strings.weaponHunterSealedRigName,
      WeaponId.hunterStormwrapRig => strings.weaponHunterStormwrapRigName,
      WeaponId.hunterBacktrailRig => strings.weaponHunterBacktrailRigName,
    };

/// Resolves a complete translated description for the character's resource pool.
String weaponDescription(
  WeaponId id, {
  required GameLocalizations strings,
  ManaPresentation manaPresentation = ManaPresentation.mana,
}) => switch (id) {
  WeaponId.plainsteel => strings.weaponPlainsteelDescription,
  WeaponId.waspfang => strings.weaponWaspfangDescription,
  WeaponId.cinderedge => strings.weaponCinderedgeDescription,
  WeaponId.basiliskKiss => strings.weaponBasiliskKissDescription,
  WeaponId.frostbrand => strings.weaponFrostbrandDescription,
  WeaponId.stormneedle => strings.weaponStormneedleDescription,
  WeaponId.nullblade => strings.weaponNullbladeDescription,
  WeaponId.sunlitVow => strings.weaponSunlitVowDescription,
  WeaponId.roadguard => strings.weaponRoadguardDescription,
  WeaponId.thornbark => strings.weaponThornbarkDescription,
  WeaponId.cinderWard => strings.weaponCinderWardDescription,
  WeaponId.tideguardShell => strings.weaponTideguardShellDescription,
  WeaponId.frostlockBuckler => strings.weaponFrostlockBucklerDescription,
  WeaponId.ironBastion => strings.weaponIronBastionDescription,
  WeaponId.stormAegis => strings.weaponStormAegisDescription,
  WeaponId.nullPrism => strings.weaponNullPrismDescription,
  WeaponId.warbannerGuard => strings.weaponWarbannerGuardDescription,
  WeaponId.oathwallRelic => strings.weaponOathwallRelicDescription,
  WeaponId.hunterBlade => strings.weaponHunterBladeDescription,
  WeaponId.hunterBombKit => strings.weaponHunterBombKitDescription,
  WeaponId.hunterNotchknife => strings.weaponHunterNotchknifeDescription,
  WeaponId.hunterHookblade => strings.weaponHunterHookbladeDescription,
  WeaponId.hunterCausticEdge => strings.weaponHunterCausticEdgeDescription,
  WeaponId.hunterCinderpoint => strings.weaponHunterCinderpointDescription,
  WeaponId.hunterSappingBlade => strings.weaponHunterSappingBladeDescription,
  WeaponId.hunterPursuitBlade => strings.weaponHunterPursuitBladeDescription,
  WeaponId.hunterLastWord => strings.weaponHunterLastWordDescription,
  WeaponId.hunterSplinterRig => strings.weaponHunterSplinterRigDescription,
  WeaponId.hunterPitchRig => strings.weaponHunterPitchRigDescription,
  WeaponId.hunterSnareRig => strings.weaponHunterSnareRigDescription,
  WeaponId.hunterEtchingRig => strings.weaponHunterEtchingRigDescription,
  WeaponId.hunterSapperHarness => strings.weaponHunterSapperHarnessDescription,
  WeaponId.hunterKilnwrapRig => strings.weaponHunterKilnwrapRigDescription,
  WeaponId.hunterSealedRig => strings.weaponHunterSealedRigDescription,
  WeaponId.hunterStormwrapRig => strings.weaponHunterStormwrapRigDescription,
  WeaponId.hunterBacktrailRig => strings.weaponHunterBacktrailRigDescription,
};

/// Localized catalog identity; exhaustive mapping makes new enum values explicit.
String projectileDisplayName(
  ProjectileId id, {
  required GameLocalizations strings,
}) => switch (id) {
  ProjectileId.unknown => strings.projectileUnknownName,
  ProjectileId.iceBolt => strings.projectileIceBoltName,
  ProjectileId.fireBolt => strings.projectileFireBoltName,
  ProjectileId.acidBolt => strings.projectileAcidBoltName,
  ProjectileId.darkBolt => strings.projectileDarkBoltName,
  ProjectileId.earthBolt => strings.projectileEarthBoltName,
  ProjectileId.holyBolt => strings.projectileHolyBoltName,
  ProjectileId.waterBolt => strings.projectileWaterBoltName,
  ProjectileId.thunderBolt => strings.projectileThunderBoltName,
  ProjectileId.poisonDart => strings.projectilePoisonDartName,
  ProjectileId.npcSpear => strings.projectileNpcSpearName,
  ProjectileId.npcArrow => strings.projectileNpcArrowName,
  ProjectileId.goddessOrb => strings.projectileGoddessOrbName,
  ProjectileId.shoggothOrb => strings.projectileShoggothOrbName,
  ProjectileId.voidClaw => strings.projectileVoidClawName,
  ProjectileId.hunterPistol => strings.projectileHunterPistolName,
  ProjectileId.hunterCrossbow => strings.projectileHunterCrossbowName,
  ProjectileId.hunterShotgun => strings.projectileHunterShotgunName,
  ProjectileId.hunterBomb => strings.projectileHunterBombName,
  ProjectileId.hunterRoadsidePistol =>
    strings.projectileHunterRoadsidePistolName,
  ProjectileId.hunterLongbarrelPistol =>
    strings.projectileHunterLongbarrelPistolName,
  ProjectileId.hunterLongwatchCrossbow =>
    strings.projectileHunterLongwatchCrossbowName,
  ProjectileId.hunterHeavyLimbCrossbow =>
    strings.projectileHunterHeavyLimbCrossbowName,
  ProjectileId.hunterBrushgun => strings.projectileHunterBrushgunName,
};

/// Description parameters read the same item/status catalogs as gameplay.
String projectileDescription(
  ProjectileId id, {
  required GameLocalizations strings,
}) {
  final item = const ProjectileCatalog().tryGet(id);
  if (item == null) return strings.projectileUnknownDescription;
  return switch (id) {
    ProjectileId.unknown => strings.projectileUnknownDescription,
    ProjectileId.iceBolt => strings.projectileIceBoltDescription,
    ProjectileId.fireBolt => strings.projectileFireBoltDescription,
    ProjectileId.acidBolt => strings.projectileAcidBoltDescription,
    ProjectileId.darkBolt => strings.projectileDarkBoltDescription,
    ProjectileId.earthBolt => strings.projectileEarthBoltDescription,
    ProjectileId.holyBolt => strings.projectileHolyBoltDescription(
      seconds: _silenceSeconds(item),
    ),
    ProjectileId.waterBolt => strings.projectileWaterBoltDescription,
    ProjectileId.thunderBolt => strings.projectileThunderBoltDescription,
    ProjectileId.poisonDart => strings.projectilePoisonDartDescription,
    ProjectileId.npcSpear => strings.projectileNpcSpearDescription,
    ProjectileId.npcArrow => strings.projectileNpcArrowDescription,
    ProjectileId.goddessOrb => strings.projectileGoddessOrbDescription,
    ProjectileId.shoggothOrb => strings.projectileShoggothOrbDescription,
    ProjectileId.voidClaw => strings.projectileVoidClawDescription,
    ProjectileId.hunterPistol => strings.projectileHunterPistolDescription,
    ProjectileId.hunterCrossbow => strings.projectileHunterCrossbowDescription(
      damagePercent: item.damageScaleBp / 100.0,
    ),
    ProjectileId.hunterShotgun => strings.projectileHunterShotgunDescription(
      damagePercent: item.damageScaleBp / 100.0,
      pellets: item.shotCount,
    ),
    ProjectileId.hunterBomb => strings.projectileHunterBombDescription,
    ProjectileId.hunterRoadsidePistol =>
      strings.projectileHunterRoadsidePistolDescription(
        damagePercent: item.damageScaleBp / 100.0,
      ),
    ProjectileId.hunterLongbarrelPistol =>
      strings.projectileHunterLongbarrelPistolDescription(
        damagePercent: item.damageScaleBp / 100.0,
      ),
    ProjectileId.hunterLongwatchCrossbow =>
      strings.projectileHunterLongwatchCrossbowDescription,
    ProjectileId.hunterHeavyLimbCrossbow =>
      strings.projectileHunterHeavyLimbCrossbowDescription(
        damagePercent: item.damageScaleBp / 100.0,
      ),
    ProjectileId.hunterBrushgun => strings.projectileHunterBrushgunDescription(
      damagePercent: item.damageScaleBp / 100.0,
      pellets: item.shotCount,
    ),
  };
}

/// Localized catalog identity; exhaustive mapping makes new enum values explicit.
String spellBookDisplayName(
  SpellBookId id, {
  required GameLocalizations strings,
}) => switch (id) {
  SpellBookId.apprenticePrimer => strings.spellBookApprenticePrimerName,
  SpellBookId.bastionCodex => strings.spellBookBastionCodexName,
  SpellBookId.emberGrimoire => strings.spellBookEmberGrimoireName,
  SpellBookId.tideAlmanac => strings.spellBookTideAlmanacName,
  SpellBookId.hexboundLexicon => strings.spellBookHexboundLexiconName,
  SpellBookId.galeFolio => strings.spellBookGaleFolioName,
  SpellBookId.nullTestament => strings.spellBookNullTestamentName,
  SpellBookId.crownOfFocus => strings.spellBookCrownOfFocusName,
  SpellBookId.hunterFieldKit => strings.spellBookHunterFieldKitName,
  SpellBookId.hunterLongtrailPack => strings.spellBookHunterLongtrailPackName,
  SpellBookId.hunterMarksmanRoll => strings.spellBookHunterMarksmanRollName,
  SpellBookId.hunterQuickAccessSatchel =>
    strings.spellBookHunterQuickAccessSatchelName,
  SpellBookId.hunterReserveBandolier =>
    strings.spellBookHunterReserveBandolierName,
  SpellBookId.hunterTrackerPouch => strings.spellBookHunterTrackerPouchName,
  SpellBookId.hunterSurveyorCase => strings.spellBookHunterSurveyorCaseName,
  SpellBookId.hunterQuarryKit => strings.spellBookHunterQuarryKitName,
};

/// Resolves a complete translated description for the character's resource pool.
String spellBookDescription(
  SpellBookId id, {
  required GameLocalizations strings,
  ManaPresentation manaPresentation = ManaPresentation.mana,
}) => switch (id) {
  SpellBookId.apprenticePrimer => strings.spellBookApprenticePrimerDescription(
    resource: manaPresentation.name,
  ),
  SpellBookId.bastionCodex => strings.spellBookBastionCodexDescription(
    resource: manaPresentation.name,
  ),
  SpellBookId.emberGrimoire => strings.spellBookEmberGrimoireDescription(
    resource: manaPresentation.name,
  ),
  SpellBookId.tideAlmanac => strings.spellBookTideAlmanacDescription(
    resource: manaPresentation.name,
  ),
  SpellBookId.hexboundLexicon => strings.spellBookHexboundLexiconDescription(
    resource: manaPresentation.name,
  ),
  SpellBookId.galeFolio => strings.spellBookGaleFolioDescription(
    resource: manaPresentation.name,
  ),
  SpellBookId.nullTestament => strings.spellBookNullTestamentDescription(
    resource: manaPresentation.name,
  ),
  SpellBookId.crownOfFocus => strings.spellBookCrownOfFocusDescription(
    resource: manaPresentation.name,
  ),
  SpellBookId.hunterFieldKit => strings.spellBookHunterFieldKitDescription,
  SpellBookId.hunterLongtrailPack =>
    strings.spellBookHunterLongtrailPackDescription,
  SpellBookId.hunterMarksmanRoll =>
    strings.spellBookHunterMarksmanRollDescription,
  SpellBookId.hunterQuickAccessSatchel =>
    strings.spellBookHunterQuickAccessSatchelDescription,
  SpellBookId.hunterReserveBandolier =>
    strings.spellBookHunterReserveBandolierDescription,
  SpellBookId.hunterTrackerPouch =>
    strings.spellBookHunterTrackerPouchDescription,
  SpellBookId.hunterSurveyorCase =>
    strings.spellBookHunterSurveyorCaseDescription,
  SpellBookId.hunterQuarryKit => strings.spellBookHunterQuarryKitDescription,
};

/// Localized catalog identity; exhaustive mapping makes new enum values explicit.
String accessoryDisplayName(
  AccessoryId id, {
  required GameLocalizations strings,
}) => switch (id) {
  AccessoryId.speedBoots => strings.accessorySpeedBootsName,
  AccessoryId.goldenRing => strings.accessoryGoldenRingName,
  AccessoryId.teethNecklace => strings.accessoryTeethNecklaceName,
  AccessoryId.diamondRing => strings.accessoryDiamondRingName,
  AccessoryId.ironBoots => strings.accessoryIronBootsName,
  AccessoryId.oathBeads => strings.accessoryOathBeadsName,
  AccessoryId.resilienceCape => strings.accessoryResilienceCapeName,
  AccessoryId.strengthBelt => strings.accessoryStrengthBeltName,
};

/// Resolves a complete translated description for the character's resource pool.
String accessoryDescription(
  AccessoryId id, {
  required GameLocalizations strings,
  ManaPresentation manaPresentation = ManaPresentation.mana,
}) => switch (id) {
  AccessoryId.speedBoots => strings.accessorySpeedBootsDescription(
    resource: manaPresentation.name,
  ),
  AccessoryId.goldenRing => strings.accessoryGoldenRingDescription,
  AccessoryId.teethNecklace => strings.accessoryTeethNecklaceDescription,
  AccessoryId.diamondRing => strings.accessoryDiamondRingDescription(
    resource: manaPresentation.name,
  ),
  AccessoryId.ironBoots => strings.accessoryIronBootsDescription,
  AccessoryId.oathBeads => strings.accessoryOathBeadsDescription(
    resource: manaPresentation.name,
  ),
  AccessoryId.resilienceCape => strings.accessoryResilienceCapeDescription,
  AccessoryId.strengthBelt => strings.accessoryStrengthBeltDescription,
};

/// Resource choice affects wording only; the same Core mana values are used.
String gearDescriptionForSlot(
  GearSlot slot,
  Object id, {
  required GameLocalizations strings,
  ManaPresentation manaPresentation = ManaPresentation.mana,
}) => switch (slot) {
  GearSlot.mainWeapon || GearSlot.offhandWeapon => weaponDescription(
    id as WeaponId,
    strings: strings,
    manaPresentation: manaPresentation,
  ),
  GearSlot.spellBook => spellBookDescription(
    id as SpellBookId,
    strings: strings,
    manaPresentation: manaPresentation,
  ),
  GearSlot.accessory => accessoryDescription(
    id as AccessoryId,
    strings: strings,
    manaPresentation: manaPresentation,
  ),
};

String gearDisplayNameForSlot(
  GearSlot slot,
  Object id, {
  required GameLocalizations strings,
}) => switch (slot) {
  GearSlot.mainWeapon ||
  GearSlot.offhandWeapon => weaponDisplayName(id as WeaponId, strings: strings),
  GearSlot.spellBook => spellBookDisplayName(
    id as SpellBookId,
    strings: strings,
  ),
  GearSlot.accessory => accessoryDisplayName(
    id as AccessoryId,
    strings: strings,
  ),
};

String damageTypeDisplayName(
  DamageType type, {
  required GameLocalizations strings,
}) => switch (type) {
  DamageType.physical => strings.damagePhysical,
  DamageType.fire => strings.damageFire,
  DamageType.ice => strings.damageIce,
  DamageType.water => strings.damageWater,
  DamageType.thunder => strings.damageThunder,
  DamageType.acid => strings.damageAcid,
  DamageType.poison => strings.damagePoison,
  DamageType.dark => strings.damageDark,
  DamageType.bleed => strings.damageBleed,
  DamageType.earth => strings.damageEarth,
  DamageType.holy => strings.damageHoly,
};

/// Formats fixed-point x100 values for display only. Never use for wire values.
String formatFixed100(int value100, {required GameLocalizations strings}) =>
    NumberFormat.decimalPattern(strings.localeName).format(value100 / 100.0);

List<String> projectileStatusSummaries(
  ProjectileItemDef def, {
  required GameLocalizations strings,
  StatusProfileCatalog statusProfiles = const StatusProfileCatalog(),
}) {
  final lines = <String>[];
  for (final proc in def.procs) {
    if (proc.statusProfileId == StatusProfileId.none) continue;
    final profile = statusProfiles.resolve(
      proc.statusProfileId,
      tuning: proc.statusTuning,
    );
    for (final application in profile.applications) {
      final line = _statusSummary(application, proc, strings);
      if (line != null) lines.add(line);
    }
  }
  return lines;
}

String? _statusSummary(
  StatusApplication application,
  WeaponProc proc,
  GameLocalizations strings,
) {
  final duration = strings.durationSeconds(
    seconds: (application.durationSeconds * 10).round() / 10,
  );
  final chance = proc.chanceBp / 100.0;
  final chanceKind = proc.chanceBp >= 10000 ? 'guaranteed' : 'chance';
  final percent = application.magnitude / 100.0;
  return switch (application.type) {
    StatusEffectType.dot => strings.statusDot(
      damageType: application.dotDamageType == null
          ? strings.damageOverTime
          : damageTypeDisplayName(application.dotDamageType!, strings: strings),
      damagePerSecond: application.magnitude / 100.0,
      duration: duration,
      chance: chance,
      chanceKind: chanceKind,
    ),
    StatusEffectType.slow => strings.statusSlow(
      percent: percent,
      duration: duration,
      chance: chance,
      chanceKind: chanceKind,
    ),
    StatusEffectType.stun => strings.statusStun(
      duration: duration,
      chance: chance,
      chanceKind: chanceKind,
    ),
    StatusEffectType.silence => strings.statusSilence(
      duration: duration,
      chance: chance,
      chanceKind: chanceKind,
    ),
    StatusEffectType.vulnerable => strings.statusVulnerable(
      percent: percent,
      duration: duration,
      chance: chance,
      chanceKind: chanceKind,
    ),
    StatusEffectType.weaken => strings.statusWeaken(
      percent: percent,
      duration: duration,
      chance: chance,
      chanceKind: chanceKind,
    ),
    StatusEffectType.drench => strings.statusDrench(
      percent: percent,
      duration: duration,
      chance: chance,
      chanceKind: chanceKind,
    ),
    StatusEffectType.haste ||
    StatusEffectType.damageReduction ||
    StatusEffectType.resourceOverTime ||
    StatusEffectType.offenseBuff => null,
  };
}

double _silenceSeconds(ProjectileItemDef item) {
  for (final proc in item.procs) {
    final profile = const StatusProfileCatalog().resolve(
      proc.statusProfileId,
      tuning: proc.statusTuning,
    );
    for (final application in profile.applications) {
      if (application.type == StatusEffectType.silence) {
        return application.durationSeconds;
      }
    }
  }
  throw StateError('Silence description requires a matching catalog effect.');
}
