import '../../entity_id.dart';
import '../../sparse_set.dart';

/// Engagement state for melee-focused enemies.
///
/// Keeps lightweight state so AI can avoid oscillating around the target and
/// apply different movement rules during strike/recover windows.
class MeleeEngagementStore extends SparseSet {
  /// Current engagement state.
  final List<MeleeEngagementState> state = <MeleeEngagementState>[];

  /// Remaining ticks in the current state (used for strike/recover windows).
  final List<int> ticksLeft = <int>[];

  /// Preferred side relative to the target (+1 right, -1 left, 0 unset).
  final List<int> preferredSide = <int>[];

  /// Tick when the current strike started (edge-trigger).
  ///
  /// Used to start telegraph animations once and schedule future hit ticks.
  final List<int> strikeStartTick = <int>[];

  /// Tick when the melee hitbox should spawn for the current strike.
  final List<int> plannedHitTick = <int>[];

  void add(EntityId entity) {
    final i = addEntity(entity);
    state[i] = MeleeEngagementState.approach;
    ticksLeft[i] = 0;
    preferredSide[i] = 0;
    strikeStartTick[i] = -1;
    plannedHitTick[i] = -1;
  }

  @override
  void onDenseAdded(int denseIndex) {
    state.add(MeleeEngagementState.approach);
    ticksLeft.add(0);
    preferredSide.add(0);
    strikeStartTick.add(-1);
    plannedHitTick.add(-1);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    state[removeIndex] = state[lastIndex];
    ticksLeft[removeIndex] = ticksLeft[lastIndex];
    preferredSide[removeIndex] = preferredSide[lastIndex];
    strikeStartTick[removeIndex] = strikeStartTick[lastIndex];
    plannedHitTick[removeIndex] = plannedHitTick[lastIndex];

    state.removeLast();
    ticksLeft.removeLast();
    preferredSide.removeLast();
    strikeStartTick.removeLast();
    plannedHitTick.removeLast();
  }
}

enum MeleeEngagementState {
  approach,
  engage,
  strike,
  recover,
}
