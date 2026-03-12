import '../entity_id.dart';

/// Cooldown ledger for reactive procs keyed by owner entity + proc key.
///
/// Proc keys are authored/system-generated stable integers per reactive proc
/// definition (for example: weaponId + procIndex).
class ReactiveProcCooldownStore {
  final List<EntityId> owner = <EntityId>[];
  final List<int> procKey = <int>[];
  final List<int> readyTick = <int>[];
  final Map<int, int> _indexByCompositeKey = <int, int>{};

  /// Returns true when the proc is still cooling down at [currentTick].
  bool isOnCooldown({
    required EntityId entity,
    required int key,
    required int currentTick,
  }) {
    final idx = _indexByCompositeKey[_composite(entity, key)];
    if (idx == null) return false;
    return readyTick[idx] > currentTick;
  }

  /// Starts/refreshes cooldown with max semantics (never shortens existing).
  void startCooldown({
    required EntityId entity,
    required int key,
    required int currentTick,
    required int durationTicks,
  }) {
    if (durationTicks <= 0) return;
    final readyAt = currentTick + durationTicks;
    final composite = _composite(entity, key);
    final existing = _indexByCompositeKey[composite];
    if (existing != null) {
      if (readyAt > readyTick[existing]) {
        readyTick[existing] = readyAt;
      }
      return;
    }

    final idx = owner.length;
    owner.add(entity);
    procKey.add(key);
    readyTick.add(readyAt);
    _indexByCompositeKey[composite] = idx;
  }

  /// Removes all cooldown entries for [entity].
  void removeEntity(EntityId entity) {
    for (var i = owner.length - 1; i >= 0; i -= 1) {
      if (owner[i] != entity) continue;
      _removeAt(i);
    }
  }

  void _removeAt(int index) {
    final last = owner.length - 1;
    final removeComposite = _composite(owner[index], procKey[index]);
    _indexByCompositeKey.remove(removeComposite);

    if (index != last) {
      owner[index] = owner[last];
      procKey[index] = procKey[last];
      readyTick[index] = readyTick[last];

      final movedComposite = _composite(owner[index], procKey[index]);
      _indexByCompositeKey[movedComposite] = index;
    }

    owner.removeLast();
    procKey.removeLast();
    readyTick.removeLast();
  }

  int _composite(EntityId entity, int key) => (entity << 32) ^ key;
}
