import '../entity_id.dart';
import '../sparse_set.dart';

class CooldownDef {
  const CooldownDef({
    this.projectileCooldownTicksLeft = 0,
    this.meleeCooldownTicksLeft = 0,
  });

  final int projectileCooldownTicksLeft;
  final int meleeCooldownTicksLeft;
}

/// Tracks ability cooldowns (ticks remaining).
class CooldownStore extends SparseSet {
  final List<int> projectileCooldownTicksLeft = <int>[];
  final List<int> meleeCooldownTicksLeft = <int>[];

  void add(EntityId entity, [CooldownDef def = const CooldownDef()]) {
    final i = addEntity(entity);
    projectileCooldownTicksLeft[i] = def.projectileCooldownTicksLeft;
    meleeCooldownTicksLeft[i] = def.meleeCooldownTicksLeft;
  }

  @override
  void onDenseAdded(int denseIndex) {
    projectileCooldownTicksLeft.add(0);
    meleeCooldownTicksLeft.add(0);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    projectileCooldownTicksLeft[removeIndex] =
        projectileCooldownTicksLeft[lastIndex];
    meleeCooldownTicksLeft[removeIndex] = meleeCooldownTicksLeft[lastIndex];
    projectileCooldownTicksLeft.removeLast();
    meleeCooldownTicksLeft.removeLast();
  }
}
