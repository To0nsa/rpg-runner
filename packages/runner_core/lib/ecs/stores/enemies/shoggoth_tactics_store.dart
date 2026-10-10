import '../../sparse_set.dart';

/// Health milestones survive actions; a follow-up belongs to one exact charge.
class ShoggothTactics {
  int phasesReached = 0;
  int phasesCommitted = 0;
  // The 35% charge milestone survives healing independently of summon waves.
  bool frenzyReached = false;
  int separatedSinceTick = -1;
  int nextTeleportTick = 0;
  int frenzyCharges = 0;
  int chainStartTick = -1;
  int chainEndTick = -1;
  int returnReadyTick = -1;

  void clearChain() {
    chainStartTick = -1;
    chainEndTick = -1;
    returnReadyTick = -1;
  }
}

/// Registered actor state, discarded before entity IDs can be reused.
class ShoggothTacticsStore extends SparseSet {
  final List<ShoggothTactics> states = [];

  ShoggothTactics stateFor(int entity) =>
      states[tryIndexOf(entity) ?? addEntity(entity)];

  @override
  void onDenseAdded(int denseIndex) => states.add(ShoggothTactics());

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    states[removeIndex] = states[lastIndex];
    states.removeLast();
  }
}
