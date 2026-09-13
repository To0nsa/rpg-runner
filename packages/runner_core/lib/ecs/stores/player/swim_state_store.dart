import '../../../terrain/swimming_tuning.dart';
import '../../entity_id.dart';
import '../../sparse_set.dart';

/// Player fluid state retained across ticks and removed with its entity.
class SwimStateStore extends SparseSet {
  final List<bool> swimming = [];

  /// Vertical submerged depth along the capsule centre column, in thousandths.
  final List<int> immersion1000 = [];

  /// First simulation tick on which another stroke may execute.
  final List<int> nextStrokeTick = [];

  void add(EntityId entity) => addEntity(entity);

  bool isSwimming(EntityId entity) {
    final index = tryIndexOf(entity);
    return index != null && swimming[index];
  }

  /// Applies enter/exit hysteresis without changing stroke cooldown state.
  void setImmersion(int index, int immersion) {
    immersion1000[index] = immersion;
    swimming[index] = swimming[index]
        ? immersion >= SwimmingTuning.exitImmersion1000
        : immersion >= SwimmingTuning.enterImmersion1000;
  }

  @override
  void onDenseAdded(int denseIndex) {
    swimming.add(false);
    immersion1000.add(0);
    nextStrokeTick.add(0);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    swimming[removeIndex] = swimming[lastIndex];
    immersion1000[removeIndex] = immersion1000[lastIndex];
    nextStrokeTick[removeIndex] = nextStrokeTick[lastIndex];
    swimming.removeLast();
    immersion1000.removeLast();
    nextStrokeTick.removeLast();
  }
}
