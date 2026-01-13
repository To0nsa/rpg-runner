/// Player render component driven purely by Core snapshots.
library;

import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/widgets.dart';

import '../../../core/snapshots/entity_render_snapshot.dart';
import '../../../core/snapshots/enums.dart';
import 'player_animations.dart';

class PlayerViewComponent extends SpriteAnimationGroupComponent<AnimKey> {
  PlayerViewComponent({
    required PlayerAnimationSet animationSet,
    Vector2? renderSize,
    Vector2? renderScale,
  }) : _stepTimeSecondsByKey = animationSet.stepTimeSecondsByKey,
       _availableAnimations = animationSet.animations,
       _oneShotKeys = animationSet.oneShotKeys,
       _baseScale = renderScale?.clone() ?? Vector2.all(1.0),
       super(
         animations: animationSet.animations,
         current: AnimKey.idle,
         size: renderSize ??
             Vector2(animationSet.frameSize.x, animationSet.frameSize.y),
         scale: renderScale?.clone() ?? Vector2.all(1.0),
         anchor: Anchor.center,
         paint: Paint()..filterQuality = FilterQuality.none,
       ) {
    // We drive animation frames deterministically from `EntityRenderSnapshot.animFrame`.
    playing = false;
  }

  final Map<AnimKey, double> _stepTimeSecondsByKey;
  final Map<AnimKey, SpriteAnimation> _availableAnimations;
  final Set<AnimKey> _oneShotKeys;
  final Vector2 _baseScale;

  void applySnapshot(EntityRenderSnapshot e, {required int tickHz}) {
    position.setValues(e.pos.x.roundToDouble(), e.pos.y.roundToDouble());

    AnimKey nextAnim = e.anim;
    if (!_availableAnimations.containsKey(nextAnim)) {
      // Allow directional variants to fall back to their base animation key.
      if (nextAnim == AnimKey.attackLeft &&
          _availableAnimations.containsKey(AnimKey.attack)) {
        nextAnim = AnimKey.attack;
      } else {
        nextAnim = AnimKey.idle;
      }
    }
    if (current != nextAnim) {
      current = nextAnim;
    }

    final desiredScaleX = _baseScale.x * (e.facing == Facing.right ? 1.0 : -1.0);
    if (scale.x != desiredScaleX || scale.y != _baseScale.y) {
      scale.setValues(desiredScaleX, _baseScale.y);
    }

    final frameHint = e.animFrame;
    if (frameHint == null) return;

    final ticker = animationTicker;
    final anim = animation;
    if (ticker == null || anim == null) return;

    final framesLen = anim.frames.length;
    if (framesLen <= 1) return;

    final stepSeconds = _stepTimeSecondsByKey[current] ?? 0.10;
    final ticksPerFrame = max(1, (stepSeconds * tickHz).round());
    final rawIndex = frameHint ~/ ticksPerFrame;
    final index = _oneShotKeys.contains(current)
        ? rawIndex.clamp(0, framesLen - 1).toInt()
        : rawIndex % framesLen;
    ticker.currentIndex = index;
  }
}
