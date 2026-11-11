import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr'),
  ];

  /// Application title. The product name is not translated.
  ///
  /// In en, this message translates to:
  /// **'Lothringen: The Long Run'**
  String get appTitle;

  /// This language’s own name, shown in the language picker.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageName;

  /// Language preference heading.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageLabel;

  /// Language preference write failed; the previous language stays selected.
  ///
  /// In en, this message translates to:
  /// **'Could not save the language. Please try again.'**
  String get languageSaveFailed;

  /// Options page title.
  ///
  /// In en, this message translates to:
  /// **'Options'**
  String get optionsTitle;

  /// Settings tab in the options page.
  ///
  /// In en, this message translates to:
  /// **'SETTINGS'**
  String get optionsSettingsTab;

  /// Controls tab in the options page.
  ///
  /// In en, this message translates to:
  /// **'CONTROLS'**
  String get optionsControlsTab;

  /// Movement control settings heading.
  ///
  /// In en, this message translates to:
  /// **'Movement'**
  String get movementTitle;

  /// Movement control option using two arrow buttons.
  ///
  /// In en, this message translates to:
  /// **'Arrows'**
  String get movementArrows;

  /// Joystick positioned around the initial touch.
  ///
  /// In en, this message translates to:
  /// **'Floating joystick'**
  String get movementFloatingJoystick;

  /// Joystick with a fixed position.
  ///
  /// In en, this message translates to:
  /// **'Fixed joystick'**
  String get movementFixedJoystick;

  /// Explanation of movement preferences; no option changes gameplay speed.
  ///
  /// In en, this message translates to:
  /// **'Choose how to move backward and forward. All controls use the same movement speed.'**
  String get movementHelp;

  /// Arrow movement instructions.
  ///
  /// In en, this message translates to:
  /// **'Hold an arrow to move in that direction.'**
  String get movementArrowsHelp;

  /// Floating joystick instructions.
  ///
  /// In en, this message translates to:
  /// **'The joystick follows your touch within the left third of the screen.'**
  String get movementFloatingHelp;

  /// Fixed joystick instructions.
  ///
  /// In en, this message translates to:
  /// **'The joystick stays in the lower-left corner. Drag its thumb left or right to move.'**
  String get movementFixedHelp;

  /// Movement preference write failed.
  ///
  /// In en, this message translates to:
  /// **'Could not save controls. Please try again.'**
  String get controlsSaveFailed;

  /// Local development profile toggle.
  ///
  /// In en, this message translates to:
  /// **'Developer mode'**
  String get developerModeTitle;

  /// Developer profile has no online rewards.
  ///
  /// In en, this message translates to:
  /// **'Local profile with all equipment and abilities. Practice and campaign play; no account rewards.'**
  String get developerModeHelp;

  /// Browser build always runs locally.
  ///
  /// In en, this message translates to:
  /// **'Developer Practice: local play with all equipment and abilities. Account features are unavailable in this build.'**
  String get developerPracticeHelp;

  /// Failure switching to the local development profile.
  ///
  /// In en, this message translates to:
  /// **'Could not open Developer mode. Please try again.'**
  String get developerModeFailed;

  /// Failure switching back to the online account.
  ///
  /// In en, this message translates to:
  /// **'Could not load your account. Check your connection and try again.'**
  String get accountLoadFailed;

  /// Link to the privacy policy.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get privacyPolicy;

  /// Link that opens the support email.
  ///
  /// In en, this message translates to:
  /// **'Contact support'**
  String get contactSupport;

  /// External link could not be opened.
  ///
  /// In en, this message translates to:
  /// **'Could not open {url}. You can open it manually.'**
  String openLinkFailed({required String url});

  /// A rejected reward preview has been reconciled with confirmed account totals.
  ///
  /// In en, this message translates to:
  /// **'This run’s rewards could not be confirmed. Your totals have been updated.'**
  String get rewardsCorrected;

  /// Run HUD text. Click or press Enter to start
  ///
  /// In en, this message translates to:
  /// **'Click or press Enter to start'**
  String get desktopStartHint;

  /// Run HUD text. Tap to start
  ///
  /// In en, this message translates to:
  /// **'Tap to start'**
  String get touchStartHint;

  /// Run HUD text. Survive as long as possible
  ///
  /// In en, this message translates to:
  /// **'Survive as long as possible'**
  String get survivalGoal;

  /// Run HUD text. Want to exit?
  ///
  /// In en, this message translates to:
  /// **'Want to exit?'**
  String get exitRunQuestion;

  /// Run HUD text. Resume
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get commonResume;

  /// Run HUD text. Exit
  ///
  /// In en, this message translates to:
  /// **'Exit'**
  String get commonExit;

  /// Run HUD text. Preparing the path…
  ///
  /// In en, this message translates to:
  /// **'Preparing the path…'**
  String get terrainPreparing;

  /// Run HUD text. Unable to prepare the path
  ///
  /// In en, this message translates to:
  /// **'Unable to prepare the path'**
  String get terrainFailed;

  /// Run HUD text. Your run is held here. Retry to continue.
  ///
  /// In en, this message translates to:
  /// **'Your run is held here. Retry to continue.'**
  String get terrainRetryHelp;

  /// Run HUD text. Retry
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// Run HUD text. Riposte ready · release to counter
  ///
  /// In en, this message translates to:
  /// **'Riposte ready · release to counter'**
  String get riposteReady;

  /// Run HUD text. Play
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get commonPlay;

  /// Run HUD text. Pause
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get commonPause;

  /// Run HUD text. Exit game
  ///
  /// In en, this message translates to:
  /// **'Exit game'**
  String get exitGameTooltip;

  /// Run HUD text. Game Over
  ///
  /// In en, this message translates to:
  /// **'Game Over'**
  String get gameOverTitle;

  /// Keyboard/mouse binding shown in the run HUD. Translate key names but preserve the actual letters and assigned inputs.
  ///
  /// In en, this message translates to:
  /// **'Space / W / Up'**
  String get keyJump;

  /// Keyboard/mouse binding shown in the run HUD. Translate key names but preserve the actual letters and assigned inputs.
  ///
  /// In en, this message translates to:
  /// **'Shift'**
  String get keyMobility;

  /// Keyboard/mouse binding shown in the run HUD. Translate key names but preserve the actual letters and assigned inputs.
  ///
  /// In en, this message translates to:
  /// **'LMB / J'**
  String get keyPrimary;

  /// Keyboard/mouse binding shown in the run HUD. Translate key names but preserve the actual letters and assigned inputs.
  ///
  /// In en, this message translates to:
  /// **'Q'**
  String get keySecondary;

  /// Keyboard/mouse binding shown in the run HUD. Translate key names but preserve the actual letters and assigned inputs.
  ///
  /// In en, this message translates to:
  /// **'RMB / K'**
  String get keyProjectile;

  /// Keyboard/mouse binding shown in the run HUD. Translate key names but preserve the actual letters and assigned inputs.
  ///
  /// In en, this message translates to:
  /// **'E / L'**
  String get keySpell;

  /// Run HUD text. Unavailable
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get abilityUnavailable;

  /// Run HUD text. Low resource
  ///
  /// In en, this message translates to:
  /// **'Low resource'**
  String get abilityLowResource;

  /// Run HUD text. Follow-up
  ///
  /// In en, this message translates to:
  /// **'Follow-up'**
  String get abilityFollowUp;

  /// Run HUD text. Ready
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get abilityReady;

  /// Run HUD text. A / D or arrows: Move | Mouse: Aim | Esc / P: Pause | Enter: Resume
  ///
  /// In en, this message translates to:
  /// **'A / D or arrows: Move | Mouse: Aim | Esc / P: Pause | Enter: Resume'**
  String get desktopControlsHelp;

  /// Run HUD text. Regeneration increased
  ///
  /// In en, this message translates to:
  /// **'Regeneration increased'**
  String get regenerationIncreased;

  /// Canonical in-world blessing name; keep its French spelling in every language.
  ///
  /// In en, this message translates to:
  /// **'Bénédiction des Dames de la forêt'**
  String get forestBlessingName;

  /// Run HUD text. Encounter ended
  ///
  /// In en, this message translates to:
  /// **'Encounter ended'**
  String get bossEncounterEnded;

  /// Boss entrance caption. Enemy is the localized name.
  ///
  /// In en, this message translates to:
  /// **'{enemy} awakens'**
  String bossAwakens({required String enemy});

  /// Screen-reader description of the boss health bar.
  ///
  /// In en, this message translates to:
  /// **'{caption}, {health} health'**
  String bossHealthSemantics({required String caption, required int health});

  /// Screen-reader announcement of a boss-victory restoration.
  ///
  /// In en, this message translates to:
  /// **'{caption}, {percent} percent health, mana and stamina restored'**
  String bossRestorationSemantics({
    required String caption,
    required int percent,
  });

  /// Compact boss victory restoration. Percent is a percentage value, not a fraction.
  ///
  /// In en, this message translates to:
  /// **'+{percent}% health · mana · stamina'**
  String bossRestoration({required int percent});

  /// Screen-reader description of the persistent blessing; retain the canonical French blessing name.
  ///
  /// In en, this message translates to:
  /// **'Bénédiction des Dames de la forêt: health, mana and stamina regeneration increased until the end of the level'**
  String get regenerationBlessingSemantics;

  /// Remaining counterattack availability in seconds; always one decimal place.
  ///
  /// In en, this message translates to:
  /// **'Riposte · {seconds}s'**
  String riposteCountdown({required double seconds});

  /// Compact cooldown, in seconds with one decimal place.
  ///
  /// In en, this message translates to:
  /// **'{seconds}s'**
  String secondsShort({required double seconds});

  /// Final run score.
  ///
  /// In en, this message translates to:
  /// **'Score: {score}'**
  String scoreValue({required int score});

  /// Current charge completion; integer percentage, not a fraction.
  ///
  /// In en, this message translates to:
  /// **'Charge {percent}%'**
  String chargePercent({required int percent});

  /// Screen-reader ability binding status. All parameters are localized labels.
  ///
  /// In en, this message translates to:
  /// **'{ability}, {binding}, {status}'**
  String abilityBindingSemantics({
    required String ability,
    required String binding,
    required String status,
  });

  /// Gear and ability selection presentation. Values are formatted from authoritative Core data.
  ///
  /// In en, this message translates to:
  /// **'Weapons'**
  String get projectileWeapons;

  /// Gear and ability selection presentation. Values are formatted from authoritative Core data.
  ///
  /// In en, this message translates to:
  /// **'Spell List'**
  String get projectileSpellList;

  /// Gear and ability selection presentation. Values are formatted from authoritative Core data.
  ///
  /// In en, this message translates to:
  /// **'This gear is currently equipped.'**
  String get gearCompareEquipped;

  /// Gear and ability selection presentation. Values are formatted from authoritative Core data.
  ///
  /// In en, this message translates to:
  /// **'No stat differences.'**
  String get gearCompareSame;

  /// Gear and ability selection presentation. Values are formatted from authoritative Core data.
  ///
  /// In en, this message translates to:
  /// **'On Hit'**
  String get gearOnHit;

  /// Gear and ability selection presentation. Values are formatted from authoritative Core data.
  ///
  /// In en, this message translates to:
  /// **'On Crit'**
  String get gearOnCrit;

  /// Gear and ability selection presentation. Values are formatted from authoritative Core data.
  ///
  /// In en, this message translates to:
  /// **'On Kill'**
  String get gearOnKill;

  /// Gear and ability selection presentation. Values are formatted from authoritative Core data.
  ///
  /// In en, this message translates to:
  /// **'On Block'**
  String get gearOnBlock;

  /// Gear and ability selection presentation. Values are formatted from authoritative Core data.
  ///
  /// In en, this message translates to:
  /// **'On Damaged'**
  String get gearOnDamaged;

  /// Gear and ability selection presentation. Values are formatted from authoritative Core data.
  ///
  /// In en, this message translates to:
  /// **'On Low Health'**
  String get gearOnLowHealth;

  /// Gear and ability selection presentation. Values are formatted from authoritative Core data.
  ///
  /// In en, this message translates to:
  /// **'Lose: {effects}'**
  String gearCompareLose({required String effects});

  /// Gear and ability selection presentation. Values are formatted from authoritative Core data.
  ///
  /// In en, this message translates to:
  /// **'Add: {effects}'**
  String gearCompareAdd({required String effects});

  /// Gear and ability selection presentation. Values are formatted from authoritative Core data.
  ///
  /// In en, this message translates to:
  /// **'Applies {status}, dealing {damage} damage per second for {duration}{chanceKind, select, guaranteed{.} other{ ({chance} chance).}}'**
  String gearProcDot({
    required String status,
    required String damage,
    required String duration,
    required String chance,
    required String chanceKind,
  });

  /// Gear and ability selection presentation. Values are formatted from authoritative Core data.
  ///
  /// In en, this message translates to:
  /// **'Applies Slow, reducing move speed by {amount} for {duration}{chanceKind, select, guaranteed{.} other{ ({chance} chance).}}'**
  String gearProcSlow({
    required String amount,
    required String duration,
    required String chance,
    required String chanceKind,
  });

  /// Gear and ability selection presentation. Values are formatted from authoritative Core data.
  ///
  /// In en, this message translates to:
  /// **'Applies Stun for {duration}{chanceKind, select, guaranteed{.} other{ ({chance} chance).}}'**
  String gearProcStun({
    required String duration,
    required String chance,
    required String chanceKind,
  });

  /// Gear and ability selection presentation. Values are formatted from authoritative Core data.
  ///
  /// In en, this message translates to:
  /// **'Applies Silence for {duration}{chanceKind, select, guaranteed{.} other{ ({chance} chance).}}'**
  String gearProcSilence({
    required String duration,
    required String chance,
    required String chanceKind,
  });

  /// Gear and ability selection presentation. Values are formatted from authoritative Core data.
  ///
  /// In en, this message translates to:
  /// **'Applies Vulnerable, increasing damage taken by {amount} for {duration}{chanceKind, select, guaranteed{.} other{ ({chance} chance).}}'**
  String gearProcVulnerable({
    required String amount,
    required String duration,
    required String chance,
    required String chanceKind,
  });

  /// Gear and ability selection presentation. Values are formatted from authoritative Core data.
  ///
  /// In en, this message translates to:
  /// **'Applies Weaken, reducing outgoing damage by {amount} for {duration}{chanceKind, select, guaranteed{.} other{ ({chance} chance).}}'**
  String gearProcWeaken({
    required String amount,
    required String duration,
    required String chance,
    required String chanceKind,
  });

  /// Gear and ability selection presentation. Values are formatted from authoritative Core data.
  ///
  /// In en, this message translates to:
  /// **'Applies Drench, reducing attack and cast speed by {amount} for {duration}{chanceKind, select, guaranteed{.} other{ ({chance} chance).}}'**
  String gearProcDrench({
    required String amount,
    required String duration,
    required String chance,
    required String chanceKind,
  });

  /// Gear and ability selection presentation. Values are formatted from authoritative Core data.
  ///
  /// In en, this message translates to:
  /// **'Applies Haste, increasing move speed by {amount} for {duration}{chanceKind, select, guaranteed{.} other{ ({chance} chance).}}'**
  String gearProcHaste({
    required String amount,
    required String duration,
    required String chance,
    required String chanceKind,
  });

  /// Gear and ability selection presentation. Values are formatted from authoritative Core data.
  ///
  /// In en, this message translates to:
  /// **'Applies Damage Reduction, reducing incoming direct-hit damage by {amount} for {duration}{chanceKind, select, guaranteed{.} other{ ({chance} chance).}}'**
  String gearProcDamageReduction({
    required String amount,
    required String duration,
    required String chance,
    required String chanceKind,
  });

  /// Gear and ability selection presentation. Values are formatted from authoritative Core data.
  ///
  /// In en, this message translates to:
  /// **'Restores {resource} by {amount} over {duration}{chanceKind, select, guaranteed{.} other{ ({chance} chance).}}'**
  String gearProcRestore({
    required String resource,
    required String amount,
    required String duration,
    required String chance,
    required String chanceKind,
  });

  /// Gear and ability selection presentation. Values are formatted from authoritative Core data.
  ///
  /// In en, this message translates to:
  /// **'Restores {resource} by {amount} immediately{chanceKind, select, guaranteed{.} other{ ({chance} chance).}}'**
  String gearProcRestoreInstant({
    required String resource,
    required String amount,
    required String chance,
    required String chanceKind,
  });

  /// Gear and ability selection presentation. Values are formatted from authoritative Core data.
  ///
  /// In en, this message translates to:
  /// **'Restores {resource} by {amount} immediately and another {amount} over {duration}{chanceKind, select, guaranteed{.} other{ ({chance} chance).}}'**
  String gearProcRestoreBoth({
    required String resource,
    required String amount,
    required String duration,
    required String chance,
    required String chanceKind,
  });

  /// Gear and ability selection presentation. Values are formatted from authoritative Core data.
  ///
  /// In en, this message translates to:
  /// **'{critKind, select, withCrit{Applies an Offense Buff, increasing power by {amount} and critical chance by {crit} for {duration}} other{Applies an Offense Buff, increasing power by {amount} for {duration}}}{chanceKind, select, guaranteed{.} other{ ({chance} chance).}}'**
  String gearProcOffense({
    required String amount,
    required String crit,
    required String critKind,
    required String duration,
    required String chance,
    required String chanceKind,
  });

  /// Ability tooltip. Complete sentences; values are locale-formatted authoritative Core numbers or localized catalog names.
  ///
  /// In en, this message translates to:
  /// **'{aim, select, aimed{Unleash a sword slash that deals {damage} damage to enemies in aiming direction and in the attack reach.} other{Launch an attack that deals {damage} damage to the closest enemy and all those who are in the attack reach.}}{dotKind, select, withDot{ It causes {status}, dealing {dotDamage} damage per second for {duration} seconds.} other{}}'**
  String abilityMelee({
    required String aim,
    required String damage,
    required String dotKind,
    required String status,
    required String dotDamage,
    required String duration,
  });

  /// Ability tooltip. Complete sentences; values are locale-formatted authoritative Core numbers or localized catalog names.
  ///
  /// In en, this message translates to:
  /// **'Keep your guard up and reduce direct-hit damage by {reduction}% from any direction while held. Existing damage-over-time and ground spell impacts bypass the shield.{riposteKind, select, withRiposte{ The first guarded hit grants {riposte}, empowering your next landed melee hit by +{riposteBonus}% damage. It stays ready while this guard is held and expires 1 second after guard ends. Misses do not consume it.} other{}}'**
  String abilityGuard({
    required String reduction,
    required String riposteKind,
    required String riposte,
    required String riposteBonus,
  });

  /// Ability tooltip. Complete sentences; values are locale-formatted authoritative Core numbers or localized catalog names.
  ///
  /// In en, this message translates to:
  /// **'Dash a short distance. Tap again within {window} seconds after the first burst to dash again in your chosen direction. Each burst pays the listed cost; cooldown starts with the first. Does not grant invulnerability.'**
  String abilityDoubleDash({required String window});

  /// Ability tooltip. Complete sentences; values are locale-formatted authoritative Core numbers or localized catalog names.
  ///
  /// In en, this message translates to:
  /// **'Aim and release for {tapDamage} damage. Hold for {chargeTime} seconds to deal {fullDamage} damage, gain +{crit}% critical chance and inflict {status} ({dotDamage} damage per second for {duration} seconds). Only full charge grants this bleed. This attack can be interrupted by taking damage.'**
  String abilityCleave({
    required String tapDamage,
    required String chargeTime,
    required String fullDamage,
    required String crit,
    required String status,
    required String dotDamage,
    required String duration,
  });

  /// Ability tooltip. Complete sentences; values are locale-formatted authoritative Core numbers or localized catalog names.
  ///
  /// In en, this message translates to:
  /// **'Fire {source, select, spell{the selected spell projectile} other{your equipped projectile}}{projectileName}, it deals {damage} damage to the closest enemy.'**
  String abilitySnap({
    required String source,
    required String projectileName,
    required String damage,
  });

  /// Ability tooltip. Complete sentences; values are locale-formatted authoritative Core numbers or localized catalog names.
  ///
  /// In en, this message translates to:
  /// **'Aim and fire {source, select, spell{the selected spell projectile} other{your equipped projectile}}{projectileName}. It deals {damage} damage to a single target.'**
  String abilityQuick({
    required String source,
    required String projectileName,
    required String damage,
  });

  /// Ability tooltip. Complete sentences; values are locale-formatted authoritative Core numbers or localized catalog names.
  ///
  /// In en, this message translates to:
  /// **'Charge and release {source, select, spell{the selected spell projectile} other{your equipped projectile}}{projectileName}. It deals {damage} damage to a single target. Charging increases damage (up to +{damageBonus}%) and critical chance (up to +{critBonus}%). Full charge takes {chargeTime} seconds. This attack can be interrupted by taking damage.'**
  String abilityOvercharge({
    required String source,
    required String projectileName,
    required String damage,
    required String damageBonus,
    required String critBonus,
    required String chargeTime,
  });

  /// Ability tooltip. Complete sentences; values are locale-formatted authoritative Core numbers or localized catalog names.
  ///
  /// In en, this message translates to:
  /// **'Fire {source, select, spell{the selected spell projectile} other{your equipped projectile}}{projectileName}, piercing through enemies in its path. It deals {damage} damage and can hit up to {maxHits} enemies.'**
  String abilitySkewer({
    required String source,
    required String projectileName,
    required String damage,
    required String maxHits,
  });

  /// Ability tooltip. Complete sentences; values are locale-formatted authoritative Core numbers or localized catalog names.
  ///
  /// In en, this message translates to:
  /// **'Perform a concussive roll. Enemies hit are affected by {status}. Does not grant invulnerability.'**
  String abilityRoll({required String status});

  /// Ability tooltip. Complete sentences; values are locale-formatted authoritative Core numbers or localized catalog names.
  ///
  /// In en, this message translates to:
  /// **'Tap to strike in front of you.'**
  String get abilityStrike;

  /// Ability tooltip. Complete sentences; values are locale-formatted authoritative Core numbers or localized catalog names.
  ///
  /// In en, this message translates to:
  /// **'Hold then release to cast a ranged bolt.'**
  String get abilityCast;

  /// Ability tooltip. Complete sentences; values are locale-formatted authoritative Core numbers or localized catalog names.
  ///
  /// In en, this message translates to:
  /// **'Tap to jump.'**
  String get abilityJump;

  /// Ability tooltip. Complete sentences; values are locale-formatted authoritative Core numbers or localized catalog names.
  ///
  /// In en, this message translates to:
  /// **'Tap to jump, then tap again in the air for a second jump.'**
  String get abilityDoubleJump;

  /// Ability tooltip. Complete sentences; values are locale-formatted authoritative Core numbers or localized catalog names.
  ///
  /// In en, this message translates to:
  /// **'Tap to use this ability.'**
  String get abilityUse;

  /// Ability tooltip. Complete sentences; values are locale-formatted authoritative Core numbers or localized catalog names.
  ///
  /// In en, this message translates to:
  /// **'Dash forward quickly. Does not grant invulnerability.'**
  String get abilityDash;

  /// Ability tooltip. Complete sentences; values are locale-formatted authoritative Core numbers or localized catalog names.
  ///
  /// In en, this message translates to:
  /// **'Cost for first jump: '**
  String get abilityCostFirstJump;

  /// Ability tooltip. Complete sentences; values are locale-formatted authoritative Core numbers or localized catalog names.
  ///
  /// In en, this message translates to:
  /// **'Cost for second jump: '**
  String get abilityCostSecondJump;

  /// Ability tooltip. Complete sentences; values are locale-formatted authoritative Core numbers or localized catalog names.
  ///
  /// In en, this message translates to:
  /// **'Cost per second: '**
  String get abilityCostSecond;

  /// Ability tooltip. Complete sentences; values are locale-formatted authoritative Core numbers or localized catalog names.
  ///
  /// In en, this message translates to:
  /// **'Cost: '**
  String get abilityCost;

  /// Ability tooltip. Complete sentences; values are locale-formatted authoritative Core numbers or localized catalog names.
  ///
  /// In en, this message translates to:
  /// **'Bleed'**
  String get abilityBleed;

  /// Ability tooltip. Complete sentences; values are locale-formatted authoritative Core numbers or localized catalog names.
  ///
  /// In en, this message translates to:
  /// **'Burn'**
  String get abilityBurn;

  /// Ability tooltip. Complete sentences; values are locale-formatted authoritative Core numbers or localized catalog names.
  ///
  /// In en, this message translates to:
  /// **'Acid'**
  String get abilityAcid;

  /// Ability tooltip. Complete sentences; values are locale-formatted authoritative Core numbers or localized catalog names.
  ///
  /// In en, this message translates to:
  /// **'Stun'**
  String get abilityStun;

  /// Ability tooltip. Complete sentences; values are locale-formatted authoritative Core numbers or localized catalog names.
  ///
  /// In en, this message translates to:
  /// **'damage over time'**
  String get abilityDamageOverTime;

  /// Ability tooltip. Complete sentences; values are locale-formatted authoritative Core numbers or localized catalog names.
  ///
  /// In en, this message translates to:
  /// **'Control'**
  String get abilityControl;

  /// Ability tooltip. Complete sentences; values are locale-formatted authoritative Core numbers or localized catalog names.
  ///
  /// In en, this message translates to:
  /// **'Haste'**
  String get abilityHaste;

  /// Ability tooltip. Complete sentences; values are locale-formatted authoritative Core numbers or localized catalog names.
  ///
  /// In en, this message translates to:
  /// **'Arcane Ward'**
  String get abilityWard;

  /// Ability tooltip. Complete sentences; values are locale-formatted authoritative Core numbers or localized catalog names.
  ///
  /// In en, this message translates to:
  /// **'Health Regen'**
  String get abilityHealthRegen;

  /// Ability tooltip. Complete sentences; values are locale-formatted authoritative Core numbers or localized catalog names.
  ///
  /// In en, this message translates to:
  /// **'Mana Regen'**
  String get abilityManaRegen;

  /// Ability tooltip. Complete sentences; values are locale-formatted authoritative Core numbers or localized catalog names.
  ///
  /// In en, this message translates to:
  /// **'Stamina Regen'**
  String get abilityStaminaRegen;

  /// Ability tooltip. Complete sentences; values are locale-formatted authoritative Core numbers or localized catalog names.
  ///
  /// In en, this message translates to:
  /// **'Resource Regen'**
  String get abilityResourceRegen;

  /// Ability tooltip. Complete sentences; values are locale-formatted authoritative Core numbers or localized catalog names.
  ///
  /// In en, this message translates to:
  /// **'Focus'**
  String get abilityFocus;

  /// Ability tooltip. Complete sentences; values are locale-formatted authoritative Core numbers or localized catalog names.
  ///
  /// In en, this message translates to:
  /// **'Status Effect'**
  String get abilityStatusEffect;

  /// Ability tooltip. Complete sentences; values are locale-formatted authoritative Core numbers or localized catalog names.
  ///
  /// In en, this message translates to:
  /// **'max Health'**
  String get abilityMaxHealth;

  /// Ability tooltip. Complete sentences; values are locale-formatted authoritative Core numbers or localized catalog names.
  ///
  /// In en, this message translates to:
  /// **'max Mana'**
  String get abilityMaxMana;

  /// Ability tooltip. Complete sentences; values are locale-formatted authoritative Core numbers or localized catalog names.
  ///
  /// In en, this message translates to:
  /// **'max Stamina'**
  String get abilityMaxStamina;

  /// Ability tooltip. Complete sentences; values are locale-formatted authoritative Core numbers or localized catalog names.
  ///
  /// In en, this message translates to:
  /// **'max resource'**
  String get abilityMaxResource;

  /// Ability tooltip. Complete sentences; values are locale-formatted authoritative Core numbers or localized catalog names.
  ///
  /// In en, this message translates to:
  /// **'DAMAGE'**
  String get abilityBadgeDamage;

  /// Ability tooltip. Complete sentences; values are locale-formatted authoritative Core numbers or localized catalog names.
  ///
  /// In en, this message translates to:
  /// **'DEFENSE'**
  String get abilityBadgeDefense;

  /// Ability tooltip. Complete sentences; values are locale-formatted authoritative Core numbers or localized catalog names.
  ///
  /// In en, this message translates to:
  /// **'DASH'**
  String get abilityBadgeDash;

  /// Ability tooltip. Complete sentences; values are locale-formatted authoritative Core numbers or localized catalog names.
  ///
  /// In en, this message translates to:
  /// **'JUMP'**
  String get abilityBadgeJump;

  /// Ability tooltip. Complete sentences; values are locale-formatted authoritative Core numbers or localized catalog names.
  ///
  /// In en, this message translates to:
  /// **'HOLD'**
  String get abilityBadgeHold;

  /// Ability tooltip. Complete sentences; values are locale-formatted authoritative Core numbers or localized catalog names.
  ///
  /// In en, this message translates to:
  /// **'UTILITY'**
  String get abilityBadgeUtility;

  /// Ability tooltip. Complete sentences; values are locale-formatted authoritative Core numbers or localized catalog names.
  ///
  /// In en, this message translates to:
  /// **'CONTROL'**
  String get abilityBadgeControl;

  /// Ability tooltip. Complete sentences; values are locale-formatted authoritative Core numbers or localized catalog names.
  ///
  /// In en, this message translates to:
  /// **'CHARGED'**
  String get abilityBadgeCharged;

  /// Ability tooltip. Complete sentences; values are locale-formatted authoritative Core numbers or localized catalog names.
  ///
  /// In en, this message translates to:
  /// **'AUTO-AIM'**
  String get abilityBadgeAutoAim;

  /// Ability tooltip. Complete sentences; values are locale-formatted authoritative Core numbers or localized catalog names.
  ///
  /// In en, this message translates to:
  /// **'AIM'**
  String get abilityBadgeAim;

  /// Ability tooltip. Complete sentences; values are locale-formatted authoritative Core numbers or localized catalog names.
  ///
  /// In en, this message translates to:
  /// **'Increase move speed by {speedBonus}% for {duration} seconds.'**
  String abilitySelfHaste({
    required String speedBonus,
    required String duration,
  });

  /// Ability tooltip. Complete sentences; values are locale-formatted authoritative Core numbers or localized catalog names.
  ///
  /// In en, this message translates to:
  /// **'Reduce direct-hit damage by {mitigation}% and cancel damage-over-time effects for {duration} seconds.'**
  String abilitySelfWard({
    required String mitigation,
    required String duration,
  });

  /// Ability tooltip. Complete sentences; values are locale-formatted authoritative Core numbers or localized catalog names.
  ///
  /// In en, this message translates to:
  /// **'Restore {restorePct}% of {resourceLabel} immediately and another {restorePct}% over {duration} seconds.'**
  String abilityRestoreBoth({
    required String restorePct,
    required String resourceLabel,
    required String duration,
  });

  /// Ability tooltip. Complete sentences; values are locale-formatted authoritative Core numbers or localized catalog names.
  ///
  /// In en, this message translates to:
  /// **'Restore {restorePct}% of {resourceLabel} immediately.'**
  String abilityRestoreInstant({
    required String restorePct,
    required String resourceLabel,
  });

  /// Ability tooltip. Complete sentences; values are locale-formatted authoritative Core numbers or localized catalog names.
  ///
  /// In en, this message translates to:
  /// **'Restore {restorePct}% of {resourceLabel} over {duration} seconds.'**
  String abilityRestore({
    required String restorePct,
    required String resourceLabel,
    required String duration,
  });

  /// Ability tooltip. Complete sentences; values are locale-formatted authoritative Core numbers or localized catalog names.
  ///
  /// In en, this message translates to:
  /// **'Increase power by {powerBonus}% and critical chance by {critBonus}% for {duration} seconds.'**
  String abilitySelfFocus({
    required String powerBonus,
    required String critBonus,
    required String duration,
  });

  /// Ability tooltip. Complete sentences; values are locale-formatted authoritative Core numbers or localized catalog names.
  ///
  /// In en, this message translates to:
  /// **'Apply {statusLabel} for {duration} seconds.'**
  String abilitySelfStatus({
    required String statusLabel,
    required String duration,
  });

  /// Ability tooltip. Complete sentences; values are locale-formatted authoritative Core numbers or localized catalog names.
  ///
  /// In en, this message translates to:
  /// **'Cleanse all active debuffs, including stun, silence, slow, vulnerability, weaken, drench, and damage-over-time effects.'**
  String get abilityCleanse;

  /// Ability tooltip. Complete sentences; values are locale-formatted authoritative Core numbers or localized catalog names.
  ///
  /// In en, this message translates to:
  /// **'stun'**
  String get cleanseStun;

  /// Ability tooltip. Complete sentences; values are locale-formatted authoritative Core numbers or localized catalog names.
  ///
  /// In en, this message translates to:
  /// **'silence'**
  String get cleanseSilence;

  /// Ability tooltip. Complete sentences; values are locale-formatted authoritative Core numbers or localized catalog names.
  ///
  /// In en, this message translates to:
  /// **'slow'**
  String get cleanseSlow;

  /// Ability tooltip. Complete sentences; values are locale-formatted authoritative Core numbers or localized catalog names.
  ///
  /// In en, this message translates to:
  /// **'vulnerability'**
  String get cleanseVulnerability;

  /// Ability tooltip. Complete sentences; values are locale-formatted authoritative Core numbers or localized catalog names.
  ///
  /// In en, this message translates to:
  /// **'weaken'**
  String get cleanseWeaken;

  /// Ability tooltip. Complete sentences; values are locale-formatted authoritative Core numbers or localized catalog names.
  ///
  /// In en, this message translates to:
  /// **'drench'**
  String get cleanseDrench;

  /// Ability tooltip. Complete sentences; values are locale-formatted authoritative Core numbers or localized catalog names.
  ///
  /// In en, this message translates to:
  /// **'damage-over-time'**
  String get cleanseDamageOverTime;

  /// Ability tooltip. Complete sentences; values are locale-formatted authoritative Core numbers or localized catalog names.
  ///
  /// In en, this message translates to:
  /// **'Base damage: {parts}.'**
  String abilityBaseDamage({required String parts});

  /// Ability tooltip. Complete sentences; values are locale-formatted authoritative Core numbers or localized catalog names.
  ///
  /// In en, this message translates to:
  /// **'{value} {resource}'**
  String abilityCostValue({required String value, required String resource});

  /// Ability tooltip. Complete sentences; values are locale-formatted authoritative Core numbers or localized catalog names.
  ///
  /// In en, this message translates to:
  /// **'Riposte'**
  String get abilityRiposte;

  /// Willow ability instructions. French addresses the player with tu. Numeric values come from Core delivery and charge definitions.
  ///
  /// In en, this message translates to:
  /// **'Throw a bomb in an arc at the farthest reachable enemy within {range} units, or lob forward without a target. It explodes on enemy or terrain contact, or {fuse} seconds after release, dealing {damage} damage in a {radius}-unit radius.{effect, select, bleed{ Survivors bleed.} burn{ Survivors burn.} stun{ Stuns susceptible enemies.} other{}} Solid terrain blocks the blast. Uses regenerating Supplies.'**
  String hunterBomb({
    required num range,
    required String fuse,
    required String damage,
    required num radius,
    required String effect,
  });

  /// Willow ability instructions. French addresses the player with tu. Numeric values come from Core delivery and charge definitions.
  ///
  /// In en, this message translates to:
  /// **'Mark the nearest visible enemy within {range} units for {duration} seconds. Your direct attacks deal {bonus}% more damage to that target. No target means no cost or cooldown.'**
  String hunterMark({
    required num range,
    required num duration,
    required num bonus,
  });

  /// Willow ability instructions. French addresses the player with tu. Numeric values come from Core delivery and charge definitions.
  ///
  /// In en, this message translates to:
  /// **'{aim, select, automatic{Auto-aim and fire at a nearby enemy.} other{Aim, then release to fire.}} Deals {damage} base damage{pellets, plural, =1{} other{ divided across {pellets} pellets}}.{piercing, select, yes{ Each projectile can hit up to {maxHits} enemies.} other{}}{charged, select, yes{ Charging increases damage from {minDamage}% to {maxDamage}%, adds up to {crit}% critical chance, and pierces up to {chargeHits} enemies at full charge. Taking damage interrupts the charge.} other{}} Uses regenerating Supplies.'**
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
  });

  /// Willow ability instructions. French addresses the player with tu. Numeric values come from Core delivery and charge definitions.
  ///
  /// In en, this message translates to:
  /// **'Briefly ready your blade, then automatically rush forward while slashing. Hits each enemy in the blade\'s path once for {damage} base damage. A short recovery follows. Solid obstacles stop the lunge. You remain vulnerable throughout.'**
  String hunterLunge({required String damage});

  /// Willow ability instructions. French addresses the player with tu. Numeric values come from Core delivery and charge definitions.
  ///
  /// In en, this message translates to:
  /// **'Strike in front of you {swings, plural, =1{once} other{{swings} times}}, dealing {damage} damage per swing. Each swing can hit every enemy in reach once.'**
  String hunterMelee({required int swings, required String damage});

  /// Willow ability instructions. French addresses the player with tu. Numeric values come from Core delivery and charge definitions.
  ///
  /// In en, this message translates to:
  /// **'Jump, then tap again in the air for a second jump.'**
  String get hunterDoubleJump;

  /// Willow ability instructions. French addresses the player with tu. Numeric values come from Core delivery and charge definitions.
  ///
  /// In en, this message translates to:
  /// **'Blink forward on the ground or in the air, crossing a nearby obstacle up to {width} units wide. Requires a clear landing beyond it. A blocked exit costs nothing. Untouchable only while vanished; damage interrupts preparation and recovery.'**
  String hunterBlink({required num width});

  /// Willow ability instructions. French addresses the player with tu. Numeric values come from Core delivery and charge definitions.
  ///
  /// In en, this message translates to:
  /// **'Dash on the ground or in the air, then tap again within {window} seconds after the first burst ends for a second dash. You can change direction between bursts. Each burst pays the listed cost; cooldown starts with the first. Does not grant invulnerability.'**
  String hunterDoubleDash({required String window});

  /// Willow ability instructions. French addresses the player with tu. Numeric values come from Core delivery and charge definitions.
  ///
  /// In en, this message translates to:
  /// **'Dash forward on the ground or in the air. Does not grant invulnerability.'**
  String get hunterDash;

  /// Status name highlighted in gear effect sentences. Match its spelling in the corresponding full gearProc message.
  ///
  /// In en, this message translates to:
  /// **'Slow'**
  String get gearStatusSlow;

  /// Status name highlighted in gear effect sentences. Match its spelling in the corresponding full gearProc message.
  ///
  /// In en, this message translates to:
  /// **'Stun'**
  String get gearStatusStun;

  /// Status name highlighted in gear effect sentences. Match its spelling in the corresponding full gearProc message.
  ///
  /// In en, this message translates to:
  /// **'Silence'**
  String get gearStatusSilence;

  /// Status name highlighted in gear effect sentences. Match its spelling in the corresponding full gearProc message.
  ///
  /// In en, this message translates to:
  /// **'Vulnerable'**
  String get gearStatusVulnerable;

  /// Status name highlighted in gear effect sentences. Match its spelling in the corresponding full gearProc message.
  ///
  /// In en, this message translates to:
  /// **'Weaken'**
  String get gearStatusWeaken;

  /// Status name highlighted in gear effect sentences. Match its spelling in the corresponding full gearProc message.
  ///
  /// In en, this message translates to:
  /// **'Drench'**
  String get gearStatusDrench;

  /// Status name highlighted in gear effect sentences. Match its spelling in the corresponding full gearProc message.
  ///
  /// In en, this message translates to:
  /// **'Haste'**
  String get gearStatusHaste;

  /// Status name highlighted in gear effect sentences. Match its spelling in the corresponding full gearProc message.
  ///
  /// In en, this message translates to:
  /// **'Damage Reduction'**
  String get gearStatusDamageReduction;

  /// Status name highlighted in gear effect sentences. Match its spelling in the corresponding full gearProc message.
  ///
  /// In en, this message translates to:
  /// **'Offense Buff'**
  String get gearStatusOffenseBuff;

  /// Maximum value of Willow’s regenerating Supplies resource.
  ///
  /// In en, this message translates to:
  /// **'max Supplies'**
  String get abilityMaxSupplies;

  /// Player-facing text on bootstrap/profile_name_setup_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Choose your name'**
  String get uiChooseYourName;

  /// Player-facing text on bootstrap/profile_name_setup_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'This is required. You can change it later in Profile.'**
  String get uiThisIsRequiredYouCanChangeItLaterInProfile;

  /// Player-facing text on bootstrap/profile_name_setup_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get uiDisplayName;

  /// Player-facing text on bootstrap/profile_name_setup_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get uiConfirm;

  /// Player-facing text on components/app_inline_edit_text.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong.'**
  String get uiSomethingWentWrong;

  /// Player-facing text on components/app_inline_edit_text.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get uiEdit;

  /// Player-facing text on pages/selectCharacter/build_name_action.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get uiSave;

  /// Player-facing text on pages/town/town_store_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get uiCancel;

  /// Player-facing text on components/leaderboard_table.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'#Rank'**
  String get uiRank;

  /// Player-facing text on pages/profile/profile_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get uiName;

  /// Player-facing text on components/leaderboard_table.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Lvl'**
  String get uiLvl;

  /// Player-facing text on components/leaderboard_table.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Character'**
  String get uiCharacter;

  /// Player-facing text on components/leaderboard_table.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Score'**
  String get uiScore;

  /// Player-facing text on components/leaderboard_table.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get uiDistance;

  /// Player-facing text on components/leaderboard_table.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get uiTime;

  /// Player-facing text on components/leaderboard_table.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get uiUnknown;

  /// Player-facing text on components/menu_icon_column.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'New activity'**
  String get uiNewActivity;

  /// Player-facing text on components/placeholder_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Coming Soon'**
  String get uiComingSoon;

  /// Player-facing text on hud/game/resource_bar.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get uiHealth;

  /// Player-facing text on hud/game/resource_bar.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Mana'**
  String get uiMana;

  /// Player-facing text on hud/game/resource_bar.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Supplies'**
  String get uiSupplies;

  /// Player-facing text on hud/game/resource_bar.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Stamina'**
  String get uiStamina;

  /// Player-facing text on hud/gameover/game_over_overlay.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Wallet: '**
  String get uiWallet;

  /// Player-facing text on hud/gameover/game_over_overlay.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Run reward: +'**
  String get uiRunReward;

  /// Player-facing text on hud/gameover/game_over_overlay.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Saving replay. Keep this screen open until it is saved.'**
  String get uiSavingReplayKeepThisScreenOpenUntilItIsSaved;

  /// Player-facing text on hud/gameover/game_over_overlay.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Replay could not be saved. Retry before leaving, or exit without a verified reward.'**
  String
  get uiReplayCouldNotBeSavedRetryBeforeLeavingOrExitWithoutAVerifiedReward;

  /// Player-facing text on hud/gameover/game_over_overlay.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Saving replay'**
  String get uiSavingReplay;

  /// Player-facing text on hud/gameover/game_over_overlay.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Replay save failed'**
  String get uiReplaySaveFailed;

  /// Player-facing text on hud/gameover/game_over_overlay.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Retry Saving'**
  String get uiRetrySaving;

  /// Player-facing text on hud/gameover/game_over_overlay.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Verification: '**
  String get uiVerification;

  /// Player-facing text on hud/gameover/game_over_overlay.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Verification delayed'**
  String get uiVerificationDelayed;

  /// Player-facing text on hud/gameover/game_over_overlay.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Collect Score'**
  String get uiCollectScore;

  /// Player-facing text on hud/gameover/game_over_overlay.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get uiSkip;

  /// Player-facing text on hud/gameover/game_over_overlay.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Restart'**
  String get uiRestart;

  /// Player-facing text on pages/hub/run_start_bootstrap_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Exit'**
  String get uiExit;

  /// Player-facing text on hud/gameover/game_over_overlay.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Exit Without Reward'**
  String get uiExitWithoutReward;

  /// Player-facing text on hud/gameover/game_over_overlay.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Saving Replay'**
  String get uiSavingReplayLabel;

  /// Player-facing text on hud/gameover/leaderboard_panel.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Loading rank summary...'**
  String get uiLoadingRankSummary;

  /// Player-facing text on hud/gameover/leaderboard_panel.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Practice'**
  String get uiPractice;

  /// Player-facing text on hud/gameover/leaderboard_panel.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Competitive'**
  String get uiCompetitive;

  /// Player-facing text on hud/gameover/leaderboard_panel.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get uiWeekly;

  /// Player-facing text on hud/gameover/leaderboard_panel.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Loading leaderboard...'**
  String get uiLoadingLeaderboard;

  /// Player-facing text on pages/leaderboards/leaderboards_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'No runs yet.'**
  String get uiNoRunsYet;

  /// Player-facing text on hud/gameover/leaderboard_panel.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Actual rank unavailable right now.'**
  String get uiActualRankUnavailableRightNow;

  /// Player-facing text on hud/gameover/leaderboard_panel.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Actual rank unavailable.'**
  String get uiActualRankUnavailable;

  /// Player-facing text on hud/gameover/leaderboard_panel.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Unranked'**
  String get uiUnranked;

  /// Player-facing text on pages/achievements/achievements_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Unable to load achievements. Reopen this page to retry.'**
  String get uiUnableToLoadAchievementsReopenThisPageToRetry;

  /// Player-facing text on pages/achievements/achievements_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Unable to claim rewards. Please try again.'**
  String get uiUnableToClaimRewardsPleaseTryAgain;

  /// Player-facing text on pages/town/town_map.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Hall of Honour'**
  String get uiHallOfHonour;

  /// Player-facing text on pages/achievements/achievements_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Achievements are unavailable in Developer Practice.'**
  String get uiAchievementsAreUnavailableInDeveloperPractice;

  /// Player-facing text on pages/achievements/achievements_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Loading achievements…'**
  String get uiLoadingAchievements;

  /// Player-facing text on pages/achievements/achievements_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Achievements are not available yet.'**
  String get uiAchievementsAreNotAvailableYet;

  /// Player-facing text on pages/achievements/achievement_claim_action.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Claim all'**
  String get uiClaimAll;

  /// Player-facing text on pages/messages/messages_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Claim'**
  String get uiClaim;

  /// Player-facing text on pages/achievements/achievement_tile.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get uiCompleted;

  /// Player-facing text on pages/achievements/achievement_tile.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Bronze'**
  String get uiBronze;

  /// Player-facing text on pages/achievements/achievement_tile.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Silver'**
  String get uiSilver;

  /// Player-facing text on pages/profile/profile_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Gold'**
  String get uiGold;

  /// Player-facing text on pages/messages/messages_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Claimed'**
  String get uiClaimed;

  /// Player-facing text on pages/achievements/achievement_tile.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get uiAvailable;

  /// Player-facing text on pages/achievements/achievement_tile.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Not reached'**
  String get uiNotReached;

  /// Player-facing text on pages/selectCharacter/gear/gear_picker_candidates_panel.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Town'**
  String get uiTown;

  /// Player-facing text on pages/profile/profile_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get uiProfile;

  /// Player-facing text on pages/hub/components/hub_menu_icon_column.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Top'**
  String get uiTop;

  /// Player-facing text on pages/messages/messages_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get uiMessages;

  /// Player-facing text on pages/hub/components/hub_menu_icon_column.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Unread messages or unclaimed gifts'**
  String get uiUnreadMessagesOrUnclaimedGifts;

  /// Player-facing text on pages/hub/components/hub_menu_icon_column.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Options'**
  String get uiOptions;

  /// Player-facing text on pages/hub/components/hub_select_character_card.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'CHARACTER SELECTION'**
  String get uiCharacterSelection;

  /// Player-facing text on pages/hub/components/hub_select_level_card.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'LEVEL SELECTION'**
  String get uiLevelSelection;

  /// Player-facing text on pages/hub/components/weekly_badge_row.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Leaderboard'**
  String get uiLeaderboard;

  /// Player-facing text on pages/selectLevel/level_setup_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Unable to navigate to run start right now. Try again.'**
  String get uiUnableToNavigateToRunStartRightNowTryAgain;

  /// Player-facing text on pages/profile/profile_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Guest'**
  String get uiGuest;

  /// Player-facing text on pages/selectLevel/level_setup_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'PRACTICE'**
  String get uiPracticeHeading;

  /// Player-facing text on pages/selectLevel/level_setup_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'COMPETITIVE'**
  String get uiCompetitiveHeading;

  /// Player-facing text on pages/leaderboards/leaderboards_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'WEEKLY'**
  String get uiWeeklyHeading;

  /// Player-facing text on pages/hub/play_hub_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'DEVELOPER MODE • Local play only'**
  String get uiDeveloperModePracticeOnly;

  /// Player-facing text on pages/hub/play_hub_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'WEEKLY • Unavailable in this build'**
  String get uiWeeklyUnavailableInThisBuild;

  /// Player-facing text on pages/hub/run_start_bootstrap_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Preparing run...'**
  String get uiPreparingRun;

  /// Player-facing text on pages/hub/run_start_bootstrap_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Retrying...'**
  String get uiRetrying;

  /// Player-facing text on pages/messages/messages_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get uiRetry;

  /// Player-facing text on pages/leaderboards/leaderboards_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get uiLoading;

  /// Player-facing text on pages/leaderboards/leaderboards_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Failed to load leaderboard.'**
  String get uiFailedToLoadLeaderboard;

  /// Player-facing text on pages/leaderboards/leaderboards_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Loading online leaderboard.'**
  String get uiLoadingOnlineLeaderboard;

  /// Player-facing text on pages/leaderboards/leaderboards_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'No leaderboard data.'**
  String get uiNoLeaderboardData;

  /// Player-facing text on pages/leaderboards/leaderboards_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'No validated runs yet.'**
  String get uiNoValidatedRunsYet;

  /// Player-facing text on pages/leaderboards/leaderboards_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'VS Ghost'**
  String get uiVsGhost;

  /// Player-facing text on pages/leaderboards/leaderboards_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Race this ghost.'**
  String get uiRaceThisGhost;

  /// Player-facing text on pages/leaderboards/leaderboards_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Ghost unavailable for this run.'**
  String get uiGhostUnavailableForThisRun;

  /// Player-facing text on pages/leaderboards/leaderboards_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'No ranked players yet.'**
  String get uiNoRankedPlayersYet;

  /// Player-facing text on pages/leaderboards/leaderboards_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'You are not ranked on this board yet.'**
  String get uiYouAreNotRankedOnThisBoardYet;

  /// Player-facing text on pages/leaderboards/leaderboards_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Your rank: '**
  String get uiYourRank;

  /// Player-facing text on pages/leaderboards/leaderboards_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'No active leaderboard board for this mode and level.'**
  String get uiNoActiveLeaderboardBoardForThisModeAndLevel;

  /// Player-facing text on pages/leaderboards/leaderboards_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Leaderboard board is not available right now.'**
  String get uiLeaderboardBoardIsNotAvailableRightNow;

  /// Player-facing text on pages/leaderboards/leaderboards_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Failed to load online leaderboard.'**
  String get uiFailedToLoadOnlineLeaderboard;

  /// Player-facing text on pages/library/library_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Bestiary'**
  String get uiBestiary;

  /// Player-facing text on pages/library/codex_entry_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Bestiary • Boss'**
  String get uiBestiaryBoss;

  /// Player-facing text on pages/library/codex_entry_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Field notes'**
  String get uiFieldNotes;

  /// Player-facing text on pages/library/codex_widgets.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Entry locked'**
  String get uiEntryLocked;

  /// Player-facing text on pages/library/library_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Locations'**
  String get uiLocations;

  /// Player-facing text on pages/library/codex_entry_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Summoned creature'**
  String get uiSummonedCreature;

  /// Player-facing text on pages/library/codex_entry_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Behaviour'**
  String get uiBehaviour;

  /// Player-facing text on pages/library/codex_entry_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Attacks'**
  String get uiAttacks;

  /// Player-facing text on pages/library/codex_entry_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Resistances'**
  String get uiResistances;

  /// Player-facing text on pages/library/codex_entry_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'No innate damage resistances.'**
  String get uiNoInnateDamageResistances;

  /// Player-facing text on pages/library/codex_entry_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Weaknesses'**
  String get uiWeaknesses;

  /// Player-facing text on pages/library/codex_entry_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'No innate damage weaknesses.'**
  String get uiNoInnateDamageWeaknesses;

  /// Player-facing text on pages/library/codex_widgets.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get uiOpen;

  /// Player-facing text on pages/library/library_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Journal'**
  String get uiJournal;

  /// Player-facing text on pages/library/library_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Close location'**
  String get uiCloseLocation;

  /// Player-facing text on pages/town/town_map.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Reset map'**
  String get uiResetMap;

  /// Player-facing text on pages/messages/messages_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Unable to mark this message as read. Please try again.'**
  String get uiUnableToMarkThisMessageAsReadPleaseTryAgain;

  /// Player-facing text on pages/messages/messages_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Unable to confirm the claim. Please try again. Your gift can only be claimed once.'**
  String
  get uiUnableToConfirmTheClaimPleaseTryAgainYourGiftCanOnlyBeClaimedOnce;

  /// Player-facing text on pages/messages/messages_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Unable to confirm deletion. Please try again.'**
  String get uiUnableToConfirmDeletionPleaseTryAgain;

  /// Player-facing text on pages/messages/messages_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Messages are unavailable in this profile.'**
  String get uiMessagesAreUnavailableInThisProfile;

  /// Player-facing text on pages/messages/messages_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Game messages'**
  String get uiGameMessages;

  /// Player-facing text on pages/messages/messages_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Refresh messages'**
  String get uiRefreshMessages;

  /// Player-facing text on pages/messages/messages_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'More messages are available.'**
  String get uiMoreMessagesAreAvailable;

  /// Player-facing text on pages/messages/messages_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'No messages yet.'**
  String get uiNoMessagesYet;

  /// Player-facing text on pages/messages/messages_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Your messages will appear here.'**
  String get uiYourMessagesWillAppearHere;

  /// Player-facing text on pages/messages/messages_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get uiLoadMore;

  /// Player-facing text on pages/messages/messages_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get uiLoadingLabel;

  /// Player-facing text on pages/messages/messages_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Select a message to read it.'**
  String get uiSelectAMessageToReadIt;

  /// Player-facing text on pages/messages/messages_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Claim your gold before deleting this message. Unclaimed gold does not expire.'**
  String get uiClaimYourGoldBeforeDeletingThisMessageUnclaimedGoldDoesNotExpire;

  /// Player-facing text on pages/messages/messages_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Claim your gifts before deleting this message. Unclaimed gifts do not expire.'**
  String get uiClaimYourGiftsBeforeDeletingThisMessageUnclaimedGiftsDoNotExpire;

  /// Player-facing text on pages/messages/messages_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Automatically removed 30 days after claiming.'**
  String get uiAutomaticallyRemoved30DaysAfterClaiming;

  /// Player-facing text on pages/messages/messages_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Automatically removed 30 days after reading.'**
  String get uiAutomaticallyRemoved30DaysAfterReading;

  /// Player-facing text on pages/messages/messages_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Already-owned gifts grant no duplicate unlock or compensation.'**
  String get uiAlreadyOwnedGiftsGrantNoDuplicateUnlockOrCompensation;

  /// Player-facing text on pages/messages/messages_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Retry reading'**
  String get uiRetryReading;

  /// Player-facing text on pages/messages/messages_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Please wait…'**
  String get uiPleaseWait;

  /// Player-facing text on pages/messages/messages_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Delete message'**
  String get uiDeleteMessage;

  /// Player-facing text on pages/messages/messages_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Unread'**
  String get uiUnread;

  /// Player-facing text on pages/messages/messages_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Gift available'**
  String get uiGiftAvailable;

  /// Player-facing text on pages/profile/profile_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Name is unchanged.'**
  String get uiNameIsUnchanged;

  /// Player-facing text on pages/profile/profile_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Name updated'**
  String get uiNameUpdated;

  /// Player-facing text on pages/profile/profile_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Account deletion is in progress.'**
  String get uiAccountDeletionIsInProgress;

  /// Player-facing text on pages/profile/profile_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Please sign in again and retry account deletion.'**
  String get uiPleaseSignInAgainAndRetryAccountDeletion;

  /// Player-facing text on pages/profile/profile_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Session expired. Please restart the game and try again.'**
  String get uiSessionExpiredPleaseRestartTheGameAndTryAgain;

  /// Player-facing text on pages/profile/profile_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Account deletion is not available in this environment.'**
  String get uiAccountDeletionIsNotAvailableInThisEnvironment;

  /// Player-facing text on pages/profile/profile_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Account deletion failed. Please try again.'**
  String get uiAccountDeletionFailedPleaseTryAgain;

  /// Player-facing text on pages/profile/profile_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Account deleted.'**
  String get uiAccountDeleted;

  /// Player-facing text on pages/profile/profile_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Play Games account linked.'**
  String get uiPlayGamesAccountLinked;

  /// Player-facing text on pages/profile/profile_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Play Games is already linked.'**
  String get uiPlayGamesIsAlreadyLinked;

  /// Player-facing text on pages/profile/profile_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Play Games sign-in canceled.'**
  String get uiPlayGamesSignInCanceled;

  /// Player-facing text on pages/profile/profile_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Play Games sign-in is not available on this device.'**
  String get uiPlayGamesSignInIsNotAvailableOnThisDevice;

  /// Player-facing text on pages/profile/profile_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Could not link Play Games account. Please try again.'**
  String get uiCouldNotLinkPlayGamesAccountPleaseTryAgain;

  /// Player-facing text on pages/profile/profile_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Delete account and data?'**
  String get uiDeleteAccountAndData;

  /// Player-facing text on pages/profile/profile_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get uiContinue;

  /// Player-facing text on pages/profile/profile_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Final confirmation'**
  String get uiFinalConfirmation;

  /// Player-facing text on pages/profile/profile_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone. Delete this account permanently?'**
  String get uiThisActionCannotBeUndoneDeleteThisAccountPermanently;

  /// Player-facing text on pages/profile/profile_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Keep account'**
  String get uiKeepAccount;

  /// Player-facing text on pages/profile/profile_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get uiDeleteAccount;

  /// Player-facing text on pages/profile/profile_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Account deletion was accepted. Device cleanup needs another attempt.'**
  String get uiAccountDeletionWasAcceptedDeviceCleanupNeedsAnotherAttempt;

  /// Player-facing text on pages/profile/profile_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Retry cleanup'**
  String get uiRetryCleanup;

  /// Player-facing text on pages/profile/profile_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Enter name'**
  String get uiEnterName;

  /// Player-facing text on pages/profile/profile_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Player stats'**
  String get uiPlayerStats;

  /// Player-facing text on pages/profile/profile_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Lifetime XP'**
  String get uiLifetimeXp;

  /// Player-facing text on pages/profile/profile_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Practice runs played'**
  String get uiPracticeRunsPlayed;

  /// Player-facing text on pages/profile/profile_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Competitive runs played'**
  String get uiCompetitiveRunsPlayed;

  /// Player-facing text on pages/profile/profile_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Enemies defeated'**
  String get uiEnemiesDefeated;

  /// Player-facing text on pages/profile/profile_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Damage dealt'**
  String get uiDamageDealt;

  /// Player-facing text on pages/profile/profile_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Damage taken'**
  String get uiDamageTaken;

  /// Player-facing text on pages/profile/profile_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Danger zone'**
  String get uiDangerZone;

  /// Player-facing text on pages/profile/profile_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Delete your account and all linked player data permanently.'**
  String get uiDeleteYourAccountAndAllLinkedPlayerDataPermanently;

  /// Player-facing text on pages/profile/profile_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Upgrade guest account'**
  String get uiUpgradeGuestAccount;

  /// Player-facing text on pages/profile/profile_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Link Play Games to keep progress across devices.'**
  String get uiLinkPlayGamesToKeepProgressAcrossDevices;

  /// Player-facing text on pages/profile/profile_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Linking...'**
  String get uiLinking;

  /// Player-facing text on pages/profile/profile_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Link Play Games'**
  String get uiLinkPlayGames;

  /// Player-facing text on pages/selectCharacter/build_name_action.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Rename build'**
  String get uiRenameBuild;

  /// Player-facing text on pages/selectCharacter/build_name_action.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Enter a build name.'**
  String get uiEnterABuildName;

  /// Player-facing text on pages/selectCharacter/build_name_action.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Could not save the name. Please try again.'**
  String get uiCouldNotSaveTheNamePleaseTryAgain;

  /// Player-facing text on pages/selectCharacter/build_name_action.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Build name'**
  String get uiBuildName;

  /// Player-facing text on pages/selectCharacter/build_name_action.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get uiSaving;

  /// Player-facing text on pages/selectCharacter/character_selection_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Could not save this selection. Please try again.'**
  String get uiCouldNotSaveThisSelectionPleaseTryAgain;

  /// Player-facing text on pages/selectCharacter/character_selection_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Choose your character'**
  String get uiChooseYourCharacter;

  /// Player-facing text on pages/selectCharacter/gear/gear_picker_candidates_panel.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'No options for this slot.'**
  String get uiNoOptionsForThisSlot;

  /// Player-facing text on pages/selectCharacter/gear/gear_picker_stats_panel.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Select an item to preview stats.'**
  String get uiSelectAnItemToPreviewStats;

  /// Player-facing text on pages/town/town_store_widgets.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'No non-zero stat bonuses.'**
  String get uiNoNonZeroStatBonuses;

  /// Player-facing text on pages/selectCharacter/gears_tab.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Visit Town store?'**
  String get uiVisitTownStore;

  /// Player-facing text on pages/selectCharacter/gears_tab.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Go to Town'**
  String get uiGoToTown;

  /// Player-facing text on pages/selectCharacter/gears_tab.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Equip'**
  String get uiEquip;

  /// Player-facing text on pages/selectCharacter/loadout_setup_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Gear'**
  String get uiGear;

  /// Player-facing text on pages/selectCharacter/loadout_setup_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Skills'**
  String get uiSkills;

  /// Player-facing text on pages/selectCharacter/loadout_setup_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Training Field'**
  String get uiTrainingField;

  /// Player-facing text on pages/selectCharacter/skills/skills_details_pane.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'No ability available for this slot.'**
  String get uiNoAbilityAvailableForThisSlot;

  /// Player-facing text on pages/selectCharacter/skills/skills_details_pane.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'No ability details available right now.'**
  String get uiNoAbilityDetailsAvailableRightNow;

  /// Player-facing text on pages/town/town_store_widgets.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Cooldown: '**
  String get uiCooldown;

  /// Player-facing text on pages/town/town_store_widgets.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Max duration: '**
  String get uiMaxDuration;

  /// Player-facing text on pages/selectCharacter/skills/skills_details_pane.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Unlock this skill in Town to view full details.'**
  String get uiUnlockThisSkillInTownToViewFullDetails;

  /// Player-facing text on pages/selectCharacter/skills/skills_details_pane.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Find in Town'**
  String get uiFindInTown;

  /// Player-facing text on pages/selectCharacter/skills/skills_list_pane.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Select Projectile'**
  String get uiSelectProjectile;

  /// Player-facing text on pages/town/town_store_widgets.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Damage: '**
  String get uiDamage;

  /// Player-facing text on pages/selectCharacter/skills_tab.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Select Projectile Source'**
  String get uiSelectProjectileSource;

  /// Player-facing text on pages/selectCharacter/training_opponent_dialog.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get uiClose;

  /// Player-facing text on pages/selectCharacter/skills_tab.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Select Weapon'**
  String get uiSelectWeapon;

  /// Player-facing text on pages/selectCharacter/training_field_tab.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Choose training opponent'**
  String get uiChooseTrainingOpponent;

  /// Player-facing text on pages/selectCharacter/training_field_tab.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get uiReset;

  /// Player-facing text on pages/selectCharacter/training_field_tab.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get uiResume;

  /// Player-facing text on pages/selectCharacter/training_field_tab.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Retry loading Training Field'**
  String get uiRetryLoadingTrainingField;

  /// Player-facing text on pages/selectCharacter/training_opponent_dialog.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Training opponent'**
  String get uiTrainingOpponent;

  /// Player-facing text on pages/selectCharacter/training_opponent_dialog.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Choose an opponent for your next fight.'**
  String get uiChooseAnOpponentForYourNextFight;

  /// Player-facing text on pages/selectCharacter/training_opponent_dialog.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Unlock enemy entries in the Library to practise against them.'**
  String get uiUnlockEnemyEntriesInTheLibraryToPractiseAgainstThem;

  /// Player-facing text on pages/selectCharacter/training_opponent_dialog.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get uiNone;

  /// Player-facing text on pages/selectCharacter/training_opponent_dialog.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Practise without an opponent.'**
  String get uiPractiseWithoutAnOpponent;

  /// Player-facing text on pages/selectLevel/level_setup_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Select Level'**
  String get uiSelectLevel;

  /// Player-facing text on pages/town/reward_verification_dialog.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Your gold is ready'**
  String get uiYourGoldIsReady;

  /// Player-facing text on pages/town/reward_verification_dialog.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Your rewards are on their way'**
  String get uiYourRewardsAreOnTheirWay;

  /// Player-facing text on pages/town/reward_verification_dialog.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Your balance has changed'**
  String get uiYourBalanceHasChanged;

  /// Player-facing text on pages/town/reward_verification_dialog.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Your run rewards are confirmed. You can now spend your gold.'**
  String get uiYourRunRewardsAreConfirmedYouCanNowSpendYourGold;

  /// Player-facing text on pages/town/reward_verification_dialog.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'We’re confirming your latest run rewards before they can be spent. You can keep playing while we finish.'**
  String
  get uiWeReConfirmingYourLatestRunRewardsBeforeTheyCanBeSpentYouCanKeepPlayingWhileWeFinish;

  /// Player-facing text on pages/town/reward_verification_dialog.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'There isn’t enough gold for this purchase. Return to the store to see your updated balance.'**
  String
  get uiThereIsnTEnoughGoldForThisPurchaseReturnToTheStoreToSeeYourUpdatedBalance;

  /// Player-facing text on pages/town/reward_verification_dialog.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Back to store'**
  String get uiBackToStore;

  /// Player-facing text on pages/town/reward_verification_dialog.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get uiGotIt;

  /// Player-facing text on pages/town/town_map.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Store'**
  String get uiStore;

  /// Player-facing text on pages/town/town_map.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get uiLibrary;

  /// Player-facing text on pages/town/town_map.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Achievement rewards available'**
  String get uiAchievementRewardsAvailable;

  /// Player-facing text on pages/town/town_map.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Store marker'**
  String get uiStoreMarker;

  /// Player-facing text on pages/town/town_map.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Library marker'**
  String get uiLibraryMarker;

  /// Player-facing text on pages/town/town_map.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Hall of Honour marker'**
  String get uiHallOfHonourMarker;

  /// Player-facing text on pages/town/town_store_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Town Store'**
  String get uiTownStore;

  /// Player-facing text on pages/town/town_store_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Purchase failed. Please try again.'**
  String get uiPurchaseFailedPleaseTryAgain;

  /// Player-facing text on pages/town/town_store_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Refresh store?'**
  String get uiRefreshStore;

  /// Player-facing text on pages/town/town_store_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Refreshing the store costs'**
  String get uiRefreshingTheStoreCosts;

  /// Player-facing text on pages/town/town_store_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Cost'**
  String get uiCost;

  /// Player-facing text on pages/town/town_store_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to refresh the store?'**
  String get uiAreYouSureYouWantToRefreshTheStore;

  /// Player-facing text on pages/town/town_store_widgets.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get uiRefresh;

  /// Player-facing text on pages/town/town_store_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Store refreshed.'**
  String get uiStoreRefreshed;

  /// Player-facing text on pages/town/town_store_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Refresh failed. Please try again.'**
  String get uiRefreshFailedPleaseTryAgain;

  /// Player-facing text on pages/town/town_store_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Not enough gold for that action.'**
  String get uiNotEnoughGoldForThatAction;

  /// Player-facing text on pages/town/town_store_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'That offer is no longer available.'**
  String get uiThatOfferIsNoLongerAvailable;

  /// Player-facing text on pages/town/town_store_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'You already own this unlock.'**
  String get uiYouAlreadyOwnThisUnlock;

  /// Player-facing text on pages/town/town_store_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Daily refresh limit reached.'**
  String get uiDailyRefreshLimitReached;

  /// Player-facing text on pages/town/town_store_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Refresh method is not available.'**
  String get uiRefreshMethodIsNotAvailable;

  /// Player-facing text on pages/town/town_store_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'No offer can change right now.'**
  String get uiNoOfferCanChangeRightNow;

  /// Player-facing text on pages/town/town_store_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Reward verification is not active yet.'**
  String get uiRewardVerificationIsNotActiveYet;

  /// Player-facing text on pages/town/town_store_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Reward has already been used.'**
  String get uiRewardHasAlreadyBeenUsed;

  /// Player-facing text on pages/town/town_store_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Reward has expired.'**
  String get uiRewardHasExpired;

  /// Player-facing text on pages/town/town_store_page.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Action rejected. Please try again.'**
  String get uiActionRejectedPleaseTryAgain;

  /// Player-facing text on pages/town/town_store_widgets.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Refreshing...'**
  String get uiRefreshing;

  /// Player-facing text on pages/town/town_store_widgets.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'No offers available right now.'**
  String get uiNoOffersAvailableRightNow;

  /// Player-facing text on pages/town/town_store_widgets.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Buying...'**
  String get uiBuying;

  /// Player-facing text on pages/town/town_store_widgets.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'Buy'**
  String get uiBuy;

  /// Player-facing text on pages/town/town_store_widgets.dart. Keep French informal (tu). Do not translate player-authored names.
  ///
  /// In en, this message translates to:
  /// **'No details available right now.'**
  String get uiNoDetailsAvailableRightNow;

  /// Startup or recovery text for the player. Diagnostic and server error strings must not be displayed.
  ///
  /// In en, this message translates to:
  /// **'Unable to start the game'**
  String get bootstrapStartFailed;

  /// Startup or recovery text for the player. Diagnostic and server error strings must not be displayed.
  ///
  /// In en, this message translates to:
  /// **'Game account unavailable'**
  String get bootstrapAccountUnavailable;

  /// Startup or recovery text for the player. Diagnostic and server error strings must not be displayed.
  ///
  /// In en, this message translates to:
  /// **'Play Games sign-in required'**
  String get bootstrapSignInRequired;

  /// Startup or recovery text for the player. Diagnostic and server error strings must not be displayed.
  ///
  /// In en, this message translates to:
  /// **'Unable to load player data'**
  String get bootstrapDataFailed;

  /// Startup or recovery text for the player. Diagnostic and server error strings must not be displayed.
  ///
  /// In en, this message translates to:
  /// **'This game account is disabled. If you recently deleted it, please wait for deletion to finish before signing in again. This can take several hours. You can then use the same Play Games account to start fresh.'**
  String get bootstrapAccountDisabled;

  /// Startup or recovery text for the player. Diagnostic and server error strings must not be displayed.
  ///
  /// In en, this message translates to:
  /// **'This platform does not support the services required by the game.'**
  String get bootstrapUnsupported;

  /// Startup or recovery text for the player. Diagnostic and server error strings must not be displayed.
  ///
  /// In en, this message translates to:
  /// **'Game services could not start. Check your connection and try again.'**
  String get bootstrapServiceFailure;

  /// Startup or recovery text for the player. Diagnostic and server error strings must not be displayed.
  ///
  /// In en, this message translates to:
  /// **'Your player data could not be loaded. Check your connection and try again.'**
  String get bootstrapDataFailure;

  /// Startup or recovery text for the player. Diagnostic and server error strings must not be displayed.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get bootstrapRetry;

  /// Startup or recovery text for the player. Diagnostic and server error strings must not be displayed.
  ///
  /// In en, this message translates to:
  /// **'Retry Play Games sign-in'**
  String get bootstrapRetrySignIn;

  /// Startup or recovery text for the player. Diagnostic and server error strings must not be displayed.
  ///
  /// In en, this message translates to:
  /// **'Play Games sign-in is required to continue.'**
  String get bootstrapSignInBody;

  /// Startup or recovery text for the player. Diagnostic and server error strings must not be displayed.
  ///
  /// In en, this message translates to:
  /// **'Bootstrap failed'**
  String get bootstrapFailed;

  /// Startup or recovery text for the player. Diagnostic and server error strings must not be displayed.
  ///
  /// In en, this message translates to:
  /// **'The Long Run'**
  String get loaderGameTitle;

  /// Startup or recovery text for the player. Diagnostic and server error strings must not be displayed.
  ///
  /// In en, this message translates to:
  /// **'Lothringen'**
  String get loaderWorldTitle;

  /// Startup or recovery text for the player. Diagnostic and server error strings must not be displayed.
  ///
  /// In en, this message translates to:
  /// **'PLAY'**
  String get playButton;

  /// Startup or recovery text for the player. Diagnostic and server error strings must not be displayed.
  ///
  /// In en, this message translates to:
  /// **'Update the game before starting another run. Your account and pending rewards remain available.'**
  String get runUpdateRequired;

  /// Startup or recovery text for the player. Diagnostic and server error strings must not be displayed.
  ///
  /// In en, this message translates to:
  /// **'The game is undergoing maintenance. Please try again later. Your pending runs and rewards will be recovered.'**
  String get runMaintenance;

  /// Startup or recovery text for the player. Diagnostic and server error strings must not be displayed.
  ///
  /// In en, this message translates to:
  /// **'Adjust your equipment and abilities before starting.'**
  String get runInvalidLoadout;

  /// Startup or recovery text for the player. Diagnostic and server error strings must not be displayed.
  ///
  /// In en, this message translates to:
  /// **'This level is unavailable in this build. Return to the hub and select an available level.'**
  String get runLevelUnavailable;

  /// Startup or recovery text for the player. Diagnostic and server error strings must not be displayed.
  ///
  /// In en, this message translates to:
  /// **'Run start requirements changed. Return to hub and try again.'**
  String get runRequirementsChanged;

  /// Startup or recovery text for the player. Diagnostic and server error strings must not be displayed.
  ///
  /// In en, this message translates to:
  /// **'Unable to start run right now. Check your connection and try again.'**
  String get runStartFailed;

  /// Startup or recovery text for the player. Diagnostic and server error strings must not be displayed.
  ///
  /// In en, this message translates to:
  /// **'Preparing replay recorder...'**
  String get runRecorderPreparing;

  /// Startup or recovery text for the player. Diagnostic and server error strings must not be displayed.
  ///
  /// In en, this message translates to:
  /// **'Preparing terrain...'**
  String get runTerrainPreparing;

  /// Startup or recovery text for the player. Diagnostic and server error strings must not be displayed.
  ///
  /// In en, this message translates to:
  /// **'Preparing ghost...'**
  String get runGhostPreparing;

  /// Startup or recovery text for the player. Diagnostic and server error strings must not be displayed.
  ///
  /// In en, this message translates to:
  /// **'Loading game art...'**
  String get runArtLoading;

  /// Startup or recovery text for the player. Diagnostic and server error strings must not be displayed.
  ///
  /// In en, this message translates to:
  /// **'Building level...'**
  String get runBuildingLevel;

  /// Startup or recovery text for the player. Diagnostic and server error strings must not be displayed.
  ///
  /// In en, this message translates to:
  /// **'Unable to load the level. Retry or return to the previous screen.'**
  String get runWorldFailed;

  /// Startup or recovery text for the player. Diagnostic and server error strings must not be displayed.
  ///
  /// In en, this message translates to:
  /// **'Unable to prepare replay recording. Check available storage and retry.'**
  String get runRecorderFailed;

  /// Startup or recovery text for the player. Diagnostic and server error strings must not be displayed.
  ///
  /// In en, this message translates to:
  /// **'Name is required.'**
  String get nameRequired;

  /// Startup or recovery text for the player. Diagnostic and server error strings must not be displayed.
  ///
  /// In en, this message translates to:
  /// **'Only letters, numbers, spaces, \"_\" and \"-\" are allowed.'**
  String get nameCharacters;

  /// Startup or recovery text for the player. Diagnostic and server error strings must not be displayed.
  ///
  /// In en, this message translates to:
  /// **'That name is reserved.'**
  String get nameReserved;

  /// Startup or recovery text for the player. Diagnostic and server error strings must not be displayed.
  ///
  /// In en, this message translates to:
  /// **'That name is not allowed.'**
  String get nameDisallowed;

  /// Startup or recovery text for the player. Diagnostic and server error strings must not be displayed.
  ///
  /// In en, this message translates to:
  /// **'That name is already taken.'**
  String get nameTaken;

  /// Startup or recovery text for the player. Diagnostic and server error strings must not be displayed.
  ///
  /// In en, this message translates to:
  /// **'Could not save name. Please try again.'**
  String get nameSaveFailed;

  /// Startup or recovery text for the player. Diagnostic and server error strings must not be displayed.
  ///
  /// In en, this message translates to:
  /// **'Could not reach the server. Check your connection and try again.'**
  String get nameServerUnavailable;

  /// Startup or recovery text for the player. Diagnostic and server error strings must not be displayed.
  ///
  /// In en, this message translates to:
  /// **'Name service is unavailable. Please try again later.'**
  String get nameServiceUnavailable;

  /// Startup or recovery text for the player. Diagnostic and server error strings must not be displayed.
  ///
  /// In en, this message translates to:
  /// **'Choose a valid display name and try again.'**
  String get nameInvalid;

  /// Startup or recovery text for the player. Diagnostic and server error strings must not be displayed.
  ///
  /// In en, this message translates to:
  /// **'Update required'**
  String get updateRequiredTitle;

  /// Startup or recovery text for the player. Diagnostic and server error strings must not be displayed.
  ///
  /// In en, this message translates to:
  /// **'Maintenance'**
  String get maintenanceTitle;

  /// Startup or recovery text for the player. Diagnostic and server error strings must not be displayed.
  ///
  /// In en, this message translates to:
  /// **'Open Google Play'**
  String get openGooglePlay;

  /// Startup or recovery text for the player. Diagnostic and server error strings must not be displayed.
  ///
  /// In en, this message translates to:
  /// **'Install the current build for this environment.'**
  String get installCurrentBuild;

  /// Startup or recovery text for the player. Diagnostic and server error strings must not be displayed.
  ///
  /// In en, this message translates to:
  /// **'Name must be at least {min} characters.'**
  String nameTooShort({required int min});

  /// Startup or recovery text for the player. Diagnostic and server error strings must not be displayed.
  ///
  /// In en, this message translates to:
  /// **'Name must be at most {max} characters.'**
  String nameTooLong({required int max});

  /// Achievement display only. Eligibility, thresholds and reward amounts remain server-owned. Dates use UTC.
  ///
  /// In en, this message translates to:
  /// **'First Steps'**
  String get achievementFirstSteps;

  /// Achievement display only. Eligibility, thresholds and reward amounts remain server-owned. Dates use UTC.
  ///
  /// In en, this message translates to:
  /// **'Marathoner'**
  String get achievementMarathoner;

  /// Achievement display only. Eligibility, thresholds and reward amounts remain server-owned. Dates use UTC.
  ///
  /// In en, this message translates to:
  /// **'Road Warrior'**
  String get achievementRoadWarrior;

  /// Achievement display only. Eligibility, thresholds and reward amounts remain server-owned. Dates use UTC.
  ///
  /// In en, this message translates to:
  /// **'Still Standing'**
  String get achievementStillStanding;

  /// Achievement display only. Eligibility, thresholds and reward amounts remain server-owned. Dates use UTC.
  ///
  /// In en, this message translates to:
  /// **'Slayer'**
  String get achievementSlayer;

  /// Achievement display only. Eligibility, thresholds and reward amounts remain server-owned. Dates use UTC.
  ///
  /// In en, this message translates to:
  /// **'Verified Practice, Competitive and Weekly runs count after 100 metres or 30 seconds and must end naturally. Quitting does not count.'**
  String get achievementQualifying;

  /// Achievement display only. Eligibility, thresholds and reward amounts remain server-owned. Dates use UTC.
  ///
  /// In en, this message translates to:
  /// **'Verified Practice, Competitive and Weekly runs count, including short runs and runs you quit.'**
  String get achievementAllRuns;

  /// Achievement display only. Eligibility, thresholds and reward amounts remain server-owned. Dates use UTC.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 run} other{{count} runs}}'**
  String achievementRuns({required int count});

  /// Achievement display only. Eligibility, thresholds and reward amounts remain server-owned. Dates use UTC.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 enemy} other{{count} enemies}}'**
  String achievementEnemies({required int count});

  /// Achievement display only. Eligibility, thresholds and reward amounts remain server-owned. Dates use UTC.
  ///
  /// In en, this message translates to:
  /// **'{count} m'**
  String achievementDistance({required int count});

  /// Achievement display only. Eligibility, thresholds and reward amounts remain server-owned. Dates use UTC.
  ///
  /// In en, this message translates to:
  /// **'Finish {count, plural, =1{1 qualifying run} other{{count} qualifying runs}}.'**
  String achievementFinish({required int count});

  /// Achievement display only. Eligibility, thresholds and reward amounts remain server-owned. Dates use UTC.
  ///
  /// In en, this message translates to:
  /// **'Reach {count} metres in one run.'**
  String achievementReach({required int count});

  /// Achievement display only. Eligibility, thresholds and reward amounts remain server-owned. Dates use UTC.
  ///
  /// In en, this message translates to:
  /// **'Travel {count} metres across runs.'**
  String achievementTravel({required int count});

  /// Achievement display only. Eligibility, thresholds and reward amounts remain server-owned. Dates use UTC.
  ///
  /// In en, this message translates to:
  /// **'Survive {duration} across runs.'**
  String achievementSurvive({required String duration});

  /// Achievement display only. Eligibility, thresholds and reward amounts remain server-owned. Dates use UTC.
  ///
  /// In en, this message translates to:
  /// **'Defeat {count, plural, =1{1 enemy} other{{count} enemies}} across runs.'**
  String achievementDefeat({required int count});

  /// Achievement display only. Eligibility, thresholds and reward amounts remain server-owned. Dates use UTC.
  ///
  /// In en, this message translates to:
  /// **'{count}h'**
  String durationHours({required int count});

  /// Achievement display only. Eligibility, thresholds and reward amounts remain server-owned. Dates use UTC.
  ///
  /// In en, this message translates to:
  /// **'{count}m'**
  String durationMinutes({required int count});

  /// Achievement display only. Eligibility, thresholds and reward amounts remain server-owned. Dates use UTC.
  ///
  /// In en, this message translates to:
  /// **'{count}s'**
  String durationSeconds({required int count});

  /// Achievement display only. Eligibility, thresholds and reward amounts remain server-owned. Dates use UTC.
  ///
  /// In en, this message translates to:
  /// **'{date} (UTC)'**
  String dateUtc({required String date});

  /// Achievement display only. Eligibility, thresholds and reward amounts remain server-owned. Dates use UTC.
  ///
  /// In en, this message translates to:
  /// **'Next reward: {gold} gold'**
  String achievementNextReward({required int gold});

  /// Achievement display only. Eligibility, thresholds and reward amounts remain server-owned. Dates use UTC.
  ///
  /// In en, this message translates to:
  /// **'{gold} gold · {state, select, claimed{Claimed} achieved{Available} other{Not reached}}'**
  String achievementTierReward({required int gold, required String state});

  /// Achievement display only. Eligibility, thresholds and reward amounts remain server-owned. Dates use UTC.
  ///
  /// In en, this message translates to:
  /// **'Achieved {date}'**
  String achievementAchievedDate({required String date});

  /// Achievement display only. Eligibility, thresholds and reward amounts remain server-owned. Dates use UTC.
  ///
  /// In en, this message translates to:
  /// **'{gold} gold'**
  String goldAmount({required int gold});

  /// Achievement display only. Eligibility, thresholds and reward amounts remain server-owned. Dates use UTC.
  ///
  /// In en, this message translates to:
  /// **'{current} / {target}'**
  String progressQuantities({required String current, required String target});

  /// Codex world-reference prose: codexOpeningTitle. Preserve canonical names and meaning; do not invent lore. Instructions use tu in French.
  ///
  /// In en, this message translates to:
  /// **'The roads of Lothringen'**
  String get codexOpeningTitle;

  /// Codex world-reference prose: codexOpening. Preserve canonical names and meaning; do not invent lore. Instructions use tu in French.
  ///
  /// In en, this message translates to:
  /// **'Théodonis stands behind old walls, surrounded by farmland and forests. The city has survived wars, raids and disease, and its apparent stability rests on institutions that have weathered many crises.\n\nLong ago, Éloïse founded La Main to confront a hidden threat. After her disappearance, the order continued its work in secret. More recently, an incident at the Villa Twinsen left questions unanswered.\n\nOn the roads of Lothringen, Neyla leads a traveling company of performers. They bring shows to the communities they visit and offer help along the way. Their journey now leads toward Théodonis.'**
  String get codexOpening;

  /// Codex world-reference prose: codexGrojibLore. Preserve canonical names and meaning; do not invent lore. Instructions use tu in French.
  ///
  /// In en, this message translates to:
  /// **'Grojib closes the distance without hesitation. A traveler who holds their ground after the first blow may find another strike already on its way.'**
  String get codexGrojibLore;

  /// Codex world-reference prose: codexHashashLore. Preserve canonical names and meaning; do not invent lore. Instructions use tu in French.
  ///
  /// In en, this message translates to:
  /// **'Hashash fights from the uncertainty of the forest, appearing where attention has already moved on. In these woods, an apparently empty path is no promise of safe passage.'**
  String get codexHashashLore;

  /// Codex world-reference prose: codexDerfLore. Preserve canonical names and meaning; do not invent lore. Instructions use tu in French.
  ///
  /// In en, this message translates to:
  /// **'Derf’s outward form conceals a transformation that turns a distant spellcaster into a pursuing, tentacled threat.'**
  String get codexDerfLore;

  /// Codex world-reference prose: codexUnocoLore. Preserve canonical names and meaning; do not invent lore. Instructions use tu in French.
  ///
  /// In en, this message translates to:
  /// **'The Unoco demons encountered over the forest carry the threat above the paths, where walls and broken ground offer little protection from a spell cast out of the air.'**
  String get codexUnocoLore;

  /// Codex world-reference prose: codexBringerLore. Preserve canonical names and meaning; do not invent lore. Instructions use tu in French.
  ///
  /// In en, this message translates to:
  /// **'The Bringer of Death bars the way through a clearing claimed by the darkness. Its scythe and rising pillars leave little room for hesitation. Defeating this guardian opens a way deeper into the forest.'**
  String get codexBringerLore;

  /// Codex world-reference prose: codexGoddessLore. Preserve canonical names and meaning; do not invent lore. Instructions use tu in French.
  ///
  /// In en, this message translates to:
  /// **'The name Voidborn Goddess records the terror of the encounter, not proof of divinity. This presence turns the clearing itself into a threat. What brought it into the forest remains unknown.'**
  String get codexGoddessLore;

  /// Codex world-reference prose: codexShoggothLore. Preserve canonical names and meaning; do not invent lore. Instructions use tu in French.
  ///
  /// In en, this message translates to:
  /// **'Shoggoth is encountered among the deeper horrors guarding the route. Smaller creatures accompany its assaults, making the fight feel less like a duel than a struggle to keep a patch of ground. Its distant origin remains unrecorded.'**
  String get codexShoggothLore;

  /// Codex world-reference prose: codexVoidcallerLore. Preserve canonical names and meaning; do not invent lore. Instructions use tu in French.
  ///
  /// In en, this message translates to:
  /// **'The Voidcaller’s presence is marked by beams, erupting claws and summoned tentacles. Its title describes what travelers have witnessed, while the nature of what answers its call remains uncertain.'**
  String get codexVoidcallerLore;

  /// Codex world-reference prose: codexShoggothMinionLore. Preserve canonical names and meaning; do not invent lore. Instructions use tu in French.
  ///
  /// In en, this message translates to:
  /// **'These smaller creatures enter the fight at Shoggoth’s summons. They are part of the same immediate threat, pressing an opponent while the larger creature prepares its next assault. Their appearance is a warning that the ground around Shoggoth will not stay clear.'**
  String get codexShoggothMinionLore;

  /// Codex world-reference prose: codexVoidTentacleLore. Preserve canonical names and meaning; do not invent lore. Instructions use tu in French.
  ///
  /// In en, this message translates to:
  /// **'A tentacle called into the arena is a local expression of the Voidcaller’s reach. It makes dangerous ground out of a place that was open a moment before. Destroying it removes that threat, but leaves the power calling it forth to be confronted.'**
  String get codexVoidTentacleLore;

  /// Codex world-reference prose: codexGrojibTactics. Preserve canonical names and meaning; do not invent lore. Instructions use tu in French.
  ///
  /// In en, this message translates to:
  /// **'A ground pursuer with a follow-up melee strike that can stun on hit. Leave room for the second swing.'**
  String get codexGrojibTactics;

  /// Codex world-reference prose: codexHashashTactics. Preserve canonical names and meaning; do not invent lore. Instructions use tu in French.
  ///
  /// In en, this message translates to:
  /// **'A mobile assassin with a teleporting ambush. Watch for its return before committing.'**
  String get codexHashashTactics;

  /// Codex world-reference prose: codexDerfTactics. Preserve canonical names and meaning; do not invent lore. Instructions use tu in French.
  ///
  /// In en, this message translates to:
  /// **'Transforms from a caster into a melee pursuer. Its extended tentacle gives the strike unusual reach.'**
  String get codexDerfTactics;

  /// Codex world-reference prose: codexUnocoTactics. Preserve canonical names and meaning; do not invent lore. Instructions use tu in French.
  ///
  /// In en, this message translates to:
  /// **'A flying caster that can also strike at close range. Keep moving while its projectile is aimed.'**
  String get codexUnocoTactics;

  /// Codex world-reference prose: codexBringerTactics. Preserve canonical names and meaning; do not invent lore. Instructions use tu in French.
  ///
  /// In en, this message translates to:
  /// **'A scythe fighter with dark pillars. Read the wind-up and move clear of the marked ground.'**
  String get codexBringerTactics;

  /// Codex world-reference prose: codexGoddessTactics. Preserve canonical names and meaning; do not invent lore. Instructions use tu in French.
  ///
  /// In en, this message translates to:
  /// **'Combines claw attacks, dark orbs and ground eruptions. Reposition when the arena is threatened.'**
  String get codexGoddessTactics;

  /// Codex world-reference prose: codexShoggothTactics. Preserve canonical names and meaning; do not invent lore. Instructions use tu in French.
  ///
  /// In en, this message translates to:
  /// **'Uses tentacles, dark orbs and summoned creatures. Manage the smaller threats while watching the boss.'**
  String get codexShoggothTactics;

  /// Codex world-reference prose: codexVoidcallerTactics. Preserve canonical names and meaning; do not invent lore. Instructions use tu in French.
  ///
  /// In en, this message translates to:
  /// **'Uses vertical and diagonal beams, fire claws and tentacle summons. Keep a route out of overlapping attacks.'**
  String get codexVoidcallerTactics;

  /// Codex world-reference prose: codexShoggothMinionTactics. Preserve canonical names and meaning; do not invent lore. Instructions use tu in French.
  ///
  /// In en, this message translates to:
  /// **'A small ground attacker summoned by Shoggoth. Avoid being crowded while the boss attacks.'**
  String get codexShoggothMinionTactics;

  /// Codex world-reference prose: codexVoidTentacleTactics. Preserve canonical names and meaning; do not invent lore. Instructions use tu in French.
  ///
  /// In en, this message translates to:
  /// **'A summoned melee threat. Move beyond its lash before turning to attack it.'**
  String get codexVoidTentacleTactics;

  /// Codex world-reference prose: codexForestLore. Preserve canonical names and meaning; do not invent lore. Instructions use tu in French.
  ///
  /// In en, this message translates to:
  /// **'Val Outpost stands beside the road through the Long-Eared Owls’ Forest. Its soldiers patrol the wooded route, train for the forest’s hazards, and carry warnings of danger back to Théodonis. Travelers can rest under their guard before continuing their journey.'**
  String get codexForestLore;

  /// Codex world-reference prose: codexFieldLore. Preserve canonical names and meaning; do not invent lore. Instructions use tu in French.
  ///
  /// In en, this message translates to:
  /// **'Léonards’ farm is the largest agricultural estate around Théodonis. A powerful family oversees its fields and harvests.'**
  String get codexFieldLore;

  /// Library, level or catalog presentation. Stable IDs and discovery rules are never translated. Named proper nouns retain their canonical spellings.
  ///
  /// In en, this message translates to:
  /// **'Val Outpost'**
  String get levelForestName;

  /// Library, level or catalog presentation. Stable IDs and discovery rules are never translated. Named proper nouns retain their canonical spellings.
  ///
  /// In en, this message translates to:
  /// **'Léonards’ farm'**
  String get levelFieldName;

  /// Library, level or catalog presentation. Stable IDs and discovery rules are never translated. Named proper nouns retain their canonical spellings.
  ///
  /// In en, this message translates to:
  /// **'New Level'**
  String get levelDeprecatedName;

  /// Library, level or catalog presentation. Stable IDs and discovery rules are never translated. Named proper nouns retain their canonical spellings.
  ///
  /// In en, this message translates to:
  /// **'Les Soleils d’or • Lothringen'**
  String get libraryBrand;

  /// Library, level or catalog presentation. Stable IDs and discovery rules are never translated. Named proper nouns retain their canonical spellings.
  ///
  /// In en, this message translates to:
  /// **'Théodonis'**
  String get townName;

  /// Library, level or catalog presentation. Stable IDs and discovery rules are never translated. Named proper nouns retain their canonical spellings.
  ///
  /// In en, this message translates to:
  /// **'Library · {section}'**
  String libraryTitle({required String section});

  /// Library, level or catalog presentation. Stable IDs and discovery rules are never translated. Named proper nouns retain their canonical spellings.
  ///
  /// In en, this message translates to:
  /// **'Defeat {count} to reveal its attacks, resistances and field notes.'**
  String codexUnlockEnemy({required int count});

  /// Library, level or catalog presentation. Stable IDs and discovery rules are never translated. Named proper nouns retain their canonical spellings.
  ///
  /// In en, this message translates to:
  /// **'{current} / {target} defeated.'**
  String codexDefeatedProgress({required int current, required int target});

  /// Library, level or catalog presentation. Stable IDs and discovery rules are never translated. Named proper nouns retain their canonical spellings.
  ///
  /// In en, this message translates to:
  /// **'Reach {count} points in one Competitive run on {level} to reveal its history.'**
  String codexUnlockLevel({required int count, required String level});

  /// Library, level or catalog presentation. Stable IDs and discovery rules are never translated. Named proper nouns retain their canonical spellings.
  ///
  /// In en, this message translates to:
  /// **'{current} / {target} best Competitive score.'**
  String codexScoreProgress({required int current, required int target});

  /// Library, level or catalog presentation. Stable IDs and discovery rules are never translated. Named proper nouns retain their canonical spellings.
  ///
  /// In en, this message translates to:
  /// **'{type}: {percent}% less damage'**
  String codexResistance({required String type, required num percent});

  /// Library, level or catalog presentation. Stable IDs and discovery rules are never translated. Named proper nouns retain their canonical spellings.
  ///
  /// In en, this message translates to:
  /// **'{type}: {percent}% more damage'**
  String codexWeakness({required String type, required num percent});

  /// Library, level or catalog presentation. Stable IDs and discovery rules are never translated. Named proper nouns retain their canonical spellings.
  ///
  /// In en, this message translates to:
  /// **'{type} {percent}%'**
  String codexDamageMix({required String type, required int percent});

  /// Library, level or catalog presentation. Stable IDs and discovery rules are never translated. Named proper nouns retain their canonical spellings.
  ///
  /// In en, this message translates to:
  /// **'{ability} • {category}\n{types} damage'**
  String codexAttack({
    required String ability,
    required String category,
    required String types,
  });

  /// Library, level or catalog presentation. Stable IDs and discovery rules are never translated. Named proper nouns retain their canonical spellings.
  ///
  /// In en, this message translates to:
  /// **'{title}, {state, select, discovered{discovered} other{locked}}'**
  String codexEntrySemantics({required String title, required String state});

  /// Library, level or catalog presentation. Stable IDs and discovery rules are never translated. Named proper nouns retain their canonical spellings.
  ///
  /// In en, this message translates to:
  /// **'Defeat {progress} to unlock'**
  String codexDefeatToUnlock({required String progress});

  /// Library, level or catalog presentation. Stable IDs and discovery rules are never translated. Named proper nouns retain their canonical spellings.
  ///
  /// In en, this message translates to:
  /// **'{level}, {state, select, open{open} other{locked}}'**
  String codexLocationSemantics({required String level, required String state});

  /// Library, level or catalog presentation. Stable IDs and discovery rules are never translated. Named proper nouns retain their canonical spellings.
  ///
  /// In en, this message translates to:
  /// **'{level} map marker'**
  String codexMapMarker({required String level});

  /// Library, level or catalog presentation. Stable IDs and discovery rules are never translated. Named proper nouns retain their canonical spellings.
  ///
  /// In en, this message translates to:
  /// **'melee'**
  String get abilityCategoryMelee;

  /// Library, level or catalog presentation. Stable IDs and discovery rules are never translated. Named proper nouns retain their canonical spellings.
  ///
  /// In en, this message translates to:
  /// **'ranged'**
  String get abilityCategoryRanged;

  /// Library, level or catalog presentation. Stable IDs and discovery rules are never translated. Named proper nouns retain their canonical spellings.
  ///
  /// In en, this message translates to:
  /// **'mobility'**
  String get abilityCategoryMobility;

  /// Library, level or catalog presentation. Stable IDs and discovery rules are never translated. Named proper nouns retain their canonical spellings.
  ///
  /// In en, this message translates to:
  /// **'defense'**
  String get abilityCategoryDefense;

  /// Library, level or catalog presentation. Stable IDs and discovery rules are never translated. Named proper nouns retain their canonical spellings.
  ///
  /// In en, this message translates to:
  /// **'utility'**
  String get abilityCategoryUtility;

  /// Run result presentation. French addresses the player with tu; parameters are localized names and authoritative score counts.
  ///
  /// In en, this message translates to:
  /// **'Boss encounter failed'**
  String get runBossFailed;

  /// Run result presentation. French addresses the player with tu; parameters are localized names and authoritative score counts.
  ///
  /// In en, this message translates to:
  /// **'You gave up the run.'**
  String get runGaveUp;

  /// Run result presentation. French addresses the player with tu; parameters are localized names and authoritative score counts.
  ///
  /// In en, this message translates to:
  /// **'You fell behind.'**
  String get runFellBehind;

  /// Run result presentation. French addresses the player with tu; parameters are localized names and authoritative score counts.
  ///
  /// In en, this message translates to:
  /// **'You fell into a gap.'**
  String get runFellIntoGap;

  /// Run result presentation. French addresses the player with tu; parameters are localized names and authoritative score counts.
  ///
  /// In en, this message translates to:
  /// **'You died.'**
  String get runDied;

  /// Run result presentation. French addresses the player with tu; parameters are localized names and authoritative score counts.
  ///
  /// In en, this message translates to:
  /// **'You succumbed to Poison from a dart trap.'**
  String get runPoisonTrap;

  /// Run result presentation. French addresses the player with tu; parameters are localized names and authoritative score counts.
  ///
  /// In en, this message translates to:
  /// **'Killed by a Spike trap.'**
  String get runSpikeTrap;

  /// Run result presentation. French addresses the player with tu; parameters are localized names and authoritative score counts.
  ///
  /// In en, this message translates to:
  /// **'Killed by a Swinging Axe trap.'**
  String get runAxeTrap;

  /// Run result presentation. French addresses the player with tu; parameters are localized names and authoritative score counts.
  ///
  /// In en, this message translates to:
  /// **'Killed by a Poison Dart.'**
  String get runPoisonDart;

  /// Run result presentation. French addresses the player with tu; parameters are localized names and authoritative score counts.
  ///
  /// In en, this message translates to:
  /// **'You succumbed to a status effect.'**
  String get runStatusDeath;

  /// Run result presentation. French addresses the player with tu; parameters are localized names and authoritative score counts.
  ///
  /// In en, this message translates to:
  /// **'Killed by a trap.'**
  String get runTrapDeath;

  /// Run result presentation. French addresses the player with tu; parameters are localized names and authoritative score counts.
  ///
  /// In en, this message translates to:
  /// **'You were consumed by a spell impact.'**
  String get runSpellDeath;

  /// Run result presentation. French addresses the player with tu; parameters are localized names and authoritative score counts.
  ///
  /// In en, this message translates to:
  /// **'Incinerated by Derf\'s explosion.'**
  String get runDerfDeath;

  /// Run result presentation. French addresses the player with tu; parameters are localized names and authoritative score counts.
  ///
  /// In en, this message translates to:
  /// **'Bullet'**
  String get impactBullet;

  /// Run result presentation. French addresses the player with tu; parameters are localized names and authoritative score counts.
  ///
  /// In en, this message translates to:
  /// **'Crossbow Bolt'**
  String get impactCrossbow;

  /// Run result presentation. French addresses the player with tu; parameters are localized names and authoritative score counts.
  ///
  /// In en, this message translates to:
  /// **'Shotgun Pellet'**
  String get impactPellet;

  /// Run result presentation. French addresses the player with tu; parameters are localized names and authoritative score counts.
  ///
  /// In en, this message translates to:
  /// **'Enemy'**
  String get scoreEnemy;

  /// Run result presentation. French addresses the player with tu; parameters are localized names and authoritative score counts.
  ///
  /// In en, this message translates to:
  /// **'Developer Practice\nNo rewards or leaderboard entries.'**
  String get practiceNoRewards;

  /// Run result presentation. French addresses the player with tu; parameters are localized names and authoritative score counts.
  ///
  /// In en, this message translates to:
  /// **'Killed by {projectile}{source, select, enemy{ from {enemy}.} other{.}}'**
  String runProjectileDeath({
    required String projectile,
    required String source,
    required String enemy,
  });

  /// Run result presentation. French addresses the player with tu; parameters are localized names and authoritative score counts.
  ///
  /// In en, this message translates to:
  /// **'Killed by a melee strike from a {enemy}.'**
  String runMeleeDeath({required String enemy});

  /// Run result presentation. French addresses the player with tu; parameters are localized names and authoritative score counts.
  ///
  /// In en, this message translates to:
  /// **'Killed by a spell impact from {enemy}.'**
  String runEnemySpellDeath({required String enemy});

  /// Run result presentation. French addresses the player with tu; parameters are localized names and authoritative score counts.
  ///
  /// In en, this message translates to:
  /// **'Queued'**
  String get submissionQueued;

  /// Run result presentation. French addresses the player with tu; parameters are localized names and authoritative score counts.
  ///
  /// In en, this message translates to:
  /// **'Requesting Upload Grant'**
  String get submissionRequestingUploadGrant;

  /// Run result presentation. French addresses the player with tu; parameters are localized names and authoritative score counts.
  ///
  /// In en, this message translates to:
  /// **'Uploading Replay'**
  String get submissionUploading;

  /// Run result presentation. French addresses the player with tu; parameters are localized names and authoritative score counts.
  ///
  /// In en, this message translates to:
  /// **'Finalizing'**
  String get submissionFinalizing;

  /// Run result presentation. French addresses the player with tu; parameters are localized names and authoritative score counts.
  ///
  /// In en, this message translates to:
  /// **'Retry Scheduled'**
  String get submissionRetryScheduled;

  /// Run result presentation. French addresses the player with tu; parameters are localized names and authoritative score counts.
  ///
  /// In en, this message translates to:
  /// **'Waiting For Verification'**
  String get submissionPendingValidation;

  /// Run result presentation. French addresses the player with tu; parameters are localized names and authoritative score counts.
  ///
  /// In en, this message translates to:
  /// **'Validating'**
  String get submissionValidating;

  /// Run result presentation. French addresses the player with tu; parameters are localized names and authoritative score counts.
  ///
  /// In en, this message translates to:
  /// **'Settling Reward'**
  String get submissionSettlementPending;

  /// Run result presentation. French addresses the player with tu; parameters are localized names and authoritative score counts.
  ///
  /// In en, this message translates to:
  /// **'Validated'**
  String get submissionValidated;

  /// Run result presentation. French addresses the player with tu; parameters are localized names and authoritative score counts.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get submissionRejected;

  /// Run result presentation. French addresses the player with tu; parameters are localized names and authoritative score counts.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get submissionExpired;

  /// Run result presentation. French addresses the player with tu; parameters are localized names and authoritative score counts.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get submissionCancelled;

  /// Run result presentation. French addresses the player with tu; parameters are localized names and authoritative score counts.
  ///
  /// In en, this message translates to:
  /// **'Internal Error'**
  String get submissionInternalError;

  /// Run result presentation. French addresses the player with tu; parameters are localized names and authoritative score counts.
  ///
  /// In en, this message translates to:
  /// **'Verification could not finish. Return to the hub, or contact support if this continues.'**
  String get submissionFailureBody;

  /// Run result presentation. French addresses the player with tu; parameters are localized names and authoritative score counts.
  ///
  /// In en, this message translates to:
  /// **'+{xp} XP'**
  String runRewardXp({required int xp});

  /// Run result presentation. French addresses the player with tu; parameters are localized names and authoritative score counts.
  ///
  /// In en, this message translates to:
  /// **'Distance: {count}m -> {points}'**
  String scoreRowDistance({required int count, required int points});

  /// Run result presentation. French addresses the player with tu; parameters are localized names and authoritative score counts.
  ///
  /// In en, this message translates to:
  /// **'Collectibles: {count} -> {points}'**
  String scoreRowCollectibles({required int count, required int points});

  /// Run result presentation. French addresses the player with tu; parameters are localized names and authoritative score counts.
  ///
  /// In en, this message translates to:
  /// **'NPCs rescued: {count} -> {points}'**
  String scoreRowRescue({required int count, required int points});

  /// Run result presentation. French addresses the player with tu; parameters are localized names and authoritative score counts.
  ///
  /// In en, this message translates to:
  /// **'Time: {time} -> {points}'**
  String scoreRowTime({required String time, required int points});

  /// Run result presentation. French addresses the player with tu; parameters are localized names and authoritative score counts.
  ///
  /// In en, this message translates to:
  /// **'{enemy} x{count} -> {points}'**
  String scoreRowEnemy({
    required String enemy,
    required int count,
    required int points,
  });

  /// Player UI display or accessibility text. Values are supplied from existing game state; French uses tu.
  ///
  /// In en, this message translates to:
  /// **'Level {level}, maximum level reached'**
  String levelMaximumSemantics({required int level});

  /// Player UI display or accessibility text. Values are supplied from existing game state; French uses tu.
  ///
  /// In en, this message translates to:
  /// **'Level {level}, {earned} of {needed} XP to next level'**
  String levelProgressSemantics({
    required int level,
    required int earned,
    required int needed,
  });

  /// Player UI display or accessibility text. Values are supplied from existing game state; French uses tu.
  ///
  /// In en, this message translates to:
  /// **'LEVEL {level}  ·  MAX LEVEL'**
  String levelMaximumLabel({required int level});

  /// Player UI display or accessibility text. Values are supplied from existing game state; French uses tu.
  ///
  /// In en, this message translates to:
  /// **'LEVEL {level}  ·  {earned} / {needed} XP'**
  String levelProgressLabel({
    required int level,
    required int earned,
    required int needed,
  });

  /// Player UI display or accessibility text. Values are supplied from existing game state; French uses tu.
  ///
  /// In en, this message translates to:
  /// **'Distance {meters}m'**
  String scoreDistance({required int meters});

  /// Player UI display or accessibility text. Values are supplied from existing game state; French uses tu.
  ///
  /// In en, this message translates to:
  /// **'Collectibles {count}'**
  String scoreCollectibles({required int count});

  /// Player UI display or accessibility text. Values are supplied from existing game state; French uses tu.
  ///
  /// In en, this message translates to:
  /// **'{meters}m'**
  String shortDistance({required int meters});

  /// Player UI display or accessibility text. Values are supplied from existing game state; French uses tu.
  ///
  /// In en, this message translates to:
  /// **'{hp} HP'**
  String healthPoints({required int hp});

  /// Player UI display or accessibility text. Values are supplied from existing game state; French uses tu.
  ///
  /// In en, this message translates to:
  /// **'You can change your name again in {hours}h {minutes}m.'**
  String nameChangeCooldown({required int hours, required int minutes});

  /// Player UI display or accessibility text. Values are supplied from existing game state; French uses tu.
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete your account, profile, and cloud progress for this user.\n\nDeletion can take several hours. You cannot start a new account with the same Play Games profile until it finishes.'**
  String get deleteAccountBody;

  /// Player UI display or accessibility text. Values are supplied from existing game state; French uses tu.
  ///
  /// In en, this message translates to:
  /// **'{name}, unlocks at level {level}'**
  String characterLockedSemantics({required String name, required int level});

  /// Player UI display or accessibility text. Values are supplied from existing game state; French uses tu.
  ///
  /// In en, this message translates to:
  /// **'Level {level}'**
  String requiredLevel({required int level});

  /// Player UI display or accessibility text. Values are supplied from existing game state; French uses tu.
  ///
  /// In en, this message translates to:
  /// **'Opponent: {enemy}'**
  String trainingOpponent({required String enemy});

  /// Player UI display or accessibility text. Values are supplied from existing game state; French uses tu.
  ///
  /// In en, this message translates to:
  /// **'Purchased {item}.'**
  String storePurchaseComplete({required String item});

  /// Player UI display or accessibility text. Values are supplied from existing game state; French uses tu.
  ///
  /// In en, this message translates to:
  /// **'Store refreshes left: {count}'**
  String storeRefreshesLeft({required int count});

  /// Player UI display or accessibility text. Values are supplied from existing game state; French uses tu.
  ///
  /// In en, this message translates to:
  /// **'Open Town to browse locked {slot, select, mainWeapon{main weapon} offhandWeapon{offhand} spellBook{spellbook} other{accessory}} options?'**
  String storeBrowseLocked({required String slot});

  /// Player UI display or accessibility text. Values are supplied from existing game state; French uses tu.
  ///
  /// In en, this message translates to:
  /// **'{slot, select, primary{PRIMARY SKILLS} secondary{SECONDARY SKILLS} projectile{PROJECTILE SKILLS} mobility{MOBILITY SKILLS} spell{SPELL SKILLS} jump{JUMP SKILLS} other{FIELDCRAFT SKILLS}}'**
  String skillHeading({required String slot});

  /// Player UI display or accessibility text. Values are supplied from existing game state; French uses tu.
  ///
  /// In en, this message translates to:
  /// **'Game · {date}'**
  String messageHeader({required String date});

  /// Player UI display or accessibility text. Values are supplied from existing game state; French uses tu.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item / skill gift} other{{count} item / skill gifts}}'**
  String messageGiftCount({required int count});

  /// Player UI display or accessibility text. Values are supplied from existing game state; French uses tu.
  ///
  /// In en, this message translates to:
  /// **'WEEKLY {window} • {level}'**
  String weeklyBadge({required String window, required String level});

  /// Player UI display or accessibility text. Values are supplied from existing game state; French uses tu.
  ///
  /// In en, this message translates to:
  /// **'{level} {mode} Scoreboard'**
  String scoreboardTitle({required String level, required String mode});

  /// Player UI display or accessibility text. Values are supplied from existing game state; French uses tu.
  ///
  /// In en, this message translates to:
  /// **'{level} {mode} BOARD'**
  String leaderboardTitle({required String level, required String mode});

  /// Player UI display or accessibility text. Values are supplied from existing game state; French uses tu.
  ///
  /// In en, this message translates to:
  /// **' / {count}'**
  String rankTotal({required int count});

  /// Player UI display or accessibility text. Values are supplied from existing game state; French uses tu.
  ///
  /// In en, this message translates to:
  /// **'Actual rank {rank}{position, select, first{ (1st place)} second{ (2nd place, podium)} third{ (3rd place, podium)} topTen{ (top 10)} other{}}{outcome, select, unchanged{, you have not done better this run.} other{.}}'**
  String rankSummary({
    required String rank,
    required String position,
    required String outcome,
  });

  /// Player UI display or accessibility text. Values are supplied from existing game state; French uses tu.
  ///
  /// In en, this message translates to:
  /// **'{label}, follow-up available'**
  String controlFollowUp({required String label});

  /// Player UI display or accessibility text. Values are supplied from existing game state; French uses tu.
  ///
  /// In en, this message translates to:
  /// **'Sword'**
  String get controlSword;

  /// Player UI display or accessibility text. Values are supplied from existing game state; French uses tu.
  ///
  /// In en, this message translates to:
  /// **'Shield'**
  String get controlShield;

  /// Player UI display or accessibility text. Values are supplied from existing game state; French uses tu.
  ///
  /// In en, this message translates to:
  /// **'Projectile'**
  String get controlProjectile;

  /// Player UI display or accessibility text. Values are supplied from existing game state; French uses tu.
  ///
  /// In en, this message translates to:
  /// **'Mobility'**
  String get controlMobility;

  /// Player UI display or accessibility text. Values are supplied from existing game state; French uses tu.
  ///
  /// In en, this message translates to:
  /// **'Jump'**
  String get controlJump;

  /// Player UI display or accessibility text. Values are supplied from existing game state; French uses tu.
  ///
  /// In en, this message translates to:
  /// **'Spell'**
  String get controlSpell;

  /// Player UI display or accessibility text. Values are supplied from existing game state; French uses tu.
  ///
  /// In en, this message translates to:
  /// **'Move left'**
  String get controlMoveLeft;

  /// Player UI display or accessibility text. Values are supplied from existing game state; French uses tu.
  ///
  /// In en, this message translates to:
  /// **'Move right'**
  String get controlMoveRight;

  /// Player UI display or accessibility text. Values are supplied from existing game state; French uses tu.
  ///
  /// In en, this message translates to:
  /// **'Movement joystick'**
  String get controlJoystick;

  /// Player UI display or accessibility text. Values are supplied from existing game state; French uses tu.
  ///
  /// In en, this message translates to:
  /// **'Backward'**
  String get controlBackward;

  /// Player UI display or accessibility text. Values are supplied from existing game state; French uses tu.
  ///
  /// In en, this message translates to:
  /// **'Forward'**
  String get controlForward;

  /// Player UI display or accessibility text. Values are supplied from existing game state; French uses tu.
  ///
  /// In en, this message translates to:
  /// **'Neutral'**
  String get controlNeutral;

  /// Player UI display or accessibility text. Values are supplied from existing game state; French uses tu.
  ///
  /// In en, this message translates to:
  /// **'Unable to start run'**
  String get runStartErrorTitle;

  /// Player UI display or accessibility text. Values are supplied from existing game state; French uses tu.
  ///
  /// In en, this message translates to:
  /// **'Luxis Games'**
  String get studioName;

  /// Default loadout slot name. Custom names stay exactly as entered; this label never replaces saved default tokens.
  ///
  /// In en, this message translates to:
  /// **'Build {number}'**
  String defaultBuildName({required int number});

  /// Whole metre distance to an offscreen actor.
  ///
  /// In en, this message translates to:
  /// **'{meters} m'**
  String offscreenDistance({required int meters});

  /// Positive offscreen distance smaller than one metre.
  ///
  /// In en, this message translates to:
  /// **'<1 m'**
  String get offscreenNearby;

  /// Offscreen group size and distance.
  ///
  /// In en, this message translates to:
  /// **'×{count} · {distance}'**
  String offscreenGroup({required int count, required String distance});

  /// Failed store or support link. Email remains a technical address.
  ///
  /// In en, this message translates to:
  /// **'Unable to open the link. Try again or contact {email}.'**
  String supportLinkFailed({required String email});

  /// Current resource and capacity.
  ///
  /// In en, this message translates to:
  /// **'{value} / {maximum}'**
  String resourceRatio({required int value, required int maximum});

  /// Quotation marks around a complete translated item description.
  ///
  /// In en, this message translates to:
  /// **'“{description}”'**
  String quotedDescription({required String description});

  /// Developer-only app title; product identifier retained.
  ///
  /// In en, this message translates to:
  /// **'rpg Runner (Dev)'**
  String get developerAppTitle;

  /// Developer-only route back to the menu.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get developerMenu;

  /// Recovery message on the route or inbox loading surface.
  ///
  /// In en, this message translates to:
  /// **'Unable to start run'**
  String get routeRunUnavailableTitle;

  /// Recovery message on the route or inbox loading surface.
  ///
  /// In en, this message translates to:
  /// **'Return to the hub and start the run again.'**
  String get routeRunUnavailableBody;

  /// Recovery message on the route or inbox loading surface.
  ///
  /// In en, this message translates to:
  /// **'Page unavailable'**
  String get routeUnavailableTitle;

  /// Recovery message on the route or inbox loading surface.
  ///
  /// In en, this message translates to:
  /// **'This page could not be opened. Go back and try again.'**
  String get routeUnavailableBody;

  /// Recovery message on the route or inbox loading surface.
  ///
  /// In en, this message translates to:
  /// **'Unable to load messages. Please try again.'**
  String get inboxLoadFailed;

  /// Retry blocked because the previous run could not release its resources.
  ///
  /// In en, this message translates to:
  /// **'Unable to release the previous run. Exit and try again.'**
  String get runCleanupFailed;

  /// Default synthetic profile name in local Developer Practice; custom names remain unchanged.
  ///
  /// In en, this message translates to:
  /// **'Developer'**
  String get developerIdentity;

  /// Town equipment merchant title and navigation.
  ///
  /// In en, this message translates to:
  /// **'Equipment'**
  String get townEquipment;

  /// Town service for learning permanent abilities; distinct from Training Field practice.
  ///
  /// In en, this message translates to:
  /// **'Training Hall'**
  String get townTraining;

  /// Accessible equipment building marker.
  ///
  /// In en, this message translates to:
  /// **'Equipment merchant marker'**
  String get townEquipmentMarker;

  /// Accessible training building marker.
  ///
  /// In en, this message translates to:
  /// **'Training hall marker'**
  String get townTrainingMarker;

  /// Equipment catalogue introduction; gold is still required to buy unowned entries.
  ///
  /// In en, this message translates to:
  /// **'Choose equipment for your next build. Every item is always available.'**
  String get townEquipmentIntro;

  /// Training catalogue introduction. Browsing does not change run selection.
  ///
  /// In en, this message translates to:
  /// **'Learn permanent techniques for the character you choose.'**
  String get townTrainingIntro;

  /// Catalogue category filter showing every slot.
  ///
  /// In en, this message translates to:
  /// **'All categories'**
  String get townAllCategories;

  /// Optional catalogue filter hiding owned entries.
  ///
  /// In en, this message translates to:
  /// **'Not yet unlocked'**
  String get townUnownedOnly;

  /// Equipment already owned; replaces purchase control.
  ///
  /// In en, this message translates to:
  /// **'Owned'**
  String get townOwned;

  /// Ability already learned; replaces purchase control.
  ///
  /// In en, this message translates to:
  /// **'Learned'**
  String get townLearned;

  /// Purchase a permanent ability with earned gold.
  ///
  /// In en, this message translates to:
  /// **'Learn'**
  String get townLearn;

  /// Accessories are account-wide; no second purchase for the other character.
  ///
  /// In en, this message translates to:
  /// **'Usable by both · One purchase'**
  String get townSharedAccessory;

  /// Retained schema-1 snapshot cannot safely support explicit-character catalogue purchases.
  ///
  /// In en, this message translates to:
  /// **'The catalogue is unavailable. Return to town and reconnect to load it.'**
  String get townCatalogueUnavailable;

  /// Empty filtered catalogue, including when every entry is owned.
  ///
  /// In en, this message translates to:
  /// **'No entries match these filters.'**
  String get townNoMatchingEntries;

  /// Expanded equipment comparison; item is currently equipped name, build is selected saved build name for browsed character.
  ///
  /// In en, this message translates to:
  /// **'Compared with {item} · {build}'**
  String townCompareWith({required String item, required String build});

  /// Catalogue category. character is eloise or bountyHunter; service is equipment or training; slot is the stable StoreSlot name.
  ///
  /// In en, this message translates to:
  /// **'{slot, select, mainWeapon{Weapons} offhandWeapon{{character, select, bountyHunter{Bomb kits} other{Shields}}} spellBook{{character, select, bountyHunter{Field kits} other{Spellbooks}}} accessory{Accessories} primary{Primary} secondary{Secondary} projectile{{service, select, training{Ranged techniques} other{{character, select, bountyHunter{Ranged weapons} other{Ranged spells}}}}} mobility{Mobility} jump{Jump} spell{{character, select, bountyHunter{Fieldcraft} other{Spells}}} other{Equipment}}'**
  String townCategory({
    required String character,
    required String service,
    required String slot,
  });

  /// Result subtitle for a verified Core mission success.
  ///
  /// In en, this message translates to:
  /// **'Mission complete'**
  String get runMissionCompleted;

  /// Result subtitle when a required mission objective is lost.
  ///
  /// In en, this message translates to:
  /// **'Mission failed'**
  String get runMissionFailed;

  /// Campaign navigation, mission progress or chapter reward label.
  ///
  /// In en, this message translates to:
  /// **'Campaign'**
  String get campaignHeading;

  /// Campaign navigation, mission progress or chapter reward label.
  ///
  /// In en, this message translates to:
  /// **'Regional map'**
  String get campaignRegionalMap;

  /// Campaign navigation, mission progress or chapter reward label.
  ///
  /// In en, this message translates to:
  /// **'Chapter reward: Willow'**
  String get campaignChapterReward;

  /// Campaign navigation, mission progress or chapter reward label.
  ///
  /// In en, this message translates to:
  /// **'First clear: {xp} XP'**
  String campaignFirstClearXp({required int xp});

  /// Campaign navigation, mission progress or chapter reward label.
  ///
  /// In en, this message translates to:
  /// **'Unlock double jump'**
  String get campaignDoubleJumpReward;

  /// Campaign navigation, mission progress or chapter reward label.
  ///
  /// In en, this message translates to:
  /// **'Keep collected gold on every verified attempt'**
  String get campaignCollectedGold;

  /// Campaign navigation, mission progress or chapter reward label.
  ///
  /// In en, this message translates to:
  /// **'Best score: {score}'**
  String campaignBestScore({required int score});

  /// Campaign navigation, mission progress or chapter reward label.
  ///
  /// In en, this message translates to:
  /// **'Complete the previous mission to unlock'**
  String get campaignPreviousRequired;

  /// Campaign navigation, mission progress or chapter reward label.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get campaignComingSoon;

  /// Campaign navigation, mission progress or chapter reward label.
  ///
  /// In en, this message translates to:
  /// **'Replay'**
  String get campaignReplay;

  /// Campaign navigation, mission progress or chapter reward label.
  ///
  /// In en, this message translates to:
  /// **'Start mission'**
  String get campaignStart;

  /// Campaign navigation, mission progress or chapter reward label.
  ///
  /// In en, this message translates to:
  /// **'Complete the Val Outpost chapter to unlock Willow'**
  String get campaignWillowLocked;

  /// Campaign navigation, mission progress or chapter reward label.
  ///
  /// In en, this message translates to:
  /// **'Your clear and first-clear rewards unlock after verification.'**
  String get campaignVerificationPending;

  /// Campaign navigation, mission progress or chapter reward label.
  ///
  /// In en, this message translates to:
  /// **'Next mission'**
  String get campaignNextMission;

  /// Required campaign objective progress.
  ///
  /// In en, this message translates to:
  /// **'Objectives: {completed}/{required}'**
  String campaignObjectives({required int completed, required int required});

  /// All campaign requirements are met; reach the authored exit.
  ///
  /// In en, this message translates to:
  /// **'Reach the exit'**
  String get campaignReachExit;

  /// Verified campaign reward and explicit equip action.
  ///
  /// In en, this message translates to:
  /// **'Equip double jump for Éloïse'**
  String get campaignEquipDoubleJump;

  /// Verified campaign reward and explicit equip action.
  ///
  /// In en, this message translates to:
  /// **'Double jump equipped'**
  String get campaignDoubleJumpEquipped;

  /// Verified campaign reward and explicit equip action.
  ///
  /// In en, this message translates to:
  /// **'Could not equip double jump. Try again.'**
  String get campaignEquipFailed;

  /// Verified campaign reward and explicit equip action.
  ///
  /// In en, this message translates to:
  /// **'Chapter complete — Willow unlocked'**
  String get campaignWillowUnlocked;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
