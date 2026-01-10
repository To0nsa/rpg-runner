import '../../entity_id.dart';
import '../../sparse_set.dart';

/// Tracks the last action intent ticks for animation selection.
class ActionAnimStore extends SparseSet {
  final List<int> lastMeleeTick = <int>[];
  final List<int> lastCastTick = <int>[];

  void add(EntityId entity) {
    addEntity(entity);
  }

  @override
  void onDenseAdded(int denseIndex) {
    lastMeleeTick.add(-1);
    lastCastTick.add(-1);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    lastMeleeTick[removeIndex] = lastMeleeTick[lastIndex];
    lastCastTick[removeIndex] = lastCastTick[lastIndex];

    lastMeleeTick.removeLast();
    lastCastTick.removeLast();
  }
}
