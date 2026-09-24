import '../../abilities/ability_def.dart';
import '../../util/fixed_math.dart';
import '../combat_target.dart';
import '../entity_id.dart';
import '../world.dart';

/// Common pre-commit gates for autonomous melee and ranged decisions.
bool canCommitAiAbility(
  EcsWorld world,
  EntityId actor, {
  required int currentTick,
  required int lock,
  required int cooldownGroupId,
  required AbilityResourceCost cost,
}) =>
    isLivingCombatActor(world, actor) &&
    world.cooldown.has(actor) &&
    !world.controlLock.isStunned(actor, currentTick) &&
    !world.controlLock.isLocked(actor, lock, currentTick) &&
    !world.activeAbility.hasActiveAbility(actor) &&
    !world.cooldown.isOnCooldown(actor, cooldownGroupId) &&
    canAffordAiAbility(world, actor, cost);

bool canAffordAiAbility(
  EcsWorld world,
  EntityId actor,
  AbilityResourceCost cost,
) {
  final mana = world.mana.tryIndexOf(actor);
  final stamina = world.stamina.tryIndexOf(actor);
  final health = world.health.tryIndexOf(actor);
  return (cost.manaCost100 == 0 ||
          mana != null && world.mana.mana[mana] >= cost.manaCost100) &&
      (cost.staminaCost100 == 0 ||
          stamina != null &&
              world.stamina.stamina[stamina] >= cost.staminaCost100) &&
      (cost.healthCost100 == 0 ||
          health != null && world.health.hp[health] - cost.healthCost100 >= 1);
}

/// Applied exactly once after payload validation, never again by execution.
void spendAiAbilityCost(
  EcsWorld world,
  EntityId actor,
  AbilityResourceCost cost,
) {
  if (cost.manaCost100 > 0) {
    final i = world.mana.indexOf(actor);
    world.mana.mana[i] = clampInt(
      world.mana.mana[i] - cost.manaCost100,
      0,
      world.mana.manaMax[i],
    );
  }
  if (cost.staminaCost100 > 0) {
    final i = world.stamina.indexOf(actor);
    world.stamina.stamina[i] = clampInt(
      world.stamina.stamina[i] - cost.staminaCost100,
      0,
      world.stamina.staminaMax[i],
    );
  }
  if (cost.healthCost100 > 0) {
    final i = world.health.indexOf(actor);
    world.health.hp[i] = clampInt(
      world.health.hp[i] - cost.healthCost100,
      1,
      world.health.hpMax[i],
    );
  }
}
