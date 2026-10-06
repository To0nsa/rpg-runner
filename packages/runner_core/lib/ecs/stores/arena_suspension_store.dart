import '../sparse_set.dart';

/// Actors outside the current boss roster retain identity but cannot interfere.
/// Registration with EcsWorld also clears suspension before entity IDs recycle.
class ArenaSuspensionStore extends SparseSet {
  @override
  void onDenseAdded(int denseIndex) {}
  @override
  void onSwapRemove(int removeIndex, int lastIndex) {}
}
