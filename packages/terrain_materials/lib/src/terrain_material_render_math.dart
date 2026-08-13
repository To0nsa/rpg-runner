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
