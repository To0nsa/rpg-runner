import '../../combat/ai_target_policy.dart';
import '../../npcs/npc_guard_region.dart';
import '../entity_id.dart';
import '../stores/ai_target_store.dart';
import '../stores/hitbox_store.dart';
import '../world.dart';
import 'ability_interrupt.dart';

/// Makes a survivor safe while retaining its body, terrain state and identity.
void protectNpc(EcsWorld world, EntityId entity) {
  final i = world.npc.tryIndexOf(entity);
  if (i == null || world.npc.protected[i]) return;
  world.npc.protected[i] = true;
  world.npc.guardRegion[i] = null;
  stopNpcCombat(world, entity);
  world.dot.removeEntity(entity);
  world.slow.removeEntity(entity);
  world.weaken.removeEntity(entity);
  world.vulnerable.removeEntity(entity);
  world.drench.removeEntity(entity);
  world.controlLock.removeEntity(entity);
  final modifier = world.statModifier.tryIndexOf(entity);
  if (modifier != null) world.statModifier.moveSpeedMul[modifier] = 1;
}

/// Ends encounter attacks and admits a vulnerable survivor to its section.
/// Health, statuses, resources, cooldowns and detached effects remain unchanged.
void beginNpcGuarding(EcsWorld world, EntityId entity, NpcGuardRegion region) {
  stopNpcCombat(world, entity);
  world.npc.beginGuarding(entity, region);
  world.aiTarget.configure(
    entity,
    targetPolicy: AiTargetPolicy.nearestOpponent,
    candidates: const [],
    playerFallback: false,
    rosterOwner: AiTargetOwner.sectionGuard,
  );
}

/// Stops autonomous combat on death or resolution without touching detached effects.
void stopNpcCombat(EcsWorld world, EntityId entity) {
  world.aiTarget.removeEntity(entity);
  world.aiTarget.forget(entity);
  AbilityInterrupt.clearActiveAndTransient(
    world,
    entity: entity,
    startDeferredCooldown: false,
  );
  final ti = world.transform.tryIndexOf(entity);
  if (ti != null) world.transform.velX[ti] = 0;
  // Detached effects keep their faction, credit and normal lifetime.
  for (var h = world.hitbox.denseEntities.length - 1; h >= 0; h--) {
    if (world.hitbox.owner[h] == entity &&
        world.hitbox.attachment[h] == HitboxAttachment.followOwner) {
      world.destroyEntity(world.hitbox.denseEntities[h]);
    }
  }
}
