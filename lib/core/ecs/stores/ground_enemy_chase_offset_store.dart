import '../entity_id.dart';
import '../sparse_set.dart';

class GroundEnemyChaseOffsetDef {
  const GroundEnemyChaseOffsetDef({
    required this.rngState,
  });

  final int rngState;
}

/// Per ground enemy chase offset state for deterministic path separation.
///
/// Ensures multiple enemies don't stack perfectly on top of one another while chasing.
class GroundEnemyChaseOffsetStore extends SparseSet {
  final List<int> rngState = <int>[];
  final List<double> chaseOffsetX = <double>[];
  final List<double> chaseSpeedScale = <double>[];
  final List<bool> initialized = <bool>[];

  void add(EntityId entity, GroundEnemyChaseOffsetDef def) {
    final i = addEntity(entity);
    rngState[i] = def.rngState;
    chaseOffsetX[i] = 0.0;
    chaseSpeedScale[i] = 1.0;
    initialized[i] = false;
  }

  @override
  void onDenseAdded(int denseIndex) {
    rngState.add(1);
    chaseOffsetX.add(0.0);
    chaseSpeedScale.add(1.0);
    initialized.add(false);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    rngState[removeIndex] = rngState[lastIndex];
    chaseOffsetX[removeIndex] = chaseOffsetX[lastIndex];
    chaseSpeedScale[removeIndex] = chaseSpeedScale[lastIndex];
    initialized[removeIndex] = initialized[lastIndex];

    rngState.removeLast();
    chaseOffsetX.removeLast();
    chaseSpeedScale.removeLast();
    initialized.removeLast();
  }
}
