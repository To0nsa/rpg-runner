import '../abilities/ability_def.dart';
import '../enemies/enemy_id.dart';

/// Arena-owned, damageable allies; admission still requires terrain clearance.
final class BossSummonDelivery extends HitDeliveryDef {
  const BossSummonDelivery({
    required this.enemyId,
    required this.maxAlive,
    required this.lifetimeSeconds,
    this.count = 1,
  }) : assert(maxAlive > 0),
       assert(count > 0),
       assert(lifetimeSeconds > 0);
  final EnemyId enemyId;
  final int maxAlive;

  /// Maximum admissions in this cast, still bounded by [maxAlive] and placement.
  final int count;
  final double lifetimeSeconds;
}

/// Captured reposition distance in world units; placement may safely fail.
final class BossTeleportDelivery extends HitDeliveryDef {
  const BossTeleportDelivery({this.distance = 150}) : assert(distance > 0);
  final double distance;
}
