import '../../abilities/ability_def.dart';
import '../entity_id.dart';
import '../sparse_set.dart';

/// Per-entity authoritative charge state derived from slot hold transitions.
///
/// Charge is tracked in simulation ticks only. UI/client timers are advisory;
/// authoritative commit-time charge comes from this store.
class AbilityChargeStateStore extends SparseSet {
  static final int slotCount = AbilitySlot.values.length;

  /// Bitmask for current hold state by slot.
  final List<int> heldMask = <int>[];

  /// Per-slot hold start tick (flattened: denseIndex * slotCount + slot.index).
  final List<int> holdStartTickBySlot = <int>[];

  /// Per-slot current hold duration in ticks while held.
  final List<int> currentHoldTicksBySlot = <int>[];

  /// Per-slot hold duration captured on the most recent release transition.
  final List<int> releasedHoldTicksBySlot = <int>[];

  /// Tick when [releasedHoldTicksBySlot] was captured; `-1` if none.
  final List<int> releasedTickBySlot = <int>[];

  /// Bitmask of slots whose charge hold timed out and was auto-canceled.
  ///
  /// Cleared when a new hold-start edge is processed for the slot.
  final List<int> canceledMask = <int>[];

  void add(EntityId entity) {
    addEntity(entity);
  }

  bool slotHeld(EntityId entity, AbilitySlot slot) {
    if (!has(entity)) return false;
    final denseIndex = indexOf(entity);
    final bit = 1 << slot.index;
    return (heldMask[denseIndex] & bit) != 0;
  }

  int currentHoldTicks(EntityId entity, AbilitySlot slot) {
    if (!has(entity)) return 0;
    return currentHoldTicksBySlot[_slotOffset(indexOf(entity), slot)];
  }

  /// Returns authoritative commit charge ticks when available.
  ///
  /// - While held: current hold duration.
  /// - On release tick: released hold duration.
  /// - Otherwise: `-1` (no authoritative charge sample for this commit).
  int commitChargeTicksOrUntracked(
    EntityId entity, {
    required AbilitySlot slot,
    required int currentTick,
  }) {
    if (!has(entity)) return -1;
    final denseIndex = indexOf(entity);
    final offset = _slotOffset(denseIndex, slot);
    if (slotHeld(entity, slot)) {
      return currentHoldTicksBySlot[offset];
    }
    if (releasedTickBySlot[offset] == currentTick) {
      return releasedHoldTicksBySlot[offset];
    }
    return -1;
  }

  int slotOffsetForDenseIndex(int denseIndex, AbilitySlot slot) {
    return _slotOffset(denseIndex, slot);
  }

  bool slotChargeCanceled(EntityId entity, AbilitySlot slot) {
    if (!has(entity)) return false;
    final denseIndex = indexOf(entity);
    final bit = 1 << slot.index;
    return (canceledMask[denseIndex] & bit) != 0;
  }

  void setSlotChargeCanceled(
    EntityId entity, {
    required AbilitySlot slot,
    required bool canceled,
  }) {
    if (!has(entity)) return;
    final denseIndex = indexOf(entity);
    final bit = 1 << slot.index;
    if (canceled) {
      canceledMask[denseIndex] |= bit;
    } else {
      canceledMask[denseIndex] &= ~bit;
    }
  }

  int _slotOffset(int denseIndex, AbilitySlot slot) {
    return denseIndex * slotCount + slot.index;
  }

  @override
  void onDenseAdded(int denseIndex) {
    heldMask.add(0);
    canceledMask.add(0);
    for (var i = 0; i < slotCount; i += 1) {
      holdStartTickBySlot.add(-1);
      currentHoldTicksBySlot.add(0);
      releasedHoldTicksBySlot.add(0);
      releasedTickBySlot.add(-1);
    }
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    heldMask[removeIndex] = heldMask[lastIndex];
    canceledMask[removeIndex] = canceledMask[lastIndex];

    final removeBase = removeIndex * slotCount;
    final lastBase = lastIndex * slotCount;
    for (var i = 0; i < slotCount; i += 1) {
      holdStartTickBySlot[removeBase + i] = holdStartTickBySlot[lastBase + i];
      currentHoldTicksBySlot[removeBase + i] =
          currentHoldTicksBySlot[lastBase + i];
      releasedHoldTicksBySlot[removeBase + i] =
          releasedHoldTicksBySlot[lastBase + i];
      releasedTickBySlot[removeBase + i] = releasedTickBySlot[lastBase + i];
    }

    heldMask.removeLast();
    canceledMask.removeLast();
    holdStartTickBySlot.removeRange(lastBase, lastBase + slotCount);
    currentHoldTicksBySlot.removeRange(lastBase, lastBase + slotCount);
    releasedHoldTicksBySlot.removeRange(lastBase, lastBase + slotCount);
    releasedTickBySlot.removeRange(lastBase, lastBase + slotCount);
  }
}
