import '../entity_id.dart';
import '../sparse_set.dart';

class DemonSteeringDef {
  const DemonSteeringDef({
    required this.rngState,
  });

  final int rngState;
}

/// Per-demon steering state for deterministic hover behavior.
class DemonSteeringStore extends SparseSet {
  final List<int> rngState = <int>[];
  final List<bool> initialized = <bool>[];
  final List<double> desiredRange = <double>[];
  final List<double> desiredRangeHoldLeftS = <double>[];
  final List<double> flightTargetAboveGround = <double>[];
  final List<double> flightTargetHoldLeftS = <double>[];

  void add(EntityId entity, DemonSteeringDef def) {
    final i = addEntity(entity);
    rngState[i] = def.rngState;
    initialized[i] = false;
    desiredRange[i] = 0.0;
    desiredRangeHoldLeftS[i] = 0.0;
    flightTargetAboveGround[i] = 0.0;
    flightTargetHoldLeftS[i] = 0.0;
  }

  @override
  void onDenseAdded(int denseIndex) {
    rngState.add(1);
    initialized.add(false);
    desiredRange.add(0.0);
    desiredRangeHoldLeftS.add(0.0);
    flightTargetAboveGround.add(0.0);
    flightTargetHoldLeftS.add(0.0);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    rngState[removeIndex] = rngState[lastIndex];
    initialized[removeIndex] = initialized[lastIndex];
    desiredRange[removeIndex] = desiredRange[lastIndex];
    desiredRangeHoldLeftS[removeIndex] = desiredRangeHoldLeftS[lastIndex];
    flightTargetAboveGround[removeIndex] = flightTargetAboveGround[lastIndex];
    flightTargetHoldLeftS[removeIndex] = flightTargetHoldLeftS[lastIndex];

    rngState.removeLast();
    initialized.removeLast();
    desiredRange.removeLast();
    desiredRangeHoldLeftS.removeLast();
    flightTargetAboveGround.removeLast();
    flightTargetHoldLeftS.removeLast();
  }
}
