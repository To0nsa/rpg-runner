/// World-facing role of one authored terrain edge region.
enum TerrainMaterialEdgeOrientation { top, leftWall, rightWall, underside }

/// Endpoint whose authored cap owns one convex connected terrain corner.
enum TerrainMaterialCornerOwner { incomingEnd, outgoingStart }

/// World-space half-width of the fill backing at an internal repeat seam.
///
/// One source pixel on each side covers the boundary texel of both neighboring
/// cells without backing the rest of the authored edge silhouette.
const double terrainMaterialRepeatSeamBackingHalfWidth = 1;

/// Tangent-normalized rectangle reserved for one endpoint or corner cap.
///
/// Coordinates are in world units relative to the edge start after the edge
/// has been rotated onto the positive X axis. The complete rectangle belongs
/// to the cap, including transparent source pixels, so lower-priority terrain
/// layers cannot leak through an authored cutout.
typedef TerrainMaterialCapFootprint = ({
  double left,
  double top,
  double width,
  double height,
});

/// Tangent-normalized rectangle owned by one repeating edge layer.
///
/// Coordinates use the same edge-local world space as
/// [TerrainMaterialCapFootprint]. Transparent pixels inside this rectangle
/// retain edge ownership instead of falling through to another terrain role.
typedef TerrainMaterialEdgeFootprint = ({
  double left,
  double top,
  double width,
  double height,
});

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

/// Selects the single authored cap that covers a connected convex corner.
///
/// The incoming inward normal and outgoing tangent may use any positive scale,
/// but must be finite and non-zero. A positive dot product means the boundary
/// turns into the owning polygon and therefore forms a convex visual corner.
/// Straight and concave joins return `null` because their clipped bands already
/// meet without an outer-corner patch.
///
/// When both endpoint caps exist, the top-facing edge wins so the playable
/// surface remains readable. Equal-priority ties select the incoming end,
/// guaranteeing one deterministic patch rather than two overlapping caps.
TerrainMaterialCornerOwner? terrainMaterialConnectedCornerOwner({
  required double incomingInwardNormalX,
  required double incomingInwardNormalY,
  required double outgoingTangentX,
  required double outgoingTangentY,
  required TerrainMaterialEdgeOrientation incomingOrientation,
  required TerrainMaterialEdgeOrientation outgoingOrientation,
  required bool incomingEndCapAvailable,
  required bool outgoingStartCapAvailable,
}) {
  final values = <double>[
    incomingInwardNormalX,
    incomingInwardNormalY,
    outgoingTangentX,
    outgoingTangentY,
  ];
  if (values.any((value) => !value.isFinite) ||
      (incomingInwardNormalX == 0 && incomingInwardNormalY == 0) ||
      (outgoingTangentX == 0 && outgoingTangentY == 0)) {
    throw ArgumentError('Terrain corner vectors must be finite and non-zero.');
  }
  final interiorTurn =
      incomingInwardNormalX * outgoingTangentX +
      incomingInwardNormalY * outgoingTangentY;
  if (interiorTurn <= 0 ||
      (!incomingEndCapAvailable && !outgoingStartCapAvailable)) {
    return null;
  }
  if (!incomingEndCapAvailable) {
    return TerrainMaterialCornerOwner.outgoingStart;
  }
  if (!outgoingStartCapAvailable) {
    return TerrainMaterialCornerOwner.incomingEnd;
  }
  if (incomingOrientation != TerrainMaterialEdgeOrientation.top &&
      outgoingOrientation == TerrainMaterialEdgeOrientation.top) {
    return TerrainMaterialCornerOwner.outgoingStart;
  }
  return TerrainMaterialCornerOwner.incomingEnd;
}

/// Returns the exclusive destination footprint of one terrain cap.
///
/// [edgeLength], [anchorX], and [anchorY] are world units in normalized edge
/// space. Source dimensions must be positive pixels. The returned rectangle
/// matches the bounds used by role-normalized cap painting.
TerrainMaterialCapFootprint terrainMaterialCapFootprint({
  required double edgeLength,
  required double anchorX,
  required double anchorY,
  required bool atEnd,
  required TerrainMaterialEdgeOrientation orientation,
  required int sourceWidth,
  required int sourceHeight,
}) {
  if (!edgeLength.isFinite || edgeLength <= 0) {
    throw ArgumentError.value(
      edgeLength,
      'edgeLength',
      'Must be finite and positive.',
    );
  }
  if (!anchorX.isFinite || !anchorY.isFinite) {
    throw ArgumentError('Terrain cap anchors must be finite.');
  }
  if (sourceWidth <= 0 || sourceHeight <= 0) {
    throw ArgumentError('Terrain cap source dimensions must be positive.');
  }
  return (
    left: (atEnd ? edgeLength : 0) - anchorX,
    top: -anchorY,
    width: terrainMaterialEdgeTileWidth(
      orientation: orientation,
      sourceWidth: sourceWidth,
      sourceHeight: sourceHeight,
    ).toDouble(),
    height: terrainMaterialEdgeTileHeight(
      orientation: orientation,
      sourceWidth: sourceWidth,
      sourceHeight: sourceHeight,
    ).toDouble(),
  );
}

/// Returns the exclusive destination footprint of one repeating edge layer.
///
/// [edgeLength] and [anchorY] are world units in normalized edge space. Source
/// dimensions must be positive pixels. The footprint matches the exact strip
/// bounds used by edge painting.
TerrainMaterialEdgeFootprint terrainMaterialEdgeFootprint({
  required double edgeLength,
  required double anchorY,
  required TerrainMaterialEdgeOrientation orientation,
  required int sourceWidth,
  required int sourceHeight,
}) {
  if (!edgeLength.isFinite || edgeLength <= 0) {
    throw ArgumentError.value(
      edgeLength,
      'edgeLength',
      'Must be finite and positive.',
    );
  }
  if (!anchorY.isFinite) {
    throw ArgumentError.value(anchorY, 'anchorY', 'Must be finite.');
  }
  if (sourceWidth <= 0 || sourceHeight <= 0) {
    throw ArgumentError('Terrain edge source dimensions must be positive.');
  }
  return (
    left: 0,
    top: -anchorY,
    width: edgeLength,
    height: terrainMaterialEdgeTileHeight(
      orientation: orientation,
      sourceWidth: sourceWidth,
      sourceHeight: sourceHeight,
    ).toDouble(),
  );
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

/// Returns internal repeat boundaries measured from an edge's start.
///
/// The result uses the same world-anchored phase as edge painting and excludes
/// the authored edge endpoints, which remain governed by cap ownership.
List<double> terrainMaterialEdgeRepeatSeamOffsets({
  required double startX,
  required double startY,
  required double tangentX,
  required double tangentY,
  required double edgeLength,
  required double repeatWidth,
}) {
  final values = <double>[
    startX,
    startY,
    tangentX,
    tangentY,
    edgeLength,
    repeatWidth,
  ];
  if (values.any((value) => !value.isFinite) || edgeLength <= 0) {
    throw ArgumentError('Terrain repeat seam inputs must be finite and valid.');
  }
  final phase = terrainMaterialEdgeRepeatPhase(
    startX: startX,
    startY: startY,
    tangentX: tangentX,
    tangentY: tangentY,
    repeatWidth: repeatWidth,
  );
  var seam = terrainMaterialTileStart(phase, repeatWidth) - phase;
  while (seam <= 0) {
    seam += repeatWidth;
  }
  final result = <double>[];
  while (seam < edgeLength) {
    result.add(seam);
    seam += repeatWidth;
  }
  return List<double>.unmodifiable(result);
}

/// First world-space tile origin at or before [coordinate].
double terrainMaterialTileStart(double coordinate, double repeatSize) =>
    coordinate - terrainMaterialPositiveModulo(coordinate, repeatSize);
