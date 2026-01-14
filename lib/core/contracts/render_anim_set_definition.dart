/// Render animation strip metadata shared between Core and Render.
library;

import '../snapshots/enums.dart';

/// Data-driven animation strip definition (frame size, paths, timing).
class RenderAnimSetDefinition {
  const RenderAnimSetDefinition({
    required this.frameWidth,
    required this.frameHeight,
    required this.sourcesByKey,
    required this.frameCountsByKey,
    required this.stepTimeSecondsByKey,
  });

  final int frameWidth;
  final int frameHeight;

  /// Asset paths (relative to `assets/images/`) for each animation strip.
  final Map<AnimKey, String> sourcesByKey;

  final Map<AnimKey, int> frameCountsByKey;
  final Map<AnimKey, double> stepTimeSecondsByKey;
}
