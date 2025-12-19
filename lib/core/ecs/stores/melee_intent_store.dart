import '../entity_id.dart';
import '../sparse_set.dart';

class MeleeIntentDef {
  const MeleeIntentDef({
    required this.damage,
    required this.halfX,
    required this.halfY,
    required this.offsetX,
    required this.offsetY,
    required this.activeTicks,
    required this.cooldownTicks,
    required this.staminaCost,
    required this.tick,
  });

  final double damage;
  final double halfX;
  final double halfY;
  final double offsetX;
  final double offsetY;
  final int activeTicks;
  final int cooldownTicks;
  final double staminaCost;

  /// Tick stamp for this intent.
  ///
  /// Use `-1` for "no intent". An intent is valid only when `tick == currentTick`.
  final int tick;
}

/// Per-entity "perform a melee attack this tick" intent.
///
/// This is written by player/enemy intent writers and consumed by `MeleeAttackSystem`.
class MeleeIntentStore extends SparseSet {
  final List<double> damage = <double>[];
  final List<double> halfX = <double>[];
  final List<double> halfY = <double>[];
  final List<double> offsetX = <double>[];
  final List<double> offsetY = <double>[];
  final List<int> activeTicks = <int>[];
  final List<int> cooldownTicks = <int>[];
  final List<double> staminaCost = <double>[];
  final List<int> tick = <int>[];

  void add(EntityId entity) {
    addEntity(entity);
  }

  void set(EntityId entity, MeleeIntentDef def) {
    assert(
      has(entity),
      'MeleeIntentStore.set called for entity without MeleeIntentStore; add the component at spawn time.',
    );
    final i = indexOf(entity);
    damage[i] = def.damage;
    halfX[i] = def.halfX;
    halfY[i] = def.halfY;
    offsetX[i] = def.offsetX;
    offsetY[i] = def.offsetY;
    activeTicks[i] = def.activeTicks;
    cooldownTicks[i] = def.cooldownTicks;
    staminaCost[i] = def.staminaCost;
    tick[i] = def.tick;
  }

  @override
  void onDenseAdded(int denseIndex) {
    damage.add(0.0);
    halfX.add(0.0);
    halfY.add(0.0);
    offsetX.add(0.0);
    offsetY.add(0.0);
    activeTicks.add(0);
    cooldownTicks.add(0);
    staminaCost.add(0.0);
    tick.add(-1);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    damage[removeIndex] = damage[lastIndex];
    halfX[removeIndex] = halfX[lastIndex];
    halfY[removeIndex] = halfY[lastIndex];
    offsetX[removeIndex] = offsetX[lastIndex];
    offsetY[removeIndex] = offsetY[lastIndex];
    activeTicks[removeIndex] = activeTicks[lastIndex];
    cooldownTicks[removeIndex] = cooldownTicks[lastIndex];
    staminaCost[removeIndex] = staminaCost[lastIndex];
    tick[removeIndex] = tick[lastIndex];

    damage.removeLast();
    halfX.removeLast();
    halfY.removeLast();
    offsetX.removeLast();
    offsetY.removeLast();
    activeTicks.removeLast();
    cooldownTicks.removeLast();
    staminaCost.removeLast();
    tick.removeLast();
  }
}
