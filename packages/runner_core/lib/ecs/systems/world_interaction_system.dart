import '../../interactions/world_interaction_catalog.dart';
import '../entity_id.dart';
import '../world.dart';

/// Runs after movement and death resolution, before resource regeneration.
/// Only final, current-version player support can activate a top interaction;
/// side/airborne contacts and enemies never grant a blessing. It does not use
/// trap camera gates, damage cycles, cooldowns, or renderer callbacks.
final class WorldInteractionSystem {
  const WorldInteractionSystem();

  void step(
    EcsWorld world, {
    required EntityId player,
    required int tick,
    required int? geometryVersion,
  }) {
    final hi = world.health.tryIndexOf(player);
    if (hi == null ||
        world.health.hp[hi] <= 0 ||
        world.deathState.has(player)) {
      return;
    }
    final contact = world.terrainContact;
    final ci = contact.tryIndexOf(player);
    final supported =
        ci != null &&
        geometryVersion != null &&
        contact.grounded[ci] &&
        contact.supportGeometryVersion[ci] == geometryVersion &&
        contact.lastValidSupportTick[ci] == tick &&
        contact.supportNormalYTicks[ci] < 0;
    for (final state in world.interactions.states) {
      if (state.activationTick == null && supported) {
        final edge = contact.supportEdgeId[ci];
        if (edge != null &&
            edge.chunkIndex == state.chunkIndex &&
            edge.chunkKey == state.binding.chunkKey &&
            edge.placementKey == state.placementKey &&
            edge.shapeId == state.binding.shapeId &&
            contact.supportPointYTicks[ci] == state.topTicks &&
            contact.supportPointXTicks[ci] >= state.leftTicks &&
            contact.supportPointXTicks[ci] <= state.rightTicks) {
          world.interactions.activate(state, tick);
          world.levelBlessings.grant(
            player,
            WorldInteractionDefinition.get(state.binding.interactionId)
                .blessing,
            tick: tick,
          );
        }
      }
      final activated = state.activationTick;
      if (activated != null) state.elapsedTicks = tick - activated;
    }
  }
}
