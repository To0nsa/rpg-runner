import '../../combat/ai_target_policy.dart';
import '../../npcs/npc_guard_region.dart';
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
  final Map<(int, int, double, double), _GuardSection> _sections = {};

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
      _sections.clear();
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
    for (final section in _sections.values) {
      section.guards.clear();
      section.enemies.clear();
    }
    for (final guard in _guards) {
      final region = world.npc.guardRegion[world.npc.indexOf(guard)]!;
      final section = _sections.putIfAbsent((
        region.firstChunkIndex,
        region.chunkCount,
        region.minX,
        region.maxX,
      ), () => _GuardSection(region));
      section.guards.add(guard);
    }
    _sections.removeWhere((_, section) => section.guards.isEmpty);
    for (final section in _sections.values) {
      for (final enemy in _enemies) {
        if (section.region.contains(
          world.transform.posX[world.transform.indexOf(enemy)],
        )) {
          section.enemies.add(enemy);
        }
      }
      for (final guard in section.guards) {
        world.aiTarget.refreshCandidates(guard, section.enemies);
      }
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
      var matchingSections = 0;
      for (final section in _sections.values) {
        if (section.region.contains(x)) {
          _candidates.addAll(section.guards);
          matchingSections++;
        }
      }
      // Overlapping territories must retain the same global entity-ID order.
      if (matchingSections > 1) _candidates.sort();
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

final class _GuardSection {
  _GuardSection(this.region);
  final NpcGuardRegion region;
  final List<EntityId> guards = [];
  final List<EntityId> enemies = [];
}
