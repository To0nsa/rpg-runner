import '../../entity_id.dart';
import '../../../snapshots/enums.dart';
import '../../sparse_set.dart';

/// Tracks the last action intent ticks for animation selection.
class ActionAnimStore extends SparseSet {
  final List<int> lastMeleeTick = <int>[];
  final List<Facing> lastMeleeFacing = <Facing>[];
  final List<int> lastCastTick = <int>[];
  final List<int> lastRangedTick = <int>[];
  final List<Facing> lastRangedFacing = <Facing>[];

  void add(EntityId entity) {
    addEntity(entity);
  }

  @override
  void onDenseAdded(int denseIndex) {
    lastMeleeTick.add(-1);
    lastMeleeFacing.add(Facing.right);
    lastCastTick.add(-1);
    lastRangedTick.add(-1);
    lastRangedFacing.add(Facing.right);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    lastMeleeTick[removeIndex] = lastMeleeTick[lastIndex];
    lastMeleeFacing[removeIndex] = lastMeleeFacing[lastIndex];
    lastCastTick[removeIndex] = lastCastTick[lastIndex];
    lastRangedTick[removeIndex] = lastRangedTick[lastIndex];
    lastRangedFacing[removeIndex] = lastRangedFacing[lastIndex];

    lastMeleeTick.removeLast();
    lastMeleeFacing.removeLast();
    lastCastTick.removeLast();
    lastRangedTick.removeLast();
    lastRangedFacing.removeLast();
  }
}
