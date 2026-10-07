import '../sparse_set.dart';

/// Encounter lifecycle state removed automatically when its entity is destroyed.
class AncientBossStateStore extends SparseSet {
  final List<int> actionIndex = [];
  final List<int> nextTeleportTick = [];
  final List<String?> utilityAbility = [];
  final List<int> utilityStartTick = [];
  final List<int> executeTick = [];
  final List<double> targetX = [];
  @override
  void onDenseAdded(int denseIndex) {
    actionIndex.add(0);
    nextTeleportTick.add(0);
    utilityAbility.add(null);
    utilityStartTick.add(-1);
    executeTick.add(-1);
    targetX.add(0);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    actionIndex[removeIndex] = actionIndex[lastIndex];
    actionIndex.removeLast();
    nextTeleportTick[removeIndex] = nextTeleportTick[lastIndex];
    nextTeleportTick.removeLast();
    utilityAbility[removeIndex] = utilityAbility[lastIndex];
    utilityAbility.removeLast();
    utilityStartTick[removeIndex] = utilityStartTick[lastIndex];
    utilityStartTick.removeLast();
    executeTick[removeIndex] = executeTick[lastIndex];
    executeTick.removeLast();
    targetX[removeIndex] = targetX[lastIndex];
    targetX.removeLast();
  }
}
