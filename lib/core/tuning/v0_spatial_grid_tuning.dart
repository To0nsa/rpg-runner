/// Simulation tuning/config for grid-based spatial indexing (broadphase now,
/// navigation later).
///
/// Keep this separate from combat tuning: broadphase is a physics/simulation
/// concern, not a combat rule.
class V0SpatialGridTuning {
  const V0SpatialGridTuning({
    this.broadphaseCellSize = v0BroadphaseCellSize,
  });

  /// Default broadphase cell size for dynamic AABB queries.
  ///
  /// With current V0 collider sizes (player ~16x16, enemies ~24x24), `32.0`
  /// keeps candidate sets small while keeping grid math cheap.
  static const double v0BroadphaseCellSize = 32.0;

  final double broadphaseCellSize;
}

