import '../entity_id.dart';
import '../sparse_set.dart';

/// Encounter lifecycle state removed automatically when its entity is destroyed.
class BossSummonStore extends SparseSet {
  final List<EntityId> owner = [];
  final List<int> expiresTick = [];
  @override
  void onDenseAdded(int denseIndex) {
    owner.add(-1);
    expiresTick.add(-1);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    owner[removeIndex] = owner[lastIndex];
    owner.removeLast();
    expiresTick[removeIndex] = expiresTick[lastIndex];
    expiresTick.removeLast();
  }
}
