import '../../../weapons/weapon_id.dart';
import '../../entity_id.dart';
import '../../sparse_set.dart';

class EquippedWeaponDef {
  const EquippedWeaponDef({this.weaponId = WeaponId.basicSword});

  final WeaponId weaponId;
}

/// Per-entity equipped weapon (for melee intent writers).
class EquippedWeaponStore extends SparseSet {
  final List<WeaponId> weaponId = <WeaponId>[];

  void add(EntityId entity, [EquippedWeaponDef def = const EquippedWeaponDef()]) {
    final i = addEntity(entity);
    weaponId[i] = def.weaponId;
  }

  @override
  void onDenseAdded(int denseIndex) {
    weaponId.add(WeaponId.basicSword);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    weaponId[removeIndex] = weaponId[lastIndex];
    weaponId.removeLast();
  }
}

