import '../../combat/damage.dart';
import '../../combat/damage_type.dart';
import '../../combat/status/status.dart';
import '../../enemies/enemy_id.dart';
import '../../events/game_event.dart';
import '../../projectiles/projectile_id.dart';
import '../../projectiles/projectile_item_id.dart';
import '../../weapons/weapon_proc.dart';
import '../entity_id.dart';

/// Flags stored alongside queued damage requests.
class DamageQueueFlags {
  static const int canceled = 1 << 0;
}

/// World-level queue for pending damage requests (SoA).
///
/// This queue is populated by hit resolution systems and processed by
/// [DamageMiddlewareSystem] and [DamageSystem].
class DamageQueueStore {
  final List<EntityId> target = <EntityId>[];
  final List<int> amount100 = <int>[];
  final List<DamageType> damageType = <DamageType>[];
  final List<StatusProfileId> statusProfileId = <StatusProfileId>[];
  final List<List<WeaponProc>> procs = <List<WeaponProc>>[];
  final List<DeathSourceKind> sourceKind = <DeathSourceKind>[];
  final List<EntityId?> sourceEntity = <EntityId?>[];
  final List<EnemyId?> sourceEnemyId = <EnemyId?>[];
  final List<ProjectileId?> sourceProjectileId = <ProjectileId?>[];
  final List<ProjectileItemId?> sourceProjectileItemId = <ProjectileItemId?>[];
  final List<int> flags = <int>[];

  int get length => target.length;

  /// Adds a damage request, returning its index or -1 if ignored.
  int add(DamageRequest request) {
    if (request.amount100 <= 0 &&
        request.statusProfileId == StatusProfileId.none &&
        request.procs.isEmpty) {
      return -1;
    }

    final index = target.length;
    target.add(request.target);
    amount100.add(request.amount100);
    damageType.add(request.damageType);
    statusProfileId.add(request.statusProfileId);
    procs.add(request.procs);
    sourceKind.add(request.sourceKind);
    sourceEntity.add(request.source);
    sourceEnemyId.add(request.sourceEnemyId);
    sourceProjectileId.add(request.sourceProjectileId);
    sourceProjectileItemId.add(request.sourceProjectileItemId);
    flags.add(0);
    return index;
  }

  void cancel(int index) {
    flags[index] |= DamageQueueFlags.canceled;
  }

  void clear() {
    target.clear();
    amount100.clear();
    damageType.clear();
    statusProfileId.clear();
    procs.clear();
    sourceKind.clear();
    sourceEntity.clear();
    sourceEnemyId.clear();
    sourceProjectileId.clear();
    sourceProjectileItemId.clear();
    flags.clear();
  }
}
