import '../ecs/spatial/grid_index_2d.dart';
import 'nav_tolerances.dart';
import 'walk_surface.dart';

/// Spatial index for walkable surface segments.
///
/// Built only when static geometry changes (graph rebuild).
class SurfaceSpatialIndex {
  SurfaceSpatialIndex({
    required GridIndex2D index,
    this.surfaceThickness = navSpatialEps,
  }) : _index = index;

  final GridIndex2D _index;
  final double surfaceThickness;

  final Map<int, List<int>> _buckets = <int, List<int>>{};
  final List<int> _activeKeys = <int>[];
  final List<List<int>> _bucketPool = <List<int>>[];

  final List<int> _seenStampBySurface = <int>[];
  int _stamp = 0;
  int _surfaceCount = 0;

  void rebuild(List<WalkSurface> surfaces) {
    for (var i = 0; i < _activeKeys.length; i += 1) {
      final key = _activeKeys[i];
      final bucket = _buckets.remove(key);
      if (bucket == null) continue;
      bucket.clear();
      _bucketPool.add(bucket);
    }
    _activeKeys.clear();

    _surfaceCount = surfaces.length;
    if (surfaces.isEmpty) return;

    for (var si = 0; si < surfaces.length; si += 1) {
      final surface = surfaces[si];
      final minX = surface.xMin;
      final maxX = surface.xMax;
      final minY = surface.yTop - surfaceThickness;
      final maxY = surface.yTop + surfaceThickness;

      final minCx = _index.worldToCellX(minX);
      final maxCx = _index.worldToCellX(maxX);
      final minCy = _index.worldToCellY(minY);
      final maxCy = _index.worldToCellY(maxY);

      for (var cellY = minCy; cellY <= maxCy; cellY += 1) {
        for (var cellX = minCx; cellX <= maxCx; cellX += 1) {
          final key = _index.cellKey(cellX, cellY);
          var bucket = _buckets[key];
          if (bucket == null) {
            bucket = _bucketPool.isNotEmpty ? _bucketPool.removeLast() : <int>[];
            _buckets[key] = bucket;
            _activeKeys.add(key);
          }
          bucket.add(si);
        }
      }
    }
  }

  /// Fills [outSurfaceIndices] with unique surface indices overlapping the AABB.
  void queryAabb({
    required double minX,
    required double minY,
    required double maxX,
    required double maxY,
    required List<int> outSurfaceIndices,
  }) {
    outSurfaceIndices.clear();
    if (_activeKeys.isEmpty) return;

    _stamp += 1;
    if (_stamp == 0x7FFFFFFF) {
      for (var i = 0; i < _seenStampBySurface.length; i += 1) {
        _seenStampBySurface[i] = 0;
      }
      _stamp = 1;
    }

    final minCx = _index.worldToCellX(minX);
    final maxCx = _index.worldToCellX(maxX);
    final minCy = _index.worldToCellY(minY);
    final maxCy = _index.worldToCellY(maxY);

    if (_seenStampBySurface.length < _surfaceCount) {
      final missing = _surfaceCount - _seenStampBySurface.length;
      for (var i = 0; i < missing; i += 1) {
        _seenStampBySurface.add(0);
      }
    }

    for (var cellY = minCy; cellY <= maxCy; cellY += 1) {
      for (var cellX = minCx; cellX <= maxCx; cellX += 1) {
        final key = _index.cellKey(cellX, cellY);
        final bucket = _buckets[key];
        if (bucket == null || bucket.isEmpty) continue;

        for (var bi = 0; bi < bucket.length; bi += 1) {
          final surfaceIndex = bucket[bi];
          if (_seenStampBySurface[surfaceIndex] == _stamp) continue;
          _seenStampBySurface[surfaceIndex] = _stamp;
          outSurfaceIndices.add(surfaceIndex);
        }
      }
    }
  }
}
