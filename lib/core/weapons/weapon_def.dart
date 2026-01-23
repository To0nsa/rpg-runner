import '../abilities/ability_def.dart' show AbilityTag;
import '../combat/damage_type.dart';
import '../combat/status/status.dart';
import 'weapon_category.dart';
import 'weapon_id.dart';
import 'weapon_proc.dart';
import 'weapon_stats.dart';

/// Static, data-first definition for a melee weapon.
///
/// Weapon definitions are queried by [WeaponId] and used by intent writers
/// (e.g. [PlayerMeleeSystem]) to fill combat metadata like damage type and
/// on-hit status profiles.
class WeaponDef {
  const WeaponDef({
    required this.id,
    required this.category,
    this.grantedAbilityTags = const {},
    this.damageType = DamageType.physical,
    // Legacy (kept until Phase 5)
    this.statusProfileId = StatusProfileId.none,
    // New Phase 2 fields
    this.procs = const [],
    this.stats = const WeaponStats(),
    this.isTwoHanded = false,
  });

  final WeaponId id;

  /// Equipment slot category (primary/offHand/projectile).
  final WeaponCategory category;

  /// Capabilities provided by this weapon.
  /// Abilities check: requiredTags ⊆ grantedAbilityTags.
  /// Safe default: empty grants nothing.
  final Set<AbilityTag> grantedAbilityTags;

  /// Default damage type applied to hits.
  final DamageType damageType;

  /// LEGACY: Single on-hit status profile, kept for current runtime.
  /// Bridge rule: if procs empty and statusProfileId != none,
  /// treat as [onHit: statusProfileId] for future payload builders.
  final StatusProfileId statusProfileId;

  /// New, extensible proc list (Phase 2+).
  final List<WeaponProc> procs;

  /// Passive stats provided by this weapon (future use).
  final WeaponStats stats;

  /// If true, occupies both Primary + Secondary equipment slots.
  /// Enforcement is equip-time validation (Phase 3/4).
  final bool isTwoHanded;
}
