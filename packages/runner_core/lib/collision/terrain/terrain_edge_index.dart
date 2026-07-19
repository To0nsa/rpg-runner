import 'dart:collection';

import '../../ecs/spatial/grid_index_2d.dart';
import 'terrain_edge.dart';
import 'terrain_numeric.dart';
import 'terrain_query_buffer.dart';

/// Deterministic closed-boundary static grid over canonical terrain edges.
///
/// Rebuild may allocate. Queries use a caller-owned [TerrainQueryBuffer] and
/// allocate nothing after that buffer is sized for this index.
class TerrainEdgeIndex {
  TerrainEdgeIndex({
    required Iterable<TerrainEdge> edges,
    int cellSizeWorld = terrainDefaultCellSizeWorld,
  }) : _grid = GridIndex2D(cellSize: cellSizeWorld.toDouble()),
       cellSizeWorld = cellSizeWorld,
       cellSizeTicks = cellSizeWorld * terrainPhysicsTicksPerWorldUnit,
       edges = UnmodifiableListView<TerrainEdge>(
         List<TerrainEdge>.of(edges)
           ..sort((left, right) => left.id.compareTo(right.id)),
       ) {
    if (cellSizeWorld <= 0) {
      throw ArgumentError.value(
        cellSizeWorld,
        'cellSizeWorld',
        'Must be positive.',
      );
    }
    _rebuild();
  }

  final GridIndex2D _grid;

  /// Square cell width in world units.
  final int cellSizeWorld;

  /// Square cell width in 1/1024-world-unit physics ticks.
  final int cellSizeTicks;

  /// Canonical immutable edge order used by candidate indices.
  final List<TerrainEdge> edges;

  final Map<int, List<int>> _buckets = <int, List<int>>{};
  late final List<List<_CellCoordinate>> _memberships;

  /// Total bucket references inserted during rebuild.
  int insertedReferences = 0;

  /// Number of occupied cells after rebuild.
  int get occupiedCellCount => _buckets.length;

  /// Creates a query buffer pre-sized for this immutable index.
  TerrainQueryBuffer createQueryBuffer() =>
      TerrainQueryBuffer(edgeCapacity: edges.length);

  /// Queries all edges whose indexed closed AABBs overlap [bounds].
  ///
  /// Results are deduplicated and emitted in canonical edge-ID order through
  /// [buffer]. The returned count is also available as
  /// `buffer.candidateCount`.
  int query(TerrainAabb bounds, TerrainQueryBuffer buffer) {
    buffer.prepare(edges.length);
    final minCellX = _closedMinCell(bounds.minX);
    final maxCellX = _closedMaxCell(bounds.maxX);
    final minCellY = _closedMinCell(bounds.minY);
    final maxCellY = _closedMaxCell(bounds.maxY);

    for (var cy = minCellY; cy <= maxCellY; cy += 1) {
      for (var cx = minCellX; cx <= maxCellX; cx += 1) {
        buffer.stats.cellsVisited += 1;
        final bucket = _buckets[_grid.cellKey(cx, cy)];
        if (bucket == null) continue;
        for (final edgeIndex in bucket) {
          buffer.stats.rawCandidates += 1;
          if (buffer.mark(edgeIndex)) {
            buffer.appendCandidateIndex(edgeIndex);
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
      final edgeIndex = buffer.candidateEdgeIndexAt(candidateIndex);
      if (edges[edgeIndex].bounds.intersects(bounds)) {
        buffer.writeCandidateEdgeIndex(acceptedCount, edgeIndex);
        acceptedCount += 1;
      }
    }
    buffer.truncateCandidates(acceptedCount);
    buffer.stats.uniqueCandidates = buffer.candidateCount;
    return buffer.candidateCount;
  }

  /// Canonical index-cell membership records for `edges-v1` signatures.
  List<String> canonicalMembershipRecords() {
    final records = <String>[];
    for (var edgeIndex = 0; edgeIndex < edges.length; edgeIndex += 1) {
      for (final cell in _memberships[edgeIndex]) {
        records.add(
          'index-cell|${edges[edgeIndex].id.canonicalKey}|'
          '${cell.x}|${cell.y}',
        );
      }
    }
    return List<String>.unmodifiable(records);
  }

  void _rebuild() {
    _memberships = List<List<_CellCoordinate>>.generate(
      edges.length,
      (_) => <_CellCoordinate>[],
    );
    for (var edgeIndex = 0; edgeIndex < edges.length; edgeIndex += 1) {
      final bounds = edges[edgeIndex].bounds;
      final minCellX = _closedMinCell(bounds.minX);
      final maxCellX = _closedMaxCell(bounds.maxX);
      final minCellY = _closedMinCell(bounds.minY);
      final maxCellY = _closedMaxCell(bounds.maxY);
      for (var cy = minCellY; cy <= maxCellY; cy += 1) {
        for (var cx = minCellX; cx <= maxCellX; cx += 1) {
          final key = _grid.cellKey(cx, cy);
          _buckets.putIfAbsent(key, () => <int>[]).add(edgeIndex);
          _memberships[edgeIndex].add(_CellCoordinate(cx, cy));
          insertedReferences += 1;
        }
      }
    }
    for (var i = 0; i < _memberships.length; i += 1) {
      _memberships[i] = List<_CellCoordinate>.unmodifiable(_memberships[i]);
    }
  }

  int _closedMinCell(int ticks) {
    final floor = terrainFloorDiv(ticks, cellSizeTicks);
    return ticks.remainder(cellSizeTicks) == 0 ? floor - 1 : floor;
  }

  int _closedMaxCell(int ticks) => terrainFloorDiv(ticks, cellSizeTicks);
}

class _CellCoordinate {
  const _CellCoordinate(this.x, this.y);

  final int x;
  final int y;
}
