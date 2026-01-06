import '../../entity_id.dart';
import '../../sparse_set.dart';

/// Tracks entities that are temporarily ignoring global gravity.
///
/// Used by movement skills (e.g. Dash) to keep the player straight.
/// Entities are removed from this store when `suppressGravityTicksLeft` hits 0.
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
