import '../../entity_id.dart';
import '../../sparse_set.dart';

class HasteDef {
  const HasteDef({required this.ticksLeft, required this.magnitude});

  final int ticksLeft;
  /// Basis points (100 = 1%).
  final int magnitude;
}

/// Active haste status (movement speed multiplier).
class HasteStore extends SparseSet {
  final List<int> ticksLeft = <int>[];
  /// Basis points (100 = 1%).
  final List<int> magnitude = <int>[];

  void add(EntityId entity, HasteDef def) {
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
