import '../../entity_id.dart';
import '../../sparse_set.dart';

/// Engagement intent for melee enemies (desired slot + movement modifiers).
class EngagementIntentStore extends SparseSet {
  /// Resolved horizontal attack range, shared by engagement and locomotion.
  final List<double> meleeRangeX = [];

  /// Desired target X for locomotion when not following a nav plan.
  final List<double> desiredTargetX = <double>[];

  /// Arrival slow radius used to dampen speed near the slot.
  final List<double> arrivalSlowRadiusX = <double>[];

  /// Speed multiplier for the current engagement state.
  final List<double> stateSpeedMul = <double>[];

  /// Speed scale to apply when chasing without a nav plan.
  final List<double> speedScale = <double>[];

  void add(EntityId entity) {
    final i = addEntity(entity);
    meleeRangeX[i] = 0;
    desiredTargetX[i] = 0.0;
    arrivalSlowRadiusX[i] = 0.0;
    stateSpeedMul[i] = 1.0;
    speedScale[i] = 1.0;
  }

  @override
  void onDenseAdded(int denseIndex) {
    meleeRangeX.add(0);
    desiredTargetX.add(0.0);
    arrivalSlowRadiusX.add(0.0);
    stateSpeedMul.add(1.0);
    speedScale.add(1.0);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    meleeRangeX[removeIndex] = meleeRangeX[lastIndex];
    desiredTargetX[removeIndex] = desiredTargetX[lastIndex];
    arrivalSlowRadiusX[removeIndex] = arrivalSlowRadiusX[lastIndex];
    stateSpeedMul[removeIndex] = stateSpeedMul[lastIndex];
    speedScale[removeIndex] = speedScale[lastIndex];

    meleeRangeX.removeLast();
    desiredTargetX.removeLast();
    arrivalSlowRadiusX.removeLast();
    stateSpeedMul.removeLast();
    speedScale.removeLast();
  }
}
