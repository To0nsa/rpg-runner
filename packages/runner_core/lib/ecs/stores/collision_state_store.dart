import '../entity_id.dart';
import '../sparse_set.dart';

/// Per-tick collision results for an entity.
///
/// Terrain motion resets and publishes these directional convenience flags.
/// They describe *physical* blocking, not combat hits, and do not select or
/// duplicate terrain authority.
class CollisionStateStore extends SparseSet {
  final List<bool> grounded = <bool>[];
  final List<bool> hitCeiling = <bool>[];
  final List<bool> hitLeft = <bool>[];
  final List<bool> hitRight = <bool>[];

  void add(EntityId entity) {
    addEntity(entity);
  }

  void resetTick(EntityId entity) {
    final i = indexOf(entity);
    grounded[i] = false;
    hitCeiling[i] = false;
    hitLeft[i] = false;
    hitRight[i] = false;
  }

  @override
  void onDenseAdded(int denseIndex) {
    grounded.add(false);
    hitCeiling.add(false);
    hitLeft.add(false);
    hitRight.add(false);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    grounded[removeIndex] = grounded[lastIndex];
    hitCeiling[removeIndex] = hitCeiling[lastIndex];
    hitLeft[removeIndex] = hitLeft[lastIndex];
    hitRight[removeIndex] = hitRight[lastIndex];

    grounded.removeLast();
    hitCeiling.removeLast();
    hitLeft.removeLast();
    hitRight.removeLast();
  }
}
