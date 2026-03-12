import 'static_world_geometry.dart';
export 'static_world_geometry.dart';

/// Pre-indexed view of static world geometry for faster collision queries.
///
/// This is constructed once (per run/session) and preserves the original solid
/// ordering in each face list to keep behavior deterministic.
class StaticWorldGeometryIndex {
  StaticWorldGeometryIndex._({
    required this.geometry,
    required this.groundPlane,
    required this.groundSegments,
    required this.groundGaps,
    required List<StaticSolid> tops,
    required List<StaticSolid> bottoms,
    required List<StaticSolid> leftWalls,
    required List<StaticSolid> rightWalls,
    required double maxTopWidth,
    required double maxBottomWidth,
    required double maxLeftWidth,
    required double maxRightWidth,
  }) : _tops = tops,
       _bottoms = bottoms,
       _leftWalls = leftWalls,
       _rightWalls = rightWalls,
       _maxTopWidth = maxTopWidth,
       _maxBottomWidth = maxBottomWidth,
       _maxLeftWidth = maxLeftWidth,
       _maxRightWidth = maxRightWidth;

  /// Creates a spatial index from the raw static geometry.
  ///
  /// This process involves:
  /// 1. Categorizing solids by their active sides (top, bottom, left, right).
  /// 2. Sorting each list by [minX] to enable binary search.
  /// 3. Computing max widths for each list to optimize overlap queries.
  /// 4. Merging the ground plane and gaps into a unified list of walkable segments.
  factory StaticWorldGeometryIndex.from(StaticWorldGeometry geometry) {
    final tops = <StaticSolid>[];
    final bottoms = <StaticSolid>[];
    final leftWalls = <StaticSolid>[];
    final rightWalls = <StaticSolid>[];

    for (final solid in geometry.solids) {
      final sides = solid.sides;
      if ((sides & StaticSolid.sideTop) != 0) tops.add(solid);
      if ((sides & StaticSolid.sideBottom) != 0) bottoms.add(solid);
      if ((sides & StaticSolid.sideLeft) != 0) leftWalls.add(solid);
      if ((sides & StaticSolid.sideRight) != 0) rightWalls.add(solid);
    }

    // Sort for binary search.
    _sortByMinX(tops);
    _sortByMinX(bottoms);
    _sortByMinX(leftWalls);
    _sortByMinX(rightWalls);

    final groundSegments = _buildGroundSegments(geometry);
    // Ground segments are already sorted by _buildGroundSegments.

    final groundGaps = geometry.groundGaps.isEmpty
        ? const <StaticGroundGap>[]
        : List<StaticGroundGap>.unmodifiable(
            List<StaticGroundGap>.from(geometry.groundGaps),
          );

    return StaticWorldGeometryIndex._(
      geometry: geometry,
      groundPlane: geometry.groundPlane,
      groundSegments: groundSegments,
      groundGaps: groundGaps,
      tops: List<StaticSolid>.unmodifiable(tops),
      bottoms: List<StaticSolid>.unmodifiable(bottoms),
      leftWalls: List<StaticSolid>.unmodifiable(leftWalls),
      rightWalls: List<StaticSolid>.unmodifiable(rightWalls),
      maxTopWidth: _computeMaxWidth(tops),
      maxBottomWidth: _computeMaxWidth(bottoms),
      maxLeftWidth: _computeMaxWidth(leftWalls),
      maxRightWidth: _computeMaxWidth(rightWalls),
    );
  }

  /// Source geometry (unchanged).
  final StaticWorldGeometry geometry;

  /// Optional infinite ground plane.
  final StaticGroundPlane? groundPlane;

  /// Walkable ground segments (used for collision + navigation).
  final List<StaticGroundSegment> groundSegments;

  /// Ground gaps (holes in the ground plane).
  final List<StaticGroundGap> groundGaps;

  /// Solids with an enabled top face.
  final List<StaticSolid> _tops;

  /// Solids with an enabled bottom face (ceilings).
  final List<StaticSolid> _bottoms;

  /// Solids with an enabled left face (walls hit when moving right).
  final List<StaticSolid> _leftWalls;

  /// Solids with an enabled right face (walls hit when moving left).
  final List<StaticSolid> _rightWalls;

  final double _maxTopWidth;
  final double _maxBottomWidth;
  final double _maxLeftWidth;
  final double _maxRightWidth;

  /// Fills [out] with solids overlapping the range [minX, maxX].
  ///
  /// Uses binary search to find potential candidates in O(log N) time.
  void queryTops(double minX, double maxX, List<StaticSolid> out) {
    _query(_tops, minX, maxX, _maxTopWidth, out);
  }

  /// Fills [out] with solids overlapping the range [minX, maxX].
  ///
  /// Uses binary search to find potential candidates in O(log N) time.
  void queryBottoms(double minX, double maxX, List<StaticSolid> out) {
    _query(_bottoms, minX, maxX, _maxBottomWidth, out);
  }

  /// Fills [out] with solids overlapping the range [minX, maxX].
  ///
  /// Uses binary search to find potential candidates in O(log N) time.
  void queryLeftWalls(double minX, double maxX, List<StaticSolid> out) {
    _query(_leftWalls, minX, maxX, _maxLeftWidth, out);
  }

  /// Fills [out] with solids overlapping the range [minX, maxX].
  ///
  /// Uses binary search to find potential candidates in O(log N) time.
  void queryRightWalls(double minX, double maxX, List<StaticSolid> out) {
    _query(_rightWalls, minX, maxX, _maxRightWidth, out);
  }

  /// Fills [out] with ground segments overlapping the range [minX, maxX].
  ///
  /// Ground segments are guaranteed to be sorted and disjoint, allowing efficient
  /// traversal.
  void queryGroundSegments(
    double minX,
    double maxX,
    List<StaticGroundSegment> out,
  ) {
    final start = _lowerBoundSegments(groundSegments, minX);
    for (var i = start; i < groundSegments.length; i += 1) {
      final seg = groundSegments[i];
      if (seg.minX >= maxX) break;
      if (seg.maxX > minX) {
        out.add(seg);
      }
    }
  }

  /// Internal helper to query a sorted list of solids.
  ///
  /// [maxWidth] is used to determine the search window. Since the list is sorted
  /// by [minX], a solid can only overlap if its [minX] is within [maxWidth] of
  /// the query's [minX].
  static void _query(
    List<StaticSolid> list,
    double minX,
    double maxX,
    double maxWidth,
    List<StaticSolid> out,
  ) {
    final lowerBoundX = minX - maxWidth;
    final start = _lowerBound(list, lowerBoundX);

    for (var i = start; i < list.length; i += 1) {
      final s = list[i];
      if (s.minX >= maxX) break;
      if (s.maxX > minX) {
        out.add(s);
      }
    }
  }
}

void _sortByMinX(List<StaticSolid> list) {
  list.sort((a, b) => a.minX.compareTo(b.minX));
}

double _computeMaxWidth(List<StaticSolid> list) {
  var maxW = 0.0;
  for (final s in list) {
    final w = s.maxX - s.minX;
    if (w > maxW) maxW = w;
  }
  return maxW;
}

/// Standard binary search (lower bound) for `List<StaticSolid>`.
/// Returns the first index where `list[i].minX >= xValue`.
int _lowerBound(List<StaticSolid> list, double xValue) {
  var min = 0;
  var max = list.length;
  while (min < max) {
    final mid = min + ((max - min) >> 1);
    final element = list[mid];
    if (element.minX < xValue) {
      min = mid + 1;
    } else {
      max = mid;
    }
  }
  return min;
}

/// Specialized search for ground segments.
/// Returns the first index where `list[i].maxX > xValue`.
/// Since ground segments are disjoint, finding where they end relative to the
/// query start is a good entry point.
int _lowerBoundSegments(List<StaticGroundSegment> list, double xValue) {
  var min = 0;
  var max = list.length;
  while (min < max) {
    final mid = min + ((max - min) >> 1);
    if (list[mid].maxX <= xValue) {
      min = mid + 1;
    } else {
      max = mid;
    }
  }
  return min;
}

/// Helper to unify the ground plane and gaps into a single sorted list of
/// walkable segments.
List<StaticGroundSegment> _buildGroundSegments(StaticWorldGeometry geometry) {
  // If segments are already provided (e.g. from a chunk generator), use them.
  if (geometry.groundSegments.isNotEmpty) {
    _validateProvidedGroundSegments(geometry.groundSegments);
    return List<StaticGroundSegment>.unmodifiable(geometry.groundSegments);
  }

  // If no ground plane exists, there are no segments (void world).
  final groundPlane = geometry.groundPlane;
  if (groundPlane == null) {
    return const <StaticGroundSegment>[];
  }

  // If there are no gaps, the ground is a single infinite plane.
  if (geometry.groundGaps.isEmpty) {
    return List<StaticGroundSegment>.unmodifiable(<StaticGroundSegment>[
      StaticGroundSegment(
        minX: double.negativeInfinity,
        maxX: double.infinity,
        topY: groundPlane.topY,
        chunkIndex: StaticSolid.groundChunk,
        localSegmentIndex: 0,
      ),
    ]);
  }

  // 1. Sort gaps by minX to process them in order.
  final gaps = List<StaticGroundGap>.from(geometry.groundGaps)
    ..sort((a, b) => a.minX.compareTo(b.minX));

  // 2. Merge overlapping or adjacent gaps into fewer, larger gaps.
  final merged = <StaticGroundGap>[];
  for (final gap in gaps) {
    if (merged.isEmpty) {
      merged.add(gap);
      continue;
    }
    final last = merged.last;
    if (gap.minX <= last.maxX) {
      // Overlapping or touching gap. Extend the last gap if needed.
      if (gap.maxX > last.maxX) {
        merged[merged.length - 1] = StaticGroundGap(
          minX: last.minX,
          maxX: gap.maxX,
        );
      }
    } else {
      // Disjoint gap.
      merged.add(gap);
    }
  }

  // 3. Create segments strictly *between* the merged gaps.
  final segments = <StaticGroundSegment>[];
  var cursor = double.negativeInfinity;
  var localIndex = 0;
  for (final gap in merged) {
    // If there is space between the current cursor (end of last gap) and
    // the start of this gap, create a segment.
    if (gap.minX > cursor) {
      segments.add(
        StaticGroundSegment(
          minX: cursor,
          maxX: gap.minX,
          topY: groundPlane.topY,
          chunkIndex: StaticSolid.groundChunk,
          localSegmentIndex: localIndex,
        ),
      );
      localIndex += 1;
    }
    // Move cursor to the end of this gap.
    cursor = gap.maxX > cursor ? gap.maxX : cursor;
  }

  // 4. Create the final segment from the last gap to infinity.
  if (cursor < double.infinity) {
    segments.add(
      StaticGroundSegment(
        minX: cursor,
        maxX: double.infinity,
        topY: groundPlane.topY,
        chunkIndex: StaticSolid.groundChunk,
        localSegmentIndex: localIndex,
      ),
    );
  }

  return List<StaticGroundSegment>.unmodifiable(segments);
}

/// Validates externally-provided ground segments.
///
/// Required contract:
/// - sorted by [minX] ascending
/// - disjoint (touching is allowed, overlap is not)
/// - valid ranges (`maxX >= minX`)
void _validateProvidedGroundSegments(List<StaticGroundSegment> segments) {
  if (segments.isEmpty) return;
  const eps = 1e-9;

  for (var i = 0; i < segments.length; i += 1) {
    final segment = segments[i];
    if (segment.maxX < segment.minX - eps) {
      throw StateError(
        'Invalid ground segment at index $i: maxX (${segment.maxX}) < minX (${segment.minX}).',
      );
    }

    if (i == 0) continue;
    final previous = segments[i - 1];
    if (segment.minX < previous.minX - eps) {
      throw StateError(
        'Ground segments must be sorted by minX. '
        'Index ${i - 1} has minX=${previous.minX}, index $i has minX=${segment.minX}.',
      );
    }
    if (segment.minX < previous.maxX - eps) {
      throw StateError(
        'Ground segments must be disjoint. '
        'Index ${i - 1} maxX=${previous.maxX} overlaps index $i minX=${segment.minX}.',
      );
    }
  }
}
