import '../entity_id.dart';
import '../sparse_set.dart';

class CollectibleDef {
  const CollectibleDef({required this.value});

  final int value;
}

/// SoA store for collectible metadata.
class CollectibleStore extends SparseSet {
  final List<int> value = <int>[];

  void add(EntityId entity, CollectibleDef def) {
    final i = addEntity(entity);
    value[i] = def.value;
  }

  @override
  void onDenseAdded(int denseIndex) {
    value.add(0);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    value[removeIndex] = value[lastIndex];
    value.removeLast();
  }
}
