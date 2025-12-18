import '../entity_id.dart';
import '../sparse_set.dart';

class CooldownDef {
  const CooldownDef({this.castCooldownTicksLeft = 0});

  final int castCooldownTicksLeft;
}

class CooldownStore extends SparseSet {
  final List<int> castCooldownTicksLeft = <int>[];

  void add(EntityId entity, [CooldownDef def = const CooldownDef()]) {
    final i = addEntity(entity);
    castCooldownTicksLeft[i] = def.castCooldownTicksLeft;
  }

  @override
  void onDenseAdded(int denseIndex) {
    castCooldownTicksLeft.add(0);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    castCooldownTicksLeft[removeIndex] = castCooldownTicksLeft[lastIndex];
    castCooldownTicksLeft.removeLast();
  }
}

