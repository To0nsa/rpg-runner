import '../../ecs/spatial/grid_index_2d.dart';
import '../types/nav_tolerances.dart';
import '../types/walk_surface.dart';

/// Spatial hash grid for fast AABB queries against [WalkSurface]s.
///
/// **Purpose**:
/// - Given an AABB (e.g., entity bounds), quickly find all surfaces that might overlap.
/// - Avoids O(N) linear scans over all surfaces.
///
/// **Design**:
/// - Uses a uniform grid (via [GridIndex2D]) to bucket surfaces by cell.
/// - Surfaces spanning multiple cells are inserted into each overlapping cell.
/// - A stamp-based deduplication prevents returning the same surface twice per query.
///
/// **Lifecycle**:
/// - Call [rebuild] when static geometry changes (e.g., new chunk loaded).
/// - Call [queryAabb] during gameplay (e.g., to find surfaces under an entity).
class SurfaceSpatialIndex {
  SurfaceSpatialIndex({
    required GridIndex2D index,
    this.surfaceThickness = navSpatialEps,
  }) : _index = index;

  /// The underlying grid coordinate system.
  final GridIndex2D _index;
  
  /// Vertical thickness added above/below each surface for overlap tests.
  final double surfaceThickness;

  /// Cell key -> list of surface indices in that cell.
  final Map<int, List<int>> _buckets = <int, List<int>>{};
  
  /// Keys of all currently populated buckets (for fast clearing).
  final List<int> _activeKeys = <int>[];
  
  /// Pool of reusable bucket lists (reduces GC pressure).
  final List<List<int>> _bucketPool = <List<int>>[];

  /// Stamp-based deduplication: `_seenStampBySurface[i] == _stamp` means already seen.
  final List<int> _seenStampBySurface = <int>[];
  int _stamp = 0;
  int _surfaceCount = 0;

  /// Rebuilds the spatial index from a new set of surfaces.
  ///
  /// **Performance**: O(S * C) where S = surfaces, C = avg cells per surface.
  void rebuild(List<WalkSurface> surfaces) {
    // Return all active buckets to the pool.
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

    // Insert each surface into all cells it overlaps.
    for (var si = 0; si < surfaces.length; si += 1) {
      final surface = surfaces[si];
      
      // Surface AABB: horizontal span + thin vertical slab.
      final minX = surface.xMin;
      final maxX = surface.xMax;
      final minY = surface.yTop - surfaceThickness;
      final maxY = surface.yTop + surfaceThickness;

      // Convert to cell coordinates.
      final minCx = _index.worldToCellX(minX);
      final maxCx = _index.worldToCellX(maxX);
      final minCy = _index.worldToCellY(minY);
      final maxCy = _index.worldToCellY(maxY);

      // Insert surface index into each overlapping cell.
      for (var cellY = minCy; cellY <= maxCy; cellY += 1) {
        for (var cellX = minCx; cellX <= maxCx; cellX += 1) {
          final key = _index.cellKey(cellX, cellY);
          var bucket = _buckets[key];
          if (bucket == null) {
            // Reuse pooled bucket or allocate new.
            bucket = _bucketPool.isNotEmpty ? _bucketPool.removeLast() : <int>[];
            _buckets[key] = bucket;
            _activeKeys.add(key);
          }
          bucket.add(si);
        }
      }
    }
  }

  /// Finds all surfaces overlapping the given AABB.
  ///
  /// Results are written to [outSurfaceIndices] (cleared first).
  /// Each surface index appears at most once (deduplicated via stamp).
  ///
  /// **Performance**: O(C * B) where C = cells in query, B = avg bucket size.
  void queryAabb({
    required double minX,
    required double minY,
    required double maxX,
    required double maxY,
    required List<int> outSurfaceIndices,
  }) {
    outSurfaceIndices.clear();
    if (_activeKeys.isEmpty) return;

    // Advance the deduplication stamp.
    _stamp += 1;
    if (_stamp == 0x7FFFFFFF) {
      // Overflow protection: reset all stamps.
      for (var i = 0; i < _seenStampBySurface.length; i += 1) {
        _seenStampBySurface[i] = 0;
      }
      _stamp = 1;
    }

    // Determine cell range for query AABB.
    final minCx = _index.worldToCellX(minX);
    final maxCx = _index.worldToCellX(maxX);
    final minCy = _index.worldToCellY(minY);
    final maxCy = _index.worldToCellY(maxY);

    // Ensure stamp array is large enough.
    if (_seenStampBySurface.length < _surfaceCount) {
      final missing = _surfaceCount - _seenStampBySurface.length;
      for (var i = 0; i < missing; i += 1) {
        _seenStampBySurface.add(0);
      }
    }

    // Iterate all cells in query range.
    for (var cellY = minCy; cellY <= maxCy; cellY += 1) {
      for (var cellX = minCx; cellX <= maxCx; cellX += 1) {
        final key = _index.cellKey(cellX, cellY);
        final bucket = _buckets[key];
        if (bucket == null || bucket.isEmpty) continue;

        // Add each unseen surface to results.
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
