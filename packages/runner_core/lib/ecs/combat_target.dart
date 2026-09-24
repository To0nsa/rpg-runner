import 'entity_id.dart';
import 'combat_eligibility.dart';
import 'stores/ai_target_store.dart';
import 'world.dart';

/// Identity selected once before AI; consumers never choose replacements.
EntityId? combatTarget(EcsWorld world, EntityId actor, EntityId player) {
  final index = world.aiTarget.tryIndexOf(actor);
  final target = index == null ? player : world.aiTarget.selected[index];
  return target != null && isLivingCombatActor(world, target) ? target : null;
}

bool isLivingCombatActor(EcsWorld world, EntityId actor) {
  if (isCombatProtected(world, actor)) return false;
  if (!world.transform.has(actor) || world.deathState.has(actor)) return false;
  final health = world.health.tryIndexOf(actor);
  return health == null || world.health.hp[health] > 0;
}

/// Evidence expires on support/profile changes or target movement. Walking on
/// the same disconnected support must not repeatedly reacquire a blocked target.
/// Profile identity is included because authoring Play can replace capabilities.
AiTargetNavigationEvidence targetNavigationEvidence(
  EcsWorld world,
  EntityId actor,
  EntityId target,
) {
  AiTargetSupportEvidence support(EntityId entity) {
    final c = world.terrainContact.tryIndexOf(entity);
    final p = world.terrainTraversalProfile.tryIndexOf(entity);
    return (
      c == null ? null : world.terrainContact.supportEdgeId[c],
      c == null ? -1 : world.terrainContact.supportGeometryVersion[c],
      p == null ? null : world.terrainTraversalProfile.profile[p],
    );
  }

  final t = world.transform.indexOf(target);
  return (
    support(actor),
    support(target),
    world.transform.posX[t],
    world.transform.posY[t],
  );
}
