import '../hit/aabb_hit_utils.dart';
import '../world.dart';
import 'grid_index_2d.dart';

/// Deterministic broadphase grid rebuilt each tick from dynamic damageable AABBs.
///
/// This grid implementation uses spatial hashing to bucket entities into cells.
/// AABBs that overlap multiple cells are added to all corresponding buckets.
///
/// **Memory Strategy**:
/// - [targets]: Rebuilt every frame to store flat arrays of AABB components.
/// - [_buckets]: Map of cell keys to lists of target indices. Keys are removed
///   when buckets become empty to keep the map size bounded to the visible/active
///   world (vital for infinite runners).
/// - [_bucketPool]: Reuses `List<int>` instances to avoid allocation churn.
/// - [_seenStampByTargetIndex]: Used for O(1) deduplication during queries (avoiding `Set`).
///
/// **Determinism**:
/// - The grid structure itself is order-independent for population.
/// - [queryAabbMinMax] iterates cells in a strict (Y then X) order.
/// - Note: The order of indices *within* a bucket is insertion order (index order in [targets]).
///   Since [targets] is rebuilt by iterating the [EcsWorld], this order depends on
///   Entity ID iteration order.
class BroadphaseGrid {
  BroadphaseGrid({required GridIndex2D index}) : _index = index;

  /// Helper for grid math (coordinate conversion, key packing).
  final GridIndex2D _index;

  /// Stores component data for all damageable entities in the current frame.
  /// Rebuilt at the start of `rebuild()`.
  final DamageableTargetCache targets = DamageableTargetCache();

  // cellKey -> list of target indices into `targets`.
  final Map<int, List<int>> _buckets = <int, List<int>>{};
  // Tracks keys currently in `_buckets` to allow fast iteration/clearing without
  // scanning the whole map (if it were sparse/large).
  final List<int> _activeKeys = <int>[];
  // Pool of lists to avoid allocating new Lists every frame.
  final List<List<int>> _bucketPool = <List<int>>[];

  // Per-query dedup for targets that span multiple cells.
  // We use a "timestamp" strategy: each query increments `_stamp`.
  // If `seen[target] == _stamp`, we've already added it this query.
  final List<int> _seenStampByTargetIndex = <int>[];
  int _stamp = 0;

  /// Rebuilds the spatial grid from the current state of [world].
  ///
  /// This must be called once per tick before any queries are performed.
  void rebuild(EcsWorld world) {
    targets.rebuild(world);

    // clear() old buckets and return lists to the pool.
    // We remove keys from the map to keep the map size small (only active cells).
    for (var i = 0; i < _activeKeys.length; i += 1) {
      final key = _activeKeys[i];
      final bucket = _buckets.remove(key);
      if (bucket == null) continue;
      bucket.clear();
      _bucketPool.add(bucket);
    }
    _activeKeys.clear();

    if (targets.isEmpty) return;

    // Populate buckets.
    for (var ti = 0; ti < targets.length; ti += 1) {
      final cx = targets.centerX[ti];
      final cy = targets.centerY[ti];
      final hx = targets.halfX[ti];
      final hy = targets.halfY[ti];

      // Calculate AABB min/max in world space.
      final minX = cx - hx;
      final maxX = cx + hx;
      final minY = cy - hy;
      final maxY = cy + hy;

      // Convert world AABB to cell index range (inclusive).
      final minCx = _index.worldToCellX(minX);
      final maxCx = _index.worldToCellX(maxX);
      final minCy = _index.worldToCellY(minY);
      final maxCy = _index.worldToCellY(maxY);

      // Add target to every cell its AABB overlaps.
      // This handles "large" entities that span multiple grid cells.
      for (var cellY = minCy; cellY <= maxCy; cellY += 1) {
        for (var cellX = minCx; cellX <= maxCx; cellX += 1) {
          final key = _index.cellKey(cellX, cellY);
          var bucket = _buckets[key];
          if (bucket == null) {
            // Get a list from the pool or allocate new.
            bucket = _bucketPool.isNotEmpty ? _bucketPool.removeLast() : <int>[];
            _buckets[key] = bucket;
            _activeKeys.add(key);
          }
          // Store the target index (not EntityId) for fast lookups.
          bucket.add(ti);
        }
      }
    }
  }

  /// Fills [outTargetIndices] with unique target indices whose AABBs may overlap
  /// the query AABB.
  ///
  /// This involves a broadphase lookup (finding grid cells) and deduplication.
  ///
  /// IMPORTANT (determinism):
  /// - Cell scan order is stable (y then x, increasing).
  /// - The output order depends on bucket insertion order (which depends on entity order).
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

    // Handle stamp overflow (wrap around)
    if (_stamp == 0x7FFFFFFF) {
      // Reset all seen stamps to 0 so we can safely start over at 1
      for (var i = 0; i < _seenStampByTargetIndex.length; i += 1) {
        _seenStampByTargetIndex[i] = 0;
      }
      _stamp = 1;
    }

    final minCx = _index.worldToCellX(minX);
    final maxCx = _index.worldToCellX(maxX);
    final minCy = _index.worldToCellY(minY);
    final maxCy = _index.worldToCellY(maxY);

    // Ensure strict capacity for the seen array to match current targets.
    // This handles the case where new targets were added in `rebuild`.
    if (_seenStampByTargetIndex.length < targets.length) {
      final missing = targets.length - _seenStampByTargetIndex.length;
      for (var i = 0; i < missing; i += 1) {
        _seenStampByTargetIndex.add(0);
      }
    }

    // Iterate over all cells touched by the query AABB.
    // Order: Row by row (Y), then column by column (X).
    for (var cellY = minCy; cellY <= maxCy; cellY += 1) {
      for (var cellX = minCx; cellX <= maxCx; cellX += 1) {
        final key = _index.cellKey(cellX, cellY);
        final bucket = _buckets[key];
        
        // Skip empty cells.
        if (bucket == null || bucket.isEmpty) continue;

        // Iterate contents of the bucket.
        // Elements are roughly sorted by insertion order (EntityId order).
        for (var bi = 0; bi < bucket.length; bi += 1) {
          final targetIndex = bucket[bi];
          
          // Use stamp to check if already visited this query.
          // This avoids adding the same entity multiple times if it spans multiple cells.
          if (_seenStampByTargetIndex[targetIndex] == _stamp) continue;
          _seenStampByTargetIndex[targetIndex] = _stamp;
          outTargetIndices.add(targetIndex);
        }
      }
    }
  }
}
