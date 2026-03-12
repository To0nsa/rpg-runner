/// Simulation tuning/config for grid-based spatial indexing (broadphase now,
/// navigation later).
///
/// Keep this separate from combat tuning: broadphase is a physics/simulation
/// concern, not a combat rule.
class SpatialGridTuning {
  const SpatialGridTuning({
    this.broadphaseCellSize = 32.0,
  });

  /// Default broadphase cell size for dynamic AABB queries.
  ///
  /// With current collider sizes (player ~16x16, enemies ~24x24), `32.0`
  /// keeps candidate sets small while keeping grid math cheap.
  final double broadphaseCellSize;
}

