import '../../entity_id.dart';
import '../../sparse_set.dart';

class SlowDef {
  const SlowDef({required this.ticksLeft, required this.magnitude});

  final int ticksLeft;
  final double magnitude;
}

/// Active slow status (movement speed multiplier).
class SlowStore extends SparseSet {
  final List<int> ticksLeft = <int>[];
  final List<double> magnitude = <double>[];

  void add(EntityId entity, SlowDef def) {
    final i = addEntity(entity);
    ticksLeft[i] = def.ticksLeft;
    magnitude[i] = def.magnitude;
  }

  @override
  void onDenseAdded(int denseIndex) {
    ticksLeft.add(0);
    magnitude.add(0.0);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    ticksLeft[removeIndex] = ticksLeft[lastIndex];
    magnitude[removeIndex] = magnitude[lastIndex];
    ticksLeft.removeLast();
    magnitude.removeLast();
  }
}

