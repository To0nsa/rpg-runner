import '../entity_id.dart';
import '../sparse_set.dart';

/// One-shot offensive buff granted by a successful parry.
///
/// The buff is consumed only when a melee hit actually lands (so misses do not
/// waste it). It may also expire after a fixed number of ticks.
class RiposteStore extends SparseSet {
  /// Tick at which this buff expires (inclusive).
  final List<int> expiresTick = <int>[];

  /// Damage bonus in basis points (bpScale = 10000).
  /// Example: 10000 = +100% (i.e. x2 total when applied).
  final List<int> bonusBp = <int>[];

  /// Originating guard activation; -1 means an independent timed grant.
  final List<int> guardStartTick = <int>[];

  /// Runtime ticks retained after the originating guard ends.
  final List<int> releaseWindowTicks = <int>[];

  /// Grants one hit; optional guard identity keeps the release window ready
  /// while that activation is held. All timestamps/windows use runtime ticks.
  void grant(
    EntityId entity, {
    required int expiresAtTick,
    required int bonusBp,
    int guardStartTick = -1,
    int releaseWindowTicks = 0,
  }) {
    final i = addEntity(entity);
    expiresTick[i] = expiresAtTick;
    this.bonusBp[i] = bonusBp;
    this.guardStartTick[i] = guardStartTick;
    this.releaseWindowTicks[i] = releaseWindowTicks;
  }

  /// Keeps an earned reward ready only during the guard that granted it.
  /// Calling again at the same tick is idempotent; a later guard cannot renew it.
  void sustainGuard(EntityId entity, int activationTick, int currentTick) {
    final i = tryIndexOf(entity);
    if (i == null ||
        guardStartTick[i] != activationTick ||
        releaseWindowTicks[i] <= 0) {
      return;
    }
    expiresTick[i] = currentTick + releaseWindowTicks[i];
  }

  /// Remaining usable ticks including the expiry tick; zero for expired grants.
  int ticksLeft(EntityId entity, int currentTick) {
    final i = tryIndexOf(entity);
    if (i == null || currentTick > expiresTick[i]) return 0;
    return expiresTick[i] - currentTick + 1;
  }

  void consume(EntityId entity) {
    removeEntity(entity);
  }

  @override
  void onDenseAdded(int denseIndex) {
    expiresTick.add(-1);
    bonusBp.add(0);
    guardStartTick.add(-1);
    releaseWindowTicks.add(0);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    expiresTick[removeIndex] = expiresTick[lastIndex];
    bonusBp[removeIndex] = bonusBp[lastIndex];
    guardStartTick[removeIndex] = guardStartTick[lastIndex];
    releaseWindowTicks[removeIndex] = releaseWindowTicks[lastIndex];
    guardStartTick.removeLast();
    releaseWindowTicks.removeLast();
    expiresTick.removeLast();
    bonusBp.removeLast();
  }
}
