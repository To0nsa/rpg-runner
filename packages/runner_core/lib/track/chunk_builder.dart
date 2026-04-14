/// Chunk geometry builder functions for track streaming.
///
/// Converts chunk-relative pattern definitions into world-space collision
/// geometry ([StaticSolid], [StaticGroundSegment], [StaticGroundGap]).
library;

import '../collision/static_world_geometry.dart';
import 'chunk_pattern.dart';

/// Result of building ground geometry from a chunk pattern.
class GroundBuildResult {
  const GroundBuildResult({required this.segments, required this.gaps});

  /// Walkable ground spans (between gaps).
  final List<StaticGroundSegment> segments;

  /// Pit/gap spans.
  final List<StaticGroundGap> gaps;
}

/// Converts pattern solids into world-space [StaticSolid]s.
///
/// [pattern] - The chunk pattern containing static collision geometry.
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
  _validateBuildInputs(
    pattern,
    chunkIndex: chunkIndex,
    chunkStartX: chunkStartX,
    chunkWidth: chunkWidth,
    gridSnap: gridSnap,
  );

  // Preserve author ordering for determinism.
  final solids = <StaticSolid>[];
  var localSolidIndex = 0;

  for (var i = 0; i < pattern.solids.length; i += 1) {
    final solid = pattern.solids[i];
    _validateSpanValue(
      solid.width,
      field: 'solid[$i].width',
      pattern: pattern,
      chunkIndex: chunkIndex,
      requirePositive: true,
    );
    _validateSpanValue(
      solid.height,
      field: 'solid[$i].height',
      pattern: pattern,
      chunkIndex: chunkIndex,
      requirePositive: true,
    );
    _validateSpanValue(
      solid.aboveGroundTop,
      field: 'solid[$i].aboveGroundTop',
      pattern: pattern,
      chunkIndex: chunkIndex,
      requirePositive: false,
    );
    if (solid.aboveGroundTop < -_validationTolerance) {
      _throwChunkValidation(
        'Solid aboveGroundTop must be >= 0 at index $i '
        '(aboveGroundTop=${solid.aboveGroundTop})',
        pattern: pattern,
        chunkIndex: chunkIndex,
      );
    }
    if (!_withinChunk(solid.x, solid.width, chunkWidth)) {
      _throwChunkValidation(
        'Solid out of chunk bounds at index $i '
        '(x=${solid.x}, width=${solid.width}, chunkWidth=$chunkWidth)',
        pattern: pattern,
        chunkIndex: chunkIndex,
      );
    }
    if (!_snapped(solid.x, gridSnap) ||
        !_snapped(solid.width, gridSnap) ||
        !_snapped(solid.height, gridSnap) ||
        !_snapped(solid.aboveGroundTop, gridSnap)) {
      _throwChunkValidation(
        'Solid not snapped to grid at index $i '
        '(x=${solid.x}, width=${solid.width}, height=${solid.height}, '
        'aboveGroundTop=${solid.aboveGroundTop}, gridSnap=$gridSnap)',
        pattern: pattern,
        chunkIndex: chunkIndex,
      );
    }
    if (!_isValidSolidSideMask(solid.sides)) {
      _throwChunkValidation(
        'Solid has invalid side mask at index $i '
        '(sides=${solid.sides})',
        pattern: pattern,
        chunkIndex: chunkIndex,
      );
    }
    if (solid.oneWayTop && (solid.sides & SolidRel.sideTop) == 0) {
      _throwChunkValidation(
        'Solid oneWayTop requires sideTop at index $i '
        '(sides=${solid.sides})',
        pattern: pattern,
        chunkIndex: chunkIndex,
      );
    }

    final topY = groundTopY - solid.aboveGroundTop;
    solids.add(
      StaticSolid(
        minX: chunkStartX + solid.x,
        minY: topY,
        maxX: chunkStartX + solid.x + solid.width,
        maxY: topY + solid.height,
        sides: solid.sides,
        oneWayTop: solid.oneWayTop,
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
  _validateBuildInputs(
    pattern,
    chunkIndex: chunkIndex,
    chunkStartX: chunkStartX,
    chunkWidth: chunkWidth,
    gridSnap: gridSnap,
  );

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

  for (var i = 0; i < orderedGaps.length; i += 1) {
    final gap = orderedGaps[i];
    _validateSpanValue(
      gap.width,
      field: 'groundGap[$i].width',
      pattern: pattern,
      chunkIndex: chunkIndex,
      requirePositive: true,
    );
    if (!_withinChunk(gap.x, gap.width, chunkWidth)) {
      _throwChunkValidation(
        'Ground gap out of chunk bounds at index $i '
        '(x=${gap.x}, width=${gap.width}, chunkWidth=$chunkWidth)',
        pattern: pattern,
        chunkIndex: chunkIndex,
      );
    }
    if (!_snapped(gap.x, gridSnap) || !_snapped(gap.width, gridSnap)) {
      _throwChunkValidation(
        'Ground gap not snapped to grid at index $i '
        '(x=${gap.x}, width=${gap.width}, gridSnap=$gridSnap)',
        pattern: pattern,
        chunkIndex: chunkIndex,
      );
    }
    if (gap.x < lastGapEnd - _gapOverlapTolerance) {
      _throwChunkValidation(
        'Ground gap overlaps previous gap at index $i '
        '(x=${gap.x}, previousEnd=$lastGapEnd)',
        pattern: pattern,
        chunkIndex: chunkIndex,
      );
    }

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
        gapId: gap.gapId,
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

const double _validationTolerance = 1e-9;
const double _gapOverlapTolerance = 1e-6;

bool _isValidSolidSideMask(int sides) {
  return sides > SolidRel.sideNone && (sides & ~SolidRel.sideAll) == 0;
}

void _validateBuildInputs(
  ChunkPattern pattern, {
  required int chunkIndex,
  required double chunkStartX,
  required double chunkWidth,
  required double gridSnap,
}) {
  _validateSpanValue(
    chunkStartX,
    field: 'chunkStartX',
    pattern: pattern,
    chunkIndex: chunkIndex,
  );
  _validateSpanValue(
    chunkWidth,
    field: 'chunkWidth',
    pattern: pattern,
    chunkIndex: chunkIndex,
    requirePositive: true,
  );
  _validateSpanValue(
    gridSnap,
    field: 'gridSnap',
    pattern: pattern,
    chunkIndex: chunkIndex,
    requirePositive: true,
  );
}

void _validateSpanValue(
  double value, {
  required String field,
  required ChunkPattern pattern,
  required int chunkIndex,
  bool requirePositive = false,
}) {
  if (!value.isFinite) {
    _throwChunkValidation(
      'Invalid non-finite value for $field: $value',
      pattern: pattern,
      chunkIndex: chunkIndex,
    );
  }
  if (requirePositive && value <= _validationTolerance) {
    _throwChunkValidation(
      'Invalid non-positive value for $field: $value',
      pattern: pattern,
      chunkIndex: chunkIndex,
    );
  }
}

Never _throwChunkValidation(
  String message, {
  required ChunkPattern pattern,
  required int chunkIndex,
}) {
  final key = pattern.chunkKey;
  final chunkKeyPart = (key == null || key.isEmpty) ? '' : ', chunkKey=$key';
  throw StateError(
    '$message (pattern=${pattern.name}$chunkKeyPart, chunkIndex=$chunkIndex)',
  );
}
