import '../../../combat/status/status.dart';
import '../../entity_id.dart';
import '../../sparse_set.dart';

class StatusImmunityMask {
  const StatusImmunityMask._();

  static const int dot = 1 << 0;
  static const int slow = 1 << 1;
  static const int stun = 1 << 2;
  static const int haste = 1 << 3;
  static const int vulnerable = 1 << 4;
  static const int weaken = 1 << 5;
  static const int silence = 1 << 6;
  static const int resourceOverTime = 1 << 7;
  static int forType(StatusEffectType type) {
    switch (type) {
      case StatusEffectType.dot:
        return dot;
      case StatusEffectType.slow:
        return slow;
      case StatusEffectType.stun:
        return stun;
      case StatusEffectType.haste:
        return haste;
      case StatusEffectType.vulnerable:
        return vulnerable;
      case StatusEffectType.weaken:
        return weaken;
      case StatusEffectType.silence:
        return silence;
      case StatusEffectType.resourceOverTime:
        return resourceOverTime;
    }
  }
}

class StatusImmunityDef {
  const StatusImmunityDef({this.mask = 0});

  final int mask;
}

/// Per-entity status immunities (bitmask of [StatusEffectType]).
class StatusImmunityStore extends SparseSet {
  final List<int> mask = <int>[];

  void add(
    EntityId entity, [
    StatusImmunityDef def = const StatusImmunityDef(),
  ]) {
    final i = addEntity(entity);
    mask[i] = def.mask;
  }

  bool isImmune(EntityId entity, StatusEffectType type) {
    final i = tryIndexOf(entity);
    if (i == null) return false;
    return (mask[i] & StatusImmunityMask.forType(type)) != 0;
  }

  @override
  void onDenseAdded(int denseIndex) {
    mask.add(0);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    mask[removeIndex] = mask[lastIndex];
    mask.removeLast();
  }
}
