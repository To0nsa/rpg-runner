/// Player animation loading utilities (render layer only).
///
/// Loads horizontal sprite-strip animations from `assets/images/entities/player/`.
library;

import 'dart:ui';

import 'package:flame/cache.dart';
import 'package:flame/components.dart';

import '../../../core/snapshots/enums.dart';
import '../../../core/tuning/player_anim_defs.dart';

class PlayerAnimationSet {
  const PlayerAnimationSet({
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

Future<PlayerAnimationSet> loadPlayerAnimations(Images images) async {
  final oneShotKeys = <AnimKey>{
    AnimKey.attack,
    AnimKey.cast,
    AnimKey.hit,
    AnimKey.death,
  };

  final frameSize = Vector2(
    playerAnimFrameWidth.toDouble(),
    playerAnimFrameHeight.toDouble(),
  );
  final sources = <AnimKey, String>{
    AnimKey.idle: 'entities/player/idle.png',
    AnimKey.run: 'entities/player/move.png',
    AnimKey.jump: 'entities/player/jump.png',
    AnimKey.fall: 'entities/player/fall.png',
    AnimKey.attack: 'entities/player/attack.png',
    AnimKey.cast: 'entities/player/cast.png',
    AnimKey.dash: 'entities/player/dash.png',
    AnimKey.hit: 'entities/player/hit.png',
    AnimKey.death: 'entities/player/death.png',
  };

  final imagesByKey = <AnimKey, Image>{};
  for (final entry in sources.entries) {
    imagesByKey[entry.key] = await images.load(entry.value);
  }

  final animations = <AnimKey, SpriteAnimation>{};

  for (final entry in imagesByKey.entries) {
    final key = entry.key;
    final img = entry.value;
    final stepTime =
        playerAnimStepTimeSecondsByKey[key] ?? playerAnimIdleStepSeconds;
    final frameCount =
        playerAnimFrameCountsByKey[key] ?? playerAnimIdleFrames;
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

  // No dedicated spawn strip yet; map to idle for now.
  animations[AnimKey.spawn] ??= animations[AnimKey.idle]!;

  return PlayerAnimationSet(
    animations: animations,
    stepTimeSecondsByKey: playerAnimStepTimeSecondsByKey,
    oneShotKeys: oneShotKeys,
    frameSize: frameSize,
  );
}
