import '../sparse_set.dart';

/// Marks invulnerability installed by the arena so release preserves other owners.
/// Entity destruction clears ownership before the entity ID can be reused.
class ArenaProtectionStore extends SparseSet {
  @override
  void onDenseAdded(int denseIndex) {}
  @override
  void onSwapRemove(int removeIndex, int lastIndex) {}
}
