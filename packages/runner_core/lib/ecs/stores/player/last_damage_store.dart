import '../../../enemies/enemy_id.dart';
import '../../../events/game_event.dart';
import '../../../projectiles/projectile_id.dart';
import '../../../traps/trap_placement.dart';
import '../../entity_id.dart';
import '../../sparse_set.dart';

/// Per-entity record of the last applied damage metadata.
///
/// Used to populate the "Game Over" screen with cause of death.
class LastDamageStore extends SparseSet {
  final List<DeathSourceKind> kind = <DeathSourceKind>[];
  final List<EnemyId> enemyId = <EnemyId>[];
  final List<bool> hasEnemyId = <bool>[];
  final List<ProjectileId> projectileId = <ProjectileId>[];
  final List<bool> hasProjectileId = <bool>[];
  final List<ProjectileId> sourceProjectileId = <ProjectileId>[];
  final List<bool> hasSourceProjectileId = <bool>[];
  final List<TrapSourceRef?> sourceTrap = <TrapSourceRef?>[];

  /// Fixed-point: 100 = 1.0
  final List<int> amount100 = <int>[];
  final List<int> tick = <int>[];

  void add(EntityId entity) {
    addEntity(entity);
  }

  @override
  void onDenseAdded(int denseIndex) {
    kind.add(DeathSourceKind.unknown);
    enemyId.add(EnemyId.unocoDemon);
    hasEnemyId.add(false);
    projectileId.add(ProjectileId.unknown);
    hasProjectileId.add(false);
    sourceProjectileId.add(ProjectileId.unknown);
    hasSourceProjectileId.add(false);
    sourceTrap.add(null);
    amount100.add(0);
    tick.add(-1);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    kind[removeIndex] = kind[lastIndex];
    enemyId[removeIndex] = enemyId[lastIndex];
    hasEnemyId[removeIndex] = hasEnemyId[lastIndex];
    projectileId[removeIndex] = projectileId[lastIndex];
    hasProjectileId[removeIndex] = hasProjectileId[lastIndex];
    sourceProjectileId[removeIndex] = sourceProjectileId[lastIndex];
    hasSourceProjectileId[removeIndex] = hasSourceProjectileId[lastIndex];
    sourceTrap[removeIndex] = sourceTrap[lastIndex];
    amount100[removeIndex] = amount100[lastIndex];
    tick[removeIndex] = tick[lastIndex];

    kind.removeLast();
    enemyId.removeLast();
    hasEnemyId.removeLast();
    projectileId.removeLast();
    hasProjectileId.removeLast();
    sourceProjectileId.removeLast();
    hasSourceProjectileId.removeLast();
    sourceTrap.removeLast();
    amount100.removeLast();
    tick.removeLast();
  }
}
