import '../../entity_id.dart';
import '../../sparse_set.dart';

class DrenchDef {
  const DrenchDef({required this.ticksLeft, required this.magnitude});

  final int ticksLeft;

  /// Basis points (100 = 1%) subtracted from attack/cast speed.
  final int magnitude;
}

/// Active attack/cast speed reduction status.
class DrenchStore extends SparseSet {
  final List<int> ticksLeft = <int>[];

  /// Basis points (100 = 1%) subtracted from attack/cast speed.
  final List<int> magnitude = <int>[];

  void add(EntityId entity, DrenchDef def) {
    final i = addEntity(entity);
    ticksLeft[i] = def.ticksLeft;
    magnitude[i] = def.magnitude;
  }

  @override
  void onDenseAdded(int denseIndex) {
    ticksLeft.add(0);
    magnitude.add(0);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    ticksLeft[removeIndex] = ticksLeft[lastIndex];
    magnitude[removeIndex] = magnitude[lastIndex];
    ticksLeft.removeLast();
    magnitude.removeLast();
  }
}
