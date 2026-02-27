import '../projectiles/projectile_id.dart';
import '../combat/damage_type.dart';
import '../combat/status/status.dart';
import '../snapshots/enums.dart';
import '../weapons/weapon_proc.dart';

/// Stable ability identifier used by loadouts, systems, and authored data.
///
/// Example: `eloise.sword_strike`.
typedef AbilityKey = String;

/// Logical action slot where an ability may be equipped/triggered.
enum AbilitySlot { primary, secondary, projectile, mobility, spell, jump }

/// High-level semantic grouping used by UI and systems.
enum AbilityCategory { melee, ranged, mobility, defense, utility }

/// Weapon family classification used for ability gating.
enum WeaponType { oneHandedSword, shield, throwingWeapon, projectileSpell }

/// Where this ability should fetch its combat payload from at commit-time.
///
/// This is the missing "source of truth" that decouples:
/// - which button/slot triggers an ability
/// - from where the ability derives weapon/projectile stats/procs/damage-type.
///
/// Critical for spell slot (can host anything).
enum AbilityPayloadSource {
  none,
  primaryWeapon,
  secondaryWeapon, // off-hand unless primary is two-handed (then primary)
  projectile,
  spellBook,
}

/// How target direction/position is acquired when committing an ability.
enum TargetingModel {
  none, // Instant self-cast / buff
  directional, // Uses input direction (melee)
  aimed, // Uses explicit aim cursor (ranged)
  aimedLine, // Directional line shot; strong when targets align
  aimedCharge, // Charged shot with long commit window
  homing, // Auto-locks nearest target
  groundTarget, // AOE circle on ground
}

/// How a committed ability is maintained after initial activation.
enum AbilityHoldMode {
  /// Standard one-shot ability lifecycle (windup -> active -> recovery).
  none,

  /// Ability remains active while the owning slot is held.
  ///
  /// The authored [AbilityDef.activeTicks] is treated as the maximum hold
  /// duration, and runtime systems may end it early on release or resource
  /// depletion.
  holdToMaintain,
}

/// Input lifecycle model authored per ability.
///
/// This is independent from targeting and charge behavior.
enum AbilityInputLifecycle {
  /// Commit on press edge.
  tap,

  /// Hold to prepare/aim/charge, commit on release edge.
  holdRelease,

  /// Commit on hold start and maintain while held.
  holdMaintain,
}

/// Runtime lifecycle stage of a committed ability.
enum AbilityPhase { idle, windup, active, recovery }

/// External/system causes that can forcibly cancel an ability.
enum ForcedInterruptCause {
  stun, // control lock stun
  death, // hp <= 0 or death state
  damageTaken, // non-zero damage applied this tick
}

// --------------------------------------------------------------------------
// HIT DELIVERY
// --------------------------------------------------------------------------

/// How often a delivery can apply damage during one activation.
enum HitPolicy {
  once, // Hit once per activation (e.g. explosion)
  oncePerTarget, // Hit each target once (e.g. sword swing)
  everyTick, // Hit every frame (e.g. beam)
}

/// Marker interface for authored hit-delivery definitions.
abstract class HitDeliveryDef {
  const HitDeliveryDef();
}

/// Melee hit volume authored in local-space rectangle terms.
class MeleeHitDelivery extends HitDeliveryDef {
  const MeleeHitDelivery({
    required this.sizeX,
    required this.sizeY,
    required this.offsetX,
    required this.offsetY,
    required this.hitPolicy,
  });

  /// Dimensions and offset in world units.
  final double sizeX;
  final double sizeY;
  final double offsetX;
  final double offsetY;
  final HitPolicy hitPolicy;
}

/// Projectile delivery config used by projectile intent/spawn systems.
class ProjectileHitDelivery extends HitDeliveryDef {
  const ProjectileHitDelivery({
    required this.projectileId,
    this.pierce = false,
    this.chain = false,
    this.chainCount = 0,
    this.hitPolicy = HitPolicy.oncePerTarget,
  }) : assert(chainCount >= 0, 'Chain count must be non-negative'),
       assert(!chain || chainCount > 0, 'If chain is true, count must be > 0');

  final ProjectileId projectileId;
  final bool pierce;
  final bool chain;
  final int chainCount;
  final HitPolicy hitPolicy;
}

/// For abilities that affect the user (Buff/Block) or have no hitbox (Dash).
class SelfHitDelivery extends HitDeliveryDef {
  const SelfHitDelivery();
}

/// Authored contact-impact payload for mobility abilities (dash/roll).
///
/// Effects are applied when the mobility user overlaps hostile targets during
/// the active phase.
class MobilityImpactDef {
  const MobilityImpactDef({
    this.hitPolicy = HitPolicy.oncePerTarget,
    this.damage100 = 0,
    this.critChanceBp = 0,
    this.damageType = DamageType.physical,
    this.procs = const <WeaponProc>[],
    this.statusProfileId = StatusProfileId.none,
  }) : assert(damage100 >= 0, 'mobility impact damage cannot be negative'),
       assert(
         critChanceBp >= 0 && critChanceBp <= 10000,
         'mobility impact crit chance must be in range [0, 10000]',
       );

  /// Convenience "no contact effects" preset.
  static const MobilityImpactDef none = MobilityImpactDef();

  /// Delivery cadence during a single activation.
  final HitPolicy hitPolicy;

  /// Fixed-point contact damage (`100 == 1.0`).
  final int damage100;

  /// Crit chance in basis points (`10000 == 100%`).
  final int critChanceBp;

  /// Damage type used for queued contact damage and status scaling.
  final DamageType damageType;

  /// Optional on-hit procs for contact damage applications.
  final List<WeaponProc> procs;

  /// Optional direct status applied on contact (independent from damage).
  final StatusProfileId statusProfileId;

  /// True when this definition would produce at least one gameplay effect.
  bool get hasAnyEffect =>
      damage100 > 0 ||
      procs.isNotEmpty ||
      statusProfileId != StatusProfileId.none;
}

// --------------------------------------------------------------------------
// CHARGE AUTHORING
// --------------------------------------------------------------------------

/// Authoring tier for charged commits.
///
/// Tiers are authored in 60 Hz tick semantics and selected by highest
/// [minHoldTicks60] <= runtime hold ticks (scaled to current tick rate).
class AbilityChargeTierDef {
  const AbilityChargeTierDef({
    required this.minHoldTicks60,
    required this.damageScaleBp,
    this.critBonusBp = 0,
    this.speedScaleBp = 10000,
    this.pierce,
    this.maxPierceHits,
  }) : assert(minHoldTicks60 >= 0, 'minHoldTicks60 cannot be negative'),
       assert(damageScaleBp >= 0, 'damageScaleBp cannot be negative'),
       assert(speedScaleBp > 0, 'speedScaleBp must be > 0'),
       assert(
         maxPierceHits == null || maxPierceHits > 0,
         'maxPierceHits must be > 0 when provided',
       );

  /// Minimum hold duration in authored 60 Hz ticks required for this tier.
  final int minHoldTicks60;

  /// Damage scale in basis points (`10000 == 1.0x`).
  final int damageScaleBp;

  /// Crit chance bonus in basis points (`100 == 1%`).
  final int critBonusBp;

  /// Projectile speed scale in basis points (`10000 == 1.0x`).
  final int speedScaleBp;

  /// Optional projectile piercing override.
  final bool? pierce;

  /// Optional projectile max pierce hit override.
  final int? maxPierceHits;
}

/// Data-authored charge profile shared by melee/projectile commit paths.
class AbilityChargeProfile {
  AbilityChargeProfile({required List<AbilityChargeTierDef> tiers})
    : assert(tiers.isNotEmpty, 'Charge profile must define at least one tier'),
      assert(
        _isStrictlyIncreasingMinHoldTicks(tiers),
        'Charge tiers must be strictly ordered by minHoldTicks60.',
      ),
      tiers = List<AbilityChargeTierDef>.unmodifiable(tiers);

  final List<AbilityChargeTierDef> tiers;

  static bool _isStrictlyIncreasingMinHoldTicks(
    List<AbilityChargeTierDef> tiers,
  ) {
    var previous = -1;
    for (final tier in tiers) {
      final current = tier.minHoldTicks60;
      if (current <= previous) return false;
      previous = current;
    }
    return true;
  }
}

// --------------------------------------------------------------------------
// RUNTIME DATA STRUCTS
// --------------------------------------------------------------------------

/// Captured aim state snapshot used by ability/runtime systems.
class AimSnapshot {
  const AimSnapshot({
    required this.angleRad,
    this.hasAngle = true,
    required this.capturedTick,
  });

  static const AimSnapshot empty = AimSnapshot(
    angleRad: 0.0,
    hasAngle: false,
    capturedTick: 0,
  );

  final double angleRad;
  final bool hasAngle;
  final int capturedTick;

  @override
  String toString() =>
      'AimSnapshot(rad: ${angleRad.toStringAsFixed(2)}, tick: $capturedTick)';
}

// --------------------------------------------------------------------------
// COOLDOWN GROUPS
// --------------------------------------------------------------------------

/// Maximum supported cooldown groups per entity.
///
/// Value: `8`.
const int kMaxCooldownGroups = 8;

/// Semantic constants for cooldown group IDs.
///
/// Abilities sharing a group share a cooldown. Use these constants
/// for clarity, or use raw integers for custom groupings.
abstract final class CooldownGroup {
  /// Primary melee abilities (sword strike, etc.)
  static const int primary = 0;

  /// Secondary/off-hand abilities (shield bash, shield block, etc.)
  static const int secondary = 1;

  /// Projectile abilities (spells, throwing weapons)
  static const int projectile = 2;

  /// Mobility abilities (dash, roll)
  static const int mobility = 3;

  /// Jump ability
  static const int jump = 4;

  /// Spell slot abilities (5-7 reserved for future/spell)
  static const int spell0 = 5;
  static const int spell1 = 6;
  static const int spell2 = 7;

  /// Returns the default cooldown group for a given slot.
  static int fromSlot(AbilitySlot slot) {
    switch (slot) {
      case AbilitySlot.primary:
        return primary;
      case AbilitySlot.secondary:
        return secondary;
      case AbilitySlot.projectile:
        return projectile;
      case AbilitySlot.mobility:
        return mobility;
      case AbilitySlot.jump:
        return jump;
      case AbilitySlot.spell:
        return spell0;
    }
  }
}

// --------------------------------------------------------------------------
// ABILITY DEFINITION
// --------------------------------------------------------------------------

/// Fixed-point resource costs for ability commits (`100 == 1.0`).
class AbilityResourceCost {
  const AbilityResourceCost({
    this.healthCost100 = 0,
    this.staminaCost100 = 0,
    this.manaCost100 = 0,
  }) : assert(healthCost100 >= 0, 'Health cost cannot be negative'),
       assert(staminaCost100 >= 0, 'Stamina cost cannot be negative'),
       assert(manaCost100 >= 0, 'Mana cost cannot be negative');

  static const AbilityResourceCost zero = AbilityResourceCost();

  final int healthCost100;
  final int staminaCost100;
  final int manaCost100;
}

/// Immutable authored definition for a playable/system ability.
class AbilityDef {
  /// Default forced interrupts for authored abilities: stun + death.
  static const Set<ForcedInterruptCause> defaultForcedInterruptCauses =
      <ForcedInterruptCause>{
        ForcedInterruptCause.stun,
        ForcedInterruptCause.death,
      };

  /// Authoring constructor for immutable ability data.
  ///
  /// Parameter order is grouped by authoring flow:
  /// identity -> delivery/input -> damage/payload -> timing/hold/charge
  /// -> costs/cooldown -> gating/self-effects -> presentation.
  ///
  AbilityDef({
    required this.id,
    required this.category,
    required Set<AbilitySlot> allowedSlots,
    this.hitDelivery = const SelfHitDelivery(),
    this.targetingModel = TargetingModel.none,
    required this.inputLifecycle,
    this.payloadSource = AbilityPayloadSource.none,
    this.baseDamage = 0,
    this.baseDamageType = DamageType.physical,
    List<WeaponProc> procs = const <WeaponProc>[],
    required this.windupTicks,
    required this.activeTicks,
    required this.recoveryTicks,
    this.holdMode = AbilityHoldMode.none,
    this.holdStaminaDrainPerSecond100 = 0,
    this.damageIgnoredBp = 0,
    this.grantsRiposteOnGuardedHit = false,
    this.mobilityImpact = MobilityImpactDef.none,
    this.mobilitySpeedX,
    this.groundJumpSpeedY,
    this.airJumpSpeedY,
    this.maxAirJumps = 0,
    this.airJumpCost = AbilityResourceCost.zero,
    this.chargeProfile,
    this.chargeMaxHoldTicks60 = 0,
    this.defaultCost = AbilityResourceCost.zero,
    Map<WeaponType, AbilityResourceCost> costProfileByWeaponType =
        const <WeaponType, AbilityResourceCost>{},
    required this.cooldownTicks,
    this.cooldownGroupId,
    Set<WeaponType> requiredWeaponTypes = const <WeaponType>{},
    this.requiresEquippedWeapon = false,
    this.canCommitWhileStunned = false,
    Set<ForcedInterruptCause> forcedInterruptCauses =
        defaultForcedInterruptCauses,
    this.selfStatusProfileId = StatusProfileId.none,
    this.selfPurgeProfileId = PurgeProfileId.none,
    required this.animKey,
  }) : allowedSlots = Set<AbilitySlot>.unmodifiable(allowedSlots),
       procs = List<WeaponProc>.unmodifiable(procs),
       costProfileByWeaponType =
           Map<WeaponType, AbilityResourceCost>.unmodifiable(
             costProfileByWeaponType,
           ),
       requiredWeaponTypes = Set<WeaponType>.unmodifiable(requiredWeaponTypes),
       forcedInterruptCauses = Set<ForcedInterruptCause>.unmodifiable(
         forcedInterruptCauses,
       ),
       assert(id != '', 'Ability id cannot be empty.'),
       assert(
         windupTicks >= 0 && activeTicks >= 0 && recoveryTicks >= 0,
         'Ticks cannot be negative',
       ),
       assert(cooldownTicks >= 0, 'Cooldown cannot be negative'),
       assert(
         holdStaminaDrainPerSecond100 >= 0,
         'Hold stamina drain cannot be negative',
       ),
       assert(
         damageIgnoredBp >= 0 && damageIgnoredBp <= 10000,
         'Damage ignored bp must be in range [0, 10000].',
       ),
       assert(
         holdMode != AbilityHoldMode.none || holdStaminaDrainPerSecond100 == 0,
         'Non-hold abilities must not define hold stamina drain.',
       ),
       assert(
         category == AbilityCategory.mobility || !mobilityImpact.hasAnyEffect,
         'Only mobility abilities may author mobilityImpact effects.',
       ),
       assert(
         mobilitySpeedX == null || category == AbilityCategory.mobility,
         'Only mobility abilities may define mobilitySpeedX.',
       ),
       assert(
         mobilitySpeedX == null || mobilitySpeedX > 0,
         'mobilitySpeedX must be positive when defined.',
       ),
       assert(
         groundJumpSpeedY == null || groundJumpSpeedY > 0,
         'groundJumpSpeedY must be positive when defined.',
       ),
       assert(
         airJumpSpeedY == null || airJumpSpeedY > 0,
         'airJumpSpeedY must be positive when defined.',
       ),
       assert(
         groundJumpSpeedY == null || allowedSlots.contains(AbilitySlot.jump),
         'Only jump-slot abilities may define groundJumpSpeedY.',
       ),
       assert(
         airJumpSpeedY == null || allowedSlots.contains(AbilitySlot.jump),
         'Only jump-slot abilities may define airJumpSpeedY.',
       ),
       assert(
         groundJumpSpeedY == null || category == AbilityCategory.mobility,
         'Only mobility abilities may define groundJumpSpeedY.',
       ),
       assert(
         airJumpSpeedY == null || category == AbilityCategory.mobility,
         'Only mobility abilities may define airJumpSpeedY.',
       ),
       assert(maxAirJumps >= 0, 'maxAirJumps cannot be negative.'),
       assert(
         maxAirJumps == 0 || allowedSlots.contains(AbilitySlot.jump),
         'Only jump-slot abilities may define maxAirJumps.',
       ),
       assert(
         maxAirJumps == 0 || category == AbilityCategory.mobility,
         'Only mobility abilities may define maxAirJumps.',
       ),
       assert(
         airJumpCost.healthCost100 >= 0 &&
             airJumpCost.staminaCost100 >= 0 &&
             airJumpCost.manaCost100 >= 0,
         'airJumpCost cannot contain negative values.',
       ),
       assert(
         (airJumpCost.healthCost100 == 0 &&
                 airJumpCost.staminaCost100 == 0 &&
                 airJumpCost.manaCost100 == 0) ||
             allowedSlots.contains(AbilitySlot.jump),
         'Only jump-slot abilities may define airJumpCost.',
       ),
       assert(
         (airJumpCost.healthCost100 == 0 &&
                 airJumpCost.staminaCost100 == 0 &&
                 airJumpCost.manaCost100 == 0) ||
             category == AbilityCategory.mobility,
         'Only mobility abilities may define airJumpCost.',
       ),
       assert(
         mobilityImpact.damage100 > 0 || mobilityImpact.procs.isEmpty,
         'mobilityImpact procs require positive mobilityImpact damage.',
       ),
       assert(
         chargeMaxHoldTicks60 >= 0,
         'Charge max hold ticks cannot be negative',
       ),
       assert(
         chargeProfile != null || chargeMaxHoldTicks60 == 0,
         'Charge max hold ticks requires a charge profile.',
       ),
       assert(
         holdMode == AbilityHoldMode.none || activeTicks > 0,
         'Hold abilities require activeTicks > 0 for max hold duration.',
       ),
       assert(
         inputLifecycle != AbilityInputLifecycle.holdMaintain ||
             holdMode == AbilityHoldMode.holdToMaintain,
         'holdMaintain lifecycle requires holdToMaintain hold mode.',
       ),
       assert(
         holdMode != AbilityHoldMode.holdToMaintain ||
             inputLifecycle == AbilityInputLifecycle.holdMaintain,
         'holdToMaintain abilities must use holdMaintain lifecycle.',
       ),
       assert(
         chargeProfile == null || inputLifecycle != AbilityInputLifecycle.tap,
         'tap lifecycle cannot be combined with tiered charge.',
       ),
       assert(
         targetingModel != TargetingModel.none ||
             inputLifecycle != AbilityInputLifecycle.holdRelease,
         'holdRelease + self is intentionally unsupported.',
       ),
       assert(
         cooldownGroupId == null ||
             (cooldownGroupId >= 0 && cooldownGroupId < kMaxCooldownGroups),
         'Cooldown group must be in range [0, $kMaxCooldownGroups)',
       );

  final AbilityKey id;

  /// UI/system grouping category.
  final AbilityCategory category;

  /// Slots where this ability is legal to equip.
  final Set<AbilitySlot> allowedSlots;

  /// Targeting mode used at commit-time.
  final TargetingModel targetingModel;

  /// Delivery definition consumed by strike systems.
  final HitDeliveryDef hitDelivery;

  /// Where payload stats/procs are sourced from when committed.
  final AbilityPayloadSource payloadSource;

  /// Authored input lifecycle contract for this ability.
  final AbilityInputLifecycle inputLifecycle;

  /// Timing values authored at `60 Hz` tick semantics.
  ///
  /// For [AbilityHoldMode.holdToMaintain], [activeTicks] is the max hold
  /// window before automatic termination.
  final int windupTicks;
  final int activeTicks;
  final int recoveryTicks;

  /// Default resource cost when no weapon-type override is authored.
  final AbilityResourceCost defaultCost;

  /// Optional resource-cost overrides keyed by resolved payload [WeaponType].
  ///
  /// This enables abilities whose commit cost depends on the active payload
  /// source (for example, same projectile ability using spell mana or throw
  /// stamina based on the currently selected projectile weapon type).
  final Map<WeaponType, AbilityResourceCost> costProfileByWeaponType;

  /// Runtime hold behavior model.
  final AbilityHoldMode holdMode;

  /// Fixed-point stamina drain per second while a hold ability is maintained.
  ///
  /// `100 == 1.0 stamina/second`.
  final int holdStaminaDrainPerSecond100;

  /// Incoming hit damage ignored while this ability is active.
  ///
  /// Basis points: `10000 == 100%` (full ignore), `5000 == 50%`.
  /// This is consumed by combat middleware and is intentionally ability-authored
  /// so defensive abilities can tune mitigation independently.
  final int damageIgnoredBp;

  /// Whether a guarded hit during this ability grants the one-shot riposte buff.
  ///
  /// This is intentionally independent from [damageIgnoredBp] so designers can
  /// author "pure block" abilities (full mitigation, no riposte reward).
  final bool grantsRiposteOnGuardedHit;

  /// Optional contact payload applied during active mobility overlaps.
  final MobilityImpactDef mobilityImpact;

  /// Horizontal speed in world-units/second for this mobility ability.
  ///
  /// Each mobility ability defines its own speed. Non-mobility abilities
  /// leave this `null`.
  final double? mobilitySpeedX;

  /// Optional authored initial vertical speed for ground jump execution.
  ///
  /// Positive value in world-units/second. Runtime applies this upward
  /// (negative Y velocity) when a ground/coyote jump executes.
  final double? groundJumpSpeedY;

  /// Optional authored fixed vertical speed for air-jump execution.
  ///
  /// Positive value in world-units/second. Runtime applies this upward
  /// (negative Y velocity) when an air jump executes.
  final double? airJumpSpeedY;

  /// Number of extra airborne jumps allowed before touching ground.
  ///
  /// `0` means no extra air jump.
  final int maxAirJumps;

  /// Resource cost applied when performing an airborne jump.
  ///
  /// Ground jumps still use [defaultCost].
  final AbilityResourceCost airJumpCost;

  /// Cooldown duration in ticks.
  final int cooldownTicks;

  /// Cooldown group index (0-7). Abilities sharing a group share a cooldown.
  ///
  /// If null, defaults to the slot's default group via [CooldownGroup.fromSlot].
  /// Suggested defaults:
  ///   0 = primary melee
  ///   1 = secondary melee
  ///   2 = projectile
  ///   3 = mobility
  ///   4 = jump
  ///   5-7 = future/spell
  final int? cooldownGroupId;

  /// Forced interruption causes this ability opts into.
  final Set<ForcedInterruptCause> forcedInterruptCauses;

  /// Animation key to play while this ability is active.
  final AnimKey animKey;

  /// Weapon families required for this ability to be legal/equippable.
  final Set<WeaponType> requiredWeaponTypes;

  /// If true, this ability requires *some* weapon to be equipped in its slot,
  /// even if [requiredWeaponTypes] is empty.
  final bool requiresEquippedWeapon;

  /// If true, this ability can be committed while stunned.
  final bool canCommitWhileStunned;

  /// Guaranteed or probabilistic effects applied on hit (ability-owned).
  /// Merged deterministically with item procs in [HitPayloadBuilder].
  final List<WeaponProc> procs;

  /// Status profile applied to self on execute (SelfHitDelivery only).
  final StatusProfileId selfStatusProfileId;

  /// Purge profile applied to self on execute (SelfHitDelivery only).
  final PurgeProfileId selfPurgeProfileId;

  /// Optional charge tuning profile for hold/release commits.
  final AbilityChargeProfile? chargeProfile;

  /// Optional hard timeout for charge holds in authored 60 Hz ticks.
  ///
  /// `0` means no timeout.
  final int chargeMaxHoldTicks60;

  /// Base damage for this ability.
  /// Fixed-point: 100 = 1.0 damage.
  /// - Melee: Base damage of the swing.
  /// - Thrown: Base damage of the throw.
  /// - Spell: Base damage of the spell projectile.
  final int baseDamage;

  /// Base damage type (element) for this ability.
  /// Explicitly defined in authored data.
  final DamageType baseDamageType;

  /// Returns the effective cooldown group for this ability.
  ///
  /// Uses [cooldownGroupId] if set, otherwise falls back to slot default.
  int effectiveCooldownGroup(AbilitySlot slot) {
    if (cooldownGroupId != null) return cooldownGroupId!;
    return CooldownGroup.fromSlot(slot);
  }

  /// Resolves the effective commit cost for the given payload [weaponType].
  ///
  /// Falls back to [defaultCost] when no matching override exists.
  AbilityResourceCost resolveCostForWeaponType(WeaponType? weaponType) {
    if (weaponType == null) return defaultCost;
    return costProfileByWeaponType[weaponType] ?? defaultCost;
  }

  @override
  String toString() => 'AbilityDef($id)';
}
