import '../../weapons/ranged_weapon_id.dart';
import '../entity_id.dart';
import '../sparse_set.dart';

class RangedWeaponIntentDef {
  const RangedWeaponIntentDef({
    required this.weaponId,
    required this.dirX,
    required this.dirY,
    required this.fallbackDirX,
    required this.fallbackDirY,
    required this.originOffset,
    required this.tick,
  });

  final RangedWeaponId weaponId;
  final double dirX;
  final double dirY;
  final double fallbackDirX;
  final double fallbackDirY;
  final double originOffset;

  /// Tick stamp for this intent.
  ///
  /// Use `-1` for "no intent". An intent is valid only when `tick == currentTick`.
  final int tick;
}

/// Per-entity "fire a ranged weapon this tick" intent.
///
/// Written by player input and consumed by `RangedWeaponSystem`.
class RangedWeaponIntentStore extends SparseSet {
  final List<RangedWeaponId> weaponId = <RangedWeaponId>[];
  final List<double> dirX = <double>[];
  final List<double> dirY = <double>[];
  final List<double> fallbackDirX = <double>[];
  final List<double> fallbackDirY = <double>[];
  final List<double> originOffset = <double>[];
  final List<int> tick = <int>[];

  void add(EntityId entity) {
    addEntity(entity);
  }

  void set(EntityId entity, RangedWeaponIntentDef def) {
    assert(
      has(entity),
      'RangedWeaponIntentStore.set called for entity without RangedWeaponIntentStore; add the component at spawn time.',
    );
    final i = indexOf(entity);
    weaponId[i] = def.weaponId;
    dirX[i] = def.dirX;
    dirY[i] = def.dirY;
    fallbackDirX[i] = def.fallbackDirX;
    fallbackDirY[i] = def.fallbackDirY;
    originOffset[i] = def.originOffset;
    tick[i] = def.tick;
  }

  @override
  void onDenseAdded(int denseIndex) {
    weaponId.add(RangedWeaponId.throwingKnife);
    dirX.add(0.0);
    dirY.add(0.0);
    fallbackDirX.add(1.0);
    fallbackDirY.add(0.0);
    originOffset.add(0.0);
    tick.add(-1);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    weaponId[removeIndex] = weaponId[lastIndex];
    dirX[removeIndex] = dirX[lastIndex];
    dirY[removeIndex] = dirY[lastIndex];
    fallbackDirX[removeIndex] = fallbackDirX[lastIndex];
    fallbackDirY[removeIndex] = fallbackDirY[lastIndex];
    originOffset[removeIndex] = originOffset[lastIndex];
    tick[removeIndex] = tick[lastIndex];

    weaponId.removeLast();
    dirX.removeLast();
    dirY.removeLast();
    fallbackDirX.removeLast();
    fallbackDirY.removeLast();
    originOffset.removeLast();
    tick.removeLast();
  }
}

