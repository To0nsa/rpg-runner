import 'entity_id.dart';

/// Base sparse-set bookkeeping for component stores.
///
/// A sparse set is a data structure that efficiently maps a potentially sparse range
/// of integers (the entity IDs) to a dense, contiguous array of data.
///
/// Internally, it maintains two lists:
/// - `_sparse`: An array indexed by [EntityId]. `_sparse[entity]` stores the
///   index into `denseEntities` plus 1 (0 indicates the entity is not present).
/// - `denseEntities`: A list of [EntityId]s packed contiguously. This allows for
///   fast iteration over all entities that possess this component.
///
/// Subclasses (Component Stores) will maintain their own component data in parallel
/// arrays, also indexed by the values stored in `_sparse` (the "dense index").
///
/// Capabilities:
/// - O(1) membership check (`has`).
/// - O(1) lookup of component data index (`indexOf`).
/// - O(1) insertion (`addEntity`).
/// - O(1) removal (`removeEntity`) using the "swap-and-pop" technique.
/// - Cache-friendly iteration over `denseEntities`.
abstract class SparseSet {
  /// The list of entities that have this component, packed densely.
  /// Iterating this list is the standard way to process all components of this type.
  final List<EntityId> denseEntities = <EntityId>[];

  /// The sparse array mapping EntityId to (denseIndex + 1).
  /// A value of 0 means the entity does not have this component.
  final List<int> _sparse = <int>[];

  /// Returns true if [entity] has this component.
  bool has(EntityId entity) {
    if (entity < 0) return false;
    if (entity >= _sparse.length) return false;
    return _sparse[entity] != 0;
  }

  /// Returns the dense index for [entity].
  ///
  /// Throws if the entity does not have this component. Use [has] or [tryIndexOf] to check.
  int indexOf(EntityId entity) {
    final idxPlus1 = _sparse[entity];
    return idxPlus1 - 1;
  }

  /// Returns the dense index for [entity], or null if it doesn't have this component.
  int? tryIndexOf(EntityId entity) {
    if (entity < 0 || entity >= _sparse.length) return null;
    final idxPlus1 = _sparse[entity];
    if (idxPlus1 == 0) return null;
    return idxPlus1 - 1;
  }

  /// Ensures the internal sparse array is large enough to hold [entity].
  void ensureCapacity(EntityId entity) {
    if (entity < _sparse.length) return;
    final toAdd = entity + 1 - _sparse.length;
    if (toAdd <= 0) return;
    _sparse.addAll(List<int>.filled(toAdd, 0));
  }

  /// Registers [entity] with this store.
  ///
  /// Returns the new stable dense index for this entity's component data.
  /// If the entity is already present, returns its existing dense index.
  ///
  /// Subclasses should call this first, then add their data to their parallel arrays.
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

  /// Removes [entity] from this store.
  ///
  /// Uses "swap-and-pop" to remove in O(1):
  /// 1. The component data for the entity to be removed is swapped with the
  ///    last component in the dense arrays.
  /// 2. The mapping in `_sparse` for the swapped entity is updated.
  /// 3. The last element is removed (popped).
  ///
  /// This operation changes the dense index of the entity that was at the end.
  void removeEntity(EntityId entity) {
    if (!has(entity)) return;

    final removeIndex = indexOf(entity);
    final lastIndex = denseEntities.length - 1;

    // Hook for subclasses to swap their data arrays before we modify indices.
    onSwapRemove(removeIndex, lastIndex);

    final lastEntity = denseEntities[lastIndex];
    denseEntities[removeIndex] = lastEntity;
    denseEntities.removeLast();

    _sparse[entity] = 0;
    if (removeIndex != lastIndex) {
      // Update the sparse map for the entity that was moved into the empty slot.
      _sparse[lastEntity] = removeIndex + 1;
    }
  }

  /// Called after a new dense slot has been appended.
  /// Subclasses should rely on this to know when a valid index has been established,
  /// though usually they just push data to their lists.
  void onDenseAdded(int denseIndex);

  /// Called before dense arrays are swap-removed from [removeIndex] and [lastIndex].
  ///
  /// Subclasses MUST perform the swap on their parallel data lists inside this method:
  /// `dataList[removeIndex] = dataList[lastIndex]; dataList.removeLast();`
  void onSwapRemove(int removeIndex, int lastIndex);
}
