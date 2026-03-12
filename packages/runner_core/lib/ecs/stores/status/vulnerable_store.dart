import '../../entity_id.dart';
import '../../sparse_set.dart';

class VulnerableDef {
  const VulnerableDef({required this.ticksLeft, required this.magnitude});

  final int ticksLeft;

  /// Basis points (100 = 1%) added to incoming damage.
  final int magnitude;
}

/// Active vulnerability status (global incoming damage amplification).
class VulnerableStore extends SparseSet {
  final List<int> ticksLeft = <int>[];

  /// Basis points (100 = 1%) added to incoming damage.
  final List<int> magnitude = <int>[];

  void add(EntityId entity, VulnerableDef def) {
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
