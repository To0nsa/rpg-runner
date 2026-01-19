/// Generic deterministic sprite animation component driven by Core snapshots.
library;

import 'package:flame/components.dart';
import 'package:flutter/widgets.dart';

import '../../../core/snapshots/entity_render_snapshot.dart';
import '../../../core/snapshots/enums.dart';
import 'sprite_anim_set.dart';
import '../../util/math_util.dart' as math;

typedef AnimKeyFallbackResolver = AnimKey Function(AnimKey desired);

class DeterministicAnimViewComponent
    extends SpriteAnimationGroupComponent<AnimKey> {
  DeterministicAnimViewComponent({
    required SpriteAnimSet animSet,
    AnimKey initial = AnimKey.idle,
    AnimKeyFallbackResolver? fallbackResolver,
    Vector2? renderSize,
    Vector2? renderScale,
    bool respectFacing = true,
  }) : _animSet = animSet,
       _availableAnimations = animSet.animations,
       _oneShotKeys = animSet.oneShotKeys,
       _fallbackResolver = fallbackResolver,
       _baseScale = renderScale?.clone() ?? Vector2.all(1.0),
       _respectFacing = respectFacing,
       super(
         animations: animSet.animations,
         current: initial,
         size: renderSize ?? Vector2(animSet.frameSize.x, animSet.frameSize.y),
         scale: renderScale?.clone() ?? Vector2.all(1.0),
         anchor: animSet.anchor,
         paint: Paint()..filterQuality = FilterQuality.none,
       ) {
    // We drive animation frames deterministically from `EntityRenderSnapshot.animFrame`.
    playing = false;
  }

  final SpriteAnimSet _animSet;
  final Map<AnimKey, SpriteAnimation> _availableAnimations;
  final Set<AnimKey> _oneShotKeys;
  final AnimKeyFallbackResolver? _fallbackResolver;
  final Vector2 _baseScale;
  final bool _respectFacing;

  void applySnapshot(
    EntityRenderSnapshot e, {
    required int tickHz,
    Vector2? pos,
    AnimKey? overrideAnim,
    int? overrideAnimFrame,
  }) {
    if (pos != null) {
      position.setFrom(pos);
    } else {
      position.setValues(
        math.roundToPixels(e.pos.x),
        math.roundToPixels(e.pos.y),
      );
    }

    var next = overrideAnim ?? e.anim;
    if (_fallbackResolver != null) {
      next = _fallbackResolver(next);
    }
    if (!_availableAnimations.containsKey(next)) {
      next = AnimKey.idle;
    }
    if (current != next) {
      current = next;
    }

    if (_respectFacing) {
      final artFacing = e.artFacingDir ?? Facing.right;
      final sign = e.facing == artFacing ? 1.0 : -1.0;
      final desiredScaleX = _baseScale.x * sign;
      if (scale.x != desiredScaleX || scale.y != _baseScale.y) {
        scale.setValues(desiredScaleX, _baseScale.y);
      }
    } else if (scale.x != _baseScale.x || scale.y != _baseScale.y) {
      scale.setValues(_baseScale.x, _baseScale.y);
    }

    final frameHint = overrideAnimFrame ?? e.animFrame;
    if (frameHint == null) return;

    final ticker = animationTicker;
    final anim = animation;
    if (ticker == null || anim == null) return;

    final framesLen = anim.frames.length;
    if (framesLen <= 1) return;

    final currentKey = current ?? AnimKey.idle;
    final ticksPerFrame = _animSet.ticksPerFrameFor(currentKey, tickHz);
    final rawIndex = frameHint ~/ ticksPerFrame;
    final index = _oneShotKeys.contains(currentKey)
        ? rawIndex.clamp(0, framesLen - 1).toInt()
        : rawIndex % framesLen;
    ticker.currentIndex = index;
  }
}
