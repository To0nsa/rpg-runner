import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'game_localizations_en.dart';
import 'game_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of GameLocalizations
/// returned by `GameLocalizations.of(context)`.
///
/// Applications need to include `GameLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/game_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: GameLocalizations.localizationsDelegates,
///   supportedLocales: GameLocalizations.supportedLocales,
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
/// be consistent with the languages listed in the GameLocalizations.supportedLocales
/// property.
abstract class GameLocalizations {
  GameLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static GameLocalizations? of(BuildContext context) {
    return Localizations.of<GameLocalizations>(context, GameLocalizations);
  }

  static const LocalizationsDelegate<GameLocalizations> delegate =
      _GameLocalizationsDelegate();

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

  /// Catalog name for weapons/plainsteel. Keep distinct from its stable internal ID.
  ///
  /// In en, this message translates to:
  /// **'Plainsteel'**
  String get weaponPlainsteelName;

  /// Catalog description for weapons/plainsteel. Describes tradeoffs; numeric tuning is supplied separately by Core.
  ///
  /// In en, this message translates to:
  /// **'Baseline one-handed sword with consistent output.'**
  String get weaponPlainsteelDescription;

  /// Catalog name for weapons/waspfang. Keep distinct from its stable internal ID.
  ///
  /// In en, this message translates to:
  /// **'Waspfang'**
  String get weaponWaspfangName;

  /// Catalog description for weapons/waspfang. Describes tradeoffs; numeric tuning is supplied separately by Core.
  ///
  /// In en, this message translates to:
  /// **'Bleed pressure sword with lower upfront power.'**
  String get weaponWaspfangDescription;

  /// Catalog name for weapons/cinderedge. Keep distinct from its stable internal ID.
  ///
  /// In en, this message translates to:
  /// **'Cinderedge'**
  String get weaponCinderedgeName;

  /// Catalog description for weapons/cinderedge. Describes tradeoffs; numeric tuning is supplied separately by Core.
  ///
  /// In en, this message translates to:
  /// **'Crit-focused blade that ignites on critical strikes.'**
  String get weaponCinderedgeDescription;

  /// Catalog name for weapons/basiliskKiss. Keep distinct from its stable internal ID.
  ///
  /// In en, this message translates to:
  /// **'Basilisk Kiss'**
  String get weaponBasiliskKissName;

  /// Catalog description for weapons/basiliskKiss. Describes tradeoffs; numeric tuning is supplied separately by Core.
  ///
  /// In en, this message translates to:
  /// **'Anti-tank sword that trades burst for acid vulnerability pressure.'**
  String get weaponBasiliskKissDescription;

  /// Catalog name for weapons/frostbrand. Keep distinct from its stable internal ID.
  ///
  /// In en, this message translates to:
  /// **'Frostbrand'**
  String get weaponFrostbrandName;

  /// Catalog description for weapons/frostbrand. Describes tradeoffs; numeric tuning is supplied separately by Core.
  ///
  /// In en, this message translates to:
  /// **'Control sword that applies slows for safer tempo.'**
  String get weaponFrostbrandDescription;

  /// Catalog name for weapons/stormneedle. Keep distinct from its stable internal ID.
  ///
  /// In en, this message translates to:
  /// **'Stormneedle'**
  String get weaponStormneedleName;

  /// Catalog description for weapons/stormneedle. Describes tradeoffs; numeric tuning is supplied separately by Core.
  ///
  /// In en, this message translates to:
  /// **'Sustained crit/stamina sword with regen and a health tradeoff.'**
  String get weaponStormneedleDescription;

  /// Catalog name for weapons/nullblade. Keep distinct from its stable internal ID.
  ///
  /// In en, this message translates to:
  /// **'Nullblade'**
  String get weaponNullbladeName;

  /// Catalog description for weapons/nullblade. Describes tradeoffs; numeric tuning is supplied separately by Core.
  ///
  /// In en, this message translates to:
  /// **'Anti-caster sword that can silence on hit.'**
  String get weaponNullbladeDescription;

  /// Catalog name for weapons/sunlitVow. Keep distinct from its stable internal ID.
  ///
  /// In en, this message translates to:
  /// **'Sunlit Vow'**
  String get weaponSunlitVowName;

  /// Catalog description for weapons/sunlitVow. Describes tradeoffs; numeric tuning is supplied separately by Core.
  ///
  /// In en, this message translates to:
  /// **'Kill-chain sword that can grant Focus and boosts sustained pressure.'**
  String get weaponSunlitVowDescription;

  /// Catalog name for weapons/roadguard. Keep distinct from its stable internal ID.
  ///
  /// In en, this message translates to:
  /// **'Roadguard'**
  String get weaponRoadguardName;

  /// Catalog description for weapons/roadguard. Describes tradeoffs; numeric tuning is supplied separately by Core.
  ///
  /// In en, this message translates to:
  /// **'Baseline all-rounder shield with dependable defense.'**
  String get weaponRoadguardDescription;

  /// Catalog name for weapons/thornbark. Keep distinct from its stable internal ID.
  ///
  /// In en, this message translates to:
  /// **'Thornbark'**
  String get weaponThornbarkName;

  /// Catalog description for weapons/thornbark. Describes tradeoffs; numeric tuning is supplied separately by Core.
  ///
  /// In en, this message translates to:
  /// **'Retaliation shield that bleeds attackers on damage.'**
  String get weaponThornbarkDescription;

  /// Catalog name for weapons/cinderWard. Keep distinct from its stable internal ID.
  ///
  /// In en, this message translates to:
  /// **'Cinder Ward'**
  String get weaponCinderWardName;

  /// Catalog description for weapons/cinderWard. Describes tradeoffs; numeric tuning is supplied separately by Core.
  ///
  /// In en, this message translates to:
  /// **'Fire-counter shield with defense and a crit-scaling dump.'**
  String get weaponCinderWardDescription;

  /// Catalog name for weapons/tideguardShell. Keep distinct from its stable internal ID.
  ///
  /// In en, this message translates to:
  /// **'Tideguard Shell'**
  String get weaponTideguardShellName;

  /// Catalog description for weapons/tideguardShell. Describes tradeoffs; numeric tuning is supplied separately by Core.
  ///
  /// In en, this message translates to:
  /// **'Water-stabilizer shield with stamina support and power tax.'**
  String get weaponTideguardShellDescription;

  /// Catalog name for weapons/frostlockBuckler. Keep distinct from its stable internal ID.
  ///
  /// In en, this message translates to:
  /// **'Frostlock Buckler'**
  String get weaponFrostlockBucklerName;

  /// Catalog description for weapons/frostlockBuckler. Describes tradeoffs; numeric tuning is supplied separately by Core.
  ///
  /// In en, this message translates to:
  /// **'Cold matchup shield with balanced defense and stamina.'**
  String get weaponFrostlockBucklerDescription;

  /// Catalog name for weapons/ironBastion. Keep distinct from its stable internal ID.
  ///
  /// In en, this message translates to:
  /// **'Iron Bastion'**
  String get weaponIronBastionName;

  /// Catalog description for weapons/ironBastion. Describes tradeoffs; numeric tuning is supplied separately by Core.
  ///
  /// In en, this message translates to:
  /// **'Heavy face-tank shield with the strongest soak and lower mobility.'**
  String get weaponIronBastionDescription;

  /// Catalog name for weapons/stormAegis. Keep distinct from its stable internal ID.
  ///
  /// In en, this message translates to:
  /// **'Storm Aegis'**
  String get weaponStormAegisName;

  /// Catalog description for weapons/stormAegis. Describes tradeoffs; numeric tuning is supplied separately by Core.
  ///
  /// In en, this message translates to:
  /// **'Thunder counterpick shield with regen and a crit dump.'**
  String get weaponStormAegisDescription;

  /// Catalog name for weapons/nullPrism. Keep distinct from its stable internal ID.
  ///
  /// In en, this message translates to:
  /// **'Null Prism'**
  String get weaponNullPrismName;

  /// Catalog description for weapons/nullPrism. Describes tradeoffs; numeric tuning is supplied separately by Core.
  ///
  /// In en, this message translates to:
  /// **'Dual dark/holy resist shield that trades mobility for coverage.'**
  String get weaponNullPrismDescription;

  /// Catalog name for weapons/warbannerGuard. Keep distinct from its stable internal ID.
  ///
  /// In en, this message translates to:
  /// **'Warbanner Guard'**
  String get weaponWarbannerGuardName;

  /// Catalog description for weapons/warbannerGuard. Describes tradeoffs; numeric tuning is supplied separately by Core.
  ///
  /// In en, this message translates to:
  /// **'Stamina-forward frontline shield with a heavy crit dump.'**
  String get weaponWarbannerGuardDescription;

  /// Catalog name for weapons/oathwallRelic. Keep distinct from its stable internal ID.
  ///
  /// In en, this message translates to:
  /// **'Oathwall Relic'**
  String get weaponOathwallRelicName;

  /// Catalog description for weapons/oathwallRelic. Describes tradeoffs; numeric tuning is supplied separately by Core.
  ///
  /// In en, this message translates to:
  /// **'Clutch survival shield with low-health haste and permanent offense tax.'**
  String get weaponOathwallRelicDescription;

  /// Catalog name for weapons/hunterBlade. Keep distinct from its stable internal ID.
  ///
  /// In en, this message translates to:
  /// **'Hunter Blade'**
  String get weaponHunterBladeName;

  /// Catalog description for weapons/hunterBlade. Describes tradeoffs; numeric tuning is supplied separately by Core.
  ///
  /// In en, this message translates to:
  /// **'Reliable mixed combat with a small defense tradeoff.'**
  String get weaponHunterBladeDescription;

  /// Catalog name for weapons/hunterBombKit. Keep distinct from its stable internal ID.
  ///
  /// In en, this message translates to:
  /// **'Bomb Kit'**
  String get weaponHunterBombKitName;

  /// Catalog description for weapons/hunterBombKit. Describes tradeoffs; numeric tuning is supplied separately by Core.
  ///
  /// In en, this message translates to:
  /// **'A protective bomb rig that trades movement speed for steadiness.'**
  String get weaponHunterBombKitDescription;

  /// Catalog name for weapons/hunterNotchknife. Keep distinct from its stable internal ID.
  ///
  /// In en, this message translates to:
  /// **'Notchknife'**
  String get weaponHunterNotchknifeName;

  /// Catalog description for weapons/hunterNotchknife. Describes tradeoffs; numeric tuning is supplied separately by Core.
  ///
  /// In en, this message translates to:
  /// **'Bleeding cuts reward disengaging, at the cost of maximum health.'**
  String get weaponHunterNotchknifeDescription;

  /// Catalog name for weapons/hunterHookblade. Keep distinct from its stable internal ID.
  ///
  /// In en, this message translates to:
  /// **'Hookblade'**
  String get weaponHunterHookbladeName;

  /// Catalog description for weapons/hunterHookblade. Describes tradeoffs; numeric tuning is supplied separately by Core.
  ///
  /// In en, this message translates to:
  /// **'Slowing cuts create room for a shot or bomb, with lower defense.'**
  String get weaponHunterHookbladeDescription;

  /// Catalog name for weapons/hunterCausticEdge. Keep distinct from its stable internal ID.
  ///
  /// In en, this message translates to:
  /// **'Caustic Edge'**
  String get weaponHunterCausticEdgeName;

  /// Catalog description for weapons/hunterCausticEdge. Describes tradeoffs; numeric tuning is supplied separately by Core.
  ///
  /// In en, this message translates to:
  /// **'Melee openings expose a target to follow-up damage, with lower health.'**
  String get weaponHunterCausticEdgeDescription;

  /// Catalog name for weapons/hunterCinderpoint. Keep distinct from its stable internal ID.
  ///
  /// In en, this message translates to:
  /// **'Cinderpoint'**
  String get weaponHunterCinderpointName;

  /// Catalog description for weapons/hunterCinderpoint. Describes tradeoffs; numeric tuning is supplied separately by Core.
  ///
  /// In en, this message translates to:
  /// **'Critical cuts ignite enemies, at the cost of Supplies regeneration.'**
  String get weaponHunterCinderpointDescription;

  /// Catalog name for weapons/hunterSappingBlade. Keep distinct from its stable internal ID.
  ///
  /// In en, this message translates to:
  /// **'Sapping Blade'**
  String get weaponHunterSappingBladeName;

  /// Catalog description for weapons/hunterSappingBlade. Describes tradeoffs; numeric tuning is supplied separately by Core.
  ///
  /// In en, this message translates to:
  /// **'Cuts can weaken enemy attacks, but maximum health is lower.'**
  String get weaponHunterSappingBladeDescription;

  /// Catalog name for weapons/hunterPursuitBlade. Keep distinct from its stable internal ID.
  ///
  /// In en, this message translates to:
  /// **'Pursuit Blade'**
  String get weaponHunterPursuitBladeName;

  /// Catalog description for weapons/hunterPursuitBlade. Describes tradeoffs; numeric tuning is supplied separately by Core.
  ///
  /// In en, this message translates to:
  /// **'Melee kills can grant a short burst of speed, with lower defense.'**
  String get weaponHunterPursuitBladeDescription;

  /// Catalog name for weapons/hunterLastWord. Keep distinct from its stable internal ID.
  ///
  /// In en, this message translates to:
  /// **'Last Word'**
  String get weaponHunterLastWordName;

  /// Catalog description for weapons/hunterLastWord. Describes tradeoffs; numeric tuning is supplied separately by Core.
  ///
  /// In en, this message translates to:
  /// **'Strong direct offense and stamina, with less health for mistakes.'**
  String get weaponHunterLastWordDescription;

  /// Catalog name for weapons/hunterSplinterRig. Keep distinct from its stable internal ID.
  ///
  /// In en, this message translates to:
  /// **'Splinter Rig'**
  String get weaponHunterSplinterRigName;

  /// Catalog description for weapons/hunterSplinterRig. Describes tradeoffs; numeric tuning is supplied separately by Core.
  ///
  /// In en, this message translates to:
  /// **'Critical blasts cause bleeding, at the cost of global power.'**
  String get weaponHunterSplinterRigDescription;

  /// Catalog name for weapons/hunterPitchRig. Keep distinct from its stable internal ID.
  ///
  /// In en, this message translates to:
  /// **'Pitch Rig'**
  String get weaponHunterPitchRigName;

  /// Catalog description for weapons/hunterPitchRig. Describes tradeoffs; numeric tuning is supplied separately by Core.
  ///
  /// In en, this message translates to:
  /// **'Critical blasts ignite survivors, with lower critical chance.'**
  String get weaponHunterPitchRigDescription;

  /// Catalog name for weapons/hunterSnareRig. Keep distinct from its stable internal ID.
  ///
  /// In en, this message translates to:
  /// **'Snare Rig'**
  String get weaponHunterSnareRigName;

  /// Catalog description for weapons/hunterSnareRig. Describes tradeoffs; numeric tuning is supplied separately by Core.
  ///
  /// In en, this message translates to:
  /// **'Blasts can slow pursuers, at the cost of global power.'**
  String get weaponHunterSnareRigDescription;

  /// Catalog name for weapons/hunterEtchingRig. Keep distinct from its stable internal ID.
  ///
  /// In en, this message translates to:
  /// **'Etching Rig'**
  String get weaponHunterEtchingRigName;

  /// Catalog description for weapons/hunterEtchingRig. Describes tradeoffs; numeric tuning is supplied separately by Core.
  ///
  /// In en, this message translates to:
  /// **'Blasts can expose survivors to follow-up damage, with lower critical chance.'**
  String get weaponHunterEtchingRigDescription;

  /// Catalog name for weapons/hunterSapperHarness. Keep distinct from its stable internal ID.
  ///
  /// In en, this message translates to:
  /// **'Sapper Harness'**
  String get weaponHunterSapperHarnessName;

  /// Catalog description for weapons/hunterSapperHarness. Describes tradeoffs; numeric tuning is supplied separately by Core.
  ///
  /// In en, this message translates to:
  /// **'Physical protection and stamina recovery, with substantially slower movement.'**
  String get weaponHunterSapperHarnessDescription;

  /// Catalog name for weapons/hunterKilnwrapRig. Keep distinct from its stable internal ID.
  ///
  /// In en, this message translates to:
  /// **'Kilnwrap Rig'**
  String get weaponHunterKilnwrapRigName;

  /// Catalog description for weapons/hunterKilnwrapRig. Describes tradeoffs; numeric tuning is supplied separately by Core.
  ///
  /// In en, this message translates to:
  /// **'Preparation for fire-heavy encounters, with lower critical chance.'**
  String get weaponHunterKilnwrapRigDescription;

  /// Catalog name for weapons/hunterSealedRig. Keep distinct from its stable internal ID.
  ///
  /// In en, this message translates to:
  /// **'Sealed Rig'**
  String get weaponHunterSealedRigName;

  /// Catalog description for weapons/hunterSealedRig. Describes tradeoffs; numeric tuning is supplied separately by Core.
  ///
  /// In en, this message translates to:
  /// **'Acid and water protection with stamina reserves, at the cost of power.'**
  String get weaponHunterSealedRigDescription;

  /// Catalog name for weapons/hunterStormwrapRig. Keep distinct from its stable internal ID.
  ///
  /// In en, this message translates to:
  /// **'Stormwrap Rig'**
  String get weaponHunterStormwrapRigName;

  /// Catalog description for weapons/hunterStormwrapRig. Describes tradeoffs; numeric tuning is supplied separately by Core.
  ///
  /// In en, this message translates to:
  /// **'Thunder protection and stamina recovery, with lower critical chance.'**
  String get weaponHunterStormwrapRigDescription;

  /// Catalog name for weapons/hunterBacktrailRig. Keep distinct from its stable internal ID.
  ///
  /// In en, this message translates to:
  /// **'Backtrail Rig'**
  String get weaponHunterBacktrailRigName;

  /// Catalog description for weapons/hunterBacktrailRig. Describes tradeoffs; numeric tuning is supplied separately by Core.
  ///
  /// In en, this message translates to:
  /// **'Low-health haste creates an escape opportunity, at a permanent power cost.'**
  String get weaponHunterBacktrailRigDescription;

  /// Catalog name for projectiles/unknown. Keep distinct from its stable internal ID.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get projectileUnknownName;

  /// Catalog description for projectiles/unknown. Describes tradeoffs; numeric tuning is supplied separately by Core.
  ///
  /// In en, this message translates to:
  /// **'No description available yet.'**
  String get projectileUnknownDescription;

  /// Catalog name for projectiles/iceBolt. Keep distinct from its stable internal ID.
  ///
  /// In en, this message translates to:
  /// **'Ice Bolt'**
  String get projectileIceBoltName;

  /// Catalog description for projectiles/iceBolt. Describes tradeoffs; numeric tuning is supplied separately by Core.
  ///
  /// In en, this message translates to:
  /// **'Spell projectile that chills on hit.'**
  String get projectileIceBoltDescription;

  /// Catalog name for projectiles/fireBolt. Keep distinct from its stable internal ID.
  ///
  /// In en, this message translates to:
  /// **'Fire Bolt'**
  String get projectileFireBoltName;

  /// Catalog description for projectiles/fireBolt. Describes tradeoffs; numeric tuning is supplied separately by Core.
  ///
  /// In en, this message translates to:
  /// **'Spell projectile that burns on hit.'**
  String get projectileFireBoltDescription;

  /// Catalog name for projectiles/acidBolt. Keep distinct from its stable internal ID.
  ///
  /// In en, this message translates to:
  /// **'Acid Bolt'**
  String get projectileAcidBoltName;

  /// Catalog description for projectiles/acidBolt. Describes tradeoffs; numeric tuning is supplied separately by Core.
  ///
  /// In en, this message translates to:
  /// **'Spell projectile that corrodes and increases damage taken.'**
  String get projectileAcidBoltDescription;

  /// Catalog name for projectiles/darkBolt. Keep distinct from its stable internal ID.
  ///
  /// In en, this message translates to:
  /// **'Dark Bolt'**
  String get projectileDarkBoltName;

  /// Catalog description for projectiles/darkBolt. Describes tradeoffs; numeric tuning is supplied separately by Core.
  ///
  /// In en, this message translates to:
  /// **'Spell projectile that weakens enemy outgoing damage on hit.'**
  String get projectileDarkBoltDescription;

  /// Catalog name for projectiles/earthBolt. Keep distinct from its stable internal ID.
  ///
  /// In en, this message translates to:
  /// **'Earth Bolt'**
  String get projectileEarthBoltName;

  /// Catalog description for projectiles/earthBolt. Describes tradeoffs; numeric tuning is supplied separately by Core.
  ///
  /// In en, this message translates to:
  /// **'Spell projectile that stuns enemies on hit.'**
  String get projectileEarthBoltDescription;

  /// Catalog name for projectiles/holyBolt. Keep distinct from its stable internal ID.
  ///
  /// In en, this message translates to:
  /// **'Holy Bolt'**
  String get projectileHolyBoltName;

  /// Holy Bolt silence duration from its resolved Core status profile, in seconds.
  ///
  /// In en, this message translates to:
  /// **'Spell projectile that silences enemy casts for {seconds, plural, one{one second} other{{seconds} seconds}}.'**
  String projectileHolyBoltDescription({required num seconds});

  /// Catalog name for projectiles/waterBolt. Keep distinct from its stable internal ID.
  ///
  /// In en, this message translates to:
  /// **'Water Bolt'**
  String get projectileWaterBoltName;

  /// Catalog description for projectiles/waterBolt. Describes tradeoffs; numeric tuning is supplied separately by Core.
  ///
  /// In en, this message translates to:
  /// **'Spell projectile that drenches and slows attack/cast speed.'**
  String get projectileWaterBoltDescription;

  /// Catalog name for projectiles/thunderBolt. Keep distinct from its stable internal ID.
  ///
  /// In en, this message translates to:
  /// **'Thunder Bolt'**
  String get projectileThunderBoltName;

  /// Catalog description for projectiles/thunderBolt. Describes tradeoffs; numeric tuning is supplied separately by Core.
  ///
  /// In en, this message translates to:
  /// **'Spell projectile with thunder damage.'**
  String get projectileThunderBoltDescription;

  /// Catalog name for projectiles/poisonDart. Keep distinct from its stable internal ID.
  ///
  /// In en, this message translates to:
  /// **'Poison Dart'**
  String get projectilePoisonDartName;

  /// Catalog description for projectiles/poisonDart. Describes tradeoffs; numeric tuning is supplied separately by Core.
  ///
  /// In en, this message translates to:
  /// **'No description available yet.'**
  String get projectilePoisonDartDescription;

  /// Catalog name for projectiles/npcSpear. Keep distinct from its stable internal ID.
  ///
  /// In en, this message translates to:
  /// **'Npc Spear'**
  String get projectileNpcSpearName;

  /// Catalog description for projectiles/npcSpear. Describes tradeoffs; numeric tuning is supplied separately by Core.
  ///
  /// In en, this message translates to:
  /// **'No description available yet.'**
  String get projectileNpcSpearDescription;

  /// Catalog name for projectiles/npcArrow. Keep distinct from its stable internal ID.
  ///
  /// In en, this message translates to:
  /// **'Npc Arrow'**
  String get projectileNpcArrowName;

  /// Catalog description for projectiles/npcArrow. Describes tradeoffs; numeric tuning is supplied separately by Core.
  ///
  /// In en, this message translates to:
  /// **'No description available yet.'**
  String get projectileNpcArrowDescription;

  /// Catalog name for projectiles/goddessOrb. Keep distinct from its stable internal ID.
  ///
  /// In en, this message translates to:
  /// **'Goddess Orb'**
  String get projectileGoddessOrbName;

  /// Catalog description for projectiles/goddessOrb. Describes tradeoffs; numeric tuning is supplied separately by Core.
  ///
  /// In en, this message translates to:
  /// **'No description available yet.'**
  String get projectileGoddessOrbDescription;

  /// Catalog name for projectiles/shoggothOrb. Keep distinct from its stable internal ID.
  ///
  /// In en, this message translates to:
  /// **'Shoggoth Orb'**
  String get projectileShoggothOrbName;

  /// Catalog description for projectiles/shoggothOrb. Describes tradeoffs; numeric tuning is supplied separately by Core.
  ///
  /// In en, this message translates to:
  /// **'No description available yet.'**
  String get projectileShoggothOrbDescription;

  /// Catalog name for projectiles/voidClaw. Keep distinct from its stable internal ID.
  ///
  /// In en, this message translates to:
  /// **'Void Claw'**
  String get projectileVoidClawName;

  /// Catalog description for projectiles/voidClaw. Describes tradeoffs; numeric tuning is supplied separately by Core.
  ///
  /// In en, this message translates to:
  /// **'No description available yet.'**
  String get projectileVoidClawDescription;

  /// Catalog name for projectiles/hunterPistol. Keep distinct from its stable internal ID.
  ///
  /// In en, this message translates to:
  /// **'Pistol'**
  String get projectileHunterPistolName;

  /// Catalog description for projectiles/hunterPistol. Describes tradeoffs; numeric tuning is supplied separately by Core.
  ///
  /// In en, this message translates to:
  /// **'Fast bullets with balanced range. Uses regenerating Supplies.'**
  String get projectileHunterPistolDescription;

  /// Catalog name for projectiles/hunterCrossbow. Keep distinct from its stable internal ID.
  ///
  /// In en, this message translates to:
  /// **'Crossbow'**
  String get projectileHunterCrossbowName;

  /// Projectile hunterCrossbow: values come from the current Core item definition; damage is total across pellets.
  ///
  /// In en, this message translates to:
  /// **'Long-range bolts dealing {damagePercent}% of base damage. Uses regenerating Supplies.'**
  String projectileHunterCrossbowDescription({required double damagePercent});

  /// Catalog name for projectiles/hunterShotgun. Keep distinct from its stable internal ID.
  ///
  /// In en, this message translates to:
  /// **'Shotgun'**
  String get projectileHunterShotgunName;

  /// Projectile hunterShotgun: values come from the current Core item definition; damage is total across pellets.
  ///
  /// In en, this message translates to:
  /// **'Short-range shells divided into {pellets, plural, one{at least one pellet} other{at least {pellets} pellets}}, dealing {damagePercent}% of total base damage. Uses regenerating Supplies.'**
  String projectileHunterShotgunDescription({
    required double damagePercent,
    required int pellets,
  });

  /// Catalog name for projectiles/hunterBomb. Keep distinct from its stable internal ID.
  ///
  /// In en, this message translates to:
  /// **'Bomb'**
  String get projectileHunterBombName;

  /// Catalog description for projectiles/hunterBomb. Describes tradeoffs; numeric tuning is supplied separately by Core.
  ///
  /// In en, this message translates to:
  /// **'A timed blast blocked by solid terrain.'**
  String get projectileHunterBombDescription;

  /// Catalog name for projectiles/hunterRoadsidePistol. Keep distinct from its stable internal ID.
  ///
  /// In en, this message translates to:
  /// **'Roadside Pistol'**
  String get projectileHunterRoadsidePistolName;

  /// Projectile hunterRoadsidePistol: values come from the current Core item definition; damage is total across pellets.
  ///
  /// In en, this message translates to:
  /// **'Fast close-range bullets dealing {damagePercent}% of base damage, with shorter reach.'**
  String projectileHunterRoadsidePistolDescription({
    required double damagePercent,
  });

  /// Catalog name for projectiles/hunterLongbarrelPistol. Keep distinct from its stable internal ID.
  ///
  /// In en, this message translates to:
  /// **'Longbarrel Pistol'**
  String get projectileHunterLongbarrelPistolName;

  /// Projectile hunterLongbarrelPistol: values come from the current Core item definition; damage is total across pellets.
  ///
  /// In en, this message translates to:
  /// **'Fast, long-reaching bullets dealing {damagePercent}% of base damage.'**
  String projectileHunterLongbarrelPistolDescription({
    required double damagePercent,
  });

  /// Catalog name for projectiles/hunterLongwatchCrossbow. Keep distinct from its stable internal ID.
  ///
  /// In en, this message translates to:
  /// **'Longwatch Crossbow'**
  String get projectileHunterLongwatchCrossbowName;

  /// Catalog description for projectiles/hunterLongwatchCrossbow. Describes tradeoffs; numeric tuning is supplied separately by Core.
  ///
  /// In en, this message translates to:
  /// **'Long-reaching, faster bolts with less damage than the standard crossbow.'**
  String get projectileHunterLongwatchCrossbowDescription;

  /// Catalog name for projectiles/hunterHeavyLimbCrossbow. Keep distinct from its stable internal ID.
  ///
  /// In en, this message translates to:
  /// **'Heavy-Limb Crossbow'**
  String get projectileHunterHeavyLimbCrossbowName;

  /// Projectile hunterHeavyLimbCrossbow: values come from the current Core item definition; damage is total across pellets.
  ///
  /// In en, this message translates to:
  /// **'Heavy bolts dealing {damagePercent}% of base damage, with slower flight and shorter reach.'**
  String projectileHunterHeavyLimbCrossbowDescription({
    required double damagePercent,
  });

  /// Catalog name for projectiles/hunterBrushgun. Keep distinct from its stable internal ID.
  ///
  /// In en, this message translates to:
  /// **'Brushgun'**
  String get projectileHunterBrushgunName;

  /// Projectile hunterBrushgun: values come from the current Core item definition; damage is total across pellets.
  ///
  /// In en, this message translates to:
  /// **'A wide spread of {pellets, plural, one{one pellet} other{{pellets} pellets}} deals {damagePercent}% of total base damage and rewards close placement.'**
  String projectileHunterBrushgunDescription({
    required double damagePercent,
    required int pellets,
  });

  /// Catalog name for books/apprenticePrimer. Keep distinct from its stable internal ID.
  ///
  /// In en, this message translates to:
  /// **'Apprentice Primer'**
  String get spellBookApprenticePrimerName;

  /// Catalog description for books/apprenticePrimer. Describes tradeoffs; numeric tuning is supplied separately by Core.
  ///
  /// In en, this message translates to:
  /// **'{resource, select, supplies{Balanced Supplies reserves, regeneration and critical chance, with less stamina.} other{Balanced mana reserves, regeneration and critical chance, with less stamina.}}'**
  String spellBookApprenticePrimerDescription({required String resource});

  /// Catalog name for books/bastionCodex. Keep distinct from its stable internal ID.
  ///
  /// In en, this message translates to:
  /// **'Bastion Codex'**
  String get spellBookBastionCodexName;

  /// Catalog description for books/bastionCodex. Describes tradeoffs; numeric tuning is supplied separately by Core.
  ///
  /// In en, this message translates to:
  /// **'{resource, select, supplies{Large Supplies reserves, regeneration and faster cooldowns, with slower health recovery.} other{Large mana reserves, regeneration and faster cooldowns, with slower health recovery.}}'**
  String spellBookBastionCodexDescription({required String resource});

  /// Catalog name for books/emberGrimoire. Keep distinct from its stable internal ID.
  ///
  /// In en, this message translates to:
  /// **'Ember Grimoire'**
  String get spellBookEmberGrimoireName;

  /// Catalog description for books/emberGrimoire. Describes tradeoffs; numeric tuning is supplied separately by Core.
  ///
  /// In en, this message translates to:
  /// **'{resource, select, supplies{Supplies, critical chance and faster cooldowns, with slower stamina recovery.} other{Mana, critical chance and faster cooldowns, with slower stamina recovery.}}'**
  String spellBookEmberGrimoireDescription({required String resource});

  /// Catalog name for books/tideAlmanac. Keep distinct from its stable internal ID.
  ///
  /// In en, this message translates to:
  /// **'Tide Almanac'**
  String get spellBookTideAlmanacName;

  /// Catalog description for books/tideAlmanac. Describes tradeoffs; numeric tuning is supplied separately by Core.
  ///
  /// In en, this message translates to:
  /// **'{resource, select, supplies{Large Supplies reserves, regeneration and faster cooldowns, with substantially less stamina.} other{Large mana reserves, regeneration and faster cooldowns, with substantially less stamina.}}'**
  String spellBookTideAlmanacDescription({required String resource});

  /// Catalog name for books/hexboundLexicon. Keep distinct from its stable internal ID.
  ///
  /// In en, this message translates to:
  /// **'Hexbound Lexicon'**
  String get spellBookHexboundLexiconName;

  /// Catalog description for books/hexboundLexicon. Describes tradeoffs; numeric tuning is supplied separately by Core.
  ///
  /// In en, this message translates to:
  /// **'{resource, select, supplies{Supplies, regeneration and critical chance, with slower health recovery.} other{Mana, regeneration and critical chance, with slower health recovery.}}'**
  String spellBookHexboundLexiconDescription({required String resource});

  /// Catalog name for books/galeFolio. Keep distinct from its stable internal ID.
  ///
  /// In en, this message translates to:
  /// **'Gale Folio'**
  String get spellBookGaleFolioName;

  /// Catalog description for books/galeFolio. Describes tradeoffs; numeric tuning is supplied separately by Core.
  ///
  /// In en, this message translates to:
  /// **'{resource, select, supplies{Large Supplies reserves, critical chance and faster cooldowns, with less stamina.} other{Large mana reserves, critical chance and faster cooldowns, with less stamina.}}'**
  String spellBookGaleFolioDescription({required String resource});

  /// Catalog name for books/nullTestament. Keep distinct from its stable internal ID.
  ///
  /// In en, this message translates to:
  /// **'Null Testament'**
  String get spellBookNullTestamentName;

  /// Catalog description for books/nullTestament. Describes tradeoffs; numeric tuning is supplied separately by Core.
  ///
  /// In en, this message translates to:
  /// **'{resource, select, supplies{Supplies reserves, regeneration and critical chance, with slower stamina recovery.} other{Mana reserves, regeneration and critical chance, with slower stamina recovery.}}'**
  String spellBookNullTestamentDescription({required String resource});

  /// Catalog name for books/crownOfFocus. Keep distinct from its stable internal ID.
  ///
  /// In en, this message translates to:
  /// **'Crown of Focus'**
  String get spellBookCrownOfFocusName;

  /// Catalog description for books/crownOfFocus. Describes tradeoffs; numeric tuning is supplied separately by Core.
  ///
  /// In en, this message translates to:
  /// **'{resource, select, supplies{Large Supplies reserves, critical chance and faster cooldowns, with substantially less stamina.} other{Large mana reserves, critical chance and faster cooldowns, with substantially less stamina.}}'**
  String spellBookCrownOfFocusDescription({required String resource});

  /// Catalog name for books/hunterFieldKit. Keep distinct from its stable internal ID.
  ///
  /// In en, this message translates to:
  /// **'Field Kit'**
  String get spellBookHunterFieldKitName;

  /// Catalog description for books/hunterFieldKit. Describes tradeoffs; numeric tuning is supplied separately by Core.
  ///
  /// In en, this message translates to:
  /// **'Balanced Supplies and critical chance, with a smaller stamina reserve.'**
  String get spellBookHunterFieldKitDescription;

  /// Catalog name for books/hunterLongtrailPack. Keep distinct from its stable internal ID.
  ///
  /// In en, this message translates to:
  /// **'Longtrail Pack'**
  String get spellBookHunterLongtrailPackName;

  /// Catalog description for books/hunterLongtrailPack. Describes tradeoffs; numeric tuning is supplied separately by Core.
  ///
  /// In en, this message translates to:
  /// **'Sustained Supplies and faster recovery between actions, with slower health regeneration.'**
  String get spellBookHunterLongtrailPackDescription;

  /// Catalog name for books/hunterMarksmanRoll. Keep distinct from its stable internal ID.
  ///
  /// In en, this message translates to:
  /// **'Marksman\'s Roll'**
  String get spellBookHunterMarksmanRollName;

  /// Catalog description for books/hunterMarksmanRoll. Describes tradeoffs; numeric tuning is supplied separately by Core.
  ///
  /// In en, this message translates to:
  /// **'Critical-shot preparation and faster cooldowns, with slower stamina recovery.'**
  String get spellBookHunterMarksmanRollDescription;

  /// Catalog name for books/hunterQuickAccessSatchel. Keep distinct from its stable internal ID.
  ///
  /// In en, this message translates to:
  /// **'Quick-Access Satchel'**
  String get spellBookHunterQuickAccessSatchelName;

  /// Catalog description for books/hunterQuickAccessSatchel. Describes tradeoffs; numeric tuning is supplied separately by Core.
  ///
  /// In en, this message translates to:
  /// **'Frequent short exchanges, with less stamina and no extra Supplies capacity.'**
  String get spellBookHunterQuickAccessSatchelDescription;

  /// Catalog name for books/hunterReserveBandolier. Keep distinct from its stable internal ID.
  ///
  /// In en, this message translates to:
  /// **'Reserve Bandolier'**
  String get spellBookHunterReserveBandolierName;

  /// Catalog description for books/hunterReserveBandolier. Describes tradeoffs; numeric tuning is supplied separately by Core.
  ///
  /// In en, this message translates to:
  /// **'A large opening reserve and critical chance, with substantially less stamina.'**
  String get spellBookHunterReserveBandolierDescription;

  /// Catalog name for books/hunterTrackerPouch. Keep distinct from its stable internal ID.
  ///
  /// In en, this message translates to:
  /// **'Tracker\'s Pouch'**
  String get spellBookHunterTrackerPouchName;

  /// Catalog description for books/hunterTrackerPouch. Describes tradeoffs; numeric tuning is supplied separately by Core.
  ///
  /// In en, this message translates to:
  /// **'Offensive pursuit that preserves stamina, at the cost of health recovery.'**
  String get spellBookHunterTrackerPouchDescription;

  /// Catalog name for books/hunterSurveyorCase. Keep distinct from its stable internal ID.
  ///
  /// In en, this message translates to:
  /// **'Surveyor\'s Case'**
  String get spellBookHunterSurveyorCaseName;

  /// Catalog description for books/hunterSurveyorCase. Describes tradeoffs; numeric tuning is supplied separately by Core.
  ///
  /// In en, this message translates to:
  /// **'A large Supplies reserve and ready utility, with slower stamina recovery.'**
  String get spellBookHunterSurveyorCaseDescription;

  /// Catalog name for books/hunterQuarryKit. Keep distinct from its stable internal ID.
  ///
  /// In en, this message translates to:
  /// **'Quarry Kit'**
  String get spellBookHunterQuarryKitName;

  /// Catalog description for books/hunterQuarryKit. Describes tradeoffs; numeric tuning is supplied separately by Core.
  ///
  /// In en, this message translates to:
  /// **'Critical offensive windows and faster cooldowns, with little stamina headroom.'**
  String get spellBookHunterQuarryKitDescription;

  /// Catalog name for accessories/speedBoots. Keep distinct from its stable internal ID.
  ///
  /// In en, this message translates to:
  /// **'Speed Boots'**
  String get accessorySpeedBootsName;

  /// Catalog description for accessories/speedBoots. Describes tradeoffs; numeric tuning is supplied separately by Core.
  ///
  /// In en, this message translates to:
  /// **'{resource, select, supplies{Tempo accessory with movement, stamina regen, and cooldown pacing at heavy Supplies tax.} other{Tempo accessory with movement, stamina regen, and cooldown pacing at heavy mana tax.}}'**
  String accessorySpeedBootsDescription({required String resource});

  /// Catalog name for accessories/goldenRing. Keep distinct from its stable internal ID.
  ///
  /// In en, this message translates to:
  /// **'Golden Ring'**
  String get accessoryGoldenRingName;

  /// Catalog description for accessories/goldenRing. Describes tradeoffs; numeric tuning is supplied separately by Core.
  ///
  /// In en, this message translates to:
  /// **'Clutch sustain ring with health and emergency low-health healing.'**
  String get accessoryGoldenRingDescription;

  /// Catalog name for accessories/teethNecklace. Keep distinct from its stable internal ID.
  ///
  /// In en, this message translates to:
  /// **'Teeth Necklace'**
  String get accessoryTeethNecklaceName;

  /// Catalog description for accessories/teethNecklace. Describes tradeoffs; numeric tuning is supplied separately by Core.
  ///
  /// In en, this message translates to:
  /// **'Stamina necklace with low-health stamina restore, traded against max health.'**
  String get accessoryTeethNecklaceDescription;

  /// Catalog name for accessories/diamondRing. Keep distinct from its stable internal ID.
  ///
  /// In en, this message translates to:
  /// **'Diamond Ring'**
  String get accessoryDiamondRingName;

  /// Catalog description for accessories/diamondRing. Describes tradeoffs; numeric tuning is supplied separately by Core.
  ///
  /// In en, this message translates to:
  /// **'{resource, select, supplies{Supplies ring with low-health Supplies restore, traded against max stamina.} other{Mana ring with low-health mana restore, traded against max stamina.}}'**
  String accessoryDiamondRingDescription({required String resource});

  /// Catalog name for accessories/ironBoots. Keep distinct from its stable internal ID.
  ///
  /// In en, this message translates to:
  /// **'Iron Boots'**
  String get accessoryIronBootsName;

  /// Catalog description for accessories/ironBoots. Describes tradeoffs; numeric tuning is supplied separately by Core.
  ///
  /// In en, this message translates to:
  /// **'Defensive boots with physical resistance that tax global power.'**
  String get accessoryIronBootsDescription;

  /// Catalog name for accessories/oathBeads. Keep distinct from its stable internal ID.
  ///
  /// In en, this message translates to:
  /// **'Oath Beads'**
  String get accessoryOathBeadsName;

  /// Catalog description for accessories/oathBeads. Describes tradeoffs; numeric tuning is supplied separately by Core.
  ///
  /// In en, this message translates to:
  /// **'{resource, select, supplies{Caster-tempo beads with cooldown, Supplies regen, and power at a defense tax.} other{Caster-tempo beads with cooldown, mana regen, and power at a defense tax.}}'**
  String accessoryOathBeadsDescription({required String resource});

  /// Catalog name for accessories/resilienceCape. Keep distinct from its stable internal ID.
  ///
  /// In en, this message translates to:
  /// **'Resilience Cape'**
  String get accessoryResilienceCapeName;

  /// Catalog description for accessories/resilienceCape. Describes tradeoffs; numeric tuning is supplied separately by Core.
  ///
  /// In en, this message translates to:
  /// **'Elemental counterpick with fire and dark resistance plus defense.'**
  String get accessoryResilienceCapeDescription;

  /// Catalog name for accessories/strengthBelt. Keep distinct from its stable internal ID.
  ///
  /// In en, this message translates to:
  /// **'Strength Belt'**
  String get accessoryStrengthBeltName;

  /// Catalog description for accessories/strengthBelt. Describes tradeoffs; numeric tuning is supplied separately by Core.
  ///
  /// In en, this message translates to:
  /// **'Burst belt with power, crit, and stamina at slower cooldown recovery.'**
  String get accessoryStrengthBeltDescription;

  /// Display name for abilities/unoco.fire_bolt_cast. The identity stays unchanged in saves and gameplay.
  ///
  /// In en, this message translates to:
  /// **'Fire Bolt Cast'**
  String get abilityUnocoFireBoltCastName;

  /// Display name for abilities/unoco.strike. The identity stays unchanged in saves and gameplay.
  ///
  /// In en, this message translates to:
  /// **'Strike'**
  String get abilityUnocoStrikeName;

  /// Display name for abilities/derf.fire_explosion. The identity stays unchanged in saves and gameplay.
  ///
  /// In en, this message translates to:
  /// **'Fire Explosion'**
  String get abilityDerfFireExplosionName;

  /// Display name for abilities/derf.tentacle_strike. The identity stays unchanged in saves and gameplay.
  ///
  /// In en, this message translates to:
  /// **'Tentacle Strike'**
  String get abilityDerfTentacleStrikeName;

  /// Display name for abilities/bringer.scythe_sweep. The identity stays unchanged in saves and gameplay.
  ///
  /// In en, this message translates to:
  /// **'Scythe Sweep'**
  String get abilityBringerScytheSweepName;

  /// Display name for abilities/bringer.death_pillar. The identity stays unchanged in saves and gameplay.
  ///
  /// In en, this message translates to:
  /// **'Death Pillar'**
  String get abilityBringerDeathPillarName;

  /// Display name for abilities/goddess.reposition_out. The identity stays unchanged in saves and gameplay.
  ///
  /// In en, this message translates to:
  /// **'Reposition Out'**
  String get abilityGoddessRepositionOutName;

  /// Display name for abilities/goddess.reposition_in. The identity stays unchanged in saves and gameplay.
  ///
  /// In en, this message translates to:
  /// **'Reposition In'**
  String get abilityGoddessRepositionInName;

  /// Display name for abilities/goddess.dodge. The identity stays unchanged in saves and gameplay.
  ///
  /// In en, this message translates to:
  /// **'Dodge'**
  String get abilityGoddessDodgeName;

  /// Display name for abilities/goddess.claw_combo. The identity stays unchanged in saves and gameplay.
  ///
  /// In en, this message translates to:
  /// **'Claw Combo'**
  String get abilityGoddessClawComboName;

  /// Display name for abilities/goddess.orb. The identity stays unchanged in saves and gameplay.
  ///
  /// In en, this message translates to:
  /// **'Orb'**
  String get abilityGoddessOrbName;

  /// Display name for abilities/goddess.eruption. The identity stays unchanged in saves and gameplay.
  ///
  /// In en, this message translates to:
  /// **'Eruption'**
  String get abilityGoddessEruptionName;

  /// Display name for abilities/shoggoth.tentacle_sweep. The identity stays unchanged in saves and gameplay.
  ///
  /// In en, this message translates to:
  /// **'Tentacle Sweep'**
  String get abilityShoggothTentacleSweepName;

  /// Display name for abilities/shoggoth.spinning_charge. The identity stays unchanged in saves and gameplay.
  ///
  /// In en, this message translates to:
  /// **'Spinning Charge'**
  String get abilityShoggothSpinningChargeName;

  /// Display name for abilities/shoggoth.orb. The identity stays unchanged in saves and gameplay.
  ///
  /// In en, this message translates to:
  /// **'Orb'**
  String get abilityShoggothOrbName;

  /// Display name for abilities/shoggoth.summon. The identity stays unchanged in saves and gameplay.
  ///
  /// In en, this message translates to:
  /// **'Summon'**
  String get abilityShoggothSummonName;

  /// Display name for abilities/shoggoth.summon_swarm. The identity stays unchanged in saves and gameplay.
  ///
  /// In en, this message translates to:
  /// **'Summon Swarm'**
  String get abilityShoggothSummonSwarmName;

  /// Display name for abilities/shoggoth.summon_horde. The identity stays unchanged in saves and gameplay.
  ///
  /// In en, this message translates to:
  /// **'Summon Horde'**
  String get abilityShoggothSummonHordeName;

  /// Display name for abilities/shoggoth.return_charge. The identity stays unchanged in saves and gameplay.
  ///
  /// In en, this message translates to:
  /// **'Return Charge'**
  String get abilityShoggothReturnChargeName;

  /// Display name for abilities/shoggoth.teleport. The identity stays unchanged in saves and gameplay.
  ///
  /// In en, this message translates to:
  /// **'Teleport'**
  String get abilityShoggothTeleportName;

  /// Display name for abilities/voidcaller.vertical_beam. The identity stays unchanged in saves and gameplay.
  ///
  /// In en, this message translates to:
  /// **'Vertical Beam'**
  String get abilityVoidcallerVerticalBeamName;

  /// Display name for abilities/voidcaller.diagonal_beam. The identity stays unchanged in saves and gameplay.
  ///
  /// In en, this message translates to:
  /// **'Diagonal Beam'**
  String get abilityVoidcallerDiagonalBeamName;

  /// Display name for abilities/voidcaller.claw. The identity stays unchanged in saves and gameplay.
  ///
  /// In en, this message translates to:
  /// **'Claw'**
  String get abilityVoidcallerClawName;

  /// Display name for abilities/voidcaller.summon. The identity stays unchanged in saves and gameplay.
  ///
  /// In en, this message translates to:
  /// **'Summon'**
  String get abilityVoidcallerSummonName;

  /// Display name for abilities/shoggoth_minion.bite. The identity stays unchanged in saves and gameplay.
  ///
  /// In en, this message translates to:
  /// **'Bite'**
  String get abilityShoggothMinionBiteName;

  /// Display name for abilities/void_tentacle.lash. The identity stays unchanged in saves and gameplay.
  ///
  /// In en, this message translates to:
  /// **'Lash'**
  String get abilityVoidTentacleLashName;

  /// Display name for abilities/grojib.strike. The identity stays unchanged in saves and gameplay.
  ///
  /// In en, this message translates to:
  /// **'Strike'**
  String get abilityGrojibStrikeName;

  /// Display name for abilities/grojib.strike2. The identity stays unchanged in saves and gameplay.
  ///
  /// In en, this message translates to:
  /// **'Second Strike'**
  String get abilityGrojibStrike2Name;

  /// Display name for abilities/hashash.strike. The identity stays unchanged in saves and gameplay.
  ///
  /// In en, this message translates to:
  /// **'Strike'**
  String get abilityHashashStrikeName;

  /// Display name for abilities/hashash.teleport_out. The identity stays unchanged in saves and gameplay.
  ///
  /// In en, this message translates to:
  /// **'Teleport Out'**
  String get abilityHashashTeleportOutName;

  /// Display name for abilities/hashash.ambush. The identity stays unchanged in saves and gameplay.
  ///
  /// In en, this message translates to:
  /// **'Ambush'**
  String get abilityHashashAmbushName;

  /// Display name for abilities/eloise.bloodletter_slash. The identity stays unchanged in saves and gameplay.
  ///
  /// In en, this message translates to:
  /// **'Sword Slash'**
  String get abilityEloiseBloodletterSlashName;

  /// Display name for abilities/eloise.bloodletter_cleave. The identity stays unchanged in saves and gameplay.
  ///
  /// In en, this message translates to:
  /// **'Bloodletter Cleave'**
  String get abilityEloiseBloodletterCleaveName;

  /// Display name for abilities/eloise.seeker_slash. The identity stays unchanged in saves and gameplay.
  ///
  /// In en, this message translates to:
  /// **'Seeker Slash'**
  String get abilityEloiseSeekerSlashName;

  /// Display name for abilities/eloise.aegis_riposte. The identity stays unchanged in saves and gameplay.
  ///
  /// In en, this message translates to:
  /// **'Aegis Riposte'**
  String get abilityEloiseAegisRiposteName;

  /// Display name for abilities/eloise.shield_block. The identity stays unchanged in saves and gameplay.
  ///
  /// In en, this message translates to:
  /// **'Shield block'**
  String get abilityEloiseShieldBlockName;

  /// Display name for abilities/eloise.snap_shot. The identity stays unchanged in saves and gameplay.
  ///
  /// In en, this message translates to:
  /// **'Snap Shot'**
  String get abilityEloiseSnapShotName;

  /// Display name for abilities/eloise.quick_shot. The identity stays unchanged in saves and gameplay.
  ///
  /// In en, this message translates to:
  /// **'Quick Shot'**
  String get abilityEloiseQuickShotName;

  /// Display name for abilities/eloise.skewer_shot. The identity stays unchanged in saves and gameplay.
  ///
  /// In en, this message translates to:
  /// **'Skewer Shot'**
  String get abilityEloiseSkewerShotName;

  /// Display name for abilities/eloise.overcharge_shot. The identity stays unchanged in saves and gameplay.
  ///
  /// In en, this message translates to:
  /// **'Overcharge Bolt'**
  String get abilityEloiseOverchargeShotName;

  /// Display name for abilities/eloise.arcane_haste. The identity stays unchanged in saves and gameplay.
  ///
  /// In en, this message translates to:
  /// **'Arcane Haste'**
  String get abilityEloiseArcaneHasteName;

  /// Display name for abilities/eloise.focus. The identity stays unchanged in saves and gameplay.
  ///
  /// In en, this message translates to:
  /// **'Focus'**
  String get abilityEloiseFocusName;

  /// Display name for abilities/eloise.arcane_ward. The identity stays unchanged in saves and gameplay.
  ///
  /// In en, this message translates to:
  /// **'Arcane Ward'**
  String get abilityEloiseArcaneWardName;

  /// Display name for abilities/eloise.cleanse. The identity stays unchanged in saves and gameplay.
  ///
  /// In en, this message translates to:
  /// **'Cleanse'**
  String get abilityEloiseCleanseName;

  /// Display name for abilities/eloise.vital_surge. The identity stays unchanged in saves and gameplay.
  ///
  /// In en, this message translates to:
  /// **'Vital Surge'**
  String get abilityEloiseVitalSurgeName;

  /// Display name for abilities/eloise.mana_infusion. The identity stays unchanged in saves and gameplay.
  ///
  /// In en, this message translates to:
  /// **'Mana Infusion'**
  String get abilityEloiseManaInfusionName;

  /// Display name for abilities/eloise.second_wind. The identity stays unchanged in saves and gameplay.
  ///
  /// In en, this message translates to:
  /// **'Second Wind'**
  String get abilityEloiseSecondWindName;

  /// Display name for abilities/eloise.jump. The identity stays unchanged in saves and gameplay.
  ///
  /// In en, this message translates to:
  /// **'Jump'**
  String get abilityEloiseJumpName;

  /// Display name for abilities/eloise.double_jump. The identity stays unchanged in saves and gameplay.
  ///
  /// In en, this message translates to:
  /// **'Double Jump'**
  String get abilityEloiseDoubleJumpName;

  /// Display name for abilities/eloise.dash. The identity stays unchanged in saves and gameplay.
  ///
  /// In en, this message translates to:
  /// **'Dash'**
  String get abilityEloiseDashName;

  /// Display name for abilities/eloise.double_dash. The identity stays unchanged in saves and gameplay.
  ///
  /// In en, this message translates to:
  /// **'Double Dash'**
  String get abilityEloiseDoubleDashName;

  /// Display name for abilities/eloise.roll. The identity stays unchanged in saves and gameplay.
  ///
  /// In en, this message translates to:
  /// **'Concussive Roll'**
  String get abilityEloiseRollName;

  /// Display name for abilities/bounty_hunter.quick_cut. The identity stays unchanged in saves and gameplay.
  ///
  /// In en, this message translates to:
  /// **'Quick Cut'**
  String get abilityBountyHunterQuickCutName;

  /// Display name for abilities/bounty_hunter.twin_cut. The identity stays unchanged in saves and gameplay.
  ///
  /// In en, this message translates to:
  /// **'Twin Cut'**
  String get abilityBountyHunterTwinCutName;

  /// Display name for abilities/bounty_hunter.lunge_slash. The identity stays unchanged in saves and gameplay.
  ///
  /// In en, this message translates to:
  /// **'Lunge Slash'**
  String get abilityBountyHunterLungeSlashName;

  /// Display name for abilities/bounty_hunter.blast_bomb. The identity stays unchanged in saves and gameplay.
  ///
  /// In en, this message translates to:
  /// **'Blast Bomb'**
  String get abilityBountyHunterBlastBombName;

  /// Display name for abilities/bounty_hunter.shrapnel_bomb. The identity stays unchanged in saves and gameplay.
  ///
  /// In en, this message translates to:
  /// **'Shrapnel Bomb'**
  String get abilityBountyHunterShrapnelBombName;

  /// Display name for abilities/bounty_hunter.fire_bomb. The identity stays unchanged in saves and gameplay.
  ///
  /// In en, this message translates to:
  /// **'Fire Bomb'**
  String get abilityBountyHunterFireBombName;

  /// Display name for abilities/bounty_hunter.concussion_bomb. The identity stays unchanged in saves and gameplay.
  ///
  /// In en, this message translates to:
  /// **'Concussion Bomb'**
  String get abilityBountyHunterConcussionBombName;

  /// Display name for abilities/bounty_hunter.snap_shot. The identity stays unchanged in saves and gameplay.
  ///
  /// In en, this message translates to:
  /// **'Snap Shot'**
  String get abilityBountyHunterSnapShotName;

  /// Display name for abilities/bounty_hunter.quick_shot. The identity stays unchanged in saves and gameplay.
  ///
  /// In en, this message translates to:
  /// **'Quick Shot'**
  String get abilityBountyHunterQuickShotName;

  /// Display name for abilities/bounty_hunter.piercing_shot. The identity stays unchanged in saves and gameplay.
  ///
  /// In en, this message translates to:
  /// **'Piercing Shot'**
  String get abilityBountyHunterPiercingShotName;

  /// Display name for abilities/bounty_hunter.scatter_shot. The identity stays unchanged in saves and gameplay.
  ///
  /// In en, this message translates to:
  /// **'Scatter Shot'**
  String get abilityBountyHunterScatterShotName;

  /// Display name for abilities/bounty_hunter.charged_shot. The identity stays unchanged in saves and gameplay.
  ///
  /// In en, this message translates to:
  /// **'Charged Shot'**
  String get abilityBountyHunterChargedShotName;

  /// Display name for abilities/bounty_hunter.dash. The identity stays unchanged in saves and gameplay.
  ///
  /// In en, this message translates to:
  /// **'Dash'**
  String get abilityBountyHunterDashName;

  /// Display name for abilities/bounty_hunter.double_dash. The identity stays unchanged in saves and gameplay.
  ///
  /// In en, this message translates to:
  /// **'Double Dash'**
  String get abilityBountyHunterDoubleDashName;

  /// Display name for abilities/bounty_hunter.blink_dash. The identity stays unchanged in saves and gameplay.
  ///
  /// In en, this message translates to:
  /// **'Blink Dash'**
  String get abilityBountyHunterBlinkDashName;

  /// Display name for abilities/bounty_hunter.jump. The identity stays unchanged in saves and gameplay.
  ///
  /// In en, this message translates to:
  /// **'Jump'**
  String get abilityBountyHunterJumpName;

  /// Display name for abilities/bounty_hunter.double_jump. The identity stays unchanged in saves and gameplay.
  ///
  /// In en, this message translates to:
  /// **'Double Jump'**
  String get abilityBountyHunterDoubleJumpName;

  /// Display name for abilities/bounty_hunter.hunters_focus. The identity stays unchanged in saves and gameplay.
  ///
  /// In en, this message translates to:
  /// **'Hunter\'s Focus'**
  String get abilityBountyHunterHuntersFocusName;

  /// Display name for abilities/bounty_hunter.mark_quarry. The identity stays unchanged in saves and gameplay.
  ///
  /// In en, this message translates to:
  /// **'Mark Quarry'**
  String get abilityBountyHunterMarkQuarryName;

  /// Display name for abilities/bounty_hunter.forced_march. The identity stays unchanged in saves and gameplay.
  ///
  /// In en, this message translates to:
  /// **'Forced March'**
  String get abilityBountyHunterForcedMarchName;

  /// Display name for abilities/bounty_hunter.field_dressing. The identity stays unchanged in saves and gameplay.
  ///
  /// In en, this message translates to:
  /// **'Field Dressing'**
  String get abilityBountyHunterFieldDressingName;

  /// Display name for abilities/bounty_hunter.antidote. The identity stays unchanged in saves and gameplay.
  ///
  /// In en, this message translates to:
  /// **'Antidote'**
  String get abilityBountyHunterAntidoteName;

  /// Display name for abilities/bounty_hunter.second_wind. The identity stays unchanged in saves and gameplay.
  ///
  /// In en, this message translates to:
  /// **'Second Wind'**
  String get abilityBountyHunterSecondWindName;

  /// Display name for abilities/bounty_hunter.prepare_charges. The identity stays unchanged in saves and gameplay.
  ///
  /// In en, this message translates to:
  /// **'Prepare Charges'**
  String get abilityBountyHunterPrepareChargesName;

  /// Display name for abilities/npc_warrior.slash. The identity stays unchanged in saves and gameplay.
  ///
  /// In en, this message translates to:
  /// **'Slash'**
  String get abilityNpcWarriorSlashName;

  /// Display name for abilities/npc_huntress.throw_spear. The identity stays unchanged in saves and gameplay.
  ///
  /// In en, this message translates to:
  /// **'Throw Spear'**
  String get abilityNpcHuntressThrowSpearName;

  /// Display name for abilities/npc_huntress.stab. The identity stays unchanged in saves and gameplay.
  ///
  /// In en, this message translates to:
  /// **'Stab'**
  String get abilityNpcHuntressStabName;

  /// Display name for abilities/npc_huntress.slash. The identity stays unchanged in saves and gameplay.
  ///
  /// In en, this message translates to:
  /// **'Slash'**
  String get abilityNpcHuntressSlashName;

  /// Display name for abilities/npc_huntress2.shoot_arrow. The identity stays unchanged in saves and gameplay.
  ///
  /// In en, this message translates to:
  /// **'Shoot Arrow'**
  String get abilityNpcHuntress2ShootArrowName;

  /// Display name for enemies/unocoDemon. The identity stays unchanged in saves and gameplay.
  ///
  /// In en, this message translates to:
  /// **'Unoco Demon'**
  String get enemyUnocoDemonName;

  /// Display name for enemies/grojib. The identity stays unchanged in saves and gameplay.
  ///
  /// In en, this message translates to:
  /// **'Grojib'**
  String get enemyGrojibName;

  /// Display name for enemies/hashash. The identity stays unchanged in saves and gameplay.
  ///
  /// In en, this message translates to:
  /// **'Hashash'**
  String get enemyHashashName;

  /// Display name for enemies/derf. The identity stays unchanged in saves and gameplay.
  ///
  /// In en, this message translates to:
  /// **'Derf'**
  String get enemyDerfName;

  /// Display name for enemies/bringerOfDeath. The identity stays unchanged in saves and gameplay.
  ///
  /// In en, this message translates to:
  /// **'Bringer of Death'**
  String get enemyBringerOfDeathName;

  /// Display name for enemies/voidbornGoddess. The identity stays unchanged in saves and gameplay.
  ///
  /// In en, this message translates to:
  /// **'Voidborn Goddess'**
  String get enemyVoidbornGoddessName;

  /// Display name for enemies/shoggoth. The identity stays unchanged in saves and gameplay.
  ///
  /// In en, this message translates to:
  /// **'Shoggoth'**
  String get enemyShoggothName;

  /// Display name for enemies/voidcaller. The identity stays unchanged in saves and gameplay.
  ///
  /// In en, this message translates to:
  /// **'Voidcaller'**
  String get enemyVoidcallerName;

  /// Display name for enemies/shoggothMinion. The identity stays unchanged in saves and gameplay.
  ///
  /// In en, this message translates to:
  /// **'Shoggoth Minion'**
  String get enemyShoggothMinionName;

  /// Display name for enemies/voidTentacle. The identity stays unchanged in saves and gameplay.
  ///
  /// In en, this message translates to:
  /// **'Void Tentacle'**
  String get enemyVoidTentacleName;

  /// Safe fallback for a retained ability ID unknown to this client; never display the raw ID.
  ///
  /// In en, this message translates to:
  /// **'Unknown ability'**
  String get unknownAbility;

  /// Safe fallback for an item unknown to this client; never display the raw ID.
  ///
  /// In en, this message translates to:
  /// **'Unknown item'**
  String get unknownItem;

  /// Shared combat/resource term used in catalog details and HUD.
  ///
  /// In en, this message translates to:
  /// **'Physical'**
  String get damagePhysical;

  /// Shared combat/resource term used in catalog details and HUD.
  ///
  /// In en, this message translates to:
  /// **'Fire'**
  String get damageFire;

  /// Shared combat/resource term used in catalog details and HUD.
  ///
  /// In en, this message translates to:
  /// **'Ice'**
  String get damageIce;

  /// Shared combat/resource term used in catalog details and HUD.
  ///
  /// In en, this message translates to:
  /// **'Water'**
  String get damageWater;

  /// Shared combat/resource term used in catalog details and HUD.
  ///
  /// In en, this message translates to:
  /// **'Thunder'**
  String get damageThunder;

  /// Shared combat/resource term used in catalog details and HUD.
  ///
  /// In en, this message translates to:
  /// **'Acid'**
  String get damageAcid;

  /// Shared combat/resource term used in catalog details and HUD.
  ///
  /// In en, this message translates to:
  /// **'Poison'**
  String get damagePoison;

  /// Shared combat/resource term used in catalog details and HUD.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get damageDark;

  /// Shared combat/resource term used in catalog details and HUD.
  ///
  /// In en, this message translates to:
  /// **'Bleed'**
  String get damageBleed;

  /// Shared combat/resource term used in catalog details and HUD.
  ///
  /// In en, this message translates to:
  /// **'Earth'**
  String get damageEarth;

  /// Shared combat/resource term used in catalog details and HUD.
  ///
  /// In en, this message translates to:
  /// **'Holy'**
  String get damageHoly;

  /// Shared combat/resource term used in catalog details and HUD.
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get resourceHealth;

  /// Shared combat/resource term used in catalog details and HUD.
  ///
  /// In en, this message translates to:
  /// **'Mana'**
  String get resourceMana;

  /// Shared combat/resource term used in catalog details and HUD.
  ///
  /// In en, this message translates to:
  /// **'Supplies'**
  String get resourceSupplies;

  /// Shared combat/resource term used in catalog details and HUD.
  ///
  /// In en, this message translates to:
  /// **'Stamina'**
  String get resourceStamina;

  /// Shared combat/resource term used in catalog details and HUD.
  ///
  /// In en, this message translates to:
  /// **'DoT'**
  String get damageOverTime;

  /// Duration in seconds, including fractional values.
  ///
  /// In en, this message translates to:
  /// **'{seconds, plural, one{1 second} other{{seconds} seconds}}'**
  String durationSeconds({required num seconds});

  /// Complete on-hit status summary. Duration is a localized duration phrase; chance is a percentage from Core basis points. The guaranteed branch omits probability.
  ///
  /// In en, this message translates to:
  /// **'{chanceKind, select, guaranteed{{damageType}: {damagePerSecond} damage per second for {duration}} other{{damageType}: {damagePerSecond} damage per second for {duration} ({chance}% chance)}}'**
  String statusDot({
    required String duration,
    required num chance,
    required String damageType,
    required num damagePerSecond,
    required String chanceKind,
  });

  /// Complete on-hit status summary. Duration is a localized duration phrase; chance is a percentage from Core basis points. The guaranteed branch omits probability.
  ///
  /// In en, this message translates to:
  /// **'{chanceKind, select, guaranteed{Slow: -{percent}% speed for {duration}} other{Slow: -{percent}% speed for {duration} ({chance}% chance)}}'**
  String statusSlow({
    required String duration,
    required num chance,
    required num percent,
    required String chanceKind,
  });

  /// Complete on-hit status summary. Duration is a localized duration phrase; chance is a percentage from Core basis points. The guaranteed branch omits probability.
  ///
  /// In en, this message translates to:
  /// **'{chanceKind, select, guaranteed{Stun: {duration}} other{Stun: {duration} ({chance}% chance)}}'**
  String statusStun({
    required String duration,
    required num chance,
    required String chanceKind,
  });

  /// Complete on-hit status summary. Duration is a localized duration phrase; chance is a percentage from Core basis points. The guaranteed branch omits probability.
  ///
  /// In en, this message translates to:
  /// **'{chanceKind, select, guaranteed{Silence: {duration}} other{Silence: {duration} ({chance}% chance)}}'**
  String statusSilence({
    required String duration,
    required num chance,
    required String chanceKind,
  });

  /// Complete on-hit status summary. Duration is a localized duration phrase; chance is a percentage from Core basis points. The guaranteed branch omits probability.
  ///
  /// In en, this message translates to:
  /// **'{chanceKind, select, guaranteed{Vulnerable: +{percent}% damage taken for {duration}} other{Vulnerable: +{percent}% damage taken for {duration} ({chance}% chance)}}'**
  String statusVulnerable({
    required String duration,
    required num chance,
    required num percent,
    required String chanceKind,
  });

  /// Complete on-hit status summary. Duration is a localized duration phrase; chance is a percentage from Core basis points. The guaranteed branch omits probability.
  ///
  /// In en, this message translates to:
  /// **'{chanceKind, select, guaranteed{Weaken: -{percent}% outgoing damage for {duration}} other{Weaken: -{percent}% outgoing damage for {duration} ({chance}% chance)}}'**
  String statusWeaken({
    required String duration,
    required num chance,
    required num percent,
    required String chanceKind,
  });

  /// Complete on-hit status summary. Duration is a localized duration phrase; chance is a percentage from Core basis points. The guaranteed branch omits probability.
  ///
  /// In en, this message translates to:
  /// **'{chanceKind, select, guaranteed{Drench: -{percent}% attack/cast speed for {duration}} other{Drench: -{percent}% attack/cast speed for {duration} ({chance}% chance)}}'**
  String statusDrench({
    required String duration,
    required num chance,
    required num percent,
    required String chanceKind,
  });

  /// Canonical character name; retain the spelling and accents in every language.
  ///
  /// In en, this message translates to:
  /// **'Éloïse'**
  String get characterEloiseName;

  /// Canonical character name; retain the spelling and accents in every language.
  ///
  /// In en, this message translates to:
  /// **'Willow'**
  String get characterWillowName;

  /// Gift label identifying the localized item and its target character. Both parameters are localized display names.
  ///
  /// In en, this message translates to:
  /// **'{item} · {character}'**
  String giftCharacterLabel({required String item, required String character});

  /// Character stat label for health.
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get statHealth;

  /// Character stat label for mana.
  ///
  /// In en, this message translates to:
  /// **'{resource, select, supplies{Supplies} other{Mana}}'**
  String statMana({required String resource});

  /// Character stat label for stamina.
  ///
  /// In en, this message translates to:
  /// **'Stamina'**
  String get statStamina;

  /// Character stat label for healthRegen.
  ///
  /// In en, this message translates to:
  /// **'Health Regen'**
  String get statHealthRegen;

  /// Character stat label for manaRegen.
  ///
  /// In en, this message translates to:
  /// **'{resource, select, supplies{Supplies Regen} other{Mana Regen}}'**
  String statManaRegen({required String resource});

  /// Character stat label for staminaRegen.
  ///
  /// In en, this message translates to:
  /// **'Stamina Regen'**
  String get statStaminaRegen;

  /// Character stat label for defense.
  ///
  /// In en, this message translates to:
  /// **'Defense'**
  String get statDefense;

  /// Character stat label for power.
  ///
  /// In en, this message translates to:
  /// **'Power'**
  String get statPower;

  /// Character stat label for moveSpeed.
  ///
  /// In en, this message translates to:
  /// **'Move Speed'**
  String get statMoveSpeed;

  /// Character stat label for cooldownReduction.
  ///
  /// In en, this message translates to:
  /// **'Cooldown Reduction'**
  String get statCooldownReduction;

  /// Character stat label for critChance.
  ///
  /// In en, this message translates to:
  /// **'Crit Chance'**
  String get statCritChance;

  /// Character stat label for physicalResistance.
  ///
  /// In en, this message translates to:
  /// **'Physical Resist'**
  String get statPhysicalResistance;

  /// Character stat label for fireResistance.
  ///
  /// In en, this message translates to:
  /// **'Fire Resist'**
  String get statFireResistance;

  /// Character stat label for iceResistance.
  ///
  /// In en, this message translates to:
  /// **'Ice Resist'**
  String get statIceResistance;

  /// Character stat label for waterResistance.
  ///
  /// In en, this message translates to:
  /// **'Water Resist'**
  String get statWaterResistance;

  /// Character stat label for thunderResistance.
  ///
  /// In en, this message translates to:
  /// **'Thunder Resist'**
  String get statThunderResistance;

  /// Character stat label for acidResistance.
  ///
  /// In en, this message translates to:
  /// **'Acid Resist'**
  String get statAcidResistance;

  /// Character stat label for darkResistance.
  ///
  /// In en, this message translates to:
  /// **'Dark Resist'**
  String get statDarkResistance;

  /// Character stat label for bleedResistance.
  ///
  /// In en, this message translates to:
  /// **'Bleed Resist'**
  String get statBleedResistance;

  /// Character stat label for earthResistance.
  ///
  /// In en, this message translates to:
  /// **'Earth Resist'**
  String get statEarthResistance;

  /// Character stat label for holyResistance.
  ///
  /// In en, this message translates to:
  /// **'Holy Resist'**
  String get statHolyResistance;

  /// Status effect or resource label.
  ///
  /// In en, this message translates to:
  /// **'Bleed'**
  String get effectBleed;

  /// Status effect or resource label.
  ///
  /// In en, this message translates to:
  /// **'Burn'**
  String get effectBurn;

  /// Status effect or resource label.
  ///
  /// In en, this message translates to:
  /// **'Resource'**
  String get resourceGeneric;
}

class _GameLocalizationsDelegate
    extends LocalizationsDelegate<GameLocalizations> {
  const _GameLocalizationsDelegate();

  @override
  Future<GameLocalizations> load(Locale locale) {
    return SynchronousFuture<GameLocalizations>(
      lookupGameLocalizations(locale),
    );
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_GameLocalizationsDelegate old) => false;
}

GameLocalizations lookupGameLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return GameLocalizationsEn();
    case 'fr':
      return GameLocalizationsFr();
  }

  throw FlutterError(
    'GameLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
