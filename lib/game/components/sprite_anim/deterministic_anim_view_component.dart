/// Generic deterministic sprite animation component driven by Core snapshots.
library;

import 'package:flame/components.dart';
import 'package:flutter/widgets.dart';

import '../../../core/snapshots/entity_render_snapshot.dart';
import '../../../core/snapshots/enums.dart';
import 'sprite_anim_set.dart';

typedef AnimKeyFallbackResolver = AnimKey Function(AnimKey desired);

class DeterministicAnimViewComponent
    extends SpriteAnimationGroupComponent<AnimKey> {
  DeterministicAnimViewComponent({
    required SpriteAnimSet animSet,
    AnimKey initial = AnimKey.idle,
    AnimKeyFallbackResolver? fallbackResolver,
    Vector2? renderSize,
    Vector2? renderScale,
  }) : _animSet = animSet,
       _availableAnimations = animSet.animations,
       _oneShotKeys = animSet.oneShotKeys,
       _fallbackResolver = fallbackResolver,
       _baseScale = renderScale?.clone() ?? Vector2.all(1.0),
       super(
         animations: animSet.animations,
         current: initial,
         size: renderSize ?? Vector2(animSet.frameSize.x, animSet.frameSize.y),
         scale: renderScale?.clone() ?? Vector2.all(1.0),
         anchor: Anchor.center,
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

  void applySnapshot(EntityRenderSnapshot e, {required int tickHz}) {
    position.setValues(e.pos.x.roundToDouble(), e.pos.y.roundToDouble());

    var next = e.anim;
    if (_fallbackResolver != null) {
      next = _fallbackResolver(next);
    }
    if (!_availableAnimations.containsKey(next)) {
      next = AnimKey.idle;
    }
    if (current != next) {
      current = next;
    }

    final artFacing = e.artFacingDir ?? Facing.right;
    final sign = e.facing == artFacing ? 1.0 : -1.0;
    final desiredScaleX = _baseScale.x * sign;
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

    final currentKey = current ?? AnimKey.idle;
    final ticksPerFrame = _animSet.ticksPerFrameFor(currentKey, tickHz);
    final rawIndex = frameHint ~/ ticksPerFrame;
    final index = _oneShotKeys.contains(currentKey)
        ? rawIndex.clamp(0, framesLen - 1).toInt()
        : rawIndex % framesLen;
    ticker.currentIndex = index;
  }
}
