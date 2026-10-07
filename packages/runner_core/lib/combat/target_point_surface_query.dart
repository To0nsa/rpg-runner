import '../collision/terrain/terrain_numeric.dart';
import '../navigation/terrain_surface_query_buffer.dart';
import '../navigation/terrain_surface_spatial_index.dart';
import '../util/vec2.dart';

/// Captures the first upward surface below an aim point, in world units.
/// Solid floors and one-way platforms share the published terrain index.
/// Returned positions remain fixed for the committed spell; no actor is moved.
final class TargetPointSurfaceQuery {
  TargetPointSurfaceQuery(this._currentIndex);

  final TerrainSurfaceSpatialIndex Function() _currentIndex;
  TerrainSurfaceSpatialIndex? _index;
  TerrainSurfaceQueryBuffer? _buffer;
  int _maximumYTicks = 0;

  /// Returns null when no published surface lies directly below `(x, y)`.
  /// Y increases downward; equal-height candidates use canonical surface order.
  Vec2? below(double x, double y) {
    final index = _currentIndex();
    if (index.surfaces.isEmpty) return null;
    if (!identical(index, _index)) {
      _index = index;
      _buffer = index.createQueryBuffer();
      _maximumYTicks = index.surfaces.fold<int>(
        index.surfaces.first.start.yTicks,
        (maximum, surface) {
          final bottom = surface.start.yTicks > surface.end.yTicks
              ? surface.start.yTicks
              : surface.end.yTicks;
          return bottom > maximum ? bottom : maximum;
        },
      );
    }
    final xTicks = physicsCoordinateToTicks(x);
    final yTicks = physicsCoordinateToTicks(y);
    if (yTicks > _maximumYTicks) return null;
    final buffer = _buffer!;
    index.queryBounds(
      minX: xTicks,
      maxX: xTicks,
      minY: yTicks,
      maxY: _maximumYTicks,
      buffer: buffer,
    );
    int? surfaceY;
    for (var i = 0; i < buffer.candidateCount; i++) {
      final candidate = buffer.surfaceAt(i, index.surfaces);
      if (xTicks < candidate.xMinTicks || xTicks > candidate.xMaxTicks) {
        continue;
      }
      final height = candidate.yAtXTicks(xTicks);
      if (height >= yTicks && (surfaceY == null || height < surfaceY)) {
        surfaceY = height;
      }
    }
    return surfaceY == null
        ? null
        : Vec2(x, surfaceY / terrainPhysicsTicksPerWorldUnit);
  }
}
