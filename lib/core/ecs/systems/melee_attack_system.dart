import '../stores/hitbox_store.dart';
import '../stores/lifetime_store.dart';
import '../world.dart';

/// Executes `MeleeIntentStore` intents by applying costs/cooldowns and spawning
/// melee hitboxes.
///
/// IMPORTANT:
/// - Only intents with `intent.tick == currentTick` are considered valid.
/// - Hitbox `faction` is derived from the attacker entity's `FactionStore`.
/// - Intents are invalidated after processing by setting `intent.tick = -1`.
class MeleeAttackSystem {
  void step(EcsWorld world, {required int currentTick}) {
    final intents = world.meleeIntent;
    if (intents.denseEntities.isEmpty) return;

    for (var ii = 0; ii < intents.denseEntities.length; ii += 1) {
      if (intents.tick[ii] != currentTick) continue;

      final attacker = intents.denseEntities[ii];

      // Invalidate now so accidental multi-pass execution in the same tick cannot
      // double-attack. (Intent is still ignored next tick due to stamp mismatch.)
      intents.tick[ii] = -1;

      if (!world.transform.has(attacker)) continue;
      if (!world.cooldown.has(attacker)) continue;

      final ci = world.cooldown.indexOf(attacker);
      if (world.cooldown.meleeCooldownTicksLeft[ci] > 0) continue;

      final fi = world.faction.tryIndexOf(attacker);
      if (fi == null) continue;
      final faction = world.faction.faction[fi];

      final staminaCost = intents.staminaCost[ii];
      int? si;
      double? nextStamina;
      if (staminaCost > 0) {
        if (!world.stamina.has(attacker)) continue;
        si = world.stamina.indexOf(attacker);
        final stamina = world.stamina.stamina[si];
        if (stamina < staminaCost) continue;
        nextStamina = stamina - staminaCost;
      }

      final attackerTi = world.transform.indexOf(attacker);
      final hitbox = world.createEntity();
      world.transform.add(
        hitbox,
        // HitboxFollowOwnerSystem will position from `owner + offset`.
        posX: world.transform.posX[attackerTi],
        posY: world.transform.posY[attackerTi],
        velX: 0.0,
        velY: 0.0,
      );
      world.hitbox.add(
        hitbox,
        HitboxDef(
          owner: attacker,
          faction: faction,
          damage: intents.damage[ii],
          halfX: intents.halfX[ii],
          halfY: intents.halfY[ii],
          offsetX: intents.offsetX[ii],
          offsetY: intents.offsetY[ii],
          dirX: intents.dirX[ii],
          dirY: intents.dirY[ii],
        ),
      );
      world.hitOnce.add(hitbox);
      world.lifetime.add(
        hitbox,
        LifetimeDef(ticksLeft: intents.activeTicks[ii]),
      );

      if (si != null) {
        world.stamina.stamina[si] = nextStamina!;
      }
      world.cooldown.meleeCooldownTicksLeft[ci] = intents.cooldownTicks[ii];
    }
  }
}
