import '../abilities/ability_def.dart' show AbilityKey;
import '../ecs/entity_id.dart';
import '../weapons/weapon_id.dart';
import '../weapons/weapon_proc.dart';
import 'damage_type.dart';

/// Resolved payload for a damaging action.
///
/// This is the "Frozen Snapshot" of an attack, constructed by [HitPayloadBuilder].
/// It carries all necessary data for the consumer (Projectile/Melee System) to
/// execute the hit.
///
/// **Design Pillars:**
/// *   **Integer Determinism**: [damage100] is in fixed-point (100 = 1.0).
/// *   **Explicit Type**: [damageType] is fully resolved.
/// *   **Potential Procs**: [procs] list candidate effects (rng roll happens at hit time).
class HitPayload {
  const HitPayload({
    required this.damage100,
    required this.critChanceBp,
    required this.damageType,
    required this.procs,
    required this.sourceId,
    this.abilityId,
    this.weaponId,
  });

  /// Final calculated damage in fixed-point units (100 = 1.0 visual damage).
  ///
  /// Includes base ability damage + weapon scaling + any intent-time modifiers.
  final int damage100;

  /// Critical strike chance in basis points (100 = 1%).
  final int critChanceBp;

  /// The elemental type of the damage (resolved from Ability vs Weapon priority).
  final DamageType damageType;

  /// List of potential on-hit effects contributed by the weapon/ability.
  ///
  /// The consumer is responsible for rolling the chance (bp) to apply these.
  final List<WeaponProc> procs;

  /// The entity that originated this hit (Player/Enemy).
  final EntityId sourceId;

  // Debugging / Logging
  final AbilityKey? abilityId;
  final WeaponId? weaponId;
}
