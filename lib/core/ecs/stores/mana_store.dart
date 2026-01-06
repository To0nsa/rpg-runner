import '../entity_id.dart';
import '../sparse_set.dart';

class ManaDef {
  const ManaDef({
    required this.mana,
    required this.manaMax,
    required this.regenPerSecond,
  });

  final double mana;
  final double manaMax;
  final double regenPerSecond;
}

/// Tracks current and max mana for spellcasters (Player).
class ManaStore extends SparseSet {
  final List<double> mana = <double>[];
  final List<double> manaMax = <double>[];
  final List<double> regenPerSecond = <double>[];

  void add(EntityId entity, ManaDef def) {
    final i = addEntity(entity);
    mana[i] = def.mana;
    manaMax[i] = def.manaMax;
    regenPerSecond[i] = def.regenPerSecond;
  }

  @override
  void onDenseAdded(int denseIndex) {
    mana.add(0);
    manaMax.add(0);
    regenPerSecond.add(0);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    mana[removeIndex] = mana[lastIndex];
    manaMax[removeIndex] = manaMax[lastIndex];
    regenPerSecond[removeIndex] = regenPerSecond[lastIndex];

    mana.removeLast();
    manaMax.removeLast();
    regenPerSecond.removeLast();
  }
}

