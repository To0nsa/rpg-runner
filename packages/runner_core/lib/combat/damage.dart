import '../ecs/entity_id.dart';
import '../enemies/enemy_id.dart';
import '../events/game_event.dart';
import '../projectiles/projectile_id.dart';
import '../weapons/weapon_proc.dart';
import '../traps/trap_placement.dart';
import '../abilities/ability_def.dart';
import 'damage_type.dart';
import 'damage_credit.dart';
import 'knockback.dart';

/// Represents a request to apply damage to an entity.
///
/// This structure captures the target, the amount of damage, and comprehensive
/// metadata about the source of the damage (entity, enemy type, projectile)
/// to be used for combat logic, death events, and statistics.
class DamageRequest {
  const DamageRequest({
    required this.target,
    required this.amount100,
    this.critChanceBp = 0,
    this.damageType = DamageType.physical,
    this.procs = const <WeaponProc>[],
    this.source,
    this.sourceMeleeAbilityId,
    this.sourceKind = DeathSourceKind.unknown,
    this.sourceEnemyId,
    this.sourceProjectileId,
    this.sourceTrap,
    this.credit = DamageCredit.none,
    this.knockback,
  });

  /// The entity receiving the damage.
  final EntityId target;

  /// The amount of health points to deduct.
  ///
  /// Fixed-point: 100 = 1.0
  final int amount100;

  /// Critical strike chance in basis points (100 = 1%).
  final int critChanceBp;

  /// Category used for resistance/vulnerability lookup.
  final DamageType damageType;

  /// Potential on-hit procs to roll at application time.
  final List<WeaponProc> procs;

  /// The optional entity responsible for dealing the damage (e.g. the shooter).
  final EntityId? source;

  /// Captured melee ability identity for post-defense hit confirmation.
  /// Null for projectiles, damage over time and other non-melee requests.
  final AbilityKey? sourceMeleeAbilityId;

  /// Categorization of the damage source for death messages or analytics.
  final DeathSourceKind sourceKind;

  /// If the dissolved source was an enemy, its static ID.
  final EnemyId? sourceEnemyId;

  /// If the damage came from a projectile, its static ID.
  final ProjectileId? sourceProjectileId;

  /// Environmental attribution remains valid after its streamed owner retires.
  final TrapSourceRef? sourceTrap;
  final DamageCredit credit;

  /// Applied only after defenses and middleware allow positive HP loss.
  final KnockbackHit? knockback;
}
