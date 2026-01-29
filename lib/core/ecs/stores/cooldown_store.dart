import '../../abilities/ability_def.dart';
import '../entity_id.dart';
import '../sparse_set.dart';

/// Tracks ability cooldowns by group index.
///
/// Each entity has [kMaxCooldownGroups] cooldown slots (default 8).
/// Abilities sharing a group share a cooldown.
///
/// **SoA Layout**: `ticksLeft[entityIndex * kMaxCooldownGroups + groupId]`
class CooldownStore extends SparseSet {
  /// Ticks remaining per group.
  /// Access via: ticksLeft[entityIndex * kMaxCooldownGroups + groupId]
  final List<int> _ticksLeft = <int>[];

  /// Ensures entity has this component. Idempotent.
  void ensure(EntityId entity) {
    if (!has(entity)) {
      addEntity(entity);
    }
  }

  /// Strict add — asserts entity is NOT already present.
  void add(EntityId entity) {
    assert(!has(entity), 'Entity $entity already has CooldownStore');
    addEntity(entity);
  }

  /// Resets all cooldowns for entity to 0.
  void reset(EntityId entity) {
    if (!has(entity)) return;
    final i = indexOf(entity);
    for (var g = 0; g < kMaxCooldownGroups; g++) {
      _ticksLeft[i * kMaxCooldownGroups + g] = 0;
    }
  }

  /// Gets ticks remaining for a specific cooldown group.
  int getTicksLeft(EntityId entity, int groupId) {
    assert(
      groupId >= 0 && groupId < kMaxCooldownGroups,
      'Group ID must be in range [0, $kMaxCooldownGroups)',
    );
    if (!has(entity)) return 0;
    final i = indexOf(entity);
    return _ticksLeft[i * kMaxCooldownGroups + groupId];
  }

  /// Sets ticks remaining for a specific cooldown group.
  void setTicksLeft(EntityId entity, int groupId, int ticks) {
    assert(
      groupId >= 0 && groupId < kMaxCooldownGroups,
      'Group ID must be in range [0, $kMaxCooldownGroups)',
    );
    assert(has(entity), 'Entity $entity missing CooldownStore');
    final i = indexOf(entity);
    _ticksLeft[i * kMaxCooldownGroups + groupId] = ticks;
  }

  /// Starts a cooldown for the given group.
  void startCooldown(EntityId entity, int groupId, int durationTicks) {
    setTicksLeft(entity, groupId, durationTicks);
  }

  /// Checks if a cooldown group is active (ticks remaining > 0).
  bool isOnCooldown(EntityId entity, int groupId) {
    return getTicksLeft(entity, groupId) > 0;
  }

  /// Decrements all cooldowns by 1 tick for all entities.
  /// Called by CooldownSystem each tick.
  void tickAll() {
    final count = denseEntities.length;
    for (var i = 0; i < count; i++) {
      for (var g = 0; g < kMaxCooldownGroups; g++) {
        final idx = i * kMaxCooldownGroups + g;
        if (_ticksLeft[idx] > 0) {
          _ticksLeft[idx] -= 1;
        }
      }
    }
  }

  // SparseSet overrides
  // ---------------------------------------------------------------------------

  @override
  void onDenseAdded(int denseIndex) {
    // Add kMaxCooldownGroups slots for new entity, all initialized to 0
    for (var g = 0; g < kMaxCooldownGroups; g++) {
      _ticksLeft.add(0);
    }
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    // Swap all group slots
    for (var g = 0; g < kMaxCooldownGroups; g++) {
      final ri = removeIndex * kMaxCooldownGroups + g;
      final li = lastIndex * kMaxCooldownGroups + g;
      _ticksLeft[ri] = _ticksLeft[li];
    }
    // Remove last kMaxCooldownGroups entries
    _ticksLeft.length -= kMaxCooldownGroups;
  }
}
