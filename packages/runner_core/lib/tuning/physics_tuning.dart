/// Global physics tuning for the Core simulation.
///
/// This is intentionally separate from movement/ability/combat tunings so it can
/// evolve into per-level/biome physics profiles later (e.g. low-gravity zones).
class FixedPointPilotTuning {
  const FixedPointPilotTuning({
    this.enabled = false,
    this.subpixelScale = 1024,
  }) : assert(subpixelScale > 0);

  /// Enables fixed-point quantization in selected motion/collision paths.
  final bool enabled;

  /// Quantization scale for world units when pilot mode is enabled.
  final int subpixelScale;
}

class PhysicsTuning {
  const PhysicsTuning({
    this.gravityY = 1200,
    this.fixedPointPilot = const FixedPointPilotTuning(),
  });

  /// Gravity acceleration (positive is downward), in world units / second^2.
  final double gravityY;

  /// Optional fixed-point pilot configuration (default-off).
  final FixedPointPilotTuning fixedPointPilot;
}

