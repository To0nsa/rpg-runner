import '../../snapshots/enums.dart';
import '../../spells/spell_id.dart';
import '../../tuning/v0_ability_tuning.dart';
import '../../tuning/v0_movement_tuning.dart';
import '../entity_id.dart';
import '../stores/cast_intent_store.dart';
import '../world.dart';

class PlayerCastSystem {
  const PlayerCastSystem({
    required this.abilities,
    required this.movement,
  });

  final V0AbilityTuningDerived abilities;
  final V0MovementTuningDerived movement;

  void step(EcsWorld world, {required EntityId player, required int currentTick}) {
    if (!world.playerInput.has(player) ||
        !world.transform.has(player) ||
        !world.movement.has(player)) {
      return;
    }
    if (!world.castIntent.has(player)) {
      assert(
        false,
        'PlayerCastSystem requires CastIntentStore on the player; add it at spawn time.',
      );
      return;
    }

    final ii = world.playerInput.indexOf(player);
    if (!world.playerInput.castPressed[ii]) return;

    const spellId = SpellId.iceBolt;

    // final ti = world.transform.indexOf(player);
    final facing = world.movement.facing[world.movement.indexOf(player)];

    final rawAimX = world.playerInput.projectileAimDirX[ii];
    final rawAimY = world.playerInput.projectileAimDirY[ii];

    final spawnOffset = movement.base.playerRadius * 0.5;
    final fallbackDirX = facing == Facing.right ? 1.0 : -1.0;

    // IMPORTANT: PlayerCastSystem writes intent only; execution happens in
    // `SpellCastSystem` which owns mana/cooldown rules and projectile spawning.
    world.castIntent.set(
      player,
      CastIntentDef(
        spellId: spellId,
        dirX: rawAimX,
        dirY: rawAimY,
        fallbackDirX: fallbackDirX,
        fallbackDirY: 0.0,
        originOffset: spawnOffset,
        cooldownTicks: abilities.castCooldownTicks,
        tick: currentTick,
      ),
    );
  }
}
