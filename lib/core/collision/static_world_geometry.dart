/// Static collision geometry owned by the Core simulation.
///
/// V0 starts with a tiny, hand-authored set (ground band + a couple platforms),
/// and later milestones replace/extend this with deterministic chunk spawning.
class StaticGroundPlane {
  const StaticGroundPlane({required this.topY});

  /// World-space Y coordinate of the ground surface (solid top).
  final double topY;
}

class StaticGroundGap {
  const StaticGroundGap({required this.minX, required this.maxX})
    : assert(maxX >= minX);

  final double minX;
  final double maxX;
}

class StaticGroundSegment {
  const StaticGroundSegment({
    required this.minX,
    required this.maxX,
    required this.topY,
    this.chunkIndex = StaticSolid.groundChunk,
    this.localSegmentIndex = -1,
  }) : assert(maxX >= minX);

  final double minX;
  final double maxX;
  final double topY;

  /// Chunk index this segment was generated from, or [StaticSolid.groundChunk].
  final int chunkIndex;

  /// Stable local index within the chunk pattern authoring list.
  final int localSegmentIndex;
}

class StaticSolid {
  const StaticSolid({
    required this.minX,
    required this.minY,
    required this.maxX,
    required this.maxY,
    this.sides = sideTop,
    this.oneWayTop = true,
    this.chunkIndex = noChunk,
    this.localSolidIndex = -1,
  }) : assert(maxX >= minX),
       assert(maxY >= minY);

  final double minX;
  final double minY;
  final double maxX;
  final double maxY;

  /// Which faces of this solid participate in collision resolution.
  ///
  /// For V0:
  /// - one-way platforms typically use `sideTop` only
  /// - obstacles typically use `sideAll`
  final int sides;

  /// If true, the top surface only collides while falling (platform behavior).
  ///
  /// This only applies when [sides] includes [sideTop].
  final bool oneWayTop;

  /// Chunk index this solid was generated from (streaming), or [noChunk] for
  /// base/static geometry.
  final int chunkIndex;

  /// Stable local index within the chunk pattern authoring list.
  ///
  /// If negative, callers should derive a stable index from the owning list.
  final int localSolidIndex;

  static const int sideNone = 0;
  static const int sideTop = 1 << 0;
  static const int sideBottom = 1 << 1;
  static const int sideLeft = 1 << 2;
  static const int sideRight = 1 << 3;
  static const int sideAll = sideTop | sideBottom | sideLeft | sideRight;

  /// Sentinel for solids not tied to a streamed chunk.
  static const int noChunk = -2;

  /// Reserved chunk index for always-on surfaces (e.g. ground plane).
  static const int groundChunk = -1;
}

/// Immutable bundle of static solids for a run/session.
class StaticWorldGeometry {
  const StaticWorldGeometry({
    this.groundPlane,
    this.groundSegments = const <StaticGroundSegment>[],
    this.solids = const <StaticSolid>[],
    this.groundGaps = const <StaticGroundGap>[],
  });

  /// Optional infinite ground plane (top surface only).
  final StaticGroundPlane? groundPlane;

  /// Walkable ground segments (used for collision + navigation).
  final List<StaticGroundSegment> groundSegments;

  final List<StaticSolid> solids;

  /// Holes in the ground plane (world-space X ranges).
  final List<StaticGroundGap> groundGaps;
}
