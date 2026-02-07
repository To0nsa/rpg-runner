import '../projectiles/projectile_id.dart';
import '../combat/damage_type.dart';
import '../combat/status/status.dart';
import '../snapshots/enums.dart';
import '../weapons/weapon_proc.dart';

// Validates strict format: "character.ability_name" (lower snake case)
// Must have at least one dot, segments must be non-empty [a-z0-9_].
// Example: "eloise.sword_strike_1"
typedef AbilityKey = String;

bool isValidAbilityKey(AbilityKey key) {
  final RegExp validKey = RegExp(r'^[a-z0-9_]+\.[a-z0-9_]+$');
  return validKey.hasMatch(key);
}

enum AbilitySlot {
  primary, // Button A (Melee)
  secondary, // Button B (Off-hand/Defensive)
  projectile, // Button C (Cast/Throw)
  mobility, // Button D (Dash)
  bonus, // Button E (Potion/Ultimate)
  jump, // Fixed slot (reserved)
}

enum AbilityCategory { melee, ranged, magic, mobility, defense, utility }

enum AbilityTag {
  // Mechanics
  melee,
  projectile,
  hitscan,
  aoe,
  buff,
  debuff,

  // Elements
  physical,
  fire,
  ice,
  lightning,

  // Properties
  heavy,
  light,
  finisher,
  opener,
}

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

enum TargetingModel {
  none, // Instant self-cast / buff
  directional, // Uses input direction (melee)
  aimed, // Uses explicit aim cursor (ranged)
  homing, // Auto-locks nearest target
  groundTarget, // AOE circle on ground
}

enum AbilityPhase { idle, windup, active, recovery }

enum InterruptPriority {
  low, // e.g. passive stance
  combat, // standard attacks (strike/cast)
  mobility, // dash/jump/roll
  forced, // system-only (stun/death)
}

// --------------------------------------------------------------------------
// HIT DELIVERY
// --------------------------------------------------------------------------

enum HitPolicy {
  once, // Hit once per activation (e.g. explosion)
  oncePerTarget, // Hit each target once (e.g. sword swing)
  everyTick, // Hit every frame (e.g. beam)
}

abstract class HitDeliveryDef {
  const HitDeliveryDef();
}

class MeleeHitDelivery extends HitDeliveryDef {
  const MeleeHitDelivery({
    required this.sizeX,
    required this.sizeY,
    required this.offsetX,
    required this.offsetY,
    required this.hitPolicy,
  });

  // Dimensions in World Units
  final double sizeX;
  final double sizeY;
  final double offsetX;
  final double offsetY;
  final HitPolicy hitPolicy;
}

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
// RUNTIME DATA STRUCTS
// --------------------------------------------------------------------------

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

class AbilityDef {
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
    required this.cooldownTicks,
    this.cooldownGroupId,
    required this.interruptPriority,
    this.canBeInterruptedBy = const {},
    required this.animKey,
    this.tags = const {},
    this.requiredTags = const {},
    this.requiredWeaponTypes = const {},
    this.requiresEquippedWeapon = false,
    this.procs = const <WeaponProc>[],
    this.selfStatusProfileId = StatusProfileId.none,
    required this.baseDamage,
    this.baseDamageType = DamageType.physical,
  }) : assert(
         windupTicks >= 0 && activeTicks >= 0 && recoveryTicks >= 0,
         'Ticks cannot be negative',
       ),
       assert(cooldownTicks >= 0, 'Cooldown cannot be negative'),
       assert(staminaCost >= 0 && manaCost >= 0, 'Costs cannot be negative'),
       assert(
         interruptPriority != InterruptPriority.forced,
         'Forced priority is reserved for system events.',
       ),
       assert(
         cooldownGroupId == null ||
             (cooldownGroupId >= 0 && cooldownGroupId < kMaxCooldownGroups),
         'Cooldown group must be in range [0, $kMaxCooldownGroups)',
       );

  final AbilityKey id;

  // UI grouping only
  final AbilityCategory category;

  // Explicit equip legality
  final Set<AbilitySlot> allowedSlots;

  // Targeting
  final TargetingModel targetingModel;

  // Hit mechanics
  final HitDeliveryDef hitDelivery;

  // Payload source
  final AbilityPayloadSource payloadSource;

  // Timing (ticks @ 60hz)
  final int windupTicks;
  final int activeTicks;
  final int recoveryTicks;

  // Costs (fixed point: 100 = 1.0)
  final int staminaCost;
  final int manaCost;

  // Cooldown
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

  // Interrupt rules
  final InterruptPriority interruptPriority;
  final Set<InterruptPriority> canBeInterruptedBy;

  // Presentation
  final AnimKey animKey;

  // Metadata
  final Set<AbilityTag> tags;
  final Set<AbilityTag> requiredTags;
  final Set<WeaponType> requiredWeaponTypes;

  /// If true, this ability requires *some* weapon to be equipped in its slot,
  /// even if [requiredWeaponTypes] is empty.
  final bool requiresEquippedWeapon;

  /// Guaranteed or probabilistic effects applied on hit (ability-owned).
  /// Merged deterministically with item procs in [HitPayloadBuilder].
  final List<WeaponProc> procs;

  /// Status profile applied to self on execute (SelfHitDelivery only).
  final StatusProfileId selfStatusProfileId;

  /// Base damage for this ability.
  /// Fixed-point: 100 = 1.0 damage.
  /// - Melee: Base damage of the swing.
  /// - Thrown: Base damage of the throw.
  /// - Spell: Base damage of the spell projectile.
  final int baseDamage;

  /// Base damage type (element) for this ability.
  /// Explicitly defined (Phase 5), no inference from tags.
  final DamageType baseDamageType;

  /// Returns the effective cooldown group for this ability.
  ///
  /// Uses [cooldownGroupId] if set, otherwise falls back to slot default.
  int effectiveCooldownGroup(AbilitySlot slot) {
    if (cooldownGroupId != null) return cooldownGroupId!;
    return CooldownGroup.fromSlot(slot);
  }

  // Runtime Validation (Helper)
  bool get isValid {
    return isValidAbilityKey(id) &&
        !canBeInterruptedBy.contains(interruptPriority);
  }

  @override
  String toString() => 'AbilityDef($id)';
}
