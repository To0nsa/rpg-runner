import 'static_world_geometry.dart';

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
    required this.tops,
    required this.bottoms,
    required this.leftWalls,
    required this.rightWalls,
  });

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

    final groundSegments = _buildGroundSegments(geometry);
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
  final List<StaticSolid> tops;

  /// Solids with an enabled bottom face (ceilings).
  final List<StaticSolid> bottoms;

  /// Solids with an enabled left face (walls hit when moving right).
  final List<StaticSolid> leftWalls;

  /// Solids with an enabled right face (walls hit when moving left).
  final List<StaticSolid> rightWalls;
}

List<StaticGroundSegment> _buildGroundSegments(StaticWorldGeometry geometry) {
  if (geometry.groundSegments.isNotEmpty) {
    return List<StaticGroundSegment>.unmodifiable(geometry.groundSegments);
  }

  final groundPlane = geometry.groundPlane;
  if (groundPlane == null) {
    return const <StaticGroundSegment>[];
  }

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

  final gaps = List<StaticGroundGap>.from(geometry.groundGaps)
    ..sort((a, b) => a.minX.compareTo(b.minX));

  final merged = <StaticGroundGap>[];
  for (final gap in gaps) {
    if (merged.isEmpty) {
      merged.add(gap);
      continue;
    }
    final last = merged.last;
    if (gap.minX <= last.maxX) {
      if (gap.maxX > last.maxX) {
        merged[merged.length - 1] =
            StaticGroundGap(minX: last.minX, maxX: gap.maxX);
      }
    } else {
      merged.add(gap);
    }
  }

  final segments = <StaticGroundSegment>[];
  var cursor = double.negativeInfinity;
  var localIndex = 0;
  for (final gap in merged) {
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
    cursor = gap.maxX > cursor ? gap.maxX : cursor;
  }

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
