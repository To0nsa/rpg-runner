// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'game_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class GameLocalizationsEn extends GameLocalizations {
  GameLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get weaponPlainsteelDescription =>
      'Baseline one-handed sword with consistent output.';

  @override
  String get weaponWaspfangDescription =>
      'Bleed pressure sword with lower upfront power.';

  @override
  String get weaponCinderedgeDescription =>
      'Crit-focused blade that ignites on critical strikes.';

  @override
  String get weaponBasiliskKissDescription =>
      'Anti-tank sword that trades burst for acid vulnerability pressure.';

  @override
  String get weaponFrostbrandDescription =>
      'Control sword that applies slows for safer tempo.';

  @override
  String get weaponStormneedleDescription =>
      'Sustained crit/stamina sword with regen and a health tradeoff.';

  @override
  String get weaponNullbladeDescription =>
      'Anti-caster sword that can silence on hit.';

  @override
  String get weaponSunlitVowDescription =>
      'Kill-chain sword that can grant Focus and boosts sustained pressure.';

  @override
  String get weaponRoadguardDescription =>
      'Baseline all-rounder shield with dependable defense.';

  @override
  String get weaponThornbarkDescription =>
      'Retaliation shield that bleeds attackers on damage.';

  @override
  String get weaponCinderWardDescription =>
      'Fire-counter shield with defense and a crit-scaling dump.';

  @override
  String get weaponTideguardShellDescription =>
      'Water-stabilizer shield with stamina support and power tax.';

  @override
  String get weaponFrostlockBucklerDescription =>
      'Cold matchup shield with balanced defense and stamina.';

  @override
  String get weaponIronBastionDescription =>
      'Heavy face-tank shield with the strongest soak and lower mobility.';

  @override
  String get weaponStormAegisDescription =>
      'Thunder counterpick shield with regen and a crit dump.';

  @override
  String get weaponNullPrismDescription =>
      'Dual dark/holy resist shield that trades mobility for coverage.';

  @override
  String get weaponWarbannerGuardDescription =>
      'Stamina-forward frontline shield with a heavy crit dump.';

  @override
  String get weaponOathwallRelicDescription =>
      'Clutch survival shield with low-health haste and permanent offense tax.';

  @override
  String get weaponHunterBladeDescription =>
      'Reliable mixed combat with a small defense tradeoff.';

  @override
  String get weaponHunterBombKitDescription =>
      'A protective bomb rig that trades movement speed for steadiness.';

  @override
  String get weaponHunterNotchknifeDescription =>
      'Bleeding cuts reward disengaging, at the cost of maximum health.';

  @override
  String get weaponHunterHookbladeDescription =>
      'Slowing cuts create room for a shot or bomb, with lower defense.';

  @override
  String get weaponHunterCausticEdgeDescription =>
      'Melee openings expose a target to follow-up damage, with lower health.';

  @override
  String get weaponHunterCinderpointDescription =>
      'Critical cuts ignite enemies, at the cost of Supplies regeneration.';

  @override
  String get weaponHunterSappingBladeDescription =>
      'Cuts can weaken enemy attacks, but maximum health is lower.';

  @override
  String get weaponHunterPursuitBladeDescription =>
      'Melee kills can grant a short burst of speed, with lower defense.';

  @override
  String get weaponHunterLastWordDescription =>
      'Strong direct offense and stamina, with less health for mistakes.';

  @override
  String get weaponHunterSplinterRigDescription =>
      'Critical blasts cause bleeding, at the cost of global power.';

  @override
  String get weaponHunterPitchRigDescription =>
      'Critical blasts ignite survivors, with lower critical chance.';

  @override
  String get weaponHunterSnareRigDescription =>
      'Blasts can slow pursuers, at the cost of global power.';

  @override
  String get weaponHunterEtchingRigDescription =>
      'Blasts can expose survivors to follow-up damage, with lower critical chance.';

  @override
  String get weaponHunterSapperHarnessDescription =>
      'Physical protection and stamina recovery, with substantially slower movement.';

  @override
  String get weaponHunterKilnwrapRigDescription =>
      'Preparation for fire-heavy encounters, with lower critical chance.';

  @override
  String get weaponHunterSealedRigDescription =>
      'Acid and water protection with stamina reserves, at the cost of power.';

  @override
  String get weaponHunterStormwrapRigDescription =>
      'Thunder protection and stamina recovery, with lower critical chance.';

  @override
  String get weaponHunterBacktrailRigDescription =>
      'Low-health haste creates an escape opportunity, at a permanent power cost.';

  @override
  String get projectileUnknownName => 'Unknown';

  @override
  String get projectileUnknownDescription => 'No description available yet.';

  @override
  String get projectileIceBoltDescription =>
      'Spell projectile that chills on hit.';

  @override
  String get projectileFireBoltDescription =>
      'Spell projectile that burns on hit.';

  @override
  String get projectileAcidBoltDescription =>
      'Spell projectile that corrodes and increases damage taken.';

  @override
  String get projectileDarkBoltDescription =>
      'Spell projectile that weakens enemy outgoing damage on hit.';

  @override
  String get projectileEarthBoltDescription =>
      'Spell projectile that stuns enemies on hit.';

  @override
  String projectileHolyBoltDescription({required num seconds}) {
    final intl.NumberFormat secondsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String secondsString = secondsNumberFormat.format(seconds);

    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$secondsString seconds',
      one: 'one second',
    );
    return 'Spell projectile that silences enemy casts for $_temp0.';
  }

  @override
  String get projectileWaterBoltDescription =>
      'Spell projectile that drenches and slows attack/cast speed.';

  @override
  String get projectileThunderBoltDescription =>
      'Spell projectile with thunder damage.';

  @override
  String get projectilePoisonDartName => 'Poison Dart';

  @override
  String get projectilePoisonDartDescription => 'No description available yet.';

  @override
  String get projectileNpcSpearName => 'Npc Spear';

  @override
  String get projectileNpcSpearDescription => 'No description available yet.';

  @override
  String get projectileNpcArrowName => 'Npc Arrow';

  @override
  String get projectileNpcArrowDescription => 'No description available yet.';

  @override
  String get projectileGoddessOrbName => 'Goddess Orb';

  @override
  String get projectileGoddessOrbDescription => 'No description available yet.';

  @override
  String get projectileShoggothOrbName => 'Shoggoth Orb';

  @override
  String get projectileShoggothOrbDescription =>
      'No description available yet.';

  @override
  String get projectileVoidClawName => 'Void Claw';

  @override
  String get projectileVoidClawDescription => 'No description available yet.';

  @override
  String get projectileHunterPistolDescription =>
      'Fast bullets with balanced range. Uses regenerating Supplies.';

  @override
  String projectileHunterCrossbowDescription({required double damagePercent}) {
    final intl.NumberFormat damagePercentNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String damagePercentString = damagePercentNumberFormat.format(
      damagePercent,
    );

    return 'Long-range bolts dealing $damagePercentString% of base damage. Uses regenerating Supplies.';
  }

  @override
  String projectileHunterShotgunDescription({
    required double damagePercent,
    required int pellets,
  }) {
    final intl.NumberFormat damagePercentNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String damagePercentString = damagePercentNumberFormat.format(
      damagePercent,
    );
    final intl.NumberFormat pelletsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String pelletsString = pelletsNumberFormat.format(pellets);

    String _temp0 = intl.Intl.pluralLogic(
      pellets,
      locale: localeName,
      other: 'at least $pelletsString pellets',
      one: 'at least one pellet',
    );
    return 'Short-range shells divided into $_temp0, dealing $damagePercentString% of total base damage. Uses regenerating Supplies.';
  }

  @override
  String get projectileHunterBombName => 'Bomb';

  @override
  String get projectileHunterBombDescription =>
      'A timed blast blocked by solid terrain.';

  @override
  String projectileHunterRoadsidePistolDescription({
    required double damagePercent,
  }) {
    final intl.NumberFormat damagePercentNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String damagePercentString = damagePercentNumberFormat.format(
      damagePercent,
    );

    return 'Fast close-range bullets dealing $damagePercentString% of base damage, with shorter reach.';
  }

  @override
  String projectileHunterLongbarrelPistolDescription({
    required double damagePercent,
  }) {
    final intl.NumberFormat damagePercentNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String damagePercentString = damagePercentNumberFormat.format(
      damagePercent,
    );

    return 'Fast, long-reaching bullets dealing $damagePercentString% of base damage.';
  }

  @override
  String get projectileHunterLongwatchCrossbowDescription =>
      'Long-reaching, faster bolts with less damage than the standard crossbow.';

  @override
  String projectileHunterHeavyLimbCrossbowDescription({
    required double damagePercent,
  }) {
    final intl.NumberFormat damagePercentNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String damagePercentString = damagePercentNumberFormat.format(
      damagePercent,
    );

    return 'Heavy bolts dealing $damagePercentString% of base damage, with slower flight and shorter reach.';
  }

  @override
  String projectileHunterBrushgunDescription({
    required double damagePercent,
    required int pellets,
  }) {
    final intl.NumberFormat damagePercentNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String damagePercentString = damagePercentNumberFormat.format(
      damagePercent,
    );
    final intl.NumberFormat pelletsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String pelletsString = pelletsNumberFormat.format(pellets);

    String _temp0 = intl.Intl.pluralLogic(
      pellets,
      locale: localeName,
      other: '$pelletsString pellets',
      one: 'one pellet',
    );
    return 'A wide spread of $_temp0 deals $damagePercentString% of total base damage and rewards close placement.';
  }

  @override
  String spellBookApprenticePrimerDescription({required String resource}) {
    String _temp0 = intl.Intl.selectLogic(resource, {
      'supplies': 'Balanced Supplies reserves, regeneration and critical chance, with less stamina.',
      'other': 'Balanced mana reserves, regeneration and critical chance, with less stamina.',
    });
    return '$_temp0';
  }

  @override
  String spellBookBastionCodexDescription({required String resource}) {
    String _temp0 = intl.Intl.selectLogic(resource, {
      'supplies': 'Large Supplies reserves, regeneration and faster cooldowns, with slower health recovery.',
      'other': 'Large mana reserves, regeneration and faster cooldowns, with slower health recovery.',
    });
    return '$_temp0';
  }

  @override
  String spellBookEmberGrimoireDescription({required String resource}) {
    String _temp0 = intl.Intl.selectLogic(resource, {
      'supplies': 'Supplies, critical chance and faster cooldowns, with slower stamina recovery.',
      'other': 'Mana, critical chance and faster cooldowns, with slower stamina recovery.',
    });
    return '$_temp0';
  }

  @override
  String spellBookTideAlmanacDescription({required String resource}) {
    String _temp0 = intl.Intl.selectLogic(resource, {
      'supplies': 'Large Supplies reserves, regeneration and faster cooldowns, with substantially less stamina.',
      'other': 'Large mana reserves, regeneration and faster cooldowns, with substantially less stamina.',
    });
    return '$_temp0';
  }

  @override
  String spellBookHexboundLexiconDescription({required String resource}) {
    String _temp0 = intl.Intl.selectLogic(resource, {
      'supplies': 'Supplies, regeneration and critical chance, with slower health recovery.',
      'other': 'Mana, regeneration and critical chance, with slower health recovery.',
    });
    return '$_temp0';
  }

  @override
  String spellBookGaleFolioDescription({required String resource}) {
    String _temp0 = intl.Intl.selectLogic(resource, {
      'supplies': 'Large Supplies reserves, critical chance and faster cooldowns, with less stamina.',
      'other': 'Large mana reserves, critical chance and faster cooldowns, with less stamina.',
    });
    return '$_temp0';
  }

  @override
  String spellBookNullTestamentDescription({required String resource}) {
    String _temp0 = intl.Intl.selectLogic(resource, {
      'supplies': 'Supplies reserves, regeneration and critical chance, with slower stamina recovery.',
      'other': 'Mana reserves, regeneration and critical chance, with slower stamina recovery.',
    });
    return '$_temp0';
  }

  @override
  String spellBookCrownOfFocusDescription({required String resource}) {
    String _temp0 = intl.Intl.selectLogic(resource, {
      'supplies': 'Large Supplies reserves, critical chance and faster cooldowns, with substantially less stamina.',
      'other': 'Large mana reserves, critical chance and faster cooldowns, with substantially less stamina.',
    });
    return '$_temp0';
  }

  @override
  String get spellBookHunterFieldKitDescription =>
      'Balanced Supplies and critical chance, with a smaller stamina reserve.';

  @override
  String get spellBookHunterLongtrailPackDescription =>
      'Sustained Supplies and faster recovery between actions, with slower health regeneration.';

  @override
  String get spellBookHunterMarksmanRollDescription =>
      'Critical-shot preparation and faster cooldowns, with slower stamina recovery.';

  @override
  String get spellBookHunterQuickAccessSatchelDescription =>
      'Frequent short exchanges, with less stamina and no extra Supplies capacity.';

  @override
  String get spellBookHunterReserveBandolierDescription =>
      'A large opening reserve and critical chance, with substantially less stamina.';

  @override
  String get spellBookHunterTrackerPouchDescription =>
      'Offensive pursuit that preserves stamina, at the cost of health recovery.';

  @override
  String get spellBookHunterSurveyorCaseDescription =>
      'A large Supplies reserve and ready utility, with slower stamina recovery.';

  @override
  String get spellBookHunterQuarryKitDescription =>
      'Critical offensive windows and faster cooldowns, with little stamina headroom.';

  @override
  String accessorySpeedBootsDescription({required String resource}) {
    String _temp0 = intl.Intl.selectLogic(resource, {
      'supplies': 'Tempo accessory with movement, stamina regen, and cooldown pacing at heavy Supplies tax.',
      'other': 'Tempo accessory with movement, stamina regen, and cooldown pacing at heavy mana tax.',
    });
    return '$_temp0';
  }

  @override
  String get accessoryGoldenRingDescription =>
      'Clutch sustain ring with health and emergency low-health healing.';

  @override
  String get accessoryTeethNecklaceDescription =>
      'Stamina necklace with low-health stamina restore, traded against max health.';

  @override
  String accessoryDiamondRingDescription({required String resource}) {
    String _temp0 = intl.Intl.selectLogic(resource, {
      'supplies': 'Supplies ring with low-health Supplies restore, traded against max stamina.',
      'other':
          'Mana ring with low-health mana restore, traded against max stamina.',
    });
    return '$_temp0';
  }

  @override
  String get accessoryIronBootsDescription =>
      'Defensive boots with physical resistance that tax global power.';

  @override
  String accessoryOathBeadsDescription({required String resource}) {
    String _temp0 = intl.Intl.selectLogic(resource, {
      'supplies': 'Caster-tempo beads with cooldown, Supplies regen, and power at a defense tax.',
      'other': 'Caster-tempo beads with cooldown, mana regen, and power at a defense tax.',
    });
    return '$_temp0';
  }

  @override
  String get accessoryResilienceCapeDescription =>
      'Elemental counterpick with fire and dark resistance plus defense.';

  @override
  String get accessoryStrengthBeltDescription =>
      'Burst belt with power, crit, and stamina at slower cooldown recovery.';

  @override
  String get abilityUnocoFireBoltCastName => 'Fire Bolt Cast';

  @override
  String get abilityUnocoStrikeName => 'Strike';

  @override
  String get abilityDerfFireExplosionName => 'Fire Explosion';

  @override
  String get abilityDerfTentacleStrikeName => 'Tentacle Strike';

  @override
  String get abilityBringerScytheSweepName => 'Scythe Sweep';

  @override
  String get abilityBringerDeathPillarName => 'Death Pillar';

  @override
  String get abilityGoddessRepositionOutName => 'Reposition Out';

  @override
  String get abilityGoddessRepositionInName => 'Reposition In';

  @override
  String get abilityGoddessDodgeName => 'Dodge';

  @override
  String get abilityGoddessClawComboName => 'Claw Combo';

  @override
  String get abilityGoddessOrbName => 'Orb';

  @override
  String get abilityGoddessEruptionName => 'Eruption';

  @override
  String get abilityShoggothTentacleSweepName => 'Tentacle Sweep';

  @override
  String get abilityShoggothSpinningChargeName => 'Spinning Charge';

  @override
  String get abilityShoggothOrbName => 'Orb';

  @override
  String get abilityShoggothSummonName => 'Summon';

  @override
  String get abilityShoggothSummonSwarmName => 'Summon Swarm';

  @override
  String get abilityShoggothSummonHordeName => 'Summon Horde';

  @override
  String get abilityShoggothReturnChargeName => 'Return Charge';

  @override
  String get abilityShoggothTeleportName => 'Teleport';

  @override
  String get abilityVoidcallerVerticalBeamName => 'Vertical Beam';

  @override
  String get abilityVoidcallerDiagonalBeamName => 'Diagonal Beam';

  @override
  String get abilityVoidcallerClawName => 'Claw';

  @override
  String get abilityVoidcallerSummonName => 'Summon';

  @override
  String get abilityShoggothMinionBiteName => 'Bite';

  @override
  String get abilityVoidTentacleLashName => 'Lash';

  @override
  String get abilityGrojibStrikeName => 'Strike';

  @override
  String get abilityGrojibStrike2Name => 'Second Strike';

  @override
  String get abilityHashashStrikeName => 'Strike';

  @override
  String get abilityHashashTeleportOutName => 'Teleport Out';

  @override
  String get abilityHashashAmbushName => 'Ambush';

  @override
  String get abilityEloiseBloodletterSlashName => 'Sword Slash';

  @override
  String get abilityEloiseBloodletterCleaveName => 'Bloodletter Cleave';

  @override
  String get abilityEloiseSeekerSlashName => 'Seeker Slash';

  @override
  String get abilityEloiseAegisRiposteName => 'Aegis Riposte';

  @override
  String get abilityEloiseShieldBlockName => 'Shield block';

  @override
  String get abilityEloiseSnapShotName => 'Snap Shot';

  @override
  String get abilityEloiseQuickShotName => 'Quick Shot';

  @override
  String get abilityEloiseSkewerShotName => 'Skewer Shot';

  @override
  String get abilityEloiseOverchargeShotName => 'Overcharge Bolt';

  @override
  String get abilityEloiseArcaneHasteName => 'Arcane Haste';

  @override
  String get abilityEloiseFocusName => 'Focus';

  @override
  String get abilityEloiseArcaneWardName => 'Arcane Ward';

  @override
  String get abilityEloiseCleanseName => 'Cleanse';

  @override
  String get abilityEloiseVitalSurgeName => 'Vital Surge';

  @override
  String get abilityEloiseManaInfusionName => 'Mana Infusion';

  @override
  String get abilityEloiseSecondWindName => 'Second Wind';

  @override
  String get abilityEloiseJumpName => 'Jump';

  @override
  String get abilityEloiseDoubleJumpName => 'Double Jump';

  @override
  String get abilityEloiseDashName => 'Dash';

  @override
  String get abilityEloiseDoubleDashName => 'Double Dash';

  @override
  String get abilityEloiseRollName => 'Concussive Roll';

  @override
  String get abilityBountyHunterQuickCutName => 'Quick Cut';

  @override
  String get abilityBountyHunterTwinCutName => 'Twin Cut';

  @override
  String get abilityBountyHunterLungeSlashName => 'Lunge Slash';

  @override
  String get abilityBountyHunterBlastBombName => 'Blast Bomb';

  @override
  String get abilityBountyHunterShrapnelBombName => 'Shrapnel Bomb';

  @override
  String get abilityBountyHunterFireBombName => 'Fire Bomb';

  @override
  String get abilityBountyHunterConcussionBombName => 'Concussion Bomb';

  @override
  String get abilityBountyHunterSnapShotName => 'Snap Shot';

  @override
  String get abilityBountyHunterQuickShotName => 'Quick Shot';

  @override
  String get abilityBountyHunterPiercingShotName => 'Piercing Shot';

  @override
  String get abilityBountyHunterScatterShotName => 'Scatter Shot';

  @override
  String get abilityBountyHunterChargedShotName => 'Charged Shot';

  @override
  String get abilityBountyHunterDashName => 'Dash';

  @override
  String get abilityBountyHunterDoubleDashName => 'Double Dash';

  @override
  String get abilityBountyHunterBlinkDashName => 'Blink Dash';

  @override
  String get abilityBountyHunterJumpName => 'Jump';

  @override
  String get abilityBountyHunterDoubleJumpName => 'Double Jump';

  @override
  String get abilityBountyHunterHuntersFocusName => 'Hunter\'s Focus';

  @override
  String get abilityBountyHunterMarkQuarryName => 'Mark Quarry';

  @override
  String get abilityBountyHunterForcedMarchName => 'Forced March';

  @override
  String get abilityBountyHunterFieldDressingName => 'Field Dressing';

  @override
  String get abilityBountyHunterAntidoteName => 'Antidote';

  @override
  String get abilityBountyHunterSecondWindName => 'Second Wind';

  @override
  String get abilityBountyHunterPrepareChargesName => 'Prepare Charges';

  @override
  String get abilityNpcWarriorSlashName => 'Slash';

  @override
  String get abilityNpcHuntressThrowSpearName => 'Throw Spear';

  @override
  String get abilityNpcHuntressStabName => 'Stab';

  @override
  String get abilityNpcHuntressSlashName => 'Slash';

  @override
  String get abilityNpcHuntress2ShootArrowName => 'Shoot Arrow';

  @override
  String get enemyUnocoDemonName => 'Unoco Demon';

  @override
  String get enemyGrojibName => 'Grojib';

  @override
  String get enemyHashashName => 'Hashash';

  @override
  String get enemyDerfName => 'Derf';

  @override
  String get enemyBringerOfDeathName => 'Bringer of Death';

  @override
  String get enemyVoidbornGoddessName => 'Voidborn Goddess';

  @override
  String get enemyShoggothName => 'Shoggoth';

  @override
  String get enemyVoidcallerName => 'Voidcaller';

  @override
  String get enemyShoggothMinionName => 'Shoggoth Minion';

  @override
  String get enemyVoidTentacleName => 'Void Tentacle';

  @override
  String get unknownAbility => 'Unknown ability';

  @override
  String get unknownItem => 'Unknown item';

  @override
  String get damagePhysical => 'Physical';

  @override
  String get damageFire => 'Fire';

  @override
  String get damageIce => 'Ice';

  @override
  String get damageWater => 'Water';

  @override
  String get damageThunder => 'Thunder';

  @override
  String get damageAcid => 'Acid';

  @override
  String get damagePoison => 'Poison';

  @override
  String get damageDark => 'Dark';

  @override
  String get damageBleed => 'Bleed';

  @override
  String get damageEarth => 'Earth';

  @override
  String get damageHoly => 'Holy';

  @override
  String get resourceHealth => 'Health';

  @override
  String get resourceMana => 'Mana';

  @override
  String get resourceSupplies => 'Supplies';

  @override
  String get resourceStamina => 'Stamina';

  @override
  String get damageOverTime => 'DoT';

  @override
  String durationSeconds({required num seconds}) {
    final intl.NumberFormat secondsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String secondsString = secondsNumberFormat.format(seconds);

    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$secondsString seconds',
      one: '1 second',
    );
    return '$_temp0';
  }

  @override
  String statusDot({
    required String duration,
    required num chance,
    required String damageType,
    required num damagePerSecond,
    required String chanceKind,
  }) {
    final intl.NumberFormat chanceNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String chanceString = chanceNumberFormat.format(chance);
    final intl.NumberFormat damagePerSecondNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String damagePerSecondString = damagePerSecondNumberFormat.format(
      damagePerSecond,
    );

    String _temp0 = intl.Intl.selectLogic(chanceKind, {
      'guaranteed':
          '$damageType: $damagePerSecondString damage per second for $duration',
      'other':
          '$damageType: $damagePerSecondString damage per second for $duration ($chanceString% chance)',
    });
    return '$_temp0';
  }

  @override
  String statusSlow({
    required String duration,
    required num chance,
    required num percent,
    required String chanceKind,
  }) {
    final intl.NumberFormat chanceNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String chanceString = chanceNumberFormat.format(chance);
    final intl.NumberFormat percentNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String percentString = percentNumberFormat.format(percent);

    String _temp0 = intl.Intl.selectLogic(chanceKind, {
      'guaranteed': 'Slow: -$percentString% speed for $duration',
      'other':
          'Slow: -$percentString% speed for $duration ($chanceString% chance)',
    });
    return '$_temp0';
  }

  @override
  String statusStun({
    required String duration,
    required num chance,
    required String chanceKind,
  }) {
    final intl.NumberFormat chanceNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String chanceString = chanceNumberFormat.format(chance);

    String _temp0 = intl.Intl.selectLogic(chanceKind, {
      'guaranteed': 'Stun: $duration',
      'other': 'Stun: $duration ($chanceString% chance)',
    });
    return '$_temp0';
  }

  @override
  String statusSilence({
    required String duration,
    required num chance,
    required String chanceKind,
  }) {
    final intl.NumberFormat chanceNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String chanceString = chanceNumberFormat.format(chance);

    String _temp0 = intl.Intl.selectLogic(chanceKind, {
      'guaranteed': 'Silence: $duration',
      'other': 'Silence: $duration ($chanceString% chance)',
    });
    return '$_temp0';
  }

  @override
  String statusVulnerable({
    required String duration,
    required num chance,
    required num percent,
    required String chanceKind,
  }) {
    final intl.NumberFormat chanceNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String chanceString = chanceNumberFormat.format(chance);
    final intl.NumberFormat percentNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String percentString = percentNumberFormat.format(percent);

    String _temp0 = intl.Intl.selectLogic(chanceKind, {
      'guaranteed': 'Vulnerable: +$percentString% damage taken for $duration',
      'other':
          'Vulnerable: +$percentString% damage taken for $duration ($chanceString% chance)',
    });
    return '$_temp0';
  }

  @override
  String statusWeaken({
    required String duration,
    required num chance,
    required num percent,
    required String chanceKind,
  }) {
    final intl.NumberFormat chanceNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String chanceString = chanceNumberFormat.format(chance);
    final intl.NumberFormat percentNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String percentString = percentNumberFormat.format(percent);

    String _temp0 = intl.Intl.selectLogic(chanceKind, {
      'guaranteed': 'Weaken: -$percentString% outgoing damage for $duration',
      'other':
          'Weaken: -$percentString% outgoing damage for $duration ($chanceString% chance)',
    });
    return '$_temp0';
  }

  @override
  String statusDrench({
    required String duration,
    required num chance,
    required num percent,
    required String chanceKind,
  }) {
    final intl.NumberFormat chanceNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String chanceString = chanceNumberFormat.format(chance);
    final intl.NumberFormat percentNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String percentString = percentNumberFormat.format(percent);

    String _temp0 = intl.Intl.selectLogic(chanceKind, {
      'guaranteed': 'Drench: -$percentString% attack/cast speed for $duration',
      'other':
          'Drench: -$percentString% attack/cast speed for $duration ($chanceString% chance)',
    });
    return '$_temp0';
  }

  @override
  String get characterEloiseName => 'Éloïse';

  @override
  String get characterWillowName => 'Willow';

  @override
  String giftCharacterLabel({required String item, required String character}) {
    return '$item · $character';
  }

  @override
  String get statHealth => 'Health';

  @override
  String statMana({required String resource}) {
    String _temp0 = intl.Intl.selectLogic(resource, {
      'supplies': 'Supplies',
      'other': 'Mana',
    });
    return '$_temp0';
  }

  @override
  String get statStamina => 'Stamina';

  @override
  String get statHealthRegen => 'Health Regen';

  @override
  String statManaRegen({required String resource}) {
    String _temp0 = intl.Intl.selectLogic(resource, {
      'supplies': 'Supplies Regen',
      'other': 'Mana Regen',
    });
    return '$_temp0';
  }

  @override
  String get statStaminaRegen => 'Stamina Regen';

  @override
  String get statDefense => 'Defense';

  @override
  String get statPower => 'Power';

  @override
  String get statMoveSpeed => 'Move Speed';

  @override
  String get statCooldownReduction => 'Cooldown Reduction';

  @override
  String get statCritChance => 'Crit Chance';

  @override
  String get statPhysicalResistance => 'Physical Resist';

  @override
  String get statFireResistance => 'Fire Resist';

  @override
  String get statIceResistance => 'Ice Resist';

  @override
  String get statWaterResistance => 'Water Resist';

  @override
  String get statThunderResistance => 'Thunder Resist';

  @override
  String get statAcidResistance => 'Acid Resist';

  @override
  String get statDarkResistance => 'Dark Resist';

  @override
  String get statBleedResistance => 'Bleed Resist';

  @override
  String get statEarthResistance => 'Earth Resist';

  @override
  String get statHolyResistance => 'Holy Resist';

  @override
  String get effectBleed => 'Bleed';

  @override
  String get effectBurn => 'Burn';

  @override
  String get resourceGeneric => 'Resource';
}
