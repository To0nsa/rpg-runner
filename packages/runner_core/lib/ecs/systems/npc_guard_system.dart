import '../../combat/ai_target_policy.dart';
import '../combat_target.dart';
import '../entity_id.dart';
import '../stores/ai_target_store.dart';
import '../world.dart';

/// Refreshes section guard rosters before the shared once-per-tick target selection.
///
/// Guards discover current enemy positions, never source/group identity. Ordinary
/// enemies may retaliate with player fallback; active encounter policies keep
/// ownership of their explicit rosters. Streaming and culling stay unchanged.
final class NpcGuardSystem {
  final List<EntityId> _guards = [];
  final List<EntityId> _enemies = [];
  final List<EntityId> _candidates = [];

  void step(EcsWorld world) {
    _guards.clear();
    for (var i = 0; i < world.npc.denseEntities.length; i++) {
      final actor = world.npc.denseEntities[i];
      if (world.npc.guardRegion[i] != null &&
          isLivingCombatActor(world, actor)) {
        _guards.add(actor);
      }
    }
    if (_guards.isEmpty) {
      for (var i = world.aiTarget.denseEntities.length - 1; i >= 0; i--) {
        if (world.aiTarget.owner[i] == AiTargetOwner.sectionGuard &&
            world.enemy.has(world.aiTarget.denseEntities[i])) {
          world.aiTarget.removeEntity(world.aiTarget.denseEntities[i]);
        }
      }
      return;
    }
    _guards.sort();
    _enemies.clear();
    for (final enemy in world.enemy.denseEntities) {
      if (isLivingCombatActor(world, enemy)) _enemies.add(enemy);
    }
    _enemies.sort();
    for (final guard in _guards) {
      final region = world.npc.guardRegion[world.npc.indexOf(guard)]!;
      _candidates.clear();
      for (final enemy in _enemies) {
        if (region.contains(
          world.transform.posX[world.transform.indexOf(enemy)],
        )) {
          _candidates.add(enemy);
        }
      }
      world.aiTarget.refreshCandidates(guard, _candidates);
    }
    // Walk backwards: releasing guard-owned targets swap-removes store entries.
    for (var i = world.aiTarget.denseEntities.length - 1; i >= 0; i--) {
      final actor = world.aiTarget.denseEntities[i];
      if (world.aiTarget.owner[i] == AiTargetOwner.sectionGuard &&
          world.enemy.has(actor) &&
          !isLivingCombatActor(world, actor)) {
        world.aiTarget.removeEntity(actor);
      }
    }
    for (final enemy in _enemies) {
      final targetIndex = world.aiTarget.tryIndexOf(enemy);
      if (targetIndex != null &&
          world.aiTarget.owner[targetIndex] != AiTargetOwner.sectionGuard) {
        continue;
      }
      final x = world.transform.posX[world.transform.indexOf(enemy)];
      _candidates.clear();
      for (final guard in _guards) {
        if (world.npc.guardRegion[world.npc.indexOf(guard)]!.contains(x)) {
          _candidates.add(guard);
        }
      }
      if (_candidates.isEmpty) {
        if (targetIndex != null) world.aiTarget.removeEntity(enemy);
      } else if (targetIndex != null) {
        world.aiTarget.refreshCandidates(enemy, _candidates);
      } else {
        world.aiTarget.configure(
          enemy,
          targetPolicy: AiTargetPolicy.nearestOpponent,
          candidates: _candidates,
          rosterOwner: AiTargetOwner.sectionGuard,
        );
      }
    }
  }
}
