/// Shared sprite-strip animation loader utilities (render layer only).
library;

import 'dart:ui';

import 'package:flame/cache.dart';
import 'package:flame/components.dart';

import '../../../core/snapshots/enums.dart';
import 'sprite_anim_set.dart';

Future<SpriteAnimSet> loadStripAnimations(
  Images images, {
  required int frameWidth,
  required int frameHeight,
  required Map<AnimKey, String> sourcesByKey,
  required Map<AnimKey, int> frameCountsByKey,
  required Map<AnimKey, double> stepTimeSecondsByKey,
  required Set<AnimKey> oneShotKeys,
}) async {
  final frameSize = Vector2(frameWidth.toDouble(), frameHeight.toDouble());

  final imagesByKey = <AnimKey, Image>{};
  for (final entry in sourcesByKey.entries) {
    imagesByKey[entry.key] = await images.load(entry.value);
  }

  final animations = <AnimKey, SpriteAnimation>{};
  for (final entry in imagesByKey.entries) {
    final key = entry.key;
    final img = entry.value;
    final stepTime = stepTimeSecondsByKey[key] ??
        stepTimeSecondsByKey[AnimKey.idle] ??
        0.1;
    final frameCount =
        frameCountsByKey[key] ?? frameCountsByKey[AnimKey.idle] ?? 1;

    assert(
      img.height == frameSize.y.toInt() &&
          img.width == frameSize.x.toInt() * frameCount,
      'Strip ${key.name} must match ${frameSize.x.toInt()}x${frameSize.y.toInt()} frames x $frameCount.',
    );

    final data = SpriteAnimationData.sequenced(
      amount: frameCount,
      stepTime: stepTime,
      textureSize: frameSize,
      loop: !oneShotKeys.contains(key),
    );
    animations[key] = SpriteAnimation.fromFrameData(img, data);
  }

  return SpriteAnimSet(
    animations: animations,
    stepTimeSecondsByKey: stepTimeSecondsByKey,
    oneShotKeys: oneShotKeys,
    frameSize: frameSize,
  );
}

