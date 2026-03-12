import '../entity_id.dart';
import '../sparse_set.dart';

class LifetimeDef {
  const LifetimeDef({required this.ticksLeft});

  final int ticksLeft;
}

/// Tracks entity lifetime in ticks. Entity is despawned when `ticksLeft <= 0`.
class LifetimeStore extends SparseSet {
  final List<int> ticksLeft = <int>[];

  void add(EntityId entity, LifetimeDef def) {
    final i = addEntity(entity);
    ticksLeft[i] = def.ticksLeft;
  }

  @override
  void onDenseAdded(int denseIndex) {
    ticksLeft.add(0);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    ticksLeft[removeIndex] = ticksLeft[lastIndex];
    ticksLeft.removeLast();
  }
}

