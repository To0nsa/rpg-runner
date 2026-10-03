import 'entity_render_snapshot.dart';

/// Immutable player, enemy, NPC and projectile presentation at one Core tick.
///
/// Uses the same entity projection as the full game snapshot. It omits HUD,
/// terrain, pickups and debug hitboxes for consumers that render only actors
/// and their projectiles. Creating a frame never advances gameplay or events.
class ActorFrameSnapshot {
  ActorFrameSnapshot({
    required this.tick,
    required this.distance,
    required this.gameOver,
    required Iterable<EntityRenderSnapshot> entities,
  }) : entities = List<EntityRenderSnapshot>.unmodifiable(entities);

  /// Fixed simulation tick, independent of renderer frame rate.
  final int tick;

  /// Furthest accepted horizontal progress, in world units.
  final double distance;
  final bool gameOver;
  final List<EntityRenderSnapshot> entities;
}
