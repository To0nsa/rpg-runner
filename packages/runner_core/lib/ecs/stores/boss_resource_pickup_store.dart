import '../sparse_set.dart';

/// Pickups owned by the single active boss arena, cleared when combat ends.
/// Destruction removes this marker before an entity ID can be recycled.
final class BossResourcePickupStore extends SparseSet {
  @override
  void onDenseAdded(int denseIndex) {}

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {}
}
