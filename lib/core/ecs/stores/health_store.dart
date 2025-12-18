import '../entity_id.dart';
import '../sparse_set.dart';

class HealthDef {
  const HealthDef({
    required this.hp,
    required this.hpMax,
    required this.regenPerSecond,
  });

  final double hp;
  final double hpMax;
  final double regenPerSecond;
}

class HealthStore extends SparseSet {
  final List<double> hp = <double>[];
  final List<double> hpMax = <double>[];
  final List<double> regenPerSecond = <double>[];

  void add(EntityId entity, HealthDef def) {
    final i = addEntity(entity);
    hp[i] = def.hp;
    hpMax[i] = def.hpMax;
    regenPerSecond[i] = def.regenPerSecond;
  }

  @override
  void onDenseAdded(int denseIndex) {
    hp.add(0);
    hpMax.add(0);
    regenPerSecond.add(0);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    hp[removeIndex] = hp[lastIndex];
    hpMax[removeIndex] = hpMax[lastIndex];
    regenPerSecond[removeIndex] = regenPerSecond[lastIndex];

    hp.removeLast();
    hpMax.removeLast();
    regenPerSecond.removeLast();
  }
}

