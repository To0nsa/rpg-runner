/// Horizontal blink bounds in world units, independent of movement speed gear.
final class BlinkMobilityDef {
  const BlinkMobilityDef({
    required this.openDistance,
    required this.maxObstacleWidth,
    required this.maxApproachDistance,
    this.exitClearance = 2,
  }) : assert(openDistance > 0),
       assert(maxObstacleWidth > 0),
       assert(maxApproachDistance >= 0),
       assert(exitClearance > 0);

  final double openDistance;
  final double maxObstacleWidth;

  /// Maximum travel before the capsule first meets an obstacle.
  final double maxApproachDistance;
  final double exitClearance;
}
