import '../ecs/entity_id.dart';
import '../enemies/enemy_id.dart';
import '../events/game_event.dart';
import '../projectiles/projectile_id.dart';
import '../projectiles/projectile_item_id.dart';
import '../weapons/weapon_proc.dart';
import 'damage_type.dart';
import 'status/status.dart';

/// Represents a request to apply damage to an entity.
///
/// This structure captures the target, the amount of damage, and comprehensive
  /// metadata about the source of the damage (entity, enemy type, projectile, projectile item)
/// to be used for combat logic, death events, and statistics.
class DamageRequest {
  const DamageRequest({
    required this.target,
    required this.amount100,
    this.damageType = DamageType.physical,
    this.statusProfileId = StatusProfileId.none,
    this.procs = const <WeaponProc>[],
    this.source,
    this.sourceKind = DeathSourceKind.unknown,
    this.sourceEnemyId,
    this.sourceProjectileId,
    this.sourceProjectileItemId,
  });

  /// The entity receiving the damage.
  final EntityId target;

  /// The amount of health points to deduct.
  ///
  /// Fixed-point: 100 = 1.0
  final int amount100;

  /// Category used for resistance/vulnerability lookup.
  final DamageType damageType;

  /// Optional status profile to apply on hit.
  final StatusProfileId statusProfileId;

  /// Potential on-hit procs to roll at application time.
  final List<WeaponProc> procs;

  /// The optional entity responsible for dealing the damage (e.g. the shooter).
  final EntityId? source;

  /// Categorization of the damage source for death messages or analytics.
  final DeathSourceKind sourceKind;

  /// If the dissolved source was an enemy, its static ID.
  final EnemyId? sourceEnemyId;

  /// If the damage came from a projectile, its static ID.
  final ProjectileId? sourceProjectileId;

  /// If the damage came from a projectile item, its static ID.
  final ProjectileItemId? sourceProjectileItemId;
}
