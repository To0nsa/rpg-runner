/// Standard ground guides for chunk authoring; collision stays in polygons.
enum TerrainElevation { normal, raised, high }

/// A 24 px step keeps High 48 px above the usual ground, leaving room in the
/// 270 px viewport for current character bodies and the 500 px/s normal jump.
const defaultTerrainHeightStepPx = 24;
const maxTerrainHeightStepPx = 32;

/// Level-owned authoring guides in world pixels (positive Y points downward).
final class TerrainElevationPresets {
  TerrainElevationPresets({
    required this.groundTopY,
    this.stepPx = defaultTerrainHeightStepPx,
  }) {
    if (!groundTopY.isFinite || stepPx < 1 || stepPx > maxTerrainHeightStepPx) {
      throw ArgumentError(
        'Terrain elevation requires finite ground and a 1-$maxTerrainHeightStepPx px step.',
      );
    }
  }

  final double groundTopY;
  final int stepPx;

  double yFor(TerrainElevation elevation) =>
      groundTopY - elevation.index * stepPx;

  TerrainElevation? elevationAt(double y) {
    for (final elevation in TerrainElevation.values) {
      if (yFor(elevation) == y) return elevation;
    }
    return null;
  }
}
