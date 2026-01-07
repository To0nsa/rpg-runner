/// Chunk geometry builder functions for track streaming.
///
/// Converts chunk-relative pattern definitions into world-space collision
/// geometry ([StaticSolid], [StaticGroundSegment], [StaticGroundGap]).
library;

import '../collision/static_world_geometry.dart';
import 'chunk_pattern.dart';

/// Result of building ground geometry from a chunk pattern.
class GroundBuildResult {
  const GroundBuildResult({
    required this.segments,
    required this.gaps,
  });

  /// Walkable ground spans (between gaps).
  final List<StaticGroundSegment> segments;

  /// Pit/gap spans.
  final List<StaticGroundGap> gaps;
}

/// Converts pattern platforms/obstacles into world-space [StaticSolid]s.
///
/// [pattern] - The chunk pattern containing platforms and obstacles.
/// [chunkStartX] - World X where this chunk begins.
/// [chunkIndex] - Sequential chunk number for tagging solids.
/// [groundTopY] - World Y of the ground surface.
/// [chunkWidth] - Width of a chunk (for bounds checking).
/// [gridSnap] - Grid snap value (for alignment checking).
List<StaticSolid> buildSolids(
  ChunkPattern pattern, {
  required double chunkStartX,
  required int chunkIndex,
  required double groundTopY,
  required double chunkWidth,
  required double gridSnap,
}) {
  // Preserve author ordering for determinism.
  final solids = <StaticSolid>[];
  var localSolidIndex = 0;

  // ── Platforms (one-way top) ──
  for (final p in pattern.platforms) {
    assert(
      _withinChunk(p.x, p.width, chunkWidth),
      'Platform out of chunk bounds: ${pattern.name}',
    );
    assert(
      _snapped(p.x, gridSnap) &&
          _snapped(p.width, gridSnap) &&
          _snapped(p.aboveGroundTop, gridSnap),
      'Platform not snapped to grid: ${pattern.name}',
    );
    final topY = groundTopY - p.aboveGroundTop;
    solids.add(
      StaticSolid(
        minX: chunkStartX + p.x,
        minY: topY,
        maxX: chunkStartX + p.x + p.width,
        maxY: topY + p.thickness,
        sides: StaticSolid.sideTop,
        oneWayTop: true,
        chunkIndex: chunkIndex,
        localSolidIndex: localSolidIndex,
      ),
    );
    localSolidIndex += 1;
  }

  // ── Obstacles (solid on all sides) ──
  for (final o in pattern.obstacles) {
    assert(
      _withinChunk(o.x, o.width, chunkWidth),
      'Obstacle out of chunk bounds: ${pattern.name}',
    );
    assert(
      _snapped(o.x, gridSnap) &&
          _snapped(o.width, gridSnap) &&
          _snapped(o.height, gridSnap),
      'Obstacle not snapped to grid: ${pattern.name}',
    );
    solids.add(
      StaticSolid(
        minX: chunkStartX + o.x,
        minY: groundTopY - o.height,
        maxX: chunkStartX + o.x + o.width,
        maxY: groundTopY,
        sides: StaticSolid.sideAll,
        oneWayTop: false,
        chunkIndex: chunkIndex,
        localSolidIndex: localSolidIndex,
      ),
    );
    localSolidIndex += 1;
  }

  return solids;
}

/// Builds ground segments by splitting at gap positions.
///
/// Gaps are sorted by X, then segments fill the remaining spans.
///
/// [pattern] - The chunk pattern containing ground gaps.
/// [chunkStartX] - World X where this chunk begins.
/// [chunkIndex] - Sequential chunk number for tagging segments.
/// [groundTopY] - World Y of the ground surface.
/// [chunkWidth] - Width of a chunk.
/// [gridSnap] - Grid snap value (for alignment checking).
GroundBuildResult buildGroundSegments(
  ChunkPattern pattern, {
  required double chunkStartX,
  required int chunkIndex,
  required double groundTopY,
  required double chunkWidth,
  required double gridSnap,
}) {
  // Sort gaps left-to-right for sequential processing.
  final orderedGaps = List<GapRel>.from(pattern.groundGaps);
  if (orderedGaps.isNotEmpty) {
    orderedGaps.sort((a, b) => a.x.compareTo(b.x));
  }

  final segments = <StaticGroundSegment>[];
  final gaps = <StaticGroundGap>[];
  var cursor = 0.0; // Tracks end of last segment/gap.
  var localSegmentIndex = 0;
  var lastGapEnd = -1.0; // For overlap assertion.

  for (final gap in orderedGaps) {
    assert(
      _withinChunk(gap.x, gap.width, chunkWidth),
      'Ground gap out of chunk bounds: ${pattern.name}',
    );
    assert(
      _snapped(gap.x, gridSnap) && _snapped(gap.width, gridSnap),
      'Ground gap not snapped to grid: ${pattern.name}',
    );
    assert(
      gap.x >= lastGapEnd - 1e-6,
      'Ground gap overlaps previous: ${pattern.name}',
    );

    final gapStart = gap.x;
    final gapEnd = gap.x + gap.width;

    // Emit segment from cursor to gap start (if non-empty).
    if (gapStart > cursor + 1e-6) {
      segments.add(
        StaticGroundSegment(
          minX: chunkStartX + cursor,
          maxX: chunkStartX + gapStart,
          topY: groundTopY,
          chunkIndex: chunkIndex,
          localSegmentIndex: localSegmentIndex,
        ),
      );
      localSegmentIndex += 1;
    }

    // Record gap for collision/rendering.
    gaps.add(
      StaticGroundGap(
        minX: chunkStartX + gapStart,
        maxX: chunkStartX + gapEnd,
      ),
    );

    // Advance cursor past gap.
    cursor = gapEnd > cursor ? gapEnd : cursor;
    lastGapEnd = gapEnd;
  }

  // Emit trailing segment from last gap to chunk end.
  if (cursor < chunkWidth - 1e-6) {
    segments.add(
      StaticGroundSegment(
        minX: chunkStartX + cursor,
        maxX: chunkStartX + chunkWidth,
        topY: groundTopY,
        chunkIndex: chunkIndex,
        localSegmentIndex: localSegmentIndex,
      ),
    );
  }

  return GroundBuildResult(segments: segments, gaps: gaps);
}

/// Checks if a span [x, x+width] fits within [0, chunkWidth].
bool _withinChunk(double x, double width, double chunkWidth) {
  return x >= 0.0 && (x + width) <= chunkWidth;
}

/// Checks if a value is snapped to the grid.
bool _snapped(double v, double gridSnap) {
  final snapped = (v / gridSnap).roundToDouble() * gridSnap;
  return (v - snapped).abs() < 1e-9;
}
