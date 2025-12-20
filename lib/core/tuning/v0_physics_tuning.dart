/// V0 global physics tuning for the Core simulation.
///
/// This is intentionally separate from movement/ability/combat tunings so it can
/// evolve into per-level/biome physics profiles later (e.g. low-gravity zones).
class V0PhysicsTuning {
  const V0PhysicsTuning({
    this.gravityY = 1200,
  });

  /// Gravity acceleration (positive is downward), in world units / second^2.
  final double gravityY;
}

