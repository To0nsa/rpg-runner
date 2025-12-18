/// Static collision geometry owned by the Core simulation.
///
/// V0 starts with a tiny, hand-authored set (ground band + a couple platforms),
/// and later milestones replace/extend this with deterministic chunk spawning.
class StaticSolid {
  const StaticSolid({
    required this.minX,
    required this.minY,
    required this.maxX,
    required this.maxY,
    this.oneWayTop = true,
  }) : assert(maxX >= minX),
       assert(maxY >= minY);

  final double minX;
  final double minY;
  final double maxX;
  final double maxY;

  /// If true, the top surface only collides while falling (platform behavior).
  final bool oneWayTop;
}

/// Immutable bundle of static solids for a run/session.
class StaticWorldGeometry {
  const StaticWorldGeometry({this.solids = const <StaticSolid>[]});

  final List<StaticSolid> solids;
}

