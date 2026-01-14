/// Shared render-side sprite animation bundle.
library;

import 'package:flame/components.dart';

import '../../../core/snapshots/enums.dart';

class SpriteAnimSet {
  const SpriteAnimSet({
    required this.animations,
    required this.stepTimeSecondsByKey,
    required this.oneShotKeys,
    required this.frameSize,
  });

  final Map<AnimKey, SpriteAnimation> animations;
  final Map<AnimKey, double> stepTimeSecondsByKey;
  final Set<AnimKey> oneShotKeys;

  /// Source frame size inside each horizontal strip image.
  final Vector2 frameSize;
}

