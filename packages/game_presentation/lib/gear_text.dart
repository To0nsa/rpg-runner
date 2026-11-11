import 'items.generated.dart';

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

/// Localized names compiled from the item authoring source.
String weaponDisplayName(WeaponId id, {required GameLocalizations strings}) =>
    authoredItemName('weapon', id.name, strings.localeName)!;

/// Resolves a complete translated description for the character's resource pool.
String weaponDescription(
  WeaponId id, {
  required GameLocalizations strings,
  ManaPresentation manaPresentation = ManaPresentation.mana,
}) => switch (id.name) {
  'plainsteel' => strings.weaponPlainsteelDescription,
  'waspfang' => strings.weaponWaspfangDescription,
  'cinderedge' => strings.weaponCinderedgeDescription,
  'basiliskKiss' => strings.weaponBasiliskKissDescription,
  'frostbrand' => strings.weaponFrostbrandDescription,
  'stormneedle' => strings.weaponStormneedleDescription,
  'nullblade' => strings.weaponNullbladeDescription,
  'sunlitVow' => strings.weaponSunlitVowDescription,
  'roadguard' => strings.weaponRoadguardDescription,
  'thornbark' => strings.weaponThornbarkDescription,
  'cinderWard' => strings.weaponCinderWardDescription,
  'tideguardShell' => strings.weaponTideguardShellDescription,
  'frostlockBuckler' => strings.weaponFrostlockBucklerDescription,
  'ironBastion' => strings.weaponIronBastionDescription,
  'stormAegis' => strings.weaponStormAegisDescription,
  'nullPrism' => strings.weaponNullPrismDescription,
  'warbannerGuard' => strings.weaponWarbannerGuardDescription,
  'oathwallRelic' => strings.weaponOathwallRelicDescription,
  'hunterBlade' => strings.weaponHunterBladeDescription,
  'hunterBombKit' => strings.weaponHunterBombKitDescription,
  'hunterNotchknife' => strings.weaponHunterNotchknifeDescription,
  'hunterHookblade' => strings.weaponHunterHookbladeDescription,
  'hunterCausticEdge' => strings.weaponHunterCausticEdgeDescription,
  'hunterCinderpoint' => strings.weaponHunterCinderpointDescription,
  'hunterSappingBlade' => strings.weaponHunterSappingBladeDescription,
  'hunterPursuitBlade' => strings.weaponHunterPursuitBladeDescription,
  'hunterLastWord' => strings.weaponHunterLastWordDescription,
  'hunterSplinterRig' => strings.weaponHunterSplinterRigDescription,
  'hunterPitchRig' => strings.weaponHunterPitchRigDescription,
  'hunterSnareRig' => strings.weaponHunterSnareRigDescription,
  'hunterEtchingRig' => strings.weaponHunterEtchingRigDescription,
  'hunterSapperHarness' => strings.weaponHunterSapperHarnessDescription,
  'hunterKilnwrapRig' => strings.weaponHunterKilnwrapRigDescription,
  'hunterSealedRig' => strings.weaponHunterSealedRigDescription,
  'hunterStormwrapRig' => strings.weaponHunterStormwrapRigDescription,
  'hunterBacktrailRig' => strings.weaponHunterBacktrailRigDescription,
  _ => weaponDisplayName(id, strings: strings),
};

/// Localized names compiled from the item authoring source.
String projectileDisplayName(
  ProjectileId id, {
  required GameLocalizations strings,
}) =>
    authoredItemName('projectile', id.name, strings.localeName) ??
    _internalProjectileDisplayName(id, strings: strings);

String _internalProjectileDisplayName(
  ProjectileId id, {
  required GameLocalizations strings,
}) => switch (id.name) {
  'unknown' => strings.projectileUnknownName,
  'poisonDart' => strings.projectilePoisonDartName,
  'npcSpear' => strings.projectileNpcSpearName,
  'npcArrow' => strings.projectileNpcArrowName,
  'goddessOrb' => strings.projectileGoddessOrbName,
  'shoggothOrb' => strings.projectileShoggothOrbName,
  'voidClaw' => strings.projectileVoidClawName,
  'hunterBomb' => strings.projectileHunterBombName,
  _ => strings.projectileUnknownName,
};

/// Description parameters read the same item/status catalogs as gameplay.
String projectileDescription(
  ProjectileId id, {
  required GameLocalizations strings,
}) {
  final item = const ProjectileCatalog().tryGet(id);
  if (item == null) return strings.projectileUnknownDescription;
  return switch (id.name) {
    'unknown' => strings.projectileUnknownDescription,
    'iceBolt' => strings.projectileIceBoltDescription,
    'fireBolt' => strings.projectileFireBoltDescription,
    'acidBolt' => strings.projectileAcidBoltDescription,
    'darkBolt' => strings.projectileDarkBoltDescription,
    'earthBolt' => strings.projectileEarthBoltDescription,
    'holyBolt' => strings.projectileHolyBoltDescription(
      seconds: _silenceSeconds(item),
    ),
    'waterBolt' => strings.projectileWaterBoltDescription,
    'thunderBolt' => strings.projectileThunderBoltDescription,
    'poisonDart' => strings.projectilePoisonDartDescription,
    'npcSpear' => strings.projectileNpcSpearDescription,
    'npcArrow' => strings.projectileNpcArrowDescription,
    'goddessOrb' => strings.projectileGoddessOrbDescription,
    'shoggothOrb' => strings.projectileShoggothOrbDescription,
    'voidClaw' => strings.projectileVoidClawDescription,
    'hunterPistol' => strings.projectileHunterPistolDescription,
    'hunterCrossbow' => strings.projectileHunterCrossbowDescription(
      damagePercent: item.damageScaleBp / 100.0,
    ),
    'hunterShotgun' => strings.projectileHunterShotgunDescription(
      damagePercent: item.damageScaleBp / 100.0,
      pellets: item.shotCount,
    ),
    'hunterBomb' => strings.projectileHunterBombDescription,
    'hunterRoadsidePistol' => strings.projectileHunterRoadsidePistolDescription(
      damagePercent: item.damageScaleBp / 100.0,
    ),
    'hunterLongbarrelPistol' =>
      strings.projectileHunterLongbarrelPistolDescription(
        damagePercent: item.damageScaleBp / 100.0,
      ),
    'hunterLongwatchCrossbow' =>
      strings.projectileHunterLongwatchCrossbowDescription,
    'hunterHeavyLimbCrossbow' =>
      strings.projectileHunterHeavyLimbCrossbowDescription(
        damagePercent: item.damageScaleBp / 100.0,
      ),
    'hunterBrushgun' => strings.projectileHunterBrushgunDescription(
      damagePercent: item.damageScaleBp / 100.0,
      pellets: item.shotCount,
    ),
    _ => projectileDisplayName(id, strings: strings),
  };
}

/// Localized names compiled from the item authoring source.
String spellBookDisplayName(
  SpellBookId id, {
  required GameLocalizations strings,
}) => authoredItemName('spellBook', id.name, strings.localeName)!;

/// Resolves a complete translated description for the character's resource pool.
String spellBookDescription(
  SpellBookId id, {
  required GameLocalizations strings,
  ManaPresentation manaPresentation = ManaPresentation.mana,
}) => switch (id.name) {
  'apprenticePrimer' => strings.spellBookApprenticePrimerDescription(
    resource: manaPresentation.name,
  ),
  'bastionCodex' => strings.spellBookBastionCodexDescription(
    resource: manaPresentation.name,
  ),
  'emberGrimoire' => strings.spellBookEmberGrimoireDescription(
    resource: manaPresentation.name,
  ),
  'tideAlmanac' => strings.spellBookTideAlmanacDescription(
    resource: manaPresentation.name,
  ),
  'hexboundLexicon' => strings.spellBookHexboundLexiconDescription(
    resource: manaPresentation.name,
  ),
  'galeFolio' => strings.spellBookGaleFolioDescription(
    resource: manaPresentation.name,
  ),
  'nullTestament' => strings.spellBookNullTestamentDescription(
    resource: manaPresentation.name,
  ),
  'crownOfFocus' => strings.spellBookCrownOfFocusDescription(
    resource: manaPresentation.name,
  ),
  'hunterFieldKit' => strings.spellBookHunterFieldKitDescription,
  'hunterLongtrailPack' => strings.spellBookHunterLongtrailPackDescription,
  'hunterMarksmanRoll' => strings.spellBookHunterMarksmanRollDescription,
  'hunterQuickAccessSatchel' =>
    strings.spellBookHunterQuickAccessSatchelDescription,
  'hunterReserveBandolier' =>
    strings.spellBookHunterReserveBandolierDescription,
  'hunterTrackerPouch' => strings.spellBookHunterTrackerPouchDescription,
  'hunterSurveyorCase' => strings.spellBookHunterSurveyorCaseDescription,
  'hunterQuarryKit' => strings.spellBookHunterQuarryKitDescription,
  _ => spellBookDisplayName(id, strings: strings),
};

/// Localized names compiled from the item authoring source.
String accessoryDisplayName(
  AccessoryId id, {
  required GameLocalizations strings,
}) => authoredItemName('accessory', id.name, strings.localeName)!;

/// Resolves a complete translated description for the character's resource pool.
String accessoryDescription(
  AccessoryId id, {
  required GameLocalizations strings,
  ManaPresentation manaPresentation = ManaPresentation.mana,
}) => switch (id.name) {
  'speedBoots' => strings.accessorySpeedBootsDescription(
    resource: manaPresentation.name,
  ),
  'goldenRing' => strings.accessoryGoldenRingDescription,
  'teethNecklace' => strings.accessoryTeethNecklaceDescription,
  'diamondRing' => strings.accessoryDiamondRingDescription(
    resource: manaPresentation.name,
  ),
  'ironBoots' => strings.accessoryIronBootsDescription,
  'oathBeads' => strings.accessoryOathBeadsDescription(
    resource: manaPresentation.name,
  ),
  'resilienceCape' => strings.accessoryResilienceCapeDescription,
  'strengthBelt' => strings.accessoryStrengthBeltDescription,
  _ => accessoryDisplayName(id, strings: strings),
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
