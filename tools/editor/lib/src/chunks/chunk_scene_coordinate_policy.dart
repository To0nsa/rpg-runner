/// Quantizes one direct-manipulation coordinate with deterministic half ties.
int quantizeChunkSceneCoordinate(double value, {required int step}) {
  if (!value.isFinite) {
    throw ArgumentError.value(value, 'value', 'must be finite');
  }
  if (step <= 0) {
    throw ArgumentError.value(step, 'step', 'must be positive');
  }
  return _roundTiesAwayFromZero(value / step) * step;
}

/// Applies the persisted prefab snapping preference to a scene gesture.
int quantizeChunkPrefabGestureCoordinate(
  double value, {
  required int tileSize,
  required bool snapToGrid,
}) => quantizeChunkSceneCoordinate(value, step: snapToGrid ? tileSize : 1);

/// Preserves intentional integer-pixel inspector input without grid snapping.
int preserveChunkExactPixelCoordinate(int value) => value;

int _roundTiesAwayFromZero(double value) =>
    value < 0 ? (value - 0.5).ceil() : (value + 0.5).floor();
