/// Static collision geometry owned by the Core simulation.
///
/// V0 starts with a tiny, hand-authored set (ground band + a couple platforms),
/// and later milestones replace/extend this with deterministic chunk spawning.
class StaticGroundPlane {
  const StaticGroundPlane({required this.topY});

  /// World-space Y coordinate of the ground surface (solid top).
  final double topY;
}

class StaticSolid {
  const StaticSolid({
    required this.minX,
    required this.minY,
    required this.maxX,
    required this.maxY,
    this.sides = sideTop,
    this.oneWayTop = true,
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

  static const int sideNone = 0;
  static const int sideTop = 1 << 0;
  static const int sideBottom = 1 << 1;
  static const int sideLeft = 1 << 2;
  static const int sideRight = 1 << 3;
  static const int sideAll = sideTop | sideBottom | sideLeft | sideRight;
}

/// Immutable bundle of static solids for a run/session.
class StaticWorldGeometry {
  const StaticWorldGeometry({
    this.groundPlane,
    this.solids = const <StaticSolid>[],
  });

  /// Optional infinite ground plane (top surface only).
  final StaticGroundPlane? groundPlane;

  final List<StaticSolid> solids;
}
