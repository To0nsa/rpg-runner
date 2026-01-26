import '../../abilities/ability_def.dart';
import '../../snapshots/enums.dart';
import '../../util/fixed_math.dart';
import '../stores/self_intent_store.dart';
import '../world.dart';

/// Executes self abilities (parry, block, buffs) that have no hitbox/projectile.
///
/// Responsibilities:
/// - Validate cooldowns and resource costs at commit.
/// - Start cooldown + ActiveAbility state on commit.
/// - Optionally apply effects at execute tick (future).
class SelfAbilitySystem {
  void step(EcsWorld world, {required int currentTick}) {
    final intents = world.selfIntent;
    if (intents.denseEntities.isEmpty) return;

    final cooldowns = world.cooldown;
    final manas = world.mana;
    final staminas = world.stamina;
    final movements = world.movement;

    final count = intents.denseEntities.length;
    for (var ii = 0; ii < count; ii += 1) {
      final entity = intents.denseEntities[ii];
      final commitTick = intents.commitTick[ii];
      final executeTick = intents.tick[ii];

      if (commitTick == currentTick) {
        if (world.controlLock.isStunned(entity, currentTick)) {
          _invalidateIntent(intents, ii);
          continue;
        }

        final ci = cooldowns.tryIndexOf(entity);
        if (ci == null) {
          _invalidateIntent(intents, ii);
          continue;
        }
        final slot = intents.slot[ii];
        final cooldownLeft = slot == AbilitySlot.projectile
            ? cooldowns.projectileCooldownTicksLeft[ci]
            : cooldowns.meleeCooldownTicksLeft[ci];
        if (cooldownLeft > 0) {
          _invalidateIntent(intents, ii);
          continue;
        }

        int? mi;
        int currentMana = 0;
        final manaCost = intents.manaCost100[ii];
        if (manaCost > 0) {
          mi = manas.tryIndexOf(entity);
          if (mi == null) {
            _invalidateIntent(intents, ii);
            continue;
          }
          currentMana = manas.mana[mi];
          if (currentMana < manaCost) {
            _invalidateIntent(intents, ii);
            continue;
          }
        }

        int? si;
        int currentStamina = 0;
        final staminaCost = intents.staminaCost100[ii];
        if (staminaCost > 0) {
          si = staminas.tryIndexOf(entity);
          if (si == null) {
            _invalidateIntent(intents, ii);
            continue;
          }
          currentStamina = staminas.stamina[si];
          if (currentStamina < staminaCost) {
            _invalidateIntent(intents, ii);
            continue;
          }
        }

        if (mi != null) {
          final max = manas.manaMax[mi];
          manas.mana[mi] = clampInt(currentMana - manaCost, 0, max);
        }
        if (si != null) {
          final max = staminas.staminaMax[si];
          staminas.stamina[si] = clampInt(
            currentStamina - staminaCost,
            0,
            max,
          );
        }

        if (slot == AbilitySlot.projectile) {
          cooldowns.projectileCooldownTicksLeft[ci] = intents.cooldownTicks[ii];
        } else {
          cooldowns.meleeCooldownTicksLeft[ci] = intents.cooldownTicks[ii];
        }

        final miIndex = movements.tryIndexOf(entity);
        final facing = miIndex == null
            ? Facing.right
            : movements.facing[miIndex];

        world.activeAbility.set(
          entity,
          id: intents.abilityId[ii],
          slot: slot,
          commitTick: currentTick,
          windupTicks: intents.windupTicks[ii],
          activeTicks: intents.activeTicks[ii],
          recoveryTicks: intents.recoveryTicks[ii],
          facingDir: facing,
        );
      }

      if (executeTick != currentTick) continue;

      _invalidateIntent(intents, ii);
    }
  }

  void _invalidateIntent(SelfIntentStore intents, int index) {
    intents.tick[index] = -1;
    intents.commitTick[index] = -1;
  }
}
