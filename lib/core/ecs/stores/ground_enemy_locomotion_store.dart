import '../entity_id.dart';
import '../sparse_set.dart';

class GroundEnemyLocomotionStore extends SparseSet {
  final List<int> jumpCooldownTicksLeft = <int>[];

  void add(EntityId entity) {
    final i = addEntity(entity);
    jumpCooldownTicksLeft[i] = 0;
  }

  @override
  void onDenseAdded(int denseIndex) {
    jumpCooldownTicksLeft.add(0);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    jumpCooldownTicksLeft[removeIndex] = jumpCooldownTicksLeft[lastIndex];
    jumpCooldownTicksLeft.removeLast();
  }
}
