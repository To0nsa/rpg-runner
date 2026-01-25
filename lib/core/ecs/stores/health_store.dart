import '../entity_id.dart';
import '../sparse_set.dart';

class HealthDef {
  const HealthDef({
    required this.hp,
    required this.hpMax,
    required this.regenPerSecond100,
  });

  /// Fixed-point: 100 = 1.0
  final int hp;
  final int hpMax;
  final int regenPerSecond100;
}

/// Tracks current and max hit points for damageable entities.
class HealthStore extends SparseSet {
  /// Fixed-point: 100 = 1.0
  final List<int> hp = <int>[];
  final List<int> hpMax = <int>[];
  final List<int> regenPerSecond100 = <int>[];
  final List<int> regenAccumulator = <int>[];

  void add(EntityId entity, HealthDef def) {
    final i = addEntity(entity);
    hp[i] = def.hp;
    hpMax[i] = def.hpMax;
    regenPerSecond100[i] = def.regenPerSecond100;
    regenAccumulator[i] = 0;
  }

  @override
  void onDenseAdded(int denseIndex) {
    hp.add(0);
    hpMax.add(0);
    regenPerSecond100.add(0);
    regenAccumulator.add(0);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    hp[removeIndex] = hp[lastIndex];
    hpMax[removeIndex] = hpMax[lastIndex];
    regenPerSecond100[removeIndex] = regenPerSecond100[lastIndex];
    regenAccumulator[removeIndex] = regenAccumulator[lastIndex];

    hp.removeLast();
    hpMax.removeLast();
    regenPerSecond100.removeLast();
    regenAccumulator.removeLast();
  }
}
