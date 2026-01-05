import '../entity_id.dart';
import '../sparse_set.dart';

enum RestorationStat {
  health,
  mana,
  stamina,
}

class RestorationItemDef {
  const RestorationItemDef({required this.stat});

  final RestorationStat stat;
}

/// SoA store for restoration item metadata.
class RestorationItemStore extends SparseSet {
  final List<RestorationStat> stat = <RestorationStat>[];

  void add(EntityId entity, RestorationItemDef def) {
    final i = addEntity(entity);
    stat[i] = def.stat;
  }

  @override
  void onDenseAdded(int denseIndex) {
    stat.add(RestorationStat.health);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    stat[removeIndex] = stat[lastIndex];
    stat.removeLast();
  }
}
