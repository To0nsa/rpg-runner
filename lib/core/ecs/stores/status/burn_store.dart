import '../../entity_id.dart';
import '../../sparse_set.dart';

class BurnDef {
  const BurnDef({
    required this.ticksLeft,
    required this.periodTicks,
    required this.dps100,
  }) : periodTicksLeft = periodTicks;

  final int ticksLeft;
  final int periodTicks;
  final int periodTicksLeft;
  /// Fixed-point DPS: 100 = 1.0 per second
  final int dps100;
}

/// Active burn (damage-over-time) status.
class BurnStore extends SparseSet {
  final List<int> ticksLeft = <int>[];
  final List<int> periodTicks = <int>[];
  final List<int> periodTicksLeft = <int>[];
  /// Fixed-point DPS: 100 = 1.0 per second
  final List<int> dps100 = <int>[];

  void add(EntityId entity, BurnDef def) {
    final i = addEntity(entity);
    ticksLeft[i] = def.ticksLeft;
    periodTicks[i] = def.periodTicks;
    periodTicksLeft[i] = def.periodTicksLeft;
    dps100[i] = def.dps100;
  }

  @override
  void onDenseAdded(int denseIndex) {
    ticksLeft.add(0);
    periodTicks.add(1);
    periodTicksLeft.add(1);
    dps100.add(0);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    ticksLeft[removeIndex] = ticksLeft[lastIndex];
    periodTicks[removeIndex] = periodTicks[lastIndex];
    periodTicksLeft[removeIndex] = periodTicksLeft[lastIndex];
    dps100[removeIndex] = dps100[lastIndex];

    ticksLeft.removeLast();
    periodTicks.removeLast();
    periodTicksLeft.removeLast();
    dps100.removeLast();
  }
}
