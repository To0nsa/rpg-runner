/// Unoco Demon render animation loading (render layer only).
library;

import 'package:flame/cache.dart';

import '../../../core/snapshots/enums.dart';
import '../sprite_anim/sprite_anim_set.dart';
import '../sprite_anim/strip_animation_loader.dart';

const _unocoFrameWidth = 81;
const _unocoFrameHeight = 71;

const _unocoFlyingFrames = 4;
const _unocoHitFrames = 4;
const _unocoDeathFrames = 7;

const _unocoFlyingStepSeconds = 0.12;
const _unocoHitStepSeconds = 0.10;
const _unocoDeathStepSeconds = 0.12;

Future<SpriteAnimSet> loadUnocoDemonAnimations(Images images) async {
  final oneShotKeys = <AnimKey>{AnimKey.hit, AnimKey.death};

  final sources = <AnimKey, String>{
    // Default state: "flying".
    AnimKey.idle: 'entities/enemies/unoco/flying.png',
    AnimKey.hit: 'entities/enemies/unoco/hit.png',
    AnimKey.death: 'entities/enemies/unoco/death.png',
  };
  final frameCounts = <AnimKey, int>{
    AnimKey.idle: _unocoFlyingFrames,
    AnimKey.hit: _unocoHitFrames,
    AnimKey.death: _unocoDeathFrames,
  };
  final stepTimes = <AnimKey, double>{
    AnimKey.idle: _unocoFlyingStepSeconds,
    AnimKey.hit: _unocoHitStepSeconds,
    AnimKey.death: _unocoDeathStepSeconds,
  };

  return loadStripAnimations(
    images,
    frameWidth: _unocoFrameWidth,
    frameHeight: _unocoFrameHeight,
    sourcesByKey: sources,
    frameCountsByKey: frameCounts,
    stepTimeSecondsByKey: stepTimes,
    oneShotKeys: oneShotKeys,
  );
}
