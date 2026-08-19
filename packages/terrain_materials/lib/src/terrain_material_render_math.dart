/// World-facing role of one authored terrain edge region.
enum TerrainMaterialEdgeOrientation { top, leftWall, rightWall, underside }

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
