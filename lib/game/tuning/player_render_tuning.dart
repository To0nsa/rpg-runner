/// Render-layer tuning for player sprite presentation.
library;

import 'package:flutter/foundation.dart';

@immutable
class PlayerRenderTuning {
  const PlayerRenderTuning({
    this.scale = 0.75,
  });

  /// Uniform scale applied to the 100x64 sprite frames.
  final double scale;
}
