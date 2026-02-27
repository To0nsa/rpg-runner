import '../../entity_id.dart';
import '../../sparse_set.dart';

class OffenseBuffDef {
  const OffenseBuffDef({
    required this.ticksLeft,
    required this.powerBonusBp,
    required this.critBonusBp,
  });

  final int ticksLeft;

  /// Basis points (100 = 1%) added to outgoing base damage in payload build.
  final int powerBonusBp;

  /// Basis points (100 = 1%) added to outgoing crit chance in payload build.
  final int critBonusBp;
}

/// Active offensive buff status (power + crit chance).
class OffenseBuffStore extends SparseSet {
  final List<int> ticksLeft = <int>[];

  /// Basis points (100 = 1%) added to outgoing base damage in payload build.
  final List<int> powerBonusBp = <int>[];

  /// Basis points (100 = 1%) added to outgoing crit chance in payload build.
  final List<int> critBonusBp = <int>[];

  void add(EntityId entity, OffenseBuffDef def) {
    final i = addEntity(entity);
    ticksLeft[i] = def.ticksLeft;
    powerBonusBp[i] = def.powerBonusBp;
    critBonusBp[i] = def.critBonusBp;
  }

  @override
  void onDenseAdded(int denseIndex) {
    ticksLeft.add(0);
    powerBonusBp.add(0);
    critBonusBp.add(0);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    ticksLeft[removeIndex] = ticksLeft[lastIndex];
    powerBonusBp[removeIndex] = powerBonusBp[lastIndex];
    critBonusBp[removeIndex] = critBonusBp[lastIndex];
    ticksLeft.removeLast();
    powerBonusBp.removeLast();
    critBonusBp.removeLast();
  }
}
