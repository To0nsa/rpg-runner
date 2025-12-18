import '../../combat/faction.dart';
import '../entity_id.dart';
import '../sparse_set.dart';

class FactionDef {
  const FactionDef({required this.faction});

  final Faction faction;
}

class FactionStore extends SparseSet {
  final List<Faction> faction = <Faction>[];

  void add(EntityId entity, FactionDef def) {
    final i = addEntity(entity);
    faction[i] = def.faction;
  }

  @override
  void onDenseAdded(int denseIndex) {
    faction.add(Faction.player);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    faction[removeIndex] = faction[lastIndex];
    faction.removeLast();
  }
}

