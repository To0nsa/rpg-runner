import 'entity_id.dart';

/// Base sparse-set bookkeeping for component stores.
///
/// - `sparse[entity]` stores (denseIndex + 1), or 0 when absent.
/// - `denseEntities[denseIndex]` stores the owning [EntityId].
///
/// This enables:
/// - O(1) contains
/// - O(1) add/remove (swap-remove)
/// - cache-friendly iteration over `denseEntities`
abstract class SparseSet {
  final List<EntityId> denseEntities = <EntityId>[];
  final List<int> _sparse = <int>[];

  bool has(EntityId entity) {
    if (entity < 0) return false;
    if (entity >= _sparse.length) return false;
    return _sparse[entity] != 0;
  }

  int indexOf(EntityId entity) {
    final idxPlus1 = _sparse[entity];
    return idxPlus1 - 1;
  }

  int? tryIndexOf(EntityId entity) {
    if (!has(entity)) return null;
    return indexOf(entity);
  }

  void ensureCapacity(EntityId entity) {
    if (entity < _sparse.length) return;
    final toAdd = entity + 1 - _sparse.length;
    if (toAdd <= 0) return;
    _sparse.addAll(List<int>.filled(toAdd, 0));
  }

  int addEntity(EntityId entity) {
    ensureCapacity(entity);
    final existing = _sparse[entity];
    if (existing != 0) return existing - 1;

    final denseIndex = denseEntities.length;
    denseEntities.add(entity);
    _sparse[entity] = denseIndex + 1;
    onDenseAdded(denseIndex);
    return denseIndex;
  }

  void removeEntity(EntityId entity) {
    if (!has(entity)) return;

    final removeIndex = indexOf(entity);
    final lastIndex = denseEntities.length - 1;

    onSwapRemove(removeIndex, lastIndex);

    final lastEntity = denseEntities[lastIndex];
    denseEntities[removeIndex] = lastEntity;
    denseEntities.removeLast();

    _sparse[entity] = 0;
    if (removeIndex != lastIndex) {
      _sparse[lastEntity] = removeIndex + 1;
    }
  }

  /// Called after a new dense slot has been appended.
  void onDenseAdded(int denseIndex);

  /// Called before dense arrays are swap-removed from [removeIndex] and [lastIndex].
  void onSwapRemove(int removeIndex, int lastIndex);
}
