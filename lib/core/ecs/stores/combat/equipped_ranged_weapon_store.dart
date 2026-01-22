import '../../../weapons/ranged_weapon_id.dart';
import '../../entity_id.dart';
import '../../sparse_set.dart';

class EquippedRangedWeaponDef {
  const EquippedRangedWeaponDef({this.weaponId = RangedWeaponId.throwingKnife});

  final RangedWeaponId weaponId;
}

/// Per-entity equipped ranged weapon (bow, throwing axe, ...).
class EquippedRangedWeaponStore extends SparseSet {
  final List<RangedWeaponId> weaponId = <RangedWeaponId>[];

  void add(
    EntityId entity, [
    EquippedRangedWeaponDef def = const EquippedRangedWeaponDef(),
  ]) {
    final i = addEntity(entity);
    weaponId[i] = def.weaponId;
  }

  @override
  void onDenseAdded(int denseIndex) {
    weaponId.add(RangedWeaponId.throwingKnife);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    weaponId[removeIndex] = weaponId[lastIndex];
    weaponId.removeLast();
  }
}

