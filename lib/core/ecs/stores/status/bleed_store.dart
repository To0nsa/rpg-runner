import '../../entity_id.dart';
import '../../sparse_set.dart';

class BleedDef {
  const BleedDef({
    required this.ticksLeft,
    required this.periodTicks,
    required this.damagePerTick100,
  }) : periodTicksLeft = periodTicks;

  final int ticksLeft;
  final int periodTicks;
  final int periodTicksLeft;
  /// Fixed-point: 100 = 1.0
  final int damagePerTick100;
}

/// Active bleed (damage-over-time) status.
class BleedStore extends SparseSet {
  final List<int> ticksLeft = <int>[];
  final List<int> periodTicks = <int>[];
  final List<int> periodTicksLeft = <int>[];
  /// Fixed-point: 100 = 1.0
  final List<int> damagePerTick100 = <int>[];

  void add(EntityId entity, BleedDef def) {
    final i = addEntity(entity);
    ticksLeft[i] = def.ticksLeft;
    periodTicks[i] = def.periodTicks;
    periodTicksLeft[i] = def.periodTicksLeft;
    damagePerTick100[i] = def.damagePerTick100;
  }

  @override
  void onDenseAdded(int denseIndex) {
    ticksLeft.add(0);
    periodTicks.add(1);
    periodTicksLeft.add(1);
    damagePerTick100.add(0);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    ticksLeft[removeIndex] = ticksLeft[lastIndex];
    periodTicks[removeIndex] = periodTicks[lastIndex];
    periodTicksLeft[removeIndex] = periodTicksLeft[lastIndex];
    damagePerTick100[removeIndex] = damagePerTick100[lastIndex];

    ticksLeft.removeLast();
    periodTicks.removeLast();
    periodTicksLeft.removeLast();
    damagePerTick100.removeLast();
  }
}
