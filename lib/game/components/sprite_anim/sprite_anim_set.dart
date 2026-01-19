/// Shared render-side sprite animation bundle.
library;

import 'dart:math';

import 'package:flame/components.dart';

import '../../../core/snapshots/enums.dart';

class SpriteAnimSet {
  SpriteAnimSet({
    required this.animations,
    required this.stepTimeSecondsByKey,
    required this.oneShotKeys,
    required this.frameSize,
    this.anchor = Anchor.center,
  });

  final Map<AnimKey, SpriteAnimation> animations;
  final Map<AnimKey, double> stepTimeSecondsByKey;
  final Set<AnimKey> oneShotKeys;

  /// Source frame size inside each horizontal strip image.
  final Vector2 frameSize;

  /// Anchor used by view components when rendering this animation set.
  ///
  /// Defaults to `Anchor.center`.
  final Anchor anchor;

  final Map<int, Map<AnimKey, int>> _ticksPerFrameCache =
      <int, Map<AnimKey, int>>{};

  int ticksPerFrameFor(AnimKey key, int tickHz) {
    final cache = _ticksPerFrameCache.putIfAbsent(
      tickHz,
      () => <AnimKey, int>{},
    );
    final existing = cache[key];
    if (existing != null) return existing;

    final stepSeconds =
        stepTimeSecondsByKey[key] ?? stepTimeSecondsByKey[AnimKey.idle] ?? 0.10;
    final ticks = max(1, (stepSeconds * tickHz).round());
    cache[key] = ticks;
    return ticks;
  }
}
