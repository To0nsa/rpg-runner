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
enum AbilitySlot { primary, secondary, projectile, mobility, bonus, jump }

/// High-level semantic grouping used by UI and systems.
enum AbilityCategory { melee, ranged, magic, mobility, defense, utility }

/// Weapon family classification used for ability gating.
enum WeaponType { oneHandedSword, shield, throwingWeapon, projectileSpell }

/// Where this ability should fetch its combat payload from at commit-time.
///
/// This is the missing "source of truth" that decouples:
/// - which button/slot triggers an ability
/// - from where the ability derives weapon/projectile stats/procs/damage-type.
///
/// Critical for Bonus slot (can host anything).
enum AbilityPayloadSource {
  none,
  primaryWeapon,
  secondaryWeapon, // off-hand unless primary is two-handed (then primary)
  projectileItem,
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
    this.hitboxScaleBp = 10000,
    this.pierce,
    this.maxPierceHits,
  }) : assert(minHoldTicks60 >= 0, 'minHoldTicks60 cannot be negative'),
       assert(damageScaleBp >= 0, 'damageScaleBp cannot be negative'),
       assert(speedScaleBp > 0, 'speedScaleBp must be > 0'),
       assert(hitboxScaleBp > 0, 'hitboxScaleBp must be > 0'),
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

  /// Melee hitbox scale in basis points (`10000 == 1.0x`).
  final int hitboxScaleBp;

  /// Optional projectile piercing override.
  final bool? pierce;

  /// Optional projectile max pierce hit override.
  final int? maxPierceHits;
}

/// Data-authored charge profile shared by melee/projectile commit paths.
class AbilityChargeProfile {
  const AbilityChargeProfile({required this.tiers});

  final List<AbilityChargeTierDef> tiers;
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

  /// Bonus slot abilities (5-7 reserved for future/bonus)
  static const int bonus0 = 5;
  static const int bonus1 = 6;
  static const int bonus2 = 7;

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
      case AbilitySlot.bonus:
        return bonus0;
    }
  }
}

// --------------------------------------------------------------------------
// ABILITY DEFINITION
// --------------------------------------------------------------------------

/// Immutable authored definition for a playable/system ability.
class AbilityDef {
  /// Default forced interrupts for authored abilities: stun + death.
  static const Set<ForcedInterruptCause> defaultForcedInterruptCauses =
      <ForcedInterruptCause>{
        ForcedInterruptCause.stun,
        ForcedInterruptCause.death,
      };

  const AbilityDef({
    required this.id,
    required this.category,
    required this.allowedSlots,
    required this.targetingModel,
    required this.hitDelivery,
    this.payloadSource = AbilityPayloadSource.none,
    required this.windupTicks,
    required this.activeTicks,
    required this.recoveryTicks,
    required this.staminaCost,
    required this.manaCost,
    this.holdMode = AbilityHoldMode.none,
    this.holdStaminaDrainPerSecond100 = 0,
    required this.cooldownTicks,
    this.cooldownGroupId,
    this.forcedInterruptCauses = defaultForcedInterruptCauses,
    required this.animKey,
    this.requiredWeaponTypes = const {},
    this.requiresEquippedWeapon = false,
    this.procs = const <WeaponProc>[],
    this.selfStatusProfileId = StatusProfileId.none,
    this.selfRestoreHealthBp = 0,
    this.selfRestoreManaBp = 0,
    this.selfRestoreStaminaBp = 0,
    this.chargeProfile,
    this.chargeMaxHoldTicks60 = 0,
    required this.baseDamage,
    this.baseDamageType = DamageType.physical,
  }) : assert(id != '', 'Ability id cannot be empty.'),
       assert(
         windupTicks >= 0 && activeTicks >= 0 && recoveryTicks >= 0,
         'Ticks cannot be negative',
       ),
       assert(cooldownTicks >= 0, 'Cooldown cannot be negative'),
       assert(staminaCost >= 0 && manaCost >= 0, 'Costs cannot be negative'),
       assert(
         holdStaminaDrainPerSecond100 >= 0,
         'Hold stamina drain cannot be negative',
       ),
       assert(
         holdMode != AbilityHoldMode.none || holdStaminaDrainPerSecond100 == 0,
         'Non-hold abilities must not define hold stamina drain.',
       ),
       assert(
         selfRestoreHealthBp >= 0,
         'Self restore health cannot be negative',
       ),
       assert(selfRestoreManaBp >= 0, 'Self restore mana cannot be negative'),
       assert(
         selfRestoreStaminaBp >= 0,
         'Self restore stamina cannot be negative',
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

  /// Timing values authored at `60 Hz` tick semantics.
  ///
  /// For [AbilityHoldMode.holdToMaintain], [activeTicks] is the max hold
  /// window before automatic termination.
  final int windupTicks;
  final int activeTicks;
  final int recoveryTicks;

  /// Resource costs in fixed-point units (`100 == 1.0`).
  final int staminaCost;
  final int manaCost;

  /// Runtime hold behavior model.
  final AbilityHoldMode holdMode;

  /// Fixed-point stamina drain per second while a hold ability is maintained.
  ///
  /// `100 == 1.0 stamina/second`.
  final int holdStaminaDrainPerSecond100;

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
  ///   5-7 = future/bonus
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

  /// Guaranteed or probabilistic effects applied on hit (ability-owned).
  /// Merged deterministically with item procs in [HitPayloadBuilder].
  final List<WeaponProc> procs;

  /// Status profile applied to self on execute (SelfHitDelivery only).
  final StatusProfileId selfStatusProfileId;

  /// Percentage of max HP restored on execute (`100 = 1%`, `10000 = 100%`).
  ///
  /// Applied only by [SelfHitDelivery] abilities.
  final int selfRestoreHealthBp;

  /// Percentage of max mana restored on execute (`100 = 1%`, `10000 = 100%`).
  ///
  /// Applied only by [SelfHitDelivery] abilities.
  final int selfRestoreManaBp;

  /// Percentage of max stamina restored on execute (`100 = 1%`, `10000 = 100%`).
  ///
  /// Applied only by [SelfHitDelivery] abilities.
  final int selfRestoreStaminaBp;

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

  @override
  String toString() => 'AbilityDef($id)';
}
