import '../sparse_set.dart';
import '../../util/vec2.dart';

/// Per-entity decision and committed utility state, cleared before ID recycling.
/// Concrete boss systems own sequence/cooldown policy; utilities own execution.
class BossCombatStateStore extends SparseSet {
  final List<int> actionIndex = [];
  final List<String?> utilityAbility = [];
  final List<int> utilityStartTick = [];
  final List<int> executeTick = [];
  final List<double> targetX = [];
  final List<Vec2?> teleportDestination = [];
  @override
  void onDenseAdded(int denseIndex) {
    actionIndex.add(0);
    utilityAbility.add(null);
    utilityStartTick.add(-1);
    executeTick.add(-1);
    targetX.add(0);
    teleportDestination.add(null);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    actionIndex[removeIndex] = actionIndex[lastIndex];
    actionIndex.removeLast();
    utilityAbility[removeIndex] = utilityAbility[lastIndex];
    utilityAbility.removeLast();
    utilityStartTick[removeIndex] = utilityStartTick[lastIndex];
    utilityStartTick.removeLast();
    executeTick[removeIndex] = executeTick[lastIndex];
    executeTick.removeLast();
    targetX[removeIndex] = targetX[lastIndex];
    targetX.removeLast();
    teleportDestination[removeIndex] = teleportDestination[lastIndex];
    teleportDestination.removeLast();
  }
}
