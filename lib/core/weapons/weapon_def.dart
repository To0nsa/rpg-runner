import '../abilities/ability_def.dart' show AbilityTag, WeaponType;
import '../combat/damage_type.dart';
import 'weapon_category.dart';
import 'weapon_id.dart';
import 'weapon_proc.dart';
import 'weapon_stats.dart';

/// Static, data-first definition for a melee weapon.
///
/// Weapon definitions are queried by [WeaponId] and used by intent writers
/// (e.g. [AbilityActivationSystem]) to fill combat metadata like damage type and
/// on-hit status profiles.
class WeaponDef {
  const WeaponDef({
    required this.id,
    required this.displayName,
    required this.description,
    required this.category,
    required this.weaponType,
    this.grantedAbilityTags = const {},
    this.damageType = DamageType.physical,
    this.procs = const [],
    this.stats = const WeaponStats(),
    this.isTwoHanded = false,
  });

  final WeaponId id;
  final String displayName;
  final String description;

  /// Equipment slot category (primary/offHand/projectile).
  final WeaponCategory category;

  /// Visual/functional family (used for ability gating).
  final WeaponType weaponType;

  /// Capabilities provided by this weapon.
  /// Abilities check: requiredTags ⊆ grantedAbilityTags.
  /// Safe default: empty grants nothing.
  final Set<AbilityTag> grantedAbilityTags;

  /// Default damage type applied to hits.
  final DamageType damageType;

  /// New, extensible proc list (Phase 2+).
  final List<WeaponProc> procs;

  /// Passive stats provided by this weapon (future use).
  final WeaponStats stats;

  /// If true, occupies both Primary + Secondary equipment slots.
  /// Enforcement is equip-time validation (Phase 3/4).
  final bool isTwoHanded;
}
