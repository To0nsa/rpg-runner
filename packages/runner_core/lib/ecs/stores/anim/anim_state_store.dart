import '../../../snapshots/enums.dart';
import '../../entity_id.dart';
import '../../sparse_set.dart';

/// Per-entity animation state computed by [AnimSystem].
class AnimStateStore extends SparseSet {
  /// Current animation key (idle, run, hit, death, etc.).
  final List<AnimKey> anim = <AnimKey>[];

  /// Frame offset for the current animation (ticks since anim start).
  final List<int> animFrame = <int>[];

  /// Fixed-point phase for terrain-grounded walk/run loops.
  ///
  /// `10000` units equal one authored animation tick. This phase is paused
  /// outside walk/run and survives transitions between those two loops.
  final List<int> groundedLocomotionPhaseBp = <int>[];

  /// Snapshot-only dash continuation. Combat keeps using [anim]/[animFrame].
  /// Start ticks identify activations; a negative frame disables presentation.
  final List<int> dashVisualStartTick = <int>[];
  final List<int> dashVisualRecoveryStartTick = <int>[];
  final List<int> dashVisualFrame = <int>[];

  void clearDashVisual(int index) {
    // Retain the activation identity so an interrupted dash cannot re-arm.
    dashVisualFrame[index] = -1;
    dashVisualRecoveryStartTick[index] = -1;
  }

  void add(EntityId entity) {
    final i = addEntity(entity);
    anim[i] = AnimKey.idle;
    animFrame[i] = 0;
    dashVisualStartTick[i] = -1;
    clearDashVisual(i);
  }

  @override
  void onDenseAdded(int denseIndex) {
    anim.add(AnimKey.idle);
    animFrame.add(0);
    groundedLocomotionPhaseBp.add(0);
    dashVisualStartTick.add(-1);
    dashVisualRecoveryStartTick.add(-1);
    dashVisualFrame.add(-1);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    anim[removeIndex] = anim[lastIndex];
    animFrame[removeIndex] = animFrame[lastIndex];
    groundedLocomotionPhaseBp[removeIndex] =
        groundedLocomotionPhaseBp[lastIndex];
    dashVisualStartTick[removeIndex] = dashVisualStartTick[lastIndex];
    dashVisualRecoveryStartTick[removeIndex] =
        dashVisualRecoveryStartTick[lastIndex];
    dashVisualFrame[removeIndex] = dashVisualFrame[lastIndex];

    anim.removeLast();
    animFrame.removeLast();
    groundedLocomotionPhaseBp.removeLast();
    dashVisualStartTick.removeLast();
    dashVisualRecoveryStartTick.removeLast();
    dashVisualFrame.removeLast();
  }
}
