import '../entity_id.dart';

/// Tracks per-entity parry consumption for the current activation.
/// We key by the active-ability startTick, so re-activations reset automatically.
class ParryConsumeStore {
  final List<EntityId> denseEntities = <EntityId>[];
  final Map<EntityId, int> _sparse = <EntityId, int>{};

  /// Last parry activation startTick consumed.
  final List<int> consumedStartTick = <int>[];

  bool has(EntityId e) => _sparse.containsKey(e);

  int? tryIndexOf(EntityId e) => _sparse[e];

  int indexOfOrAdd(EntityId e) {
    final existing = _sparse[e];
    if (existing != null) return existing;
    final i = denseEntities.length;
    denseEntities.add(e);
    _sparse[e] = i;
    consumedStartTick.add(-1);
    return i;
  }

  void removeEntity(EntityId e) {
    final i = _sparse.remove(e);
    if (i == null) return;
    final last = denseEntities.length - 1;
    if (i != last) {
      final moved = denseEntities[last];
      denseEntities[i] = moved;
      _sparse[moved] = i;
      consumedStartTick[i] = consumedStartTick[last];
    }
    denseEntities.removeLast();
    consumedStartTick.removeLast();
  }
}
