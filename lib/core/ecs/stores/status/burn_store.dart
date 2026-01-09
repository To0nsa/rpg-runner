import '../../entity_id.dart';
import '../../sparse_set.dart';

class BurnDef {
  const BurnDef({
    required this.ticksLeft,
    required this.periodTicks,
    required this.damagePerTick,
  }) : periodTicksLeft = periodTicks;

  final int ticksLeft;
  final int periodTicks;
  final int periodTicksLeft;
  final double damagePerTick;
}

/// Active burn (damage-over-time) status.
class BurnStore extends SparseSet {
  final List<int> ticksLeft = <int>[];
  final List<int> periodTicks = <int>[];
  final List<int> periodTicksLeft = <int>[];
  final List<double> damagePerTick = <double>[];

  void add(EntityId entity, BurnDef def) {
    final i = addEntity(entity);
    ticksLeft[i] = def.ticksLeft;
    periodTicks[i] = def.periodTicks;
    periodTicksLeft[i] = def.periodTicksLeft;
    damagePerTick[i] = def.damagePerTick;
  }

  @override
  void onDenseAdded(int denseIndex) {
    ticksLeft.add(0);
    periodTicks.add(1);
    periodTicksLeft.add(1);
    damagePerTick.add(0.0);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    ticksLeft[removeIndex] = ticksLeft[lastIndex];
    periodTicks[removeIndex] = periodTicks[lastIndex];
    periodTicksLeft[removeIndex] = periodTicksLeft[lastIndex];
    damagePerTick[removeIndex] = damagePerTick[lastIndex];

    ticksLeft.removeLast();
    periodTicks.removeLast();
    periodTicksLeft.removeLast();
    damagePerTick.removeLast();
  }
}

