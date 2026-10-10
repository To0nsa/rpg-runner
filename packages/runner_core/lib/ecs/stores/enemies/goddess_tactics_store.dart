import '../../../util/deterministic_rng.dart';
import '../../../util/vec2.dart';
import '../../sparse_set.dart';

enum GoddessTactic {
  idle,
  approach,
  exitPending,
  exitOrb,
  teleportOut,
  teleportIn,
}

/// Actor-local decisions and owned transitions; unrelated bosses share no RNG.
class GoddessTactics {
  GoddessTactics(this.rngState);

  int rngState;
  GoddessTactic phase = GoddessTactic.idle;
  int nextTeleportTick = 0;
  int orbsRemaining = 0;
  bool initialized = false;
  double approachX = 0;
  int approachEndTick = 0;
  String? abilityId;
  int startTick = -1;
  int endTick = -1;
  Vec2? destination;

  bool get scriptedTransition =>
      phase != GoddessTactic.idle && phase != GoddessTactic.approach;

  int roll(int count) {
    rngState = nextUint32(rngState);
    return rngState % count;
  }

  void clearTransition() {
    phase = GoddessTactic.idle;
    abilityId = null;
    startTick = -1;
    endTick = -1;
    destination = null;
  }
}

/// Tactical state survives individual casts and is removed with its actor.
class GoddessTacticsStore extends SparseSet {
  GoddessTacticsStore({required int seed}) : _seed = seed;
  final int _seed;
  final List<GoddessTactics> states = [];

  GoddessTactics stateFor(int entity) =>
      states[tryIndexOf(entity) ?? addEntity(entity)];

  @override
  void onDenseAdded(int denseIndex) {
    states.add(
      GoddessTactics(seedFrom(_seed, denseEntities[denseIndex] ^ 0x476f6454)),
    );
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    states[removeIndex] = states[lastIndex];
    states.removeLast();
  }
}
