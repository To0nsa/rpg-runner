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

  void grant(
    EntityId entity, {
    required int expiresAtTick,
    required int bonusBp,
  }) {
    final i = addEntity(entity);
    expiresTick[i] = expiresAtTick;
    this.bonusBp[i] = bonusBp;
  }

  void consume(EntityId entity) {
    removeEntity(entity);
  }

  @override
  void onDenseAdded(int denseIndex) {
    expiresTick.add(-1);
    bonusBp.add(0);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    expiresTick[removeIndex] = expiresTick[lastIndex];
    bonusBp[removeIndex] = bonusBp[lastIndex];
    expiresTick.removeLast();
    bonusBp.removeLast();
  }
}

