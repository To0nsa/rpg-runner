import '../hit/aabb_hit_utils.dart';
import '../world.dart';
import 'grid_index_2d.dart';

/// Deterministic broadphase grid rebuilt each tick from dynamic damageable AABBs.
///
/// Buckets store indices into `targets` (not EntityIds) to avoid repeated sparse
/// lookups during hit queries.
class BroadphaseGrid {
  BroadphaseGrid({required GridIndex2D index}) : _index = index;

  final GridIndex2D _index;
  final DamageableTargetCache targets = DamageableTargetCache();

  // cellKey -> list of target indices into `targets`.
  final Map<int, List<int>> _buckets = <int, List<int>>{};
  final List<int> _activeKeys = <int>[];
  final List<List<int>> _bucketPool = <List<int>>[];

  // Per-query dedup for targets that span multiple cells.
  final List<int> _seenStampByTargetIndex = <int>[];
  int _stamp = 0;

  void rebuild(EcsWorld world) {
    targets.rebuild(world);

    // Keep the map bounded to "active" cells (avoid unbounded growth as the
    // world scrolls). Reuse lists via a small pool to reduce allocations.
    for (var i = 0; i < _activeKeys.length; i += 1) {
      final key = _activeKeys[i];
      final bucket = _buckets.remove(key);
      if (bucket == null) continue;
      bucket.clear();
      _bucketPool.add(bucket);
    }
    _activeKeys.clear();

    if (targets.isEmpty) return;

    for (var ti = 0; ti < targets.length; ti += 1) {
      final cx = targets.centerX[ti];
      final cy = targets.centerY[ti];
      final hx = targets.halfX[ti];
      final hy = targets.halfY[ti];

      final minX = cx - hx;
      final maxX = cx + hx;
      final minY = cy - hy;
      final maxY = cy + hy;

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
          bucket.add(ti);
        }
      }
    }
  }

  /// Fills [outTargetIndices] with unique target indices whose AABBs may overlap
  /// the query AABB.
  ///
  /// IMPORTANT (determinism):
  /// - Cell scan order is stable (y then x, increasing).
  /// - Callers must sort by `targets.entities[targetIndex]` if they need a stable
  ///   per-query hit selection order.
  void queryAabbMinMax({
    required double minX,
    required double minY,
    required double maxX,
    required double maxY,
    required List<int> outTargetIndices,
  }) {
    outTargetIndices.clear();
    if (targets.isEmpty) return;

    _stamp += 1;

    // Avoid stamp overflow affecting correctness.
    if (_stamp == 0x7FFFFFFF) {
      for (var i = 0; i < _seenStampByTargetIndex.length; i += 1) {
        _seenStampByTargetIndex[i] = 0;
      }
      _stamp = 1;
    }

    final minCx = _index.worldToCellX(minX);
    final maxCx = _index.worldToCellX(maxX);
    final minCy = _index.worldToCellY(minY);
    final maxCy = _index.worldToCellY(maxY);

    if (_seenStampByTargetIndex.length < targets.length) {
      final missing = targets.length - _seenStampByTargetIndex.length;
      for (var i = 0; i < missing; i += 1) {
        _seenStampByTargetIndex.add(0);
      }
    }

    for (var cellY = minCy; cellY <= maxCy; cellY += 1) {
      for (var cellX = minCx; cellX <= maxCx; cellX += 1) {
        final key = _index.cellKey(cellX, cellY);
        final bucket = _buckets[key];
        if (bucket == null || bucket.isEmpty) continue;

        for (var bi = 0; bi < bucket.length; bi += 1) {
          final targetIndex = bucket[bi];
          if (_seenStampByTargetIndex[targetIndex] == _stamp) continue;
          _seenStampByTargetIndex[targetIndex] = _stamp;
          outTargetIndices.add(targetIndex);
        }
      }
    }
  }
}
