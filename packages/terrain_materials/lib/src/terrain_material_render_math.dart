import 'dart:math' as math;

/// World-facing role of one authored terrain edge region.
enum TerrainMaterialEdgeOrientation { top, leftWall, rightWall, underside }

/// Endpoint of the earlier-painted edge that can underlap an adjacent edge.
enum TerrainMaterialJoinEndpoint { start, end }

/// Returns stable back-to-front indices for terrain edge decoration.
///
/// Source order is retained within each group, while top-facing edges are
/// returned last so the playable surface silhouette wins at shared corners.
List<int> terrainMaterialEdgePaintOrder(
  Iterable<TerrainMaterialEdgeOrientation> orientations,
) {
  final values = orientations.toList(growable: false);
  return List<int>.unmodifiable(<int>[
    for (var index = 0; index < values.length; index += 1)
      if (values[index] != TerrainMaterialEdgeOrientation.top) index,
    for (var index = 0; index < values.length; index += 1)
      if (values[index] == TerrainMaterialEdgeOrientation.top) index,
  ]);
}

/// Returns the interior-depth multiplier needed to close a diverging join.
///
/// [lowerTangentX] and [lowerTangentY] follow the edge that paints first, and
/// [lowerInwardNormalX] and [lowerInwardNormalY] point into its polygon. The
/// upper tangent belongs to the adjacent edge that paints later. For an [endpoint]
/// of [TerrainMaterialJoinEndpoint.end], the upper edge starts at the shared
/// join; for `start`, the upper edge ends there.
///
/// A zero result means the clipped rectangular bands already meet, including
/// straight and converging joins. A positive result is multiplied by the
/// layer's interior depth so only the earlier edge extends beneath the later
/// one.
double terrainMaterialJoinUnderlapFactor({
  required TerrainMaterialJoinEndpoint endpoint,
  required double lowerTangentX,
  required double lowerTangentY,
  required double lowerInwardNormalX,
  required double lowerInwardNormalY,
  required double upperTangentX,
  required double upperTangentY,
}) {
  final values = <double>[
    lowerTangentX,
    lowerTangentY,
    lowerInwardNormalX,
    lowerInwardNormalY,
    upperTangentX,
    upperTangentY,
  ];
  if (values.any((value) => !value.isFinite)) {
    throw ArgumentError('Terrain join vectors must be finite.');
  }
  final lowerLength = math.sqrt(
    lowerTangentX * lowerTangentX + lowerTangentY * lowerTangentY,
  );
  final inwardLength = math.sqrt(
    lowerInwardNormalX * lowerInwardNormalX +
        lowerInwardNormalY * lowerInwardNormalY,
  );
  final upperLength = math.sqrt(
    upperTangentX * upperTangentX + upperTangentY * upperTangentY,
  );
  if (lowerLength <= _terrainMaterialJoinEpsilon ||
      inwardLength <= _terrainMaterialJoinEpsilon ||
      upperLength <= _terrainMaterialJoinEpsilon) {
    return 0;
  }

  final lowerX = lowerTangentX / lowerLength;
  final lowerY = lowerTangentY / lowerLength;
  final inwardX = lowerInwardNormalX / inwardLength;
  final inwardY = lowerInwardNormalY / inwardLength;
  final upperX = upperTangentX / upperLength;
  final upperY = upperTangentY / upperLength;
  final alignment = lowerX * upperX + lowerY * upperY;
  if (alignment <= _terrainMaterialJoinEpsilon) return 0;

  final upperAcrossLowerNormal = upperX * inwardX + upperY * inwardY;
  final divergence = switch (endpoint) {
    TerrainMaterialJoinEndpoint.start => upperAcrossLowerNormal,
    TerrainMaterialJoinEndpoint.end => -upperAcrossLowerNormal,
  };
  if (divergence <= _terrainMaterialJoinEpsilon) return 0;
  return divergence / alignment;
}

/// Clockwise quarter-turns that normalize a world-facing region so its edge
/// tangent runs left-to-right and its material interior faces down.
///
/// Runtime and editor painters apply this normalization before rotating the
/// result onto the actual edge. Consequently, axis-aligned source art keeps
/// the same visual orientation it has in its atlas.
int terrainMaterialEdgeNormalizationQuarterTurns(
  TerrainMaterialEdgeOrientation orientation,
) => switch (orientation) {
  TerrainMaterialEdgeOrientation.top => 0,
  TerrainMaterialEdgeOrientation.leftWall => 1,
  TerrainMaterialEdgeOrientation.rightWall => 3,
  TerrainMaterialEdgeOrientation.underside => 2,
};

/// Width of a world-facing edge region after tangent-space normalization.
int terrainMaterialEdgeTileWidth({
  required TerrainMaterialEdgeOrientation orientation,
  required int sourceWidth,
  required int sourceHeight,
}) => switch (orientation) {
  TerrainMaterialEdgeOrientation.leftWall ||
  TerrainMaterialEdgeOrientation.rightWall => sourceHeight,
  TerrainMaterialEdgeOrientation.top ||
  TerrainMaterialEdgeOrientation.underside => sourceWidth,
};

/// Height of a world-facing edge region after tangent-space normalization.
///
/// `anchorY` is measured against this normalized height. For wall art this is
/// the source region width; for top and underside art it is its source height.
int terrainMaterialEdgeTileHeight({
  required TerrainMaterialEdgeOrientation orientation,
  required int sourceWidth,
  required int sourceHeight,
}) => switch (orientation) {
  TerrainMaterialEdgeOrientation.leftWall ||
  TerrainMaterialEdgeOrientation.rightWall => sourceWidth,
  TerrainMaterialEdgeOrientation.top ||
  TerrainMaterialEdgeOrientation.underside => sourceHeight,
};

/// Positive repeat remainder shared by runtime and editor previews.
double terrainMaterialPositiveModulo(double value, double repeatSize) {
  if (!value.isFinite || !repeatSize.isFinite || repeatSize <= 0) {
    throw ArgumentError('Repeat coordinates must be finite and size positive.');
  }
  final remainder = value % repeatSize;
  return remainder < 0 ? remainder + repeatSize : remainder;
}

/// Repeat phase from the signed projection of a world point onto a tangent.
double terrainMaterialEdgeRepeatPhase({
  required double startX,
  required double startY,
  required double tangentX,
  required double tangentY,
  required double repeatWidth,
}) => terrainMaterialPositiveModulo(
  (startX * tangentX) + (startY * tangentY),
  repeatWidth,
);

/// First world-space tile origin at or before [coordinate].
double terrainMaterialTileStart(double coordinate, double repeatSize) =>
    coordinate - terrainMaterialPositiveModulo(coordinate, repeatSize);

const double _terrainMaterialJoinEpsilon = 0.000001;
