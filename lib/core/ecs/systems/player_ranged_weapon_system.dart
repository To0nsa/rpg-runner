import '../../snapshots/enums.dart';
import '../../weapons/ranged_weapon_catalog.dart';
import '../entity_id.dart';
import '../stores/ranged_weapon_intent_store.dart';
import '../world.dart';
import 'dart:math';

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

    final actionAnimIndex = world.actionAnim.tryIndexOf(player);
    if (actionAnimIndex == null) {
      assert(
        false,
        'PlayerRangedWeaponSystem requires ActionAnimStore on the player; add it at spawn time.',
      );
      return;
    }

    final weaponId = world.equippedRangedWeapon.weaponId[equippedIndex];
    final weapon = weapons.get(weaponId);

    final facing = world.movement.facing[movementIndex];
    final fallbackDirX = facing == Facing.right ? 1.0 : -1.0;

    final aimX = world.playerInput.rangedAimDirX[inputIndex];
    final aimY = world.playerInput.rangedAimDirY[inputIndex];
    final len2 = aimX * aimX + aimY * aimY;
    final double dirX;
    //final double dirY;
    if (len2 > 1e-12) {
      final invLen = 1.0 / sqrt(len2);
      dirX = aimX * invLen;
      //dirY = aimY * invLen;
    } else {
      dirX = fallbackDirX;
      //dirY = 0.0;
    }

    // Visuals: face along the throw direction when firing.
    if (dirX.abs() > 1e-6) {
      world.movement.facing[movementIndex] =
          dirX >= 0 ? Facing.right : Facing.left;
    }

    world.rangedWeaponIntent.set(
      player,
      RangedWeaponIntentDef(
        weaponId: weaponId,
        dirX: aimX,
        dirY: aimY,
        fallbackDirX: fallbackDirX,
        fallbackDirY: 0.0,
        originOffset: weapon.originOffset,
        tick: currentTick,
      ),
    );

    world.actionAnim.lastRangedTick[actionAnimIndex] = currentTick;
    world.actionAnim.lastRangedFacing[actionAnimIndex] =
        dirX >= 0 ? Facing.right : Facing.left;
  }
}
