import '../../entity_id.dart';
import '../../sparse_set.dart';

class StatModifierDef {
  const StatModifierDef({this.moveSpeedMul = 1.0});

  final double moveSpeedMul;
}

/// Runtime modifiers derived from status effects and buffs.
class StatModifierStore extends SparseSet {
  final List<double> moveSpeedMul = <double>[];

  void add(EntityId entity, [StatModifierDef def = const StatModifierDef()]) {
    final i = addEntity(entity);
    moveSpeedMul[i] = def.moveSpeedMul;
  }

  @override
  void onDenseAdded(int denseIndex) {
    moveSpeedMul.add(1.0);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    moveSpeedMul[removeIndex] = moveSpeedMul[lastIndex];
    moveSpeedMul.removeLast();
  }
}

