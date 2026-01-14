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
  final List<int> lastMeleeTick = <int>[];
  final List<Facing> lastMeleeFacing = <Facing>[];
  final List<int> lastMeleeAnimTicks = <int>[];

  void add(EntityId entity, EnemyDef def) {
    final i = addEntity(entity);
    enemyId[i] = def.enemyId;
    facing[i] = def.facing;
    lastMeleeTick[i] = -1;
    lastMeleeFacing[i] = def.facing;
    lastMeleeAnimTicks[i] = 0;
  }

  @override
  void onDenseAdded(int denseIndex) {
    enemyId.add(EnemyId.unocoDemon);
    facing.add(Facing.left);
    lastMeleeTick.add(-1);
    lastMeleeFacing.add(Facing.left);
    lastMeleeAnimTicks.add(0);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    enemyId[removeIndex] = enemyId[lastIndex];
    facing[removeIndex] = facing[lastIndex];
    lastMeleeTick[removeIndex] = lastMeleeTick[lastIndex];
    lastMeleeFacing[removeIndex] = lastMeleeFacing[lastIndex];
    lastMeleeAnimTicks[removeIndex] = lastMeleeAnimTicks[lastIndex];

    enemyId.removeLast();
    facing.removeLast();
    lastMeleeTick.removeLast();
    lastMeleeFacing.removeLast();
    lastMeleeAnimTicks.removeLast();
  }
}

