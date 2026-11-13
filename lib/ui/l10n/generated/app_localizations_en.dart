// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get tutorialNext => 'Next';

  @override
  String tutorialStepProgress({required int step, required int total}) {
    return 'Step $step/$total';
  }

  @override
  String get characterTrainingTab => 'Training';

  @override
  String get characterSelected => 'Selected';

  @override
  String characterSelect({required String name}) {
    return 'Select $name';
  }

  @override
  String get characterActiveBuild => 'Active build';

  @override
  String get characterUseBuild => 'Use this build';

  @override
  String characterSelectBuildSemantics({
    required String build,
    required String character,
  }) {
    return 'Use $build with $character';
  }

  @override
  String characterEditBuildSemantics({
    required String build,
    required String character,
  }) {
    return 'Edit $build for $character';
  }

  @override
  String characterBuildUnlockLevel({required int level}) {
    return 'Unlocks at level $level';
  }

  @override
  String get characterNextRun => 'Selected for next run';

  @override
  String characterBuildSummary({
    required String character,
    required String build,
  }) {
    return '$character · $build';
  }

  @override
  String get characterRenameBuild => 'Rename';

  @override
  String get characterBuildSaved => 'Saved';

  @override
  String get characterBuildSaveFailed =>
      'Could not save your changes. Please retry.';

  @override
  String get appTitle => 'Lothringen: The Long Run';

  @override
  String get languageName => 'English';

  @override
  String get languageLabel => 'Language';

  @override
  String get languageSaveFailed =>
      'Could not save the language. Please try again.';

  @override
  String get optionsTitle => 'Options';

  @override
  String get optionsSettingsTab => 'SETTINGS';

  @override
  String get optionsControlsTab => 'CONTROLS';

  @override
  String get movementTitle => 'Movement';

  @override
  String get movementArrows => 'Arrows';

  @override
  String get movementFloatingJoystick => 'Floating joystick';

  @override
  String get movementFixedJoystick => 'Fixed joystick';

  @override
  String get movementHelp =>
      'Choose how to move backward and forward. All controls use the same movement speed.';

  @override
  String get movementArrowsHelp => 'Hold an arrow to move in that direction.';

  @override
  String get movementFloatingHelp =>
      'The joystick follows your touch within the left third of the screen.';

  @override
  String get movementFixedHelp =>
      'The joystick stays in the lower-left corner. Drag its thumb left or right to move.';

  @override
  String get controlsSaveFailed => 'Could not save controls. Please try again.';

  @override
  String get developerModeTitle => 'Developer mode';

  @override
  String get developerModeHelp =>
      'Local profile with all equipment and abilities. Practice and campaign play; no account rewards.';

  @override
  String get developerPracticeHelp =>
      'Developer Practice: local play with all equipment and abilities. Account features are unavailable in this build.';

  @override
  String get developerModeFailed =>
      'Could not open Developer mode. Please try again.';

  @override
  String get accountLoadFailed =>
      'Could not load your account. Check your connection and try again.';

  @override
  String get privacyPolicy => 'Privacy policy';

  @override
  String get contactSupport => 'Contact support';

  @override
  String openLinkFailed({required String url}) {
    return 'Could not open $url. You can open it manually.';
  }

  @override
  String get rewardsCorrected =>
      'This run’s rewards could not be confirmed. Your totals have been updated.';

  @override
  String get desktopStartHint => 'Click or press Enter to start';

  @override
  String get touchStartHint => 'Tap to start';

  @override
  String get survivalGoal => 'Survive as long as possible';

  @override
  String get exitRunQuestion => 'Want to exit?';

  @override
  String get commonResume => 'Resume';

  @override
  String get commonExit => 'Exit';

  @override
  String get terrainPreparing => 'Preparing the path…';

  @override
  String get terrainFailed => 'Unable to prepare the path';

  @override
  String get terrainRetryHelp => 'Your run is held here. Retry to continue.';

  @override
  String get commonRetry => 'Retry';

  @override
  String get riposteReady => 'Riposte ready · release to counter';

  @override
  String get commonPlay => 'Play';

  @override
  String get commonPause => 'Pause';

  @override
  String get exitGameTooltip => 'Exit game';

  @override
  String get gameOverTitle => 'Game Over';

  @override
  String get keyJump => 'Space / W / Up';

  @override
  String get keyMobility => 'Shift';

  @override
  String get keyPrimary => 'LMB / J';

  @override
  String get keySecondary => 'Q';

  @override
  String get keyProjectile => 'RMB / K';

  @override
  String get keySpell => 'E / L';

  @override
  String get abilityUnavailable => 'Unavailable';

  @override
  String get abilityLowResource => 'Low resource';

  @override
  String get abilityFollowUp => 'Follow-up';

  @override
  String get abilityReady => 'Ready';

  @override
  String get desktopControlsHelp =>
      'A / D or arrows: Move | Mouse: Aim | Esc / P: Pause | Enter: Resume';

  @override
  String get regenerationIncreased => 'Regeneration increased';

  @override
  String get forestBlessingName => 'Bénédiction des Dames de la forêt';

  @override
  String get bossEncounterEnded => 'Encounter ended';

  @override
  String bossAwakens({required String enemy}) {
    return '$enemy awakens';
  }

  @override
  String bossHealthSemantics({required String caption, required int health}) {
    final intl.NumberFormat healthNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String healthString = healthNumberFormat.format(health);

    return '$caption, $healthString health';
  }

  @override
  String bossRestorationSemantics({
    required String caption,
    required int percent,
  }) {
    final intl.NumberFormat percentNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String percentString = percentNumberFormat.format(percent);

    return '$caption, $percentString percent health, mana and stamina restored';
  }

  @override
  String bossRestoration({required int percent}) {
    final intl.NumberFormat percentNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String percentString = percentNumberFormat.format(percent);

    return '+$percentString% health · mana · stamina';
  }

  @override
  String get regenerationBlessingSemantics =>
      'Bénédiction des Dames de la forêt: health, mana and stamina regeneration increased until the end of the level';

  @override
  String riposteCountdown({required double seconds}) {
    final intl.NumberFormat secondsNumberFormat =
        intl.NumberFormat.decimalPatternDigits(
          locale: localeName,
          decimalDigits: 1,
        );
    final String secondsString = secondsNumberFormat.format(seconds);

    return 'Riposte · ${secondsString}s';
  }

  @override
  String secondsShort({required double seconds}) {
    final intl.NumberFormat secondsNumberFormat =
        intl.NumberFormat.decimalPatternDigits(
          locale: localeName,
          decimalDigits: 1,
        );
    final String secondsString = secondsNumberFormat.format(seconds);

    return '${secondsString}s';
  }

  @override
  String scoreValue({required int score}) {
    final intl.NumberFormat scoreNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String scoreString = scoreNumberFormat.format(score);

    return 'Score: $scoreString';
  }

  @override
  String chargePercent({required int percent}) {
    final intl.NumberFormat percentNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String percentString = percentNumberFormat.format(percent);

    return 'Charge $percentString%';
  }

  @override
  String abilityBindingSemantics({
    required String ability,
    required String binding,
    required String status,
  }) {
    return '$ability, $binding, $status';
  }

  @override
  String get projectileWeapons => 'Weapons';

  @override
  String get projectileSpellList => 'Spell List';

  @override
  String get gearCompareEquipped => 'This gear is currently equipped.';

  @override
  String get gearCompareSame => 'No stat differences.';

  @override
  String get gearOnHit => 'On Hit';

  @override
  String get gearOnCrit => 'On Crit';

  @override
  String get gearOnKill => 'On Kill';

  @override
  String get gearOnBlock => 'On Block';

  @override
  String get gearOnDamaged => 'On Damaged';

  @override
  String get gearOnLowHealth => 'On Low Health';

  @override
  String gearCompareLose({required String effects}) {
    return 'Lose: $effects';
  }

  @override
  String gearCompareAdd({required String effects}) {
    return 'Add: $effects';
  }

  @override
  String gearProcDot({
    required String status,
    required String damage,
    required String duration,
    required String chance,
    required String chanceKind,
  }) {
    String _temp0 = intl.Intl.selectLogic(chanceKind, {
      'guaranteed': '.',
      'other': ' ($chance chance).',
    });
    return 'Applies $status, dealing $damage damage per second for $duration$_temp0';
  }

  @override
  String gearProcSlow({
    required String amount,
    required String duration,
    required String chance,
    required String chanceKind,
  }) {
    String _temp0 = intl.Intl.selectLogic(chanceKind, {
      'guaranteed': '.',
      'other': ' ($chance chance).',
    });
    return 'Applies Slow, reducing move speed by $amount for $duration$_temp0';
  }

  @override
  String gearProcStun({
    required String duration,
    required String chance,
    required String chanceKind,
  }) {
    String _temp0 = intl.Intl.selectLogic(chanceKind, {
      'guaranteed': '.',
      'other': ' ($chance chance).',
    });
    return 'Applies Stun for $duration$_temp0';
  }

  @override
  String gearProcSilence({
    required String duration,
    required String chance,
    required String chanceKind,
  }) {
    String _temp0 = intl.Intl.selectLogic(chanceKind, {
      'guaranteed': '.',
      'other': ' ($chance chance).',
    });
    return 'Applies Silence for $duration$_temp0';
  }

  @override
  String gearProcVulnerable({
    required String amount,
    required String duration,
    required String chance,
    required String chanceKind,
  }) {
    String _temp0 = intl.Intl.selectLogic(chanceKind, {
      'guaranteed': '.',
      'other': ' ($chance chance).',
    });
    return 'Applies Vulnerable, increasing damage taken by $amount for $duration$_temp0';
  }

  @override
  String gearProcWeaken({
    required String amount,
    required String duration,
    required String chance,
    required String chanceKind,
  }) {
    String _temp0 = intl.Intl.selectLogic(chanceKind, {
      'guaranteed': '.',
      'other': ' ($chance chance).',
    });
    return 'Applies Weaken, reducing outgoing damage by $amount for $duration$_temp0';
  }

  @override
  String gearProcDrench({
    required String amount,
    required String duration,
    required String chance,
    required String chanceKind,
  }) {
    String _temp0 = intl.Intl.selectLogic(chanceKind, {
      'guaranteed': '.',
      'other': ' ($chance chance).',
    });
    return 'Applies Drench, reducing attack and cast speed by $amount for $duration$_temp0';
  }

  @override
  String gearProcHaste({
    required String amount,
    required String duration,
    required String chance,
    required String chanceKind,
  }) {
    String _temp0 = intl.Intl.selectLogic(chanceKind, {
      'guaranteed': '.',
      'other': ' ($chance chance).',
    });
    return 'Applies Haste, increasing move speed by $amount for $duration$_temp0';
  }

  @override
  String gearProcDamageReduction({
    required String amount,
    required String duration,
    required String chance,
    required String chanceKind,
  }) {
    String _temp0 = intl.Intl.selectLogic(chanceKind, {
      'guaranteed': '.',
      'other': ' ($chance chance).',
    });
    return 'Applies Damage Reduction, reducing incoming direct-hit damage by $amount for $duration$_temp0';
  }

  @override
  String gearProcRestore({
    required String resource,
    required String amount,
    required String duration,
    required String chance,
    required String chanceKind,
  }) {
    String _temp0 = intl.Intl.selectLogic(chanceKind, {
      'guaranteed': '.',
      'other': ' ($chance chance).',
    });
    return 'Restores $resource by $amount over $duration$_temp0';
  }

  @override
  String gearProcRestoreInstant({
    required String resource,
    required String amount,
    required String chance,
    required String chanceKind,
  }) {
    String _temp0 = intl.Intl.selectLogic(chanceKind, {
      'guaranteed': '.',
      'other': ' ($chance chance).',
    });
    return 'Restores $resource by $amount immediately$_temp0';
  }

  @override
  String gearProcRestoreBoth({
    required String resource,
    required String amount,
    required String duration,
    required String chance,
    required String chanceKind,
  }) {
    String _temp0 = intl.Intl.selectLogic(chanceKind, {
      'guaranteed': '.',
      'other': ' ($chance chance).',
    });
    return 'Restores $resource by $amount immediately and another $amount over $duration$_temp0';
  }

  @override
  String gearProcOffense({
    required String amount,
    required String crit,
    required String critKind,
    required String duration,
    required String chance,
    required String chanceKind,
  }) {
    String _temp0 = intl.Intl.selectLogic(critKind, {
      'withCrit':
          'Applies an Offense Buff, increasing power by $amount and critical chance by $crit for $duration',
      'other':
          'Applies an Offense Buff, increasing power by $amount for $duration',
    });
    String _temp1 = intl.Intl.selectLogic(chanceKind, {
      'guaranteed': '.',
      'other': ' ($chance chance).',
    });
    return '$_temp0$_temp1';
  }

  @override
  String abilityMelee({
    required String aim,
    required String damage,
    required String dotKind,
    required String status,
    required String dotDamage,
    required String duration,
  }) {
    String _temp0 = intl.Intl.selectLogic(aim, {
      'aimed':
          'Unleash a sword slash that deals $damage damage to enemies in aiming direction and in the attack reach.',
      'other':
          'Launch an attack that deals $damage damage to the closest enemy and all those who are in the attack reach.',
    });
    String _temp1 = intl.Intl.selectLogic(dotKind, {
      'withDot':
          ' It causes $status, dealing $dotDamage damage per second for $duration seconds.',
      'other': '',
    });
    return '$_temp0$_temp1';
  }

  @override
  String abilityGuard({
    required String reduction,
    required String riposteKind,
    required String riposte,
    required String riposteBonus,
  }) {
    String _temp0 = intl.Intl.selectLogic(riposteKind, {
      'withRiposte':
          ' The first guarded hit grants $riposte, empowering your next landed melee hit by +$riposteBonus% damage. It stays ready while this guard is held and expires 1 second after guard ends. Misses do not consume it.',
      'other': '',
    });
    return 'Keep your guard up and reduce direct-hit damage by $reduction% from any direction while held. Existing damage-over-time and ground spell impacts bypass the shield.$_temp0';
  }

  @override
  String abilityDoubleDash({required String window}) {
    return 'Dash a short distance. Tap again within $window seconds after the first burst to dash again in your chosen direction. Each burst pays the listed cost; cooldown starts with the first. Does not grant invulnerability.';
  }

  @override
  String abilityCleave({
    required String tapDamage,
    required String chargeTime,
    required String fullDamage,
    required String crit,
    required String status,
    required String dotDamage,
    required String duration,
  }) {
    return 'Aim and release for $tapDamage damage. Hold for $chargeTime seconds to deal $fullDamage damage, gain +$crit% critical chance and inflict $status ($dotDamage damage per second for $duration seconds). Only full charge grants this bleed. This attack can be interrupted by taking damage.';
  }

  @override
  String abilitySnap({
    required String source,
    required String projectileName,
    required String damage,
  }) {
    String _temp0 = intl.Intl.selectLogic(source, {
      'spell': 'the selected spell projectile',
      'other': 'your equipped projectile',
    });
    return 'Fire $_temp0$projectileName, it deals $damage damage to the closest enemy.';
  }

  @override
  String abilityQuick({
    required String source,
    required String projectileName,
    required String damage,
  }) {
    String _temp0 = intl.Intl.selectLogic(source, {
      'spell': 'the selected spell projectile',
      'other': 'your equipped projectile',
    });
    return 'Aim and fire $_temp0$projectileName. It deals $damage damage to a single target.';
  }

  @override
  String abilityOvercharge({
    required String source,
    required String projectileName,
    required String damage,
    required String damageBonus,
    required String critBonus,
    required String chargeTime,
  }) {
    String _temp0 = intl.Intl.selectLogic(source, {
      'spell': 'the selected spell projectile',
      'other': 'your equipped projectile',
    });
    return 'Charge and release $_temp0$projectileName. It deals $damage damage to a single target. Charging increases damage (up to +$damageBonus%) and critical chance (up to +$critBonus%). Full charge takes $chargeTime seconds. This attack can be interrupted by taking damage.';
  }

  @override
  String abilitySkewer({
    required String source,
    required String projectileName,
    required String damage,
    required String maxHits,
  }) {
    String _temp0 = intl.Intl.selectLogic(source, {
      'spell': 'the selected spell projectile',
      'other': 'your equipped projectile',
    });
    return 'Fire $_temp0$projectileName, piercing through enemies in its path. It deals $damage damage and can hit up to $maxHits enemies.';
  }

  @override
  String abilityRoll({required String status}) {
    return 'Perform a concussive roll. Enemies hit are affected by $status. Does not grant invulnerability.';
  }

  @override
  String get abilityStrike => 'Tap to strike in front of you.';

  @override
  String get abilityCast => 'Hold then release to cast a ranged bolt.';

  @override
  String get abilityJump => 'Tap to jump.';

  @override
  String get abilityDoubleJump =>
      'Tap to jump, then tap again in the air for a second jump.';

  @override
  String get abilityUse => 'Tap to use this ability.';

  @override
  String get abilityDash =>
      'Dash forward quickly. Does not grant invulnerability.';

  @override
  String get abilityCostFirstJump => 'Cost for first jump: ';

  @override
  String get abilityCostSecondJump => 'Cost for second jump: ';

  @override
  String get abilityCostSecond => 'Cost per second: ';

  @override
  String get abilityCost => 'Cost: ';

  @override
  String get abilityBleed => 'Bleed';

  @override
  String get abilityBurn => 'Burn';

  @override
  String get abilityAcid => 'Acid';

  @override
  String get abilityStun => 'Stun';

  @override
  String get abilityDamageOverTime => 'damage over time';

  @override
  String get abilityControl => 'Control';

  @override
  String get abilityHaste => 'Haste';

  @override
  String get abilityWard => 'Arcane Ward';

  @override
  String get abilityHealthRegen => 'Health Regen';

  @override
  String get abilityManaRegen => 'Mana Regen';

  @override
  String get abilityStaminaRegen => 'Stamina Regen';

  @override
  String get abilityResourceRegen => 'Resource Regen';

  @override
  String get abilityFocus => 'Focus';

  @override
  String get abilityStatusEffect => 'Status Effect';

  @override
  String get abilityMaxHealth => 'max Health';

  @override
  String get abilityMaxMana => 'max Mana';

  @override
  String get abilityMaxStamina => 'max Stamina';

  @override
  String get abilityMaxResource => 'max resource';

  @override
  String get abilityBadgeDamage => 'DAMAGE';

  @override
  String get abilityBadgeDefense => 'DEFENSE';

  @override
  String get abilityBadgeDash => 'DASH';

  @override
  String get abilityBadgeJump => 'JUMP';

  @override
  String get abilityBadgeHold => 'HOLD';

  @override
  String get abilityBadgeUtility => 'UTILITY';

  @override
  String get abilityBadgeControl => 'CONTROL';

  @override
  String get abilityBadgeCharged => 'CHARGED';

  @override
  String get abilityBadgeAutoAim => 'AUTO-AIM';

  @override
  String get abilityBadgeAim => 'AIM';

  @override
  String abilitySelfHaste({
    required String speedBonus,
    required String duration,
  }) {
    return 'Increase move speed by $speedBonus% for $duration seconds.';
  }

  @override
  String abilitySelfWard({
    required String mitigation,
    required String duration,
  }) {
    return 'Reduce direct-hit damage by $mitigation% and cancel damage-over-time effects for $duration seconds.';
  }

  @override
  String abilityRestoreBoth({
    required String restorePct,
    required String resourceLabel,
    required String duration,
  }) {
    return 'Restore $restorePct% of $resourceLabel immediately and another $restorePct% over $duration seconds.';
  }

  @override
  String abilityRestoreInstant({
    required String restorePct,
    required String resourceLabel,
  }) {
    return 'Restore $restorePct% of $resourceLabel immediately.';
  }

  @override
  String abilityRestore({
    required String restorePct,
    required String resourceLabel,
    required String duration,
  }) {
    return 'Restore $restorePct% of $resourceLabel over $duration seconds.';
  }

  @override
  String abilitySelfFocus({
    required String powerBonus,
    required String critBonus,
    required String duration,
  }) {
    return 'Increase power by $powerBonus% and critical chance by $critBonus% for $duration seconds.';
  }

  @override
  String abilitySelfStatus({
    required String statusLabel,
    required String duration,
  }) {
    return 'Apply $statusLabel for $duration seconds.';
  }

  @override
  String get abilityCleanse =>
      'Cleanse all active debuffs, including stun, silence, slow, vulnerability, weaken, drench, and damage-over-time effects.';

  @override
  String get cleanseStun => 'stun';

  @override
  String get cleanseSilence => 'silence';

  @override
  String get cleanseSlow => 'slow';

  @override
  String get cleanseVulnerability => 'vulnerability';

  @override
  String get cleanseWeaken => 'weaken';

  @override
  String get cleanseDrench => 'drench';

  @override
  String get cleanseDamageOverTime => 'damage-over-time';

  @override
  String abilityBaseDamage({required String parts}) {
    return 'Base damage: $parts.';
  }

  @override
  String abilityCostValue({required String value, required String resource}) {
    return '$value $resource';
  }

  @override
  String get abilityRiposte => 'Riposte';

  @override
  String hunterBomb({
    required num range,
    required String fuse,
    required String damage,
    required num radius,
    required String effect,
  }) {
    final intl.NumberFormat rangeNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String rangeString = rangeNumberFormat.format(range);
    final intl.NumberFormat radiusNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String radiusString = radiusNumberFormat.format(radius);

    String _temp0 = intl.Intl.selectLogic(effect, {
      'bleed': ' Survivors bleed.',
      'burn': ' Survivors burn.',
      'stun': ' Stuns susceptible enemies.',
      'other': '',
    });
    return 'Throw a bomb in an arc at the farthest reachable enemy within $rangeString units, or lob forward without a target. It explodes on enemy or terrain contact, or $fuse seconds after release, dealing $damage damage in a $radiusString-unit radius.$_temp0 Solid terrain blocks the blast. Uses regenerating Supplies.';
  }

  @override
  String hunterMark({
    required num range,
    required num duration,
    required num bonus,
  }) {
    final intl.NumberFormat rangeNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String rangeString = rangeNumberFormat.format(range);
    final intl.NumberFormat durationNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String durationString = durationNumberFormat.format(duration);
    final intl.NumberFormat bonusNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String bonusString = bonusNumberFormat.format(bonus);

    return 'Mark the nearest visible enemy within $rangeString units for $durationString seconds. Your direct attacks deal $bonusString% more damage to that target. No target means no cost or cooldown.';
  }

  @override
  String hunterShot({
    required String aim,
    required String damage,
    required int pellets,
    required String piercing,
    required int maxHits,
    required String charged,
    required num minDamage,
    required num maxDamage,
    required num crit,
    required int chargeHits,
  }) {
    final intl.NumberFormat pelletsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String pelletsString = pelletsNumberFormat.format(pellets);
    final intl.NumberFormat maxHitsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String maxHitsString = maxHitsNumberFormat.format(maxHits);
    final intl.NumberFormat minDamageNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String minDamageString = minDamageNumberFormat.format(minDamage);
    final intl.NumberFormat maxDamageNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String maxDamageString = maxDamageNumberFormat.format(maxDamage);
    final intl.NumberFormat critNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String critString = critNumberFormat.format(crit);
    final intl.NumberFormat chargeHitsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String chargeHitsString = chargeHitsNumberFormat.format(chargeHits);

    String _temp0 = intl.Intl.selectLogic(aim, {
      'automatic': 'Auto-aim and fire at a nearby enemy.',
      'other': 'Aim, then release to fire.',
    });
    String _temp1 = intl.Intl.pluralLogic(
      pellets,
      locale: localeName,
      other: ' divided across $pelletsString pellets',
      one: '',
    );
    String _temp2 = intl.Intl.selectLogic(piercing, {
      'yes': ' Each projectile can hit up to $maxHitsString enemies.',
      'other': '',
    });
    String _temp3 = intl.Intl.selectLogic(charged, {
      'yes':
          ' Charging increases damage from $minDamageString% to $maxDamageString%, adds up to $critString% critical chance, and pierces up to $chargeHitsString enemies at full charge. Taking damage interrupts the charge.',
      'other': '',
    });
    return '$_temp0 Deals $damage base damage$_temp1.$_temp2$_temp3 Uses regenerating Supplies.';
  }

  @override
  String hunterLunge({required String damage}) {
    return 'Briefly ready your blade, then automatically rush forward while slashing. Hits each enemy in the blade\'s path once for $damage base damage. A short recovery follows. Solid obstacles stop the lunge. You remain vulnerable throughout.';
  }

  @override
  String hunterMelee({required int swings, required String damage}) {
    final intl.NumberFormat swingsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String swingsString = swingsNumberFormat.format(swings);

    String _temp0 = intl.Intl.pluralLogic(
      swings,
      locale: localeName,
      other: '$swingsString times',
      one: 'once',
    );
    return 'Strike in front of you $_temp0, dealing $damage damage per swing. Each swing can hit every enemy in reach once.';
  }

  @override
  String get hunterDoubleJump =>
      'Jump, then tap again in the air for a second jump.';

  @override
  String hunterBlink({required num width}) {
    final intl.NumberFormat widthNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String widthString = widthNumberFormat.format(width);

    return 'Blink forward on the ground or in the air, crossing a nearby obstacle up to $widthString units wide. Requires a clear landing beyond it. A blocked exit costs nothing. Untouchable only while vanished; damage interrupts preparation and recovery.';
  }

  @override
  String hunterDoubleDash({required String window}) {
    return 'Dash on the ground or in the air, then tap again within $window seconds after the first burst ends for a second dash. You can change direction between bursts. Each burst pays the listed cost; cooldown starts with the first. Does not grant invulnerability.';
  }

  @override
  String get hunterDash =>
      'Dash forward on the ground or in the air. Does not grant invulnerability.';

  @override
  String get gearStatusSlow => 'Slow';

  @override
  String get gearStatusStun => 'Stun';

  @override
  String get gearStatusSilence => 'Silence';

  @override
  String get gearStatusVulnerable => 'Vulnerable';

  @override
  String get gearStatusWeaken => 'Weaken';

  @override
  String get gearStatusDrench => 'Drench';

  @override
  String get gearStatusHaste => 'Haste';

  @override
  String get gearStatusDamageReduction => 'Damage Reduction';

  @override
  String get gearStatusOffenseBuff => 'Offense Buff';

  @override
  String get abilityMaxSupplies => 'max Supplies';

  @override
  String get uiChooseYourName => 'Choose your name';

  @override
  String get uiThisIsRequiredYouCanChangeItLaterInProfile =>
      'This is required. You can change it later in Profile.';

  @override
  String get uiDisplayName => 'Display name';

  @override
  String get uiConfirm => 'Confirm';

  @override
  String get uiSomethingWentWrong => 'Something went wrong.';

  @override
  String get uiEdit => 'Edit';

  @override
  String get uiSave => 'Save';

  @override
  String get uiCancel => 'Cancel';

  @override
  String get uiRank => '#Rank';

  @override
  String get uiName => 'Name';

  @override
  String get uiLvl => 'Lvl';

  @override
  String get uiCharacter => 'Character';

  @override
  String get uiScore => 'Score';

  @override
  String get uiDistance => 'Distance';

  @override
  String get uiTime => 'Time';

  @override
  String get uiUnknown => 'Unknown';

  @override
  String get uiNewActivity => 'New activity';

  @override
  String get uiComingSoon => 'Coming Soon';

  @override
  String get uiHealth => 'Health';

  @override
  String get uiMana => 'Mana';

  @override
  String get uiSupplies => 'Supplies';

  @override
  String get uiStamina => 'Stamina';

  @override
  String get uiWallet => 'Wallet: ';

  @override
  String get uiRunReward => 'Run reward: +';

  @override
  String get uiSavingReplayKeepThisScreenOpenUntilItIsSaved =>
      'Saving replay. Keep this screen open until it is saved.';

  @override
  String
  get uiReplayCouldNotBeSavedRetryBeforeLeavingOrExitWithoutAVerifiedReward =>
      'Replay could not be saved. Retry before leaving, or exit without a verified reward.';

  @override
  String get uiSavingReplay => 'Saving replay';

  @override
  String get uiReplaySaveFailed => 'Replay save failed';

  @override
  String get uiRetrySaving => 'Retry Saving';

  @override
  String get uiVerification => 'Verification: ';

  @override
  String get uiVerificationDelayed => 'Verification delayed';

  @override
  String get uiCollectScore => 'Collect Score';

  @override
  String get uiSkip => 'Skip';

  @override
  String get uiRestart => 'Restart';

  @override
  String get uiExit => 'Exit';

  @override
  String get uiExitWithoutReward => 'Exit Without Reward';

  @override
  String get uiSavingReplayLabel => 'Saving Replay';

  @override
  String get uiLoadingRankSummary => 'Loading rank summary...';

  @override
  String get uiPractice => 'Practice';

  @override
  String get uiCompetitive => 'Competitive';

  @override
  String get uiWeekly => 'Weekly';

  @override
  String get uiLoadingLeaderboard => 'Loading leaderboard...';

  @override
  String get uiNoRunsYet => 'No runs yet.';

  @override
  String get uiActualRankUnavailableRightNow =>
      'Actual rank unavailable right now.';

  @override
  String get uiActualRankUnavailable => 'Actual rank unavailable.';

  @override
  String get uiUnranked => 'Unranked';

  @override
  String get uiUnableToLoadAchievementsReopenThisPageToRetry =>
      'Unable to load achievements. Reopen this page to retry.';

  @override
  String get uiUnableToClaimRewardsPleaseTryAgain =>
      'Unable to claim rewards. Please try again.';

  @override
  String get uiHallOfHonour => 'Hall of Honour';

  @override
  String get uiAchievementsAreUnavailableInDeveloperPractice =>
      'Achievements are unavailable in Developer Practice.';

  @override
  String get uiLoadingAchievements => 'Loading achievements…';

  @override
  String get uiAchievementsAreNotAvailableYet =>
      'Achievements are not available yet.';

  @override
  String get uiClaimAll => 'Claim all';

  @override
  String get uiClaim => 'Claim';

  @override
  String get uiCompleted => 'Completed';

  @override
  String get uiBronze => 'Bronze';

  @override
  String get uiSilver => 'Silver';

  @override
  String get uiGold => 'Gold';

  @override
  String get uiClaimed => 'Claimed';

  @override
  String get uiAvailable => 'Available';

  @override
  String get uiNotReached => 'Not reached';

  @override
  String get uiTown => 'Town';

  @override
  String get uiProfile => 'Profile';

  @override
  String get uiTop => 'Top';

  @override
  String get uiMessages => 'Messages';

  @override
  String get uiUnreadMessagesOrUnclaimedGifts =>
      'Unread messages or unclaimed gifts';

  @override
  String get uiOptions => 'Options';

  @override
  String get uiCharacterSelection => 'CHARACTER SELECTION';

  @override
  String get uiLevelSelection => 'RUNNER LEVEL SELECTION';

  @override
  String get uiLeaderboard => 'Leaderboard';

  @override
  String get uiUnableToNavigateToRunStartRightNowTryAgain =>
      'Unable to navigate to run start right now. Try again.';

  @override
  String get uiGuest => 'Guest';

  @override
  String get uiPracticeHeading => 'PRACTICE';

  @override
  String get uiCompetitiveHeading => 'COMPETITIVE';

  @override
  String get uiWeeklyHeading => 'WEEKLY';

  @override
  String get uiDeveloperModePracticeOnly => 'DEVELOPER MODE • Local play only';

  @override
  String get uiWeeklyUnavailableInThisBuild =>
      'WEEKLY • Unavailable in this build';

  @override
  String get uiPreparingRun => 'Preparing run...';

  @override
  String get uiRetrying => 'Retrying...';

  @override
  String get uiRetry => 'Retry';

  @override
  String get uiLoading => 'Loading...';

  @override
  String get uiFailedToLoadLeaderboard => 'Failed to load leaderboard.';

  @override
  String get uiLoadingOnlineLeaderboard => 'Loading online leaderboard.';

  @override
  String get uiNoLeaderboardData => 'No leaderboard data.';

  @override
  String get uiNoValidatedRunsYet => 'No validated runs yet.';

  @override
  String get uiVsGhost => 'VS Ghost';

  @override
  String get uiRaceThisGhost => 'Race this ghost.';

  @override
  String get uiGhostUnavailableForThisRun => 'Ghost unavailable for this run.';

  @override
  String get uiNoRankedPlayersYet => 'No ranked players yet.';

  @override
  String get uiYouAreNotRankedOnThisBoardYet =>
      'You are not ranked on this board yet.';

  @override
  String get uiYourRank => 'Your rank: ';

  @override
  String get uiNoActiveLeaderboardBoardForThisModeAndLevel =>
      'No active leaderboard board for this mode and level.';

  @override
  String get uiLeaderboardBoardIsNotAvailableRightNow =>
      'Leaderboard board is not available right now.';

  @override
  String get uiFailedToLoadOnlineLeaderboard =>
      'Failed to load online leaderboard.';

  @override
  String get uiBestiary => 'Bestiary';

  @override
  String get uiBestiaryBoss => 'Bestiary • Boss';

  @override
  String get uiFieldNotes => 'Field notes';

  @override
  String get uiEntryLocked => 'Entry locked';

  @override
  String get uiLocations => 'Locations';

  @override
  String get uiSummonedCreature => 'Summoned creature';

  @override
  String get uiBehaviour => 'Behaviour';

  @override
  String get uiAttacks => 'Attacks';

  @override
  String get uiResistances => 'Resistances';

  @override
  String get uiNoInnateDamageResistances => 'No innate damage resistances.';

  @override
  String get uiWeaknesses => 'Weaknesses';

  @override
  String get uiNoInnateDamageWeaknesses => 'No innate damage weaknesses.';

  @override
  String get uiOpen => 'Open';

  @override
  String get uiJournal => 'Journal';

  @override
  String get uiCloseLocation => 'Close location';

  @override
  String get uiResetMap => 'Reset map';

  @override
  String get uiUnableToMarkThisMessageAsReadPleaseTryAgain =>
      'Unable to mark this message as read. Please try again.';

  @override
  String
  get uiUnableToConfirmTheClaimPleaseTryAgainYourGiftCanOnlyBeClaimedOnce =>
      'Unable to confirm the claim. Please try again. Your gift can only be claimed once.';

  @override
  String get uiUnableToConfirmDeletionPleaseTryAgain =>
      'Unable to confirm deletion. Please try again.';

  @override
  String get uiMessagesAreUnavailableInThisProfile =>
      'Messages are unavailable in this profile.';

  @override
  String get uiGameMessages => 'Game messages';

  @override
  String get uiRefreshMessages => 'Refresh messages';

  @override
  String get uiMoreMessagesAreAvailable => 'More messages are available.';

  @override
  String get uiNoMessagesYet => 'No messages yet.';

  @override
  String get uiYourMessagesWillAppearHere => 'Your messages will appear here.';

  @override
  String get uiLoadMore => 'Load more';

  @override
  String get uiLoadingLabel => 'Loading…';

  @override
  String get uiSelectAMessageToReadIt => 'Select a message to read it.';

  @override
  String
  get uiClaimYourGoldBeforeDeletingThisMessageUnclaimedGoldDoesNotExpire =>
      'Claim your gold before deleting this message. Unclaimed gold does not expire.';

  @override
  String
  get uiClaimYourGiftsBeforeDeletingThisMessageUnclaimedGiftsDoNotExpire =>
      'Claim your gifts before deleting this message. Unclaimed gifts do not expire.';

  @override
  String get uiAutomaticallyRemoved30DaysAfterClaiming =>
      'Automatically removed 30 days after claiming.';

  @override
  String get uiAutomaticallyRemoved30DaysAfterReading =>
      'Automatically removed 30 days after reading.';

  @override
  String get uiAlreadyOwnedGiftsGrantNoDuplicateUnlockOrCompensation =>
      'Already-owned gifts grant no duplicate unlock or compensation.';

  @override
  String get uiRetryReading => 'Retry reading';

  @override
  String get uiPleaseWait => 'Please wait…';

  @override
  String get uiDeleteMessage => 'Delete message';

  @override
  String get uiUnread => 'Unread';

  @override
  String get uiGiftAvailable => 'Gift available';

  @override
  String get uiNameIsUnchanged => 'Name is unchanged.';

  @override
  String get uiNameUpdated => 'Name updated';

  @override
  String get uiAccountDeletionIsInProgress =>
      'Account deletion is in progress.';

  @override
  String get uiPleaseSignInAgainAndRetryAccountDeletion =>
      'Please sign in again and retry account deletion.';

  @override
  String get uiSessionExpiredPleaseRestartTheGameAndTryAgain =>
      'Session expired. Please restart the game and try again.';

  @override
  String get uiAccountDeletionIsNotAvailableInThisEnvironment =>
      'Account deletion is not available in this environment.';

  @override
  String get uiAccountDeletionFailedPleaseTryAgain =>
      'Account deletion failed. Please try again.';

  @override
  String get uiAccountDeleted => 'Account deleted.';

  @override
  String get uiPlayGamesAccountLinked => 'Play Games account linked.';

  @override
  String get uiPlayGamesIsAlreadyLinked => 'Play Games is already linked.';

  @override
  String get uiPlayGamesSignInCanceled => 'Play Games sign-in canceled.';

  @override
  String get uiPlayGamesSignInIsNotAvailableOnThisDevice =>
      'Play Games sign-in is not available on this device.';

  @override
  String get uiCouldNotLinkPlayGamesAccountPleaseTryAgain =>
      'Could not link Play Games account. Please try again.';

  @override
  String get uiDeleteAccountAndData => 'Delete account and data?';

  @override
  String get uiContinue => 'Continue';

  @override
  String get uiFinalConfirmation => 'Final confirmation';

  @override
  String get uiThisActionCannotBeUndoneDeleteThisAccountPermanently =>
      'This action cannot be undone. Delete this account permanently?';

  @override
  String get uiKeepAccount => 'Keep account';

  @override
  String get uiDeleteAccount => 'Delete account';

  @override
  String get uiAccountDeletionWasAcceptedDeviceCleanupNeedsAnotherAttempt =>
      'Account deletion was accepted. Device cleanup needs another attempt.';

  @override
  String get uiRetryCleanup => 'Retry cleanup';

  @override
  String get uiEnterName => 'Enter name';

  @override
  String get uiPlayerStats => 'Player stats';

  @override
  String get uiLifetimeXp => 'Lifetime XP';

  @override
  String get uiPracticeRunsPlayed => 'Practice runs played';

  @override
  String get uiCompetitiveRunsPlayed => 'Competitive runs played';

  @override
  String get uiEnemiesDefeated => 'Enemies defeated';

  @override
  String get uiDamageDealt => 'Damage dealt';

  @override
  String get uiDamageTaken => 'Damage taken';

  @override
  String get uiDangerZone => 'Danger zone';

  @override
  String get uiDeleteYourAccountAndAllLinkedPlayerDataPermanently =>
      'Delete your account and all linked player data permanently.';

  @override
  String get uiUpgradeGuestAccount => 'Upgrade guest account';

  @override
  String get uiLinkPlayGamesToKeepProgressAcrossDevices =>
      'Link Play Games to keep progress across devices.';

  @override
  String get uiLinking => 'Linking...';

  @override
  String get uiLinkPlayGames => 'Link Play Games';

  @override
  String get uiRenameBuild => 'Rename build';

  @override
  String get uiEnterABuildName => 'Enter a build name.';

  @override
  String get uiCouldNotSaveTheNamePleaseTryAgain =>
      'Could not save the name. Please try again.';

  @override
  String get uiBuildName => 'Build name';

  @override
  String get uiSaving => 'Saving…';

  @override
  String get uiCouldNotSaveThisSelectionPleaseTryAgain =>
      'Could not save this selection. Please try again.';

  @override
  String get uiChooseYourCharacter => 'Choose your character';

  @override
  String get uiNoOptionsForThisSlot => 'No options for this slot.';

  @override
  String get uiSelectAnItemToPreviewStats => 'Select an item to preview stats.';

  @override
  String get uiNoNonZeroStatBonuses => 'No non-zero stat bonuses.';

  @override
  String get uiVisitTownStore => 'Visit Town store?';

  @override
  String get uiGoToTown => 'Go to Town';

  @override
  String get uiEquip => 'Equip';

  @override
  String get uiGear => 'Gear';

  @override
  String get uiSkills => 'Skills';

  @override
  String get uiTrainingField => 'Training Field';

  @override
  String get uiNoAbilityAvailableForThisSlot =>
      'No ability available for this slot.';

  @override
  String get uiNoAbilityDetailsAvailableRightNow =>
      'No ability details available right now.';

  @override
  String get uiCooldown => 'Cooldown: ';

  @override
  String get uiMaxDuration => 'Max duration: ';

  @override
  String get uiUnlockThisSkillInTownToViewFullDetails =>
      'Unlock this skill in Town to view full details.';

  @override
  String get uiFindInTown => 'Find in Town';

  @override
  String get uiSelectProjectile => 'Select Projectile';

  @override
  String get uiDamage => 'Damage: ';

  @override
  String get uiSelectProjectileSource => 'Select Projectile Source';

  @override
  String get uiClose => 'Close';

  @override
  String get uiSelectWeapon => 'Select Weapon';

  @override
  String get uiChooseTrainingOpponent => 'Choose training opponent';

  @override
  String get uiReset => 'Reset';

  @override
  String get uiResume => 'Resume';

  @override
  String get uiRetryLoadingTrainingField => 'Retry loading Training Field';

  @override
  String get uiTrainingOpponent => 'Training opponent';

  @override
  String get uiChooseAnOpponentForYourNextFight =>
      'Choose an opponent for your next fight.';

  @override
  String get uiUnlockEnemyEntriesInTheLibraryToPractiseAgainstThem =>
      'Unlock enemy entries in the Library to practise against them.';

  @override
  String get uiNone => 'None';

  @override
  String get uiPractiseWithoutAnOpponent => 'Practise without an opponent.';

  @override
  String get uiSelectLevel => 'Select Level';

  @override
  String get uiYourGoldIsReady => 'Your gold is ready';

  @override
  String get uiYourRewardsAreOnTheirWay => 'Your rewards are on their way';

  @override
  String get uiYourBalanceHasChanged => 'Your balance has changed';

  @override
  String get uiYourRunRewardsAreConfirmedYouCanNowSpendYourGold =>
      'Your run rewards are confirmed. You can now spend your gold.';

  @override
  String
  get uiWeReConfirmingYourLatestRunRewardsBeforeTheyCanBeSpentYouCanKeepPlayingWhileWeFinish =>
      'We’re confirming your latest run rewards before they can be spent. You can keep playing while we finish.';

  @override
  String
  get uiThereIsnTEnoughGoldForThisPurchaseReturnToTheStoreToSeeYourUpdatedBalance =>
      'There isn’t enough gold for this purchase. Return to the store to see your updated balance.';

  @override
  String get uiBackToStore => 'Back to store';

  @override
  String get uiGotIt => 'Got it';

  @override
  String get uiStore => 'Store';

  @override
  String get uiLibrary => 'Library';

  @override
  String get uiAchievementRewardsAvailable => 'Achievement rewards available';

  @override
  String get uiStoreMarker => 'Store marker';

  @override
  String get uiLibraryMarker => 'Library marker';

  @override
  String get uiHallOfHonourMarker => 'Hall of Honour marker';

  @override
  String get uiTownStore => 'Town Store';

  @override
  String get uiPurchaseFailedPleaseTryAgain =>
      'Purchase failed. Please try again.';

  @override
  String get uiRefreshStore => 'Refresh store?';

  @override
  String get uiRefreshingTheStoreCosts => 'Refreshing the store costs';

  @override
  String get uiCost => 'Cost';

  @override
  String get uiAreYouSureYouWantToRefreshTheStore =>
      'Are you sure you want to refresh the store?';

  @override
  String get uiRefresh => 'Refresh';

  @override
  String get uiStoreRefreshed => 'Store refreshed.';

  @override
  String get uiRefreshFailedPleaseTryAgain =>
      'Refresh failed. Please try again.';

  @override
  String get uiNotEnoughGoldForThatAction => 'Not enough gold for that action.';

  @override
  String get uiThatOfferIsNoLongerAvailable =>
      'That offer is no longer available.';

  @override
  String get uiYouAlreadyOwnThisUnlock => 'You already own this unlock.';

  @override
  String get uiDailyRefreshLimitReached => 'Daily refresh limit reached.';

  @override
  String get uiRefreshMethodIsNotAvailable =>
      'Refresh method is not available.';

  @override
  String get uiNoOfferCanChangeRightNow => 'No offer can change right now.';

  @override
  String get uiRewardVerificationIsNotActiveYet =>
      'Reward verification is not active yet.';

  @override
  String get uiRewardHasAlreadyBeenUsed => 'Reward has already been used.';

  @override
  String get uiRewardHasExpired => 'Reward has expired.';

  @override
  String get uiActionRejectedPleaseTryAgain =>
      'Action rejected. Please try again.';

  @override
  String get uiRefreshing => 'Refreshing...';

  @override
  String get uiNoOffersAvailableRightNow => 'No offers available right now.';

  @override
  String get uiBuying => 'Buying...';

  @override
  String get uiBuy => 'Buy';

  @override
  String get uiNoDetailsAvailableRightNow => 'No details available right now.';

  @override
  String get bootstrapStartFailed => 'Unable to start the game';

  @override
  String get bootstrapAccountUnavailable => 'Game account unavailable';

  @override
  String get bootstrapSignInRequired => 'Play Games sign-in required';

  @override
  String get bootstrapDataFailed => 'Unable to load player data';

  @override
  String get bootstrapAccountDisabled =>
      'This game account is disabled. If you recently deleted it, please wait for deletion to finish before signing in again. This can take several hours. You can then use the same Play Games account to start fresh.';

  @override
  String get bootstrapUnsupported =>
      'This platform does not support the services required by the game.';

  @override
  String get bootstrapServiceFailure =>
      'Game services could not start. Check your connection and try again.';

  @override
  String get bootstrapDataFailure =>
      'Your player data could not be loaded. Check your connection and try again.';

  @override
  String get bootstrapRetry => 'Try again';

  @override
  String get bootstrapRetrySignIn => 'Retry Play Games sign-in';

  @override
  String get bootstrapSignInBody =>
      'Play Games sign-in is required to continue.';

  @override
  String get bootstrapFailed => 'Bootstrap failed';

  @override
  String get loaderGameTitle => 'The Long Run';

  @override
  String get loaderWorldTitle => 'Lothringen';

  @override
  String get playButton => 'PLAY';

  @override
  String get runUpdateRequired =>
      'Update the game before starting another run. Your account and pending rewards remain available.';

  @override
  String get runMaintenance =>
      'The game is undergoing maintenance. Please try again later. Your pending runs and rewards will be recovered.';

  @override
  String get runInvalidLoadout =>
      'Adjust your equipment and abilities before starting.';

  @override
  String get runLevelUnavailable =>
      'This level is unavailable in this build. Return to the hub and select an available level.';

  @override
  String get runRequirementsChanged =>
      'Run start requirements changed. Return to hub and try again.';

  @override
  String get runStartFailed =>
      'Unable to start run right now. Check your connection and try again.';

  @override
  String get runRecorderPreparing => 'Preparing replay recorder...';

  @override
  String get runTerrainPreparing => 'Preparing terrain...';

  @override
  String get runGhostPreparing => 'Preparing ghost...';

  @override
  String get runArtLoading => 'Loading game art...';

  @override
  String get runBuildingLevel => 'Building level...';

  @override
  String get runWorldFailed =>
      'Unable to load the level. Retry or return to the previous screen.';

  @override
  String get runRecorderFailed =>
      'Unable to prepare replay recording. Check available storage and retry.';

  @override
  String get nameRequired => 'Name is required.';

  @override
  String get nameCharacters =>
      'Only letters, numbers, spaces, \"_\" and \"-\" are allowed.';

  @override
  String get nameReserved => 'That name is reserved.';

  @override
  String get nameDisallowed => 'That name is not allowed.';

  @override
  String get nameTaken => 'That name is already taken.';

  @override
  String get nameSaveFailed => 'Could not save name. Please try again.';

  @override
  String get nameServerUnavailable =>
      'Could not reach the server. Check your connection and try again.';

  @override
  String get nameServiceUnavailable =>
      'Name service is unavailable. Please try again later.';

  @override
  String get nameInvalid => 'Choose a valid display name and try again.';

  @override
  String get updateRequiredTitle => 'Update required';

  @override
  String get maintenanceTitle => 'Maintenance';

  @override
  String get openGooglePlay => 'Open Google Play';

  @override
  String get installCurrentBuild =>
      'Install the current build for this environment.';

  @override
  String nameTooShort({required int min}) {
    final intl.NumberFormat minNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String minString = minNumberFormat.format(min);

    return 'Name must be at least $minString characters.';
  }

  @override
  String nameTooLong({required int max}) {
    final intl.NumberFormat maxNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String maxString = maxNumberFormat.format(max);

    return 'Name must be at most $maxString characters.';
  }

  @override
  String get achievementFirstSteps => 'First Steps';

  @override
  String get achievementMarathoner => 'Marathoner';

  @override
  String get achievementRoadWarrior => 'Road Warrior';

  @override
  String get achievementStillStanding => 'Still Standing';

  @override
  String get achievementSlayer => 'Slayer';

  @override
  String get achievementQualifying =>
      'Verified Practice, Competitive and Weekly runs count after 100 metres or 30 seconds and must end naturally. Quitting does not count.';

  @override
  String get achievementAllRuns =>
      'Verified Practice, Competitive and Weekly runs count, including short runs and runs you quit.';

  @override
  String achievementRuns({required int count}) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString runs',
      one: '1 run',
    );
    return '$_temp0';
  }

  @override
  String achievementEnemies({required int count}) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString enemies',
      one: '1 enemy',
    );
    return '$_temp0';
  }

  @override
  String achievementDistance({required int count}) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString m';
  }

  @override
  String achievementFinish({required int count}) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString qualifying runs',
      one: '1 qualifying run',
    );
    return 'Finish $_temp0.';
  }

  @override
  String achievementReach({required int count}) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Reach $countString metres in one run.';
  }

  @override
  String achievementTravel({required int count}) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Travel $countString metres across runs.';
  }

  @override
  String achievementSurvive({required String duration}) {
    return 'Survive $duration across runs.';
  }

  @override
  String achievementDefeat({required int count}) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString enemies',
      one: '1 enemy',
    );
    return 'Defeat $_temp0 across runs.';
  }

  @override
  String durationHours({required int count}) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '${countString}h';
  }

  @override
  String durationMinutes({required int count}) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '${countString}m';
  }

  @override
  String durationSeconds({required int count}) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '${countString}s';
  }

  @override
  String dateUtc({required String date}) {
    return '$date (UTC)';
  }

  @override
  String achievementNextReward({required int gold}) {
    final intl.NumberFormat goldNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String goldString = goldNumberFormat.format(gold);

    return 'Next reward: $goldString gold';
  }

  @override
  String achievementProgressSummary({
    required String progress,
    required int gold,
  }) {
    final intl.NumberFormat goldNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String goldString = goldNumberFormat.format(gold);

    return '$progress · Next $goldString gold';
  }

  @override
  String achievementClaimAmount({required String scope, required int gold}) {
    final intl.NumberFormat goldNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String goldString = goldNumberFormat.format(gold);

    String _temp0 = intl.Intl.selectLogic(scope, {
      'all': 'Claim all $goldString',
      'other': 'Claim $goldString',
    });
    return '$_temp0';
  }

  @override
  String achievementClaimGoldLabel({required String scope, required int gold}) {
    final intl.NumberFormat goldNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String goldString = goldNumberFormat.format(gold);

    String _temp0 = intl.Intl.selectLogic(scope, {
      'all': 'Claim all $goldString gold',
      'other': 'Claim $goldString gold',
    });
    return '$_temp0';
  }

  @override
  String get achievementWhatCounts => 'What counts?';

  @override
  String achievementTierStatus({required String state}) {
    String _temp0 = intl.Intl.selectLogic(state, {
      'claimed': 'Claimed',
      'achieved': 'Available',
      'next': 'In progress',
      'other': 'Locked',
    });
    return '$_temp0';
  }

  @override
  String achievementTierReward({required int gold, required String state}) {
    final intl.NumberFormat goldNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String goldString = goldNumberFormat.format(gold);

    String _temp0 = intl.Intl.selectLogic(state, {
      'claimed': 'Claimed',
      'achieved': 'Available',
      'next': 'In progress',
      'other': 'Locked',
    });
    return '$goldString gold · $_temp0';
  }

  @override
  String achievementAchievedDate({required String date}) {
    return 'Achieved $date';
  }

  @override
  String goldAmount({required int gold}) {
    final intl.NumberFormat goldNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String goldString = goldNumberFormat.format(gold);

    return '$goldString gold';
  }

  @override
  String progressQuantities({required String current, required String target}) {
    return '$current / $target';
  }

  @override
  String get codexGrojibLore =>
      'Grojib closes the distance without hesitation. A traveler who holds their ground after the first blow may find another strike already on its way.';

  @override
  String get codexHashashLore =>
      'Hashash fights from the uncertainty of the forest, appearing where attention has already moved on. In these woods, an apparently empty path is no promise of safe passage.';

  @override
  String get codexDerfLore =>
      'Derf’s outward form conceals a transformation that turns a distant spellcaster into a pursuing, tentacled threat.';

  @override
  String get codexUnocoLore =>
      'The Unoco demons encountered over the forest carry the threat above the paths, where walls and broken ground offer little protection from a spell cast out of the air.';

  @override
  String get codexBringerLore =>
      'The Bringer of Death bars the way through a clearing claimed by the darkness. Its scythe and rising pillars leave little room for hesitation. Defeating this guardian opens a way deeper into the forest.';

  @override
  String get codexGoddessLore =>
      'The name Voidborn Goddess records the terror of the encounter, not proof of divinity. This presence turns the clearing itself into a threat. What brought it into the forest remains unknown.';

  @override
  String get codexShoggothLore =>
      'Shoggoth is encountered among the deeper horrors guarding the route. Smaller creatures accompany its assaults, making the fight feel less like a duel than a struggle to keep a patch of ground. Its distant origin remains unrecorded.';

  @override
  String get codexVoidcallerLore =>
      'The Voidcaller’s presence is marked by beams, erupting claws and summoned tentacles. Its title describes what travelers have witnessed, while the nature of what answers its call remains uncertain.';

  @override
  String get codexShoggothMinionLore =>
      'These smaller creatures enter the fight at Shoggoth’s summons. They are part of the same immediate threat, pressing an opponent while the larger creature prepares its next assault. Their appearance is a warning that the ground around Shoggoth will not stay clear.';

  @override
  String get codexVoidTentacleLore =>
      'A tentacle called into the arena is a local expression of the Voidcaller’s reach. It makes dangerous ground out of a place that was open a moment before. Destroying it removes that threat, but leaves the power calling it forth to be confronted.';

  @override
  String get codexGrojibTactics =>
      'A ground pursuer with a follow-up melee strike that can stun on hit.';

  @override
  String get codexHashashTactics =>
      'A mobile assassin with a teleporting ambush.';

  @override
  String get codexDerfTactics =>
      'Transforms from a caster into a melee pursuer. Its extended tentacle gives the strike unusual reach.';

  @override
  String get codexUnocoTactics =>
      'A flying caster that can also strike at close range.';

  @override
  String get codexBringerTactics => 'A scythe fighter with dark pillars.';

  @override
  String get codexGoddessTactics =>
      'Combines claw attacks, dark orbs and ground eruptions.';

  @override
  String get codexShoggothTactics =>
      'Uses tentacles, dark orbs and summoned creatures.';

  @override
  String get codexVoidcallerTactics =>
      'Uses vertical and diagonal beams, fire claws and tentacle summons.';

  @override
  String get codexShoggothMinionTactics =>
      'A small ground attacker summoned by Shoggoth.';

  @override
  String get codexVoidTentacleTactics => 'A summoned melee threat.';

  @override
  String get codexForestLore =>
      'Set apart from Théodonis in a darker stretch of the Long-Eared Owls’ Forest, Val Outpost consists of half a dozen large tents in a well-organized, guarded camp. In quieter times, it maintains a presence on the road and prepares soldiers for combat and survival in the forest.\n\nCaptain Théo commands twenty-four elite forest guards here, while Hanna, their field medic, tends the wounded. Their orders are to contain a bugbear tribe’s expansion across the Vosga and secure the approaches to the road. Tensions return in waves, and the outpost must absorb them before they reach Théodonis.\n\nVal also serves as a link to the city. Its captain can have messages relayed to Théodonis, and the camp offers refuge to travelers in distress: a hot meal, a clean place to sleep, and a few hours under the soldiers’ guard. Beyond the tents, the forest remains dangerous.';

  @override
  String get codexFieldLore =>
      'Léonards’ farm is the largest agricultural estate around Théodonis. A powerful family oversees its fields and harvests.';

  @override
  String get levelForestName => 'Val Outpost';

  @override
  String get levelFieldName => 'Léonards’ farm';

  @override
  String get levelDeprecatedName => 'New Level';

  @override
  String get townName => 'Théodonis';

  @override
  String libraryTitle({required String section}) {
    return 'Library · $section';
  }

  @override
  String codexUnlockEnemy({required int count}) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Defeat $countString to reveal its attacks, resistances and field notes.';
  }

  @override
  String codexDefeatedProgress({required int current, required int target}) {
    final intl.NumberFormat currentNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String currentString = currentNumberFormat.format(current);
    final intl.NumberFormat targetNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String targetString = targetNumberFormat.format(target);

    return '$currentString / $targetString defeated.';
  }

  @override
  String codexUnlockLevel({required int count, required String level}) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Reach $countString points in one Competitive run on $level to reveal its history.';
  }

  @override
  String codexScoreProgress({required int current, required int target}) {
    final intl.NumberFormat currentNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String currentString = currentNumberFormat.format(current);
    final intl.NumberFormat targetNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String targetString = targetNumberFormat.format(target);

    return '$currentString / $targetString best Competitive score.';
  }

  @override
  String codexResistance({required String type, required num percent}) {
    final intl.NumberFormat percentNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String percentString = percentNumberFormat.format(percent);

    return '$type: $percentString% less damage';
  }

  @override
  String codexWeakness({required String type, required num percent}) {
    final intl.NumberFormat percentNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String percentString = percentNumberFormat.format(percent);

    return '$type: $percentString% more damage';
  }

  @override
  String codexDamageMix({required String type, required int percent}) {
    final intl.NumberFormat percentNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String percentString = percentNumberFormat.format(percent);

    return '$type $percentString%';
  }

  @override
  String codexAttack({
    required String ability,
    required String category,
    required String types,
  }) {
    return '$ability • $category\n$types damage';
  }

  @override
  String codexEntrySemantics({required String title, required String state}) {
    String _temp0 = intl.Intl.selectLogic(state, {
      'discovered': 'discovered',
      'other': 'locked',
    });
    return '$title, $_temp0';
  }

  @override
  String codexDefeatToUnlock({required String progress}) {
    return 'Defeat $progress to unlock';
  }

  @override
  String codexLocationSemantics({
    required String level,
    required String state,
  }) {
    String _temp0 = intl.Intl.selectLogic(state, {
      'open': 'open',
      'other': 'locked',
    });
    return '$level, $_temp0';
  }

  @override
  String codexMapMarker({required String level}) {
    return '$level map marker';
  }

  @override
  String get abilityCategoryMelee => 'melee';

  @override
  String get abilityCategoryRanged => 'ranged';

  @override
  String get abilityCategoryMobility => 'mobility';

  @override
  String get abilityCategoryDefense => 'defense';

  @override
  String get abilityCategoryUtility => 'utility';

  @override
  String get runBossFailed => 'Boss encounter failed';

  @override
  String get runGaveUp => 'You gave up the run.';

  @override
  String get runFellBehind => 'You fell behind.';

  @override
  String get runFellIntoGap => 'You fell into a gap.';

  @override
  String get runDied => 'You died.';

  @override
  String get runPoisonTrap => 'You succumbed to Poison from a dart trap.';

  @override
  String get runSpikeTrap => 'Killed by a Spike trap.';

  @override
  String get runAxeTrap => 'Killed by a Swinging Axe trap.';

  @override
  String get runPoisonDart => 'Killed by a Poison Dart.';

  @override
  String get runStatusDeath => 'You succumbed to a status effect.';

  @override
  String get runTrapDeath => 'Killed by a trap.';

  @override
  String get runSpellDeath => 'You were consumed by a spell impact.';

  @override
  String get runDerfDeath => 'Incinerated by Derf\'s explosion.';

  @override
  String get impactBullet => 'Bullet';

  @override
  String get impactCrossbow => 'Crossbow Bolt';

  @override
  String get impactPellet => 'Shotgun Pellet';

  @override
  String get scoreEnemy => 'Enemy';

  @override
  String get practiceNoRewards =>
      'Developer Practice\nNo rewards or leaderboard entries.';

  @override
  String runProjectileDeath({
    required String projectile,
    required String source,
    required String enemy,
  }) {
    String _temp0 = intl.Intl.selectLogic(source, {
      'enemy': ' from $enemy.',
      'other': '.',
    });
    return 'Killed by $projectile$_temp0';
  }

  @override
  String runMeleeDeath({required String enemy}) {
    return 'Killed by a melee strike from a $enemy.';
  }

  @override
  String runEnemySpellDeath({required String enemy}) {
    return 'Killed by a spell impact from $enemy.';
  }

  @override
  String get submissionQueued => 'Queued';

  @override
  String get submissionRequestingUploadGrant => 'Requesting Upload Grant';

  @override
  String get submissionUploading => 'Uploading Replay';

  @override
  String get submissionFinalizing => 'Finalizing';

  @override
  String get submissionRetryScheduled => 'Retry Scheduled';

  @override
  String get submissionPendingValidation => 'Waiting For Verification';

  @override
  String get submissionValidating => 'Validating';

  @override
  String get submissionSettlementPending => 'Settling Reward';

  @override
  String get submissionValidated => 'Validated';

  @override
  String get submissionRejected => 'Rejected';

  @override
  String get submissionExpired => 'Expired';

  @override
  String get submissionCancelled => 'Cancelled';

  @override
  String get submissionInternalError => 'Internal Error';

  @override
  String get submissionFailureBody =>
      'Verification could not finish. Return to the hub, or contact support if this continues.';

  @override
  String runRewardXp({required int xp}) {
    final intl.NumberFormat xpNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String xpString = xpNumberFormat.format(xp);

    return '+$xpString XP';
  }

  @override
  String scoreRowDistance({required int count, required int points}) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);
    final intl.NumberFormat pointsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String pointsString = pointsNumberFormat.format(points);

    return 'Distance: ${countString}m -> $pointsString';
  }

  @override
  String scoreRowCollectibles({required int count, required int points}) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);
    final intl.NumberFormat pointsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String pointsString = pointsNumberFormat.format(points);

    return 'Collectibles: $countString -> $pointsString';
  }

  @override
  String scoreRowRescue({required int count, required int points}) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);
    final intl.NumberFormat pointsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String pointsString = pointsNumberFormat.format(points);

    return 'NPCs rescued: $countString -> $pointsString';
  }

  @override
  String scoreRowTime({required String time, required int points}) {
    final intl.NumberFormat pointsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String pointsString = pointsNumberFormat.format(points);

    return 'Time: $time -> $pointsString';
  }

  @override
  String scoreRowEnemy({
    required String enemy,
    required int count,
    required int points,
  }) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);
    final intl.NumberFormat pointsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String pointsString = pointsNumberFormat.format(points);

    return '$enemy x$countString -> $pointsString';
  }

  @override
  String levelMaximumSemantics({required int level}) {
    final intl.NumberFormat levelNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String levelString = levelNumberFormat.format(level);

    return 'Level $levelString, maximum level reached';
  }

  @override
  String levelProgressSemantics({
    required int level,
    required int earned,
    required int needed,
  }) {
    final intl.NumberFormat levelNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String levelString = levelNumberFormat.format(level);
    final intl.NumberFormat earnedNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String earnedString = earnedNumberFormat.format(earned);
    final intl.NumberFormat neededNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String neededString = neededNumberFormat.format(needed);

    return 'Level $levelString, $earnedString of $neededString XP to next level';
  }

  @override
  String levelMaximumLabel({required int level}) {
    final intl.NumberFormat levelNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String levelString = levelNumberFormat.format(level);

    return 'LEVEL $levelString  ·  MAX LEVEL';
  }

  @override
  String levelProgressLabel({
    required int level,
    required int earned,
    required int needed,
  }) {
    final intl.NumberFormat levelNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String levelString = levelNumberFormat.format(level);
    final intl.NumberFormat earnedNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String earnedString = earnedNumberFormat.format(earned);
    final intl.NumberFormat neededNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String neededString = neededNumberFormat.format(needed);

    return 'LEVEL $levelString  ·  $earnedString / $neededString XP';
  }

  @override
  String scoreDistance({required int meters}) {
    final intl.NumberFormat metersNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String metersString = metersNumberFormat.format(meters);

    return 'Distance ${metersString}m';
  }

  @override
  String scoreCollectibles({required int count}) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Collectibles $countString';
  }

  @override
  String shortDistance({required int meters}) {
    final intl.NumberFormat metersNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String metersString = metersNumberFormat.format(meters);

    return '${metersString}m';
  }

  @override
  String healthPoints({required int hp}) {
    final intl.NumberFormat hpNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String hpString = hpNumberFormat.format(hp);

    return '$hpString HP';
  }

  @override
  String nameChangeCooldown({required int hours, required int minutes}) {
    final intl.NumberFormat hoursNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String hoursString = hoursNumberFormat.format(hours);
    final intl.NumberFormat minutesNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String minutesString = minutesNumberFormat.format(minutes);

    return 'You can change your name again in ${hoursString}h ${minutesString}m.';
  }

  @override
  String get deleteAccountBody =>
      'This will permanently delete your account, profile, and cloud progress for this user.\n\nDeletion can take several hours. You cannot start a new account with the same Play Games profile until it finishes.';

  @override
  String characterLockedSemantics({required String name, required int level}) {
    final intl.NumberFormat levelNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String levelString = levelNumberFormat.format(level);

    return '$name, unlocks at level $levelString';
  }

  @override
  String requiredLevel({required int level}) {
    final intl.NumberFormat levelNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String levelString = levelNumberFormat.format(level);

    return 'Level $levelString';
  }

  @override
  String trainingOpponent({required String enemy}) {
    return 'Opponent: $enemy';
  }

  @override
  String storePurchaseComplete({required String item}) {
    return 'Purchased $item.';
  }

  @override
  String storeRefreshesLeft({required int count}) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Store refreshes left: $countString';
  }

  @override
  String storeBrowseLocked({required String slot}) {
    String _temp0 = intl.Intl.selectLogic(slot, {
      'mainWeapon': 'main weapon',
      'offhandWeapon': 'offhand',
      'spellBook': 'spellbook',
      'other': 'accessory',
    });
    return 'Open Town to browse locked $_temp0 options?';
  }

  @override
  String skillHeading({required String slot}) {
    String _temp0 = intl.Intl.selectLogic(slot, {
      'primary': 'PRIMARY SKILLS',
      'secondary': 'SECONDARY SKILLS',
      'projectile': 'PROJECTILE SKILLS',
      'mobility': 'MOBILITY SKILLS',
      'spell': 'SPELL SKILLS',
      'jump': 'JUMP SKILLS',
      'other': 'FIELDCRAFT SKILLS',
    });
    return '$_temp0';
  }

  @override
  String messageHeader({required String date}) {
    return 'Game · $date';
  }

  @override
  String messageGiftCount({required int count}) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString item / skill gifts',
      one: '1 item / skill gift',
    );
    return '$_temp0';
  }

  @override
  String weeklyBadge({required String window}) {
    String _temp0 = intl.Intl.selectLogic(window, {
      'unknown': 'WEEKLY RUNNER',
      'other': 'WEEKLY RUNNER - $window',
    });
    return '$_temp0';
  }

  @override
  String scoreboardTitle({required String level, required String mode}) {
    return '$level $mode Scoreboard';
  }

  @override
  String leaderboardTitle({required String level, required String mode}) {
    return '$level $mode BOARD';
  }

  @override
  String rankTotal({required int count}) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return ' / $countString';
  }

  @override
  String rankSummary({
    required String rank,
    required String position,
    required String outcome,
  }) {
    String _temp0 = intl.Intl.selectLogic(position, {
      'first': ' (1st place)',
      'second': ' (2nd place, podium)',
      'third': ' (3rd place, podium)',
      'topTen': ' (top 10)',
      'other': '',
    });
    String _temp1 = intl.Intl.selectLogic(outcome, {
      'unchanged': ', you have not done better this run.',
      'other': '.',
    });
    return 'Actual rank $rank$_temp0$_temp1';
  }

  @override
  String controlFollowUp({required String label}) {
    return '$label, follow-up available';
  }

  @override
  String get controlSword => 'Sword';

  @override
  String get controlShield => 'Shield';

  @override
  String get controlProjectile => 'Projectile';

  @override
  String get controlMobility => 'Mobility';

  @override
  String get controlJump => 'Jump';

  @override
  String get controlSpell => 'Spell';

  @override
  String get controlMoveLeft => 'Move left';

  @override
  String get controlMoveRight => 'Move right';

  @override
  String get controlJoystick => 'Movement joystick';

  @override
  String get controlBackward => 'Backward';

  @override
  String get controlForward => 'Forward';

  @override
  String get controlNeutral => 'Neutral';

  @override
  String get runStartErrorTitle => 'Unable to start run';

  @override
  String get studioName => 'Luxis Games';

  @override
  String defaultBuildName({required int number}) {
    final intl.NumberFormat numberNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String numberString = numberNumberFormat.format(number);

    return 'Build $numberString';
  }

  @override
  String offscreenDistance({required int meters}) {
    final intl.NumberFormat metersNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String metersString = metersNumberFormat.format(meters);

    return '$metersString m';
  }

  @override
  String get offscreenNearby => '<1 m';

  @override
  String offscreenGroup({required int count, required String distance}) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '×$countString · $distance';
  }

  @override
  String supportLinkFailed({required String email}) {
    return 'Unable to open the link. Try again or contact $email.';
  }

  @override
  String resourceRatio({required int value, required int maximum}) {
    final intl.NumberFormat valueNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String valueString = valueNumberFormat.format(value);
    final intl.NumberFormat maximumNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String maximumString = maximumNumberFormat.format(maximum);

    return '$valueString / $maximumString';
  }

  @override
  String quotedDescription({required String description}) {
    return '“$description”';
  }

  @override
  String get developerAppTitle => 'rpg Runner (Dev)';

  @override
  String get developerMenu => 'Menu';

  @override
  String get routeRunUnavailableTitle => 'Unable to start run';

  @override
  String get routeRunUnavailableBody =>
      'Return to the hub and start the run again.';

  @override
  String get routeUnavailableTitle => 'Page unavailable';

  @override
  String get routeUnavailableBody =>
      'This page could not be opened. Go back and try again.';

  @override
  String get inboxLoadFailed => 'Unable to load messages. Please try again.';

  @override
  String get runCleanupFailed =>
      'Unable to release the previous run. Exit and try again.';

  @override
  String get developerIdentity => 'Developer';

  @override
  String get townEquipment => 'Equipment store';

  @override
  String get townTraining => 'Training Hall';

  @override
  String get townEquipmentMarker => 'Equipment store marker';

  @override
  String get townTrainingMarker => 'Training hall marker';

  @override
  String get townEquipmentIntro =>
      'Choose equipment for your next build. Every item is always available.';

  @override
  String get townTrainingIntro =>
      'Learn permanent techniques for the character you choose.';

  @override
  String get townAllCategories => 'All categories';

  @override
  String get townUnownedOnly => 'Not yet unlocked';

  @override
  String townBuyAmount({required int gold}) {
    final intl.NumberFormat goldNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String goldString = goldNumberFormat.format(gold);

    return 'Buy $goldString';
  }

  @override
  String townBuyGoldLabel({required int gold}) {
    final intl.NumberFormat goldNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String goldString = goldNumberFormat.format(gold);

    return 'Buy for $goldString gold';
  }

  @override
  String townLearnAmount({required int gold}) {
    final intl.NumberFormat goldNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String goldString = goldNumberFormat.format(gold);

    return 'Learn $goldString';
  }

  @override
  String townLearnGoldLabel({required int gold}) {
    final intl.NumberFormat goldNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String goldString = goldNumberFormat.format(gold);

    return 'Learn for $goldString gold';
  }

  @override
  String get pickerEquipped => 'Equipped';

  @override
  String get townOwned => 'Owned';

  @override
  String get townLearned => 'Learned';

  @override
  String get townLearn => 'Learn';

  @override
  String get townCatalogueUnavailable =>
      'The catalogue is unavailable. Return to town and reconnect to load it.';

  @override
  String get townNoMatchingEntries => 'No entries match these filters.';

  @override
  String townCategory({
    required String character,
    required String service,
    required String slot,
  }) {
    String _temp0 = intl.Intl.selectLogic(character, {
      'bountyHunter': 'Bomb kits',
      'other': 'Shields',
    });
    String _temp1 = intl.Intl.selectLogic(character, {
      'bountyHunter': 'Field kits',
      'other': 'Spellbooks',
    });
    String _temp2 = intl.Intl.selectLogic(character, {
      'bountyHunter': 'Ranged weapons',
      'other': 'Ranged spells',
    });
    String _temp3 = intl.Intl.selectLogic(service, {
      'training': 'Ranged techniques',
      'other': '$_temp2',
    });
    String _temp4 = intl.Intl.selectLogic(character, {
      'bountyHunter': 'Fieldcraft',
      'other': 'Spells',
    });
    String _temp5 = intl.Intl.selectLogic(slot, {
      'mainWeapon': 'Weapons',
      'offhandWeapon': '$_temp0',
      'spellBook': '$_temp1',
      'accessory': 'Accessories',
      'primary': 'Primary',
      'secondary': 'Secondary',
      'projectile': '$_temp3',
      'mobility': 'Mobility',
      'jump': 'Jump',
      'spell': '$_temp4',
      'other': 'Equipment',
    });
    return '$_temp5';
  }

  @override
  String get runMissionCompleted => 'Mission complete';

  @override
  String get runMissionFailed => 'Mission failed';

  @override
  String get campaignHeading => 'Campaign';

  @override
  String get campaignRegionalMap => 'Regional map';

  @override
  String get campaignChapterReward => 'Chapter completion rewards';

  @override
  String campaignFirstClearXp({required int xp}) {
    return 'First clear: $xp XP';
  }

  @override
  String get campaignDoubleJumpReward => 'Unlock double jump';

  @override
  String get campaignCollectedGold =>
      'Keep collected gold on every verified attempt';

  @override
  String campaignBestScore({required int score}) {
    return 'Best score: $score';
  }

  @override
  String get campaignLocked => 'Locked';

  @override
  String get campaignComingSoon => 'Coming soon';

  @override
  String get campaignWillowLocked =>
      'Complete the Val Outpost chapter to unlock Willow';

  @override
  String get campaignVerificationPending =>
      'Your clear and first-clear rewards unlock after verification.';

  @override
  String get campaignNextMission => 'Next mission';

  @override
  String campaignObjectives({required int completed, required int required}) {
    return 'Objectives: $completed/$required';
  }

  @override
  String get campaignReachExit => 'Reach the exit';

  @override
  String get campaignEquipDoubleJump => 'Equip double jump for Éloïse';

  @override
  String get campaignDoubleJumpEquipped => 'Double jump equipped';

  @override
  String get campaignEquipFailed => 'Could not equip double jump. Try again.';

  @override
  String get campaignWillowUnlocked => 'Chapter complete — Willow unlocked';

  @override
  String campaignChapterRewardAmounts({required int xp, required int gold}) {
    return '$xp XP · $gold gold';
  }

  @override
  String get campaignChapterRewardsGranted => 'Chapter rewards received.';

  @override
  String campaignCollectCoin({required int collected}) {
    return 'Collect a coin $collected/1';
  }

  @override
  String get codexCombatAdvice => 'Combat advice';

  @override
  String get codexInnateDefences => 'Innate defences';

  @override
  String get codexBoss => 'Boss';

  @override
  String get codexNoInnateModifiers => 'None';

  @override
  String codexAttackDetails({required String category, required String types}) {
    return '$category · $types damage';
  }

  @override
  String get codexGrojibRole => 'Ground pursuer';

  @override
  String get codexGrojibAdvice => 'Leave room for the second swing.';

  @override
  String get codexHashashRole => 'Teleporting assassin';

  @override
  String get codexHashashAdvice => 'Watch for its return before committing.';

  @override
  String get codexDerfRole => 'Transforming caster';

  @override
  String get codexDerfAdvice => 'Allow for the reach of its extended tentacle.';

  @override
  String get codexUnocoRole => 'Flying caster';

  @override
  String get codexUnocoAdvice => 'Keep moving while its projectile is aimed.';

  @override
  String get codexBringerRole => 'Scythe fighter';

  @override
  String get codexBringerAdvice =>
      'Read the wind-up and move clear of the marked ground.';

  @override
  String get codexGoddessRole => 'Claw and orb fighter';

  @override
  String get codexGoddessAdvice => 'Reposition when the arena is threatened.';

  @override
  String get codexShoggothRole => 'Tentacled summoner';

  @override
  String get codexShoggothAdvice =>
      'Manage the smaller threats while watching the boss.';

  @override
  String get codexVoidcallerRole => 'Beam caster';

  @override
  String get codexVoidcallerAdvice =>
      'Keep a route out of overlapping attacks.';

  @override
  String get codexShoggothMinionRole => 'Summoned ground attacker';

  @override
  String get codexShoggothMinionAdvice =>
      'Avoid being crowded while the boss attacks.';

  @override
  String get codexVoidTentacleRole => 'Summoned melee attacker';

  @override
  String get hubRunnerHeading => 'Runner';

  @override
  String get hubRunnerPlay => 'Play Runner';

  @override
  String get hubCampaignPlay => 'Play Campaign';

  @override
  String get hubChangeBuild => 'Change build';

  @override
  String get hubLocalPractice => 'Local practice';

  @override
  String get hubWeeklyPlay => 'Play';

  @override
  String get codexVoidTentacleAdvice =>
      'Move beyond its lash before turning to attack it.';

  @override
  String campaignReceiveBlessing({required int received}) {
    return 'Receive a blessing $received/1';
  }

  @override
  String get journalEmpty => 'No journal entries yet.';
}
