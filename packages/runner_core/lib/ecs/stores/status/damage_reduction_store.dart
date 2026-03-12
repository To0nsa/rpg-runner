import '../../entity_id.dart';
import '../../sparse_set.dart';

class DamageReductionDef {
  const DamageReductionDef({required this.ticksLeft, required this.magnitude});

  final int ticksLeft;

  /// Basis points (100 = 1%) subtracted from direct incoming hits.
  final int magnitude;
}

/// Active direct-hit damage reduction status.
class DamageReductionStore extends SparseSet {
  final List<int> ticksLeft = <int>[];

  /// Basis points (100 = 1%) subtracted from direct incoming hits.
  final List<int> magnitude = <int>[];

  void add(EntityId entity, DamageReductionDef def) {
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
