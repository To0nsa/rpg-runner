import '../interactions/world_interaction_catalog.dart';

/// Persistent interaction projection. A newly mounted view can reconstruct the
/// lit state without receiving the original activation event. Frame selection
/// is frozen by Core during pause/death, independently of renderer frame time.
final class WorldInteractionSnapshot {
  const WorldInteractionSnapshot({
    required this.instanceId,
    required this.interactionId,
    required this.x,
    required this.y,
    required this.scale,
    required this.zIndex,
    required this.active,
    required this.elapsedTicks,
  });

  final String instanceId;
  final WorldInteractionId interactionId;

  /// World-space midpoint of the activation surface, in world units.
  final double x, y;
  final double scale;
  final int zIndex;
  final bool active;
  final int elapsedTicks;
}
