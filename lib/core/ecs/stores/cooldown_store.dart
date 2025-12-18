import '../entity_id.dart';
import '../sparse_set.dart';

class CooldownDef {
  const CooldownDef({
    this.castCooldownTicksLeft = 0,
    this.meleeCooldownTicksLeft = 0,
  });

  final int castCooldownTicksLeft;
  final int meleeCooldownTicksLeft;
}

class CooldownStore extends SparseSet {
  final List<int> castCooldownTicksLeft = <int>[];
  final List<int> meleeCooldownTicksLeft = <int>[];

  void add(EntityId entity, [CooldownDef def = const CooldownDef()]) {
    final i = addEntity(entity);
    castCooldownTicksLeft[i] = def.castCooldownTicksLeft;
    meleeCooldownTicksLeft[i] = def.meleeCooldownTicksLeft;
  }

  @override
  void onDenseAdded(int denseIndex) {
    castCooldownTicksLeft.add(0);
    meleeCooldownTicksLeft.add(0);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    castCooldownTicksLeft[removeIndex] = castCooldownTicksLeft[lastIndex];
    meleeCooldownTicksLeft[removeIndex] = meleeCooldownTicksLeft[lastIndex];
    castCooldownTicksLeft.removeLast();
    meleeCooldownTicksLeft.removeLast();
  }
}
