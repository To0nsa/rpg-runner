import '../../entity_id.dart';
import '../../sparse_set.dart';

class FlyingEnemySteeringDef {
  const FlyingEnemySteeringDef({
    required this.rngState,
  });

  final int rngState;
}

/// Per flying enemy steering state for deterministic hover behavior.
///
/// Holds RNG state and smoothed target ranges to make enemies wobble nicely.
class FlyingEnemySteeringStore extends SparseSet {
  final List<int> rngState = <int>[];
  final List<bool> initialized = <bool>[];
  final List<double> desiredRange = <double>[];
  final List<double> desiredRangeHoldLeftS = <double>[];
  final List<double> flightTargetAboveGround = <double>[];
  final List<double> flightTargetHoldLeftS = <double>[];
  final List<bool> hasLocalTerrainReference = <bool>[];
  final List<double> localTerrainReferenceY = <double>[];
  final List<double> effectiveFlightReferenceY = <double>[];
  final List<bool> terrainBlockedLastTick = <bool>[];
  final List<int> blockingNormalXTicks = <int>[];
  final List<int> blockingNormalYTicks = <int>[];
  final List<int> clearanceCandidateId = <int>[];
  final List<int> clearanceHoldTicksLeft = <int>[];
  final List<double> clearanceVelocityX = <double>[];
  final List<double> clearanceVelocityY = <double>[];

  void add(EntityId entity, FlyingEnemySteeringDef def) {
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
    hasLocalTerrainReference.add(false);
    localTerrainReferenceY.add(0.0);
    effectiveFlightReferenceY.add(0.0);
    terrainBlockedLastTick.add(false);
    blockingNormalXTicks.add(0);
    blockingNormalYTicks.add(0);
    clearanceCandidateId.add(-1);
    clearanceHoldTicksLeft.add(0);
    clearanceVelocityX.add(0.0);
    clearanceVelocityY.add(0.0);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    rngState[removeIndex] = rngState[lastIndex];
    initialized[removeIndex] = initialized[lastIndex];
    desiredRange[removeIndex] = desiredRange[lastIndex];
    desiredRangeHoldLeftS[removeIndex] = desiredRangeHoldLeftS[lastIndex];
    flightTargetAboveGround[removeIndex] = flightTargetAboveGround[lastIndex];
    flightTargetHoldLeftS[removeIndex] = flightTargetHoldLeftS[lastIndex];
    hasLocalTerrainReference[removeIndex] =
        hasLocalTerrainReference[lastIndex];
    localTerrainReferenceY[removeIndex] = localTerrainReferenceY[lastIndex];
    effectiveFlightReferenceY[removeIndex] =
        effectiveFlightReferenceY[lastIndex];
    terrainBlockedLastTick[removeIndex] = terrainBlockedLastTick[lastIndex];
    blockingNormalXTicks[removeIndex] = blockingNormalXTicks[lastIndex];
    blockingNormalYTicks[removeIndex] = blockingNormalYTicks[lastIndex];
    clearanceCandidateId[removeIndex] = clearanceCandidateId[lastIndex];
    clearanceHoldTicksLeft[removeIndex] = clearanceHoldTicksLeft[lastIndex];
    clearanceVelocityX[removeIndex] = clearanceVelocityX[lastIndex];
    clearanceVelocityY[removeIndex] = clearanceVelocityY[lastIndex];

    rngState.removeLast();
    initialized.removeLast();
    desiredRange.removeLast();
    desiredRangeHoldLeftS.removeLast();
    flightTargetAboveGround.removeLast();
    flightTargetHoldLeftS.removeLast();
    hasLocalTerrainReference.removeLast();
    localTerrainReferenceY.removeLast();
    effectiveFlightReferenceY.removeLast();
    terrainBlockedLastTick.removeLast();
    blockingNormalXTicks.removeLast();
    blockingNormalYTicks.removeLast();
    clearanceCandidateId.removeLast();
    clearanceHoldTicksLeft.removeLast();
    clearanceVelocityX.removeLast();
    clearanceVelocityY.removeLast();
  }
}
