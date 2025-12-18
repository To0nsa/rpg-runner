import 'static_world_geometry.dart';

/// Pre-indexed view of static world geometry for faster collision queries.
///
/// This is constructed once (per run/session) and preserves the original solid
/// ordering in each face list to keep behavior deterministic.
class StaticWorldGeometryIndex {
  StaticWorldGeometryIndex._({
    required this.geometry,
    required this.groundPlane,
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

    return StaticWorldGeometryIndex._(
      geometry: geometry,
      groundPlane: geometry.groundPlane,
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

  /// Solids with an enabled top face.
  final List<StaticSolid> tops;

  /// Solids with an enabled bottom face (ceilings).
  final List<StaticSolid> bottoms;

  /// Solids with an enabled left face (walls hit when moving right).
  final List<StaticSolid> leftWalls;

  /// Solids with an enabled right face (walls hit when moving left).
  final List<StaticSolid> rightWalls;
}
