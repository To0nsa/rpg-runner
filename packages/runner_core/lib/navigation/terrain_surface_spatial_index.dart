import '../collision/terrain/terrain_numeric.dart';
import '../ecs/spatial/grid_index_2d.dart';
import 'terrain_surface_query_buffer.dart';
import 'types/terrain_navigation_surface.dart';

/// Deterministic closed-boundary grid over one canonical sloped surface set.
///
/// Rebuild allocates buckets once. Queries mutate only caller-owned
/// [TerrainSurfaceQueryBuffer] storage after that buffer is sized for this
/// immutable index, and results never truncate to meet a candidate budget.
class TerrainSurfaceSpatialIndex {
  TerrainSurfaceSpatialIndex({
    required this.surfaceSet,
    this.cellSizeWorld = terrainDefaultCellSizeWorld,
  }) : _grid = GridIndex2D(cellSize: cellSizeWorld.toDouble()),
       cellSizeTicks = cellSizeWorld * terrainPhysicsTicksPerWorldUnit,
       surfaces = surfaceSet.surfaces {
    if (cellSizeWorld <= 0) {
      throw ArgumentError.value(
        cellSizeWorld,
        'cellSizeWorld',
        'Must be positive.',
      );
    }
    _rebuild();
  }

  /// Immutable surface/version source owned by this index.
  final TerrainSurfaceSet surfaceSet;
  final GridIndex2D _grid;

  /// Square cell width in world units.
  final int cellSizeWorld;

  /// Square cell width in authoritative physics ticks.
  final int cellSizeTicks;

  /// Canonical immutable surface order used by candidate indices.
  final List<TerrainNavigationSurface> surfaces;

  final Map<int, List<int>> _buckets = <int, List<int>>{};

  /// Total bucket references inserted during construction.
  int insertedReferences = 0;

  /// Exact geometry version shared with [surfaceSet].
  int get geometryVersion => surfaceSet.geometryVersion;

  /// Number of occupied grid cells after construction.
  int get occupiedCellCount => _buckets.length;

  /// Creates scratch storage already sized for this immutable index.
  TerrainSurfaceQueryBuffer createQueryBuffer() =>
      TerrainSurfaceQueryBuffer(surfaceCapacity: surfaces.length);

  /// Queries exact segment bounds overlapping the closed tick-space AABB.
  int query(TerrainAabb bounds, TerrainSurfaceQueryBuffer buffer) =>
      queryBounds(
        minX: bounds.minX,
        minY: bounds.minY,
        maxX: bounds.maxX,
        maxY: bounds.maxY,
        buffer: buffer,
      );

  /// Primitive-bound query for allocation-sensitive navigation loops.
  int queryBounds({
    required int minX,
    required int minY,
    required int maxX,
    required int maxY,
    required TerrainSurfaceQueryBuffer buffer,
  }) {
    if (minX > maxX || minY > maxY) {
      throw ArgumentError('Surface query minimums must not exceed maximums.');
    }
    buffer.prepare(surfaces.length);
    final minCellX = _closedMinCell(minX);
    final maxCellX = _closedMaxCell(maxX);
    final minCellY = _closedMinCell(minY);
    final maxCellY = _closedMaxCell(maxY);

    for (var cellY = minCellY; cellY <= maxCellY; cellY += 1) {
      for (var cellX = minCellX; cellX <= maxCellX; cellX += 1) {
        buffer.stats.cellsVisited += 1;
        final bucket = _buckets[_grid.cellKey(cellX, cellY)];
        if (bucket == null) continue;
        for (final surfaceIndex in bucket) {
          buffer.stats.rawCandidates += 1;
          if (buffer.mark(surfaceIndex)) {
            buffer.appendCandidateIndex(surfaceIndex);
          }
        }
      }
    }

    buffer.sortCandidateIndices();
    var acceptedCount = 0;
    for (
      var candidateIndex = 0;
      candidateIndex < buffer.candidateCount;
      candidateIndex += 1
    ) {
      final surfaceIndex = buffer.candidateSurfaceIndexAt(candidateIndex);
      final surface = surfaces[surfaceIndex];
      final minSurfaceY = surface.start.yTicks < surface.end.yTicks
          ? surface.start.yTicks
          : surface.end.yTicks;
      final maxSurfaceY = surface.start.yTicks > surface.end.yTicks
          ? surface.start.yTicks
          : surface.end.yTicks;
      if (surface.xMinTicks <= maxX &&
          surface.xMaxTicks >= minX &&
          minSurfaceY <= maxY &&
          maxSurfaceY >= minY) {
        buffer.writeCandidateSurfaceIndex(acceptedCount, surfaceIndex);
        acceptedCount += 1;
      }
    }
    buffer.truncateCandidates(acceptedCount);
    buffer.stats.uniqueCandidates = acceptedCount;
    return acceptedCount;
  }

  void _rebuild() {
    for (var surfaceIndex = 0; surfaceIndex < surfaces.length; surfaceIndex++) {
      final surface = surfaces[surfaceIndex];
      final minY = surface.start.yTicks < surface.end.yTicks
          ? surface.start.yTicks
          : surface.end.yTicks;
      final maxY = surface.start.yTicks > surface.end.yTicks
          ? surface.start.yTicks
          : surface.end.yTicks;
      final minCellX = _closedMinCell(surface.xMinTicks);
      final maxCellX = _closedMaxCell(surface.xMaxTicks);
      final minCellY = _closedMinCell(minY);
      final maxCellY = _closedMaxCell(maxY);
      for (var cellY = minCellY; cellY <= maxCellY; cellY += 1) {
        for (var cellX = minCellX; cellX <= maxCellX; cellX += 1) {
          _buckets
              .putIfAbsent(_grid.cellKey(cellX, cellY), () => <int>[])
              .add(surfaceIndex);
          insertedReferences += 1;
        }
      }
    }
  }

  int _closedMinCell(int ticks) {
    final floor = terrainFloorDiv(ticks, cellSizeTicks);
    return ticks.remainder(cellSizeTicks) == 0 ? floor - 1 : floor;
  }

  int _closedMaxCell(int ticks) => terrainFloorDiv(ticks, cellSizeTicks);
}
