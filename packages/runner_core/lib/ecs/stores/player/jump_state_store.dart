import '../../entity_id.dart';
import '../../sparse_set.dart';

/// Per-entity jump runtime state (forgiveness + air-jump tracking).
///
/// This store is consumed by [JumpSystem] and intentionally keeps jump-only
/// counters out of generic movement state.
class JumpStateStore extends SparseSet {
  /// Remaining ticks of coyote-time grace.
  final List<int> coyoteTicksLeft = <int>[];

  /// Remaining ticks of buffered jump input.
  final List<int> jumpBufferTicksLeft = <int>[];

  /// Number of airborne jumps used since last grounded tick.
  final List<int> airJumpsUsed = <int>[];

  void add(EntityId entity) {
    addEntity(entity);
  }

  @override
  void onDenseAdded(int denseIndex) {
    coyoteTicksLeft.add(0);
    jumpBufferTicksLeft.add(0);
    airJumpsUsed.add(0);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    coyoteTicksLeft[removeIndex] = coyoteTicksLeft[lastIndex];
    jumpBufferTicksLeft[removeIndex] = jumpBufferTicksLeft[lastIndex];
    airJumpsUsed[removeIndex] = airJumpsUsed[lastIndex];

    coyoteTicksLeft.removeLast();
    jumpBufferTicksLeft.removeLast();
    airJumpsUsed.removeLast();
  }
}
