import '../../entity_id.dart';
import '../../sparse_set.dart';
import '../../../util/deterministic_rng.dart';

/// Seeded dodge cadence and pending reactive teleport, cleared with the actor.
/// Each actor's random stream derives from the run seed and entity ID.
class GoddessDodgeStore extends SparseSet {
  GoddessDodgeStore({required int seed}) : _seed = seed;

  final int _seed;
  final List<int> attacks = [];

  /// Landed player projectiles since the last direct non-projectile hit/counter.
  final List<int> consecutiveProjectileHits = [];

  /// Zero until the first eligible attack samples the 4–6 attack interval.
  final List<int> attackInterval = [];
  final List<int> rngState = [];

  /// Captured distant landing side (-1/1); zero keeps the close crossing rule.
  final List<int> landingSide = [];
  final List<int> startTick = [];
  final List<int> executeTick = [];
  final List<EntityId> player = [];

  /// A combo counts once; evading it also rejects that activation's follow-ups.
  /// World-assigned combo activation IDs never recycle during a run.
  final List<Map<(EntityId, int), bool>> comboDodged = [];

  /// Samples the initial 4–6 attack interval only once per actor.
  void ensureAttackInterval(int index) {
    if (attackInterval[index] == 0) _rollInterval(index);
  }

  /// Both reactive triggers reset together after a successful vanish commit.
  void resetAfterDodge(int index) {
    attacks[index] = 0;
    consecutiveProjectileHits[index] = 0;
    _rollInterval(index);
  }

  void _rollInterval(int index) {
    final roll = nextUint32(rngState[index]);
    rngState[index] = roll;
    attackInterval[index] = 4 + roll % 3;
  }

  @override
  void onDenseAdded(int denseIndex) {
    attacks.add(0);
    consecutiveProjectileHits.add(0);
    attackInterval.add(0);
    rngState.add(seedFrom(_seed, denseEntities[denseIndex] ^ 0x476f6444));
    landingSide.add(0);
    startTick.add(-1);
    executeTick.add(-1);
    player.add(-1);
    comboDodged.add({});
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    attacks[removeIndex] = attacks[lastIndex];
    consecutiveProjectileHits[removeIndex] =
        consecutiveProjectileHits[lastIndex];
    attackInterval[removeIndex] = attackInterval[lastIndex];
    rngState[removeIndex] = rngState[lastIndex];
    landingSide[removeIndex] = landingSide[lastIndex];
    startTick[removeIndex] = startTick[lastIndex];
    executeTick[removeIndex] = executeTick[lastIndex];
    player[removeIndex] = player[lastIndex];
    comboDodged[removeIndex] = comboDodged[lastIndex];
    attacks.removeLast();
    consecutiveProjectileHits.removeLast();
    attackInterval.removeLast();
    rngState.removeLast();
    landingSide.removeLast();
    startTick.removeLast();
    executeTick.removeLast();
    player.removeLast();
    comboDodged.removeLast();
  }
}
