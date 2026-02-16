import '../../../util/fixed_math.dart';
import '../../entity_id.dart';
import '../../sparse_set.dart';

class StatModifierDef {
  const StatModifierDef({
    this.moveSpeedMul = 1.0,
    this.actionSpeedBp = bpScale,
  });

  final double moveSpeedMul;
  final int actionSpeedBp;
}

/// Runtime modifiers derived from status effects and buffs.
class StatModifierStore extends SparseSet {
  final List<double> moveSpeedMul = <double>[];
  final List<int> actionSpeedBp = <int>[];

  void add(EntityId entity, [StatModifierDef def = const StatModifierDef()]) {
    final i = addEntity(entity);
    moveSpeedMul[i] = def.moveSpeedMul;
    actionSpeedBp[i] = def.actionSpeedBp;
  }

  @override
  void onDenseAdded(int denseIndex) {
    moveSpeedMul.add(1.0);
    actionSpeedBp.add(bpScale);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    moveSpeedMul[removeIndex] = moveSpeedMul[lastIndex];
    actionSpeedBp[removeIndex] = actionSpeedBp[lastIndex];
    moveSpeedMul.removeLast();
    actionSpeedBp.removeLast();
  }
}
