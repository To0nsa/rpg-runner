import '../../combat/faction.dart';
import '../../snapshots/enums.dart';
import '../../tuning/v0_ability_tuning.dart';
import '../../tuning/v0_movement_tuning.dart';
import '../entity_id.dart';
import '../stores/hitbox_store.dart';
import '../stores/lifetime_store.dart';
import '../world.dart';

class MeleeSystem {
  const MeleeSystem({
    required this.abilities,
    required this.movement,
  });

  final V0AbilityTuningDerived abilities;
  final V0MovementTuningDerived movement;

  void step(EcsWorld world, {required EntityId player}) {
    _updateHitboxTransforms(world);
    _trySpawnPlayerMelee(world, player: player);
  }

  void _trySpawnPlayerMelee(EcsWorld world, {required EntityId player}) {
    if (!world.playerInput.has(player)) return;
    if (!world.transform.has(player)) return;
    if (!world.movement.has(player)) return;
    if (!world.stamina.has(player)) return;
    if (!world.cooldown.has(player)) return;

    final ii = world.playerInput.indexOf(player);
    if (!world.playerInput.attackPressed[ii]) return;

    final si = world.stamina.indexOf(player);
    if (world.stamina.stamina[si] < abilities.base.meleeStaminaCost) return;

    final ci = world.cooldown.indexOf(player);
    if (world.cooldown.meleeCooldownTicksLeft[ci] > 0) return;

    final mi = world.movement.indexOf(player);
    final facing = world.movement.facing[mi];
    final dirX = (facing == Facing.right) ? 1.0 : -1.0;

    final halfX = abilities.base.meleeHitboxSizeX * 0.5;
    final halfY = abilities.base.meleeHitboxSizeY * 0.5;

    // origin = playerPos + aimDir * (playerRadius * 0.5) for casts
    // melee uses facing-only:
    // center = playerPos + dirX * (playerRadius * 0.5 + halfX)
    final forward = movement.base.playerRadius * 0.5 + halfX;
    final offsetX = dirX * forward;
    const offsetY = 0.0;

    final ti = world.transform.indexOf(player);
    final hitX = world.transform.posX[ti] + offsetX;
    final hitY = world.transform.posY[ti] + offsetY;

    final hitbox = world.createEntity();
    world.transform.add(hitbox, posX: hitX, posY: hitY, velX: 0.0, velY: 0.0);
    world.hitbox.add(
      hitbox,
      HitboxDef(
        owner: player,
        faction: Faction.player,
        damage: abilities.base.meleeDamage,
        halfX: halfX,
        halfY: halfY,
        offsetX: offsetX,
        offsetY: offsetY,
      ),
    );
    world.hitOnce.add(hitbox);
    world.lifetime.add(hitbox, LifetimeDef(ticksLeft: abilities.meleeActiveTicks));

    world.cooldown.meleeCooldownTicksLeft[ci] = abilities.meleeCooldownTicks;
    world.stamina.stamina[si] -= abilities.base.meleeStaminaCost;
  }

  void _updateHitboxTransforms(EcsWorld world) {
    final hitboxes = world.hitbox;
    for (var hi = 0; hi < hitboxes.denseEntities.length; hi += 1) {
      final e = hitboxes.denseEntities[hi];
      if (!world.transform.has(e)) continue;

      final owner = hitboxes.owner[hi];
      if (!world.transform.has(owner)) continue;

      final ownerTi = world.transform.indexOf(owner);
      final x = world.transform.posX[ownerTi] + hitboxes.offsetX[hi];
      final y = world.transform.posY[ownerTi] + hitboxes.offsetY[hi];

      world.transform.setPosXY(e, x, y);
    }
  }
}
