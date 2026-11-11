/// Existing canonical artwork choices, independent of authored item membership.
/// Shared by source validation and the item editor; adding an item never adds art.
enum CanonicalWeaponIcon {
  plainsteel,
  waspfang,
  cinderedge,
  basiliskKiss,
  frostbrand,
  stormneedle,
  nullblade,
  sunlitVow,
  roadguard,
  thornbark,
  cinderWard,
  tideguardShell,
  frostlockBuckler,
  ironBastion,
  stormAegis,
  nullPrism,
  warbannerGuard,
  oathwallRelic,
  hunterBlade,
  hunterBombKit,
  hunterNotchknife,
  hunterHookblade,
  hunterCausticEdge,
  hunterCinderpoint,
  hunterSappingBlade,
  hunterPursuitBlade,
  hunterLastWord,
  hunterSplinterRig,
  hunterPitchRig,
  hunterSnareRig,
  hunterEtchingRig,
  hunterSapperHarness,
  hunterKilnwrapRig,
  hunterSealedRig,
  hunterStormwrapRig,
  hunterBacktrailRig,
}

enum CanonicalAccessoryIcon {
  speedBoots,
  goldenRing,
  teethNecklace,
  diamondRing,
  ironBoots,
  oathBeads,
  resilienceCape,
  strengthBelt,
}

enum CanonicalSpellBookIcon {
  apprenticePrimer,
  bastionCodex,
  emberGrimoire,
  tideAlmanac,
  hexboundLexicon,
  galeFolio,
  nullTestament,
  crownOfFocus,
  hunterFieldKit,
  hunterLongtrailPack,
  hunterMarksmanRoll,
  hunterQuickAccessSatchel,
  hunterReserveBandolier,
  hunterTrackerPouch,
  hunterSurveyorCase,
  hunterQuarryKit,
}

enum CanonicalProjectileIcon {
  iceBolt,
  fireBolt,
  acidBolt,
  darkBolt,
  earthBolt,
  holyBolt,
  waterBolt,
  thunderBolt,
  hunterPistol,
  hunterCrossbow,
  hunterShotgun,
  hunterRoadsidePistol,
  hunterLongbarrelPistol,
  hunterLongwatchCrossbow,
  hunterHeavyLimbCrossbow,
  hunterBrushgun,
}

final canonicalItemIconChoices = <String, List<String>>{
  'weapon': CanonicalWeaponIcon.values
      .map((v) => v.name)
      .toList(growable: false),
  'accessory': CanonicalAccessoryIcon.values
      .map((v) => v.name)
      .toList(growable: false),
  'spellBook': CanonicalSpellBookIcon.values
      .map((v) => v.name)
      .toList(growable: false),
  'projectile': CanonicalProjectileIcon.values
      .map((v) => v.name)
      .toList(growable: false),
};
