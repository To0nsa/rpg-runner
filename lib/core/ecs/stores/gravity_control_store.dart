import '../entity_id.dart';
import '../sparse_set.dart';

class GravityControlStore extends SparseSet {
  final List<int> suppressGravityTicksLeft = <int>[];

  void setSuppressForTicks(EntityId entity, int ticks) {
    if (ticks <= 0) {
      removeEntity(entity);
      return;
    }

    final i = addEntity(entity);
    suppressGravityTicksLeft[i] = ticks;
  }

  @override
  void onDenseAdded(int denseIndex) {
    suppressGravityTicksLeft.add(0);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    suppressGravityTicksLeft[removeIndex] = suppressGravityTicksLeft[lastIndex];
    suppressGravityTicksLeft.removeLast();
  }
}
