import '../../combat/ai_target_policy.dart';
import '../combat_target.dart';
import '../entity_id.dart';
import '../world.dart';

/// Selects within explicit rosters, then retains a valid same-priority target.
final class AiTargetSystem {
  void step(EcsWorld world, {required EntityId player}) {
    final targets = world.aiTarget;
    for (var i = 0; i < targets.denseEntities.length; i++) {
      final actor = targets.denseEntities[i];
      if (!isLivingCombatActor(world, actor)) {
        targets.selected[i] = null;
        continue;
      }
      final at = world.transform.indexOf(actor);
      final actorFaction = world.faction.tryIndexOf(actor);
      final policy = targets.policy[i];
      EntityId? best;
      var bestTier = 2;
      var bestDistance = double.infinity;
      var retainedTier = 2;
      final retained = targets.selected[i];
      void consider(EntityId candidate, {required bool isPlayer}) {
        if (!isLivingCombatActor(world, candidate)) return;
        final cf = world.faction.tryIndexOf(candidate);
        if (actorFaction != null &&
            cf != null &&
            world.faction.faction[actorFaction] == world.faction.faction[cf]) {
          return;
        }
        final ct = world.transform.indexOf(candidate);
        final dx = world.transform.posX[ct] - world.transform.posX[at];
        final dy = world.transform.posY[ct] - world.transform.posY[at];
        final distance = dx * dx + dy * dy;
        if (!isPlayer && distance > targets.perceptionSquared[i]) return;
        final rejected = targets.unreachable[i][candidate];
        if (rejected != null) {
          if (rejected == targetNavigationEvidence(world, actor, candidate)) {
            return;
          }
          targets.unreachable[i].remove(candidate);
        }
        final tier = isPlayer && policy == AiTargetPolicy.preferEncounterNpcs
            ? 1
            : 0;
        if (candidate == retained) retainedTier = tier;
        if (tier < bestTier ||
            (tier == bestTier &&
                (distance < bestDistance ||
                    (distance == bestDistance && candidate < best!)))) {
          best = candidate;
          bestTier = tier;
          bestDistance = distance;
        }
      }

      if (targets.includePlayer[i]) consider(player, isPlayer: true);
      if (policy != AiTargetPolicy.playerOnly) {
        for (final opponent in targets.opponents[i]) {
          if (opponent != player) consider(opponent, isPlayer: false);
        }
      }
      targets.selected[i] =
          retained != null && retainedTier <= bestTier && retainedTier < 2
          ? retained
          : best;
    }
  }
}
