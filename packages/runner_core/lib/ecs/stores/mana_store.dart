import '../entity_id.dart';
import '../sparse_set.dart';

class ManaDef {
  const ManaDef({
    required this.mana,
    required this.manaMax,
    required this.regenPerSecond100,
  });

  /// Fixed-point: 100 = 1.0
  final int mana;
  final int manaMax;
  final int regenPerSecond100;
}

/// Tracks current and max mana for spellcasters (Player).
class ManaStore extends SparseSet {
  /// Fixed-point: 100 = 1.0
  final List<int> mana = <int>[];
  final List<int> manaMax = <int>[];
  final List<int> regenPerSecond100 = <int>[];
  final List<int> regenAccumulator = <int>[];

  void add(EntityId entity, ManaDef def) {
    final i = addEntity(entity);
    mana[i] = def.mana;
    manaMax[i] = def.manaMax;
    regenPerSecond100[i] = def.regenPerSecond100;
    regenAccumulator[i] = 0;
  }

  @override
  void onDenseAdded(int denseIndex) {
    mana.add(0);
    manaMax.add(0);
    regenPerSecond100.add(0);
    regenAccumulator.add(0);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    mana[removeIndex] = mana[lastIndex];
    manaMax[removeIndex] = manaMax[lastIndex];
    regenPerSecond100[removeIndex] = regenPerSecond100[lastIndex];
    regenAccumulator[removeIndex] = regenAccumulator[lastIndex];

    mana.removeLast();
    manaMax.removeLast();
    regenPerSecond100.removeLast();
    regenAccumulator.removeLast();
  }
}
