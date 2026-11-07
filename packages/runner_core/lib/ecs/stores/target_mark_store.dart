import '../entity_id.dart';
import '../sparse_set.dart';

/// One quarry per attacker. Destroying either endpoint removes its permission;
/// expiry is exclusive and cannot transfer to a recycled entity ID.
class TargetMarkStore extends SparseSet {
  final List<EntityId> target = [];
  final List<int> expiresTick = [];
  final List<int> bonusBp = [];
  void set(
    EntityId attacker, {
    required EntityId target,
    required int expiresTick,
    required int bonusBp,
  }) {
    final i = addEntity(attacker);
    this.target[i] = target;
    this.expiresTick[i] = expiresTick;
    this.bonusBp[i] = bonusBp;
  }

  void forget(EntityId entity) {
    for (var i = denseEntities.length - 1; i >= 0; i--) {
      if (target[i] == entity || denseEntities[i] == entity) {
        removeEntity(denseEntities[i]);
      }
    }
  }

  @override
  void onDenseAdded(int index) {
    target.add(0);
    expiresTick.add(0);
    bonusBp.add(0);
  }

  @override
  void onSwapRemove(int index, int last) {
    target[index] = target[last];
    expiresTick[index] = expiresTick[last];
    bonusBp[index] = bonusBp[last];
    target.removeLast();
    expiresTick.removeLast();
    bonusBp.removeLast();
  }
}
