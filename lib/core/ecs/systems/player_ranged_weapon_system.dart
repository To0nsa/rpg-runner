import '../../snapshots/enums.dart';
import '../../weapons/ranged_weapon_catalog.dart';
import '../entity_id.dart';
import '../stores/ranged_weapon_intent_store.dart';
import '../world.dart';

/// Translates player input into a [RangedWeaponIntentDef] for the
/// [RangedWeaponAttackSystem].
class PlayerRangedWeaponSystem {
  const PlayerRangedWeaponSystem({required this.weapons});

  final RangedWeaponCatalog weapons;

  void step(
    EcsWorld world, {
    required EntityId player,
    required int currentTick,
  }) {
    // We need input to know if firing.
    final inputIndex = world.playerInput.tryIndexOf(player);
    if (inputIndex == null) return;

    // Facing direction is used as fallback aim.
    final movementIndex = world.movement.tryIndexOf(player);
    if (movementIndex == null) return;

    if (!world.rangedWeaponIntent.has(player)) {
      assert(
        false,
        'PlayerRangedWeaponSystem requires RangedWeaponIntentStore on the player; add it at spawn time.',
      );
      return;
    }

    final equippedIndex = world.equippedRangedWeapon.tryIndexOf(player);
    if (equippedIndex == null) {
      assert(
        false,
        'PlayerRangedWeaponSystem requires EquippedRangedWeaponStore on the player; add it at spawn time.',
      );
      return;
    }

    if (!world.playerInput.rangedPressed[inputIndex]) return;

    final weaponId = world.equippedRangedWeapon.weaponId[equippedIndex];
    final weapon = weapons.get(weaponId);

    final facing = world.movement.facing[movementIndex];
    final fallbackDirX = facing == Facing.right ? 1.0 : -1.0;

    world.rangedWeaponIntent.set(
      player,
      RangedWeaponIntentDef(
        weaponId: weaponId,
        dirX: world.playerInput.rangedAimDirX[inputIndex],
        dirY: world.playerInput.rangedAimDirY[inputIndex],
        fallbackDirX: fallbackDirX,
        fallbackDirY: 0.0,
        originOffset: weapon.originOffset,
        tick: currentTick,
      ),
    );
  }
}

