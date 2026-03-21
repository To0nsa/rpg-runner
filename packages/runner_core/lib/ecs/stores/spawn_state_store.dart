import '../entity_id.dart';
import '../sparse_set.dart';

class SpawnStateDef {
  const SpawnStateDef({this.startTick = -1, this.animTicks = 0});

  final int startTick;
  final int animTicks;
}

/// Per-entity spawn animation timing state.
class SpawnStateStore extends SparseSet {
  final List<int> startTick = <int>[];
  final List<int> animTicks = <int>[];

  void add(EntityId entity, [SpawnStateDef def = const SpawnStateDef()]) {
    final i = addEntity(entity);
    startTick[i] = def.startTick;
    animTicks[i] = def.animTicks;
  }

  void set({
    required EntityId entity,
    required int startTickValue,
    required int animTicksValue,
  }) {
    final i = tryIndexOf(entity);
    if (i == null) return;
    startTick[i] = startTickValue;
    animTicks[i] = animTicksValue;
  }

  @override
  void onDenseAdded(int denseIndex) {
    startTick.add(-1);
    animTicks.add(0);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    startTick[removeIndex] = startTick[lastIndex];
    animTicks[removeIndex] = animTicks[lastIndex];

    startTick.removeLast();
    animTicks.removeLast();
  }
}
