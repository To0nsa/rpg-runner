import '../../util/double_math.dart';
import '../../weapons/ranged_weapon_catalog.dart';
import '../../weapons/spawn_ranged_weapon_projectile.dart';
import '../world.dart';
import '../../projectiles/projectile_catalog.dart';

/// Executes [RangedWeaponIntentStore] intents by spawning weapon projectiles and
/// managing costs (stamina + cooldowns).
class RangedWeaponSystem {
  RangedWeaponSystem({
    required this.weapons,
    required this.projectiles,
  });

  final RangedWeaponCatalogDerived weapons;
  final ProjectileCatalogDerived projectiles;

  void step(EcsWorld world, {required int currentTick}) {
    final intents = world.rangedWeaponIntent;
    if (intents.denseEntities.isEmpty) return;

    final transforms = world.transform;
    final cooldowns = world.cooldown;
    final staminas = world.stamina;
    final factions = world.faction;

    final count = intents.denseEntities.length;
    for (var ii = 0; ii < count; ii += 1) {
      if (intents.tick[ii] != currentTick) continue;

      final caster = intents.denseEntities[ii];

      // Invalidate intent immediately.
      intents.tick[ii] = -1;

      final ti = transforms.tryIndexOf(caster);
      if (ti == null) continue;

      // Cannot fire while stunned.
      if (world.controlLock.isStunned(caster, currentTick)) continue;

      final ci = cooldowns.tryIndexOf(caster);
      if (ci == null) continue;
      if (cooldowns.rangedWeaponCooldownTicksLeft[ci] > 0) continue;

      final fi = factions.tryIndexOf(caster);
      if (fi == null) continue;
      final faction = factions.faction[fi];

      final weaponId = intents.weaponId[ii];
      final weapon = weapons.base.get(weaponId);

      // Stamina check.
      // ignore: deprecated_member_use_from_same_package
      final staminaCost = weapon.legacyStaminaCost;
      int? si;
      double? nextStamina;
      if (staminaCost > 0.0) {
        si = staminas.tryIndexOf(caster);
        if (si == null) continue;
        final currentStamina = staminas.stamina[si];
        if (currentStamina < staminaCost) continue;
        nextStamina = currentStamina - staminaCost;
      }

      spawnRangedWeaponProjectileFromCaster(
        world,
        projectiles: projectiles,
        projectileId: weapon.projectileId,
        faction: faction,
        owner: caster,
        casterX: transforms.posX[ti],
        casterY: transforms.posY[ti],
        originOffset: intents.originOffset[ii],
        dirX: intents.dirX[ii],
        dirY: intents.dirY[ii],
        fallbackDirX: intents.fallbackDirX[ii],
        fallbackDirY: intents.fallbackDirY[ii],
        // ignore: deprecated_member_use_from_same_package
        damage: weapon.legacyDamage,
        damageType: weapon.damageType,
        statusProfileId: weapon.statusProfileId,
        ballistic: weapon.ballistic,
        gravityScale: weapon.gravityScale,
      );

      // Apply stamina cost.
      if (si != null) {
        staminas.stamina[si] =
            clampDouble(nextStamina!, 0.0, staminas.staminaMax[si]);
      }
      cooldowns.rangedWeaponCooldownTicksLeft[ci] =
          weapons.cooldownTicks(weaponId);
    }
  }
}
