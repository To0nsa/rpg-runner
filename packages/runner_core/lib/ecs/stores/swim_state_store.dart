import '../../terrain/swimming_tuning.dart';
import '../entity_id.dart';
import '../sparse_set.dart';

/// Fluid state for players and swimming enemies, removed with its entity.
class SwimStateStore extends SparseSet {
  final List<bool> swimming = [];

  /// Vertical submerged depth along the capsule centre column, in thousandths.
  final List<int> immersion1000 = [];

  /// Surface of the selected overlapping pool in physics ticks; null when dry.
  final List<int?> surfaceYTicks = [];

  /// First simulation tick on which another stroke may execute.
  final List<int> nextStrokeTick = [];

  void add(EntityId entity) => addEntity(entity);

  bool isSwimming(EntityId entity) {
    final index = tryIndexOf(entity);
    return index != null && swimming[index];
  }

  /// Applies enter/exit hysteresis without changing stroke cooldown state.
  void setImmersion(int index, int immersion, {int? surfaceY}) {
    immersion1000[index] = immersion;
    surfaceYTicks[index] = immersion > 0 ? surfaceY : null;
    swimming[index] = swimming[index]
        ? immersion >= SwimmingTuning.exitImmersion1000
        : immersion >= SwimmingTuning.enterImmersion1000;
  }

  @override
  void onDenseAdded(int denseIndex) {
    swimming.add(false);
    immersion1000.add(0);
    surfaceYTicks.add(null);
    nextStrokeTick.add(0);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    swimming[removeIndex] = swimming[lastIndex];
    immersion1000[removeIndex] = immersion1000[lastIndex];
    surfaceYTicks[removeIndex] = surfaceYTicks[lastIndex];
    nextStrokeTick[removeIndex] = nextStrokeTick[lastIndex];
    swimming.removeLast();
    immersion1000.removeLast();
    surfaceYTicks.removeLast();
    nextStrokeTick.removeLast();
  }
}
