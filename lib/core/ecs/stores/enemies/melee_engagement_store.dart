import '../../entity_id.dart';
import '../../sparse_set.dart';

/// Engagement state for melee-focused enemies.
///
/// Keeps lightweight state so AI can avoid oscillating around the target and
/// apply different movement rules during attack/recover windows.
class MeleeEngagementStore extends SparseSet {
  /// Current engagement state.
  final List<MeleeEngagementState> state = <MeleeEngagementState>[];

  /// Remaining ticks in the current state (used for attack/recover windows).
  final List<int> ticksLeft = <int>[];

  /// Preferred side relative to the target (+1 right, -1 left, 0 unset).
  final List<int> preferredSide = <int>[];

  void add(EntityId entity) {
    final i = addEntity(entity);
    state[i] = MeleeEngagementState.approach;
    ticksLeft[i] = 0;
    preferredSide[i] = 0;
  }

  @override
  void onDenseAdded(int denseIndex) {
    state.add(MeleeEngagementState.approach);
    ticksLeft.add(0);
    preferredSide.add(0);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    state[removeIndex] = state[lastIndex];
    ticksLeft[removeIndex] = ticksLeft[lastIndex];
    preferredSide[removeIndex] = preferredSide[lastIndex];

    state.removeLast();
    ticksLeft.removeLast();
    preferredSide.removeLast();
  }
}

enum MeleeEngagementState {
  approach,
  engage,
  attack,
  recover,
}
