import '../../sparse_set.dart';

/// The admitted retreat must finish before its reserved orb can start.
enum ShoggothRangedPhase { none, retreating, orbPending }

/// Health milestones and attack cadence survive actions; follow-ups own an exact action.
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
  int meleeActionsSinceOrb = 0;
  ShoggothRangedPhase rangedPhase = ShoggothRangedPhase.none;
  String? observedAbilityId;
  int observedStartTick = -1;
  int observedEndTick = -1;

  /// Completion is observed before the shared phase system clears the action.
  void observeAction(String abilityId, int startTick, int endTick) {
    observedAbilityId = abilityId;
    observedStartTick = startTick;
    observedEndTick = endTick;
  }

  void clearObservation() {
    observedAbilityId = null;
    observedStartTick = -1;
    observedEndTick = -1;
  }

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
