import '../../../enemies/enemy_id.dart';
import '../../../snapshots/enums.dart';
import '../../entity_id.dart';
import '../../sparse_set.dart';

class EnemyDef {
  const EnemyDef({
    required this.enemyId,
    this.facing = Facing.left,
  });

  final EnemyId enemyId;
  final Facing facing;
}

/// Minimal enemy marker + per-enemy state.
///
/// Indicates this entity is an enemy and which type it is.
/// Also holds facing direction.
class EnemyStore extends SparseSet {
  final List<EnemyId> enemyId = <EnemyId>[];
  final List<Facing> facing = <Facing>[];

  void add(EntityId entity, EnemyDef def) {
    final i = addEntity(entity);
    enemyId[i] = def.enemyId;
    facing[i] = def.facing;
  }

  @override
  void onDenseAdded(int denseIndex) {
    enemyId.add(EnemyId.unocoDemon);
    facing.add(Facing.left);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    enemyId[removeIndex] = enemyId[lastIndex];
    facing[removeIndex] = facing[lastIndex];

    enemyId.removeLast();
    facing.removeLast();
  }
}

