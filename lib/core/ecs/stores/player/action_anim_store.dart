import '../../entity_id.dart';
import '../../../snapshots/enums.dart';
import '../../sparse_set.dart';

/// Tracks the last action intent ticks for animation selection.
class ActionAnimStore extends SparseSet {
  final List<int> lastMeleeTick = <int>[];
  final List<Facing> lastMeleeFacing = <Facing>[];
  final List<int> lastCastTick = <int>[];

  void add(EntityId entity) {
    addEntity(entity);
  }

  @override
  void onDenseAdded(int denseIndex) {
    lastMeleeTick.add(-1);
    lastMeleeFacing.add(Facing.right);
    lastCastTick.add(-1);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    lastMeleeTick[removeIndex] = lastMeleeTick[lastIndex];
    lastMeleeFacing[removeIndex] = lastMeleeFacing[lastIndex];
    lastCastTick[removeIndex] = lastCastTick[lastIndex];

    lastMeleeTick.removeLast();
    lastMeleeFacing.removeLast();
    lastCastTick.removeLast();
  }
}
