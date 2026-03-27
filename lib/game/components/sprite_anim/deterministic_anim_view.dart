/// Generic deterministic sprite animation component driven by Core snapshots.
library;

import 'dart:math' as dart_math;

import 'package:flame/components.dart';
import 'package:flutter/widgets.dart';

import 'package:runner_core/snapshots/entity_render_snapshot.dart';
import 'package:runner_core/snapshots/enums.dart';
import '../../tuning/combat_feedback_tuning.dart';
import 'sprite_anim_set.dart';
import '../../util/math_util.dart' as math;

typedef AnimKeyFallbackResolver = AnimKey Function(AnimKey desired);

enum RenderVisualStyle { live, ghost }

class DeterministicAnimView
    extends SpriteAnimationGroupComponent<AnimKey> {
  DeterministicAnimView({
    required SpriteAnimSet animSet,
    AnimKey initial = AnimKey.idle,
    AnimKeyFallbackResolver? fallbackResolver,
    Vector2? renderSize,
    Vector2? renderScale,
    bool respectFacing = true,
    CombatFeedbackTuning feedbackTuning = const CombatFeedbackTuning(),
    RenderVisualStyle visualStyle = RenderVisualStyle.live,
  }) : _animSet = animSet,
       _availableAnimations = animSet.animations,
       _oneShotKeys = animSet.oneShotKeys,
       _fallbackResolver = fallbackResolver,
       _baseScale = renderScale?.clone() ?? Vector2.all(1.0),
       _feedbackTuning = feedbackTuning,
      _respectFacing = respectFacing,
      _visualStyle = visualStyle,
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
    _dotPulseColor = feedbackTuning.dotFallbackColor;
    _resourcePulseColor = feedbackTuning.resourceFallbackColor;
  }

  final SpriteAnimSet _animSet;
  final Map<AnimKey, SpriteAnimation> _availableAnimations;
  final Set<AnimKey> _oneShotKeys;
  final AnimKeyFallbackResolver? _fallbackResolver;
  final Vector2 _baseScale;
  CombatFeedbackTuning _feedbackTuning;
  final bool _respectFacing;
  RenderVisualStyle _visualStyle;
  int _statusVisualMask = EntityStatusVisualMask.none;
  double _directHitFlashSeconds = 0.0;
  double _directHitFlashDurationSeconds = 0.0;
  double _directHitFlashStrength = 0.0;
  double _dotPulseSeconds = 0.0;
  double _dotPulseDurationSeconds = 0.0;
  double _dotPulseStrength = 0.0;
  Color _dotPulseColor = const Color(0xFFFFFFFF);
  double _resourcePulseSeconds = 0.0;
  double _resourcePulseDurationSeconds = 0.0;
  double _resourcePulseStrength = 0.0;
  Color _resourcePulseColor = const Color(0xFFFFFFFF);

  /// Updates render feedback tuning at runtime.
  void setFeedbackTuning(CombatFeedbackTuning tuning) {
    _feedbackTuning = tuning;
  }

  /// Updates render visual style at runtime.
  void setVisualStyle(RenderVisualStyle visualStyle) {
    _visualStyle = visualStyle;
  }

  /// Sets persistent status visuals for this entity.
  void setStatusVisualMask(int mask) {
    _statusVisualMask = mask;
  }

  /// Triggers a white impact flash.
  void triggerDirectHitFlash({double intensity01 = 1.0}) {
    final intensity = intensity01.clamp(0.0, 1.0);
    if (intensity <= 0.0) return;
    _directHitFlashDurationSeconds = _feedbackTuning.directHitPulse
        .durationForIntensity(intensity);
    _directHitFlashSeconds = _directHitFlashDurationSeconds;
    _directHitFlashStrength = _feedbackTuning.directHitPulse.alphaForIntensity(
      intensity,
    );
  }

  /// Triggers a DoT pulse flash.
  void triggerDotPulse({required Color color, double intensity01 = 1.0}) {
    final intensity = intensity01.clamp(0.0, 1.0);
    if (intensity <= 0.0) return;
    _dotPulseColor = color;
    _dotPulseDurationSeconds = _feedbackTuning.dotPulse.durationForIntensity(
      intensity,
    );
    _dotPulseSeconds = _dotPulseDurationSeconds;
    _dotPulseStrength = _feedbackTuning.dotPulse.alphaForIntensity(intensity);
  }

  /// Triggers a resource-over-time pulse flash.
  void triggerResourcePulse({required Color color, double intensity01 = 1.0}) {
    final intensity = intensity01.clamp(0.0, 1.0);
    if (intensity <= 0.0) return;
    _resourcePulseColor = color;
    _resourcePulseDurationSeconds = _feedbackTuning.resourcePulse
        .durationForIntensity(intensity);
    _resourcePulseSeconds = _resourcePulseDurationSeconds;
    _resourcePulseStrength = _feedbackTuning.resourcePulse.alphaForIntensity(
      intensity,
    );
  }

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

  @override
  void render(Canvas canvas) {
    if (_visualStyle != RenderVisualStyle.ghost) {
      super.render(canvas);
      return;
    }

    final originalFilter = paint.colorFilter;
    final originalOpacity = opacity;
    paint.colorFilter = const ColorFilter.mode(
      Color.fromARGB(230, 0, 0, 0),
      BlendMode.srcATop,
    );
    opacity = 1.0;

    const outlineOffsets = <Offset>[
      Offset(-1.0, -1.0),
      Offset(-1.0, 0.0),
      Offset(-1.0, 1.0),
      Offset(1.0, 0.0),
      Offset(1.0, -1.0),
      Offset(1.0, 1.0),
      Offset(0.0, -1.0),
      Offset(0.0, 1.0),
    ];
    for (final offset in outlineOffsets) {
      canvas.save();
      canvas.translate(offset.dx, offset.dy);
      super.render(canvas);
      canvas.restore();
    }

    paint.colorFilter = originalFilter;
    opacity = originalOpacity;
    super.render(canvas);
  }

  @override
  void update(double dt) {
    _directHitFlashSeconds = dart_math.max(0.0, _directHitFlashSeconds - dt);
    _dotPulseSeconds = dart_math.max(0.0, _dotPulseSeconds - dt);
    _resourcePulseSeconds = dart_math.max(0.0, _resourcePulseSeconds - dt);
    _applyVisualTint();
    super.update(dt);
  }

  void _applyVisualTint() {
    if (_visualStyle == RenderVisualStyle.ghost) {
      _applyGhostVisualTint();
      return;
    }
    double weightedRed = 0.0;
    double weightedGreen = 0.0;
    double weightedBlue = 0.0;
    double totalWeight = 0.0;
    double totalAlpha = 0.0;

    void addTint(Color color, double alpha) {
      if (alpha <= 0.0) return;
      weightedRed += color.r * alpha;
      weightedGreen += color.g * alpha;
      weightedBlue += color.b * alpha;
      totalWeight += alpha;
      totalAlpha += alpha;
    }

    final statusOverlay = _statusOverlayForMask(_statusVisualMask);
    addTint(statusOverlay.$1, statusOverlay.$2);

    if (_dotPulseSeconds > 0.0 && _dotPulseDurationSeconds > 0.0) {
      final t = (_dotPulseSeconds / _dotPulseDurationSeconds).clamp(0.0, 1.0);
      addTint(
        _dotPulseColor,
        _dotPulseStrength *
            _fadeWeight(t, _feedbackTuning.dotPulse.fadeExponent),
      );
    }
    if (_resourcePulseSeconds > 0.0 && _resourcePulseDurationSeconds > 0.0) {
      final t = (_resourcePulseSeconds / _resourcePulseDurationSeconds).clamp(
        0.0,
        1.0,
      );
      addTint(
        _resourcePulseColor,
        _resourcePulseStrength *
            _fadeWeight(t, _feedbackTuning.resourcePulse.fadeExponent),
      );
    }
    if (_directHitFlashSeconds > 0.0 && _directHitFlashDurationSeconds > 0.0) {
      final t = (_directHitFlashSeconds / _directHitFlashDurationSeconds).clamp(
        0.0,
        1.0,
      );
      addTint(
        _feedbackTuning.directHitColor,
        _directHitFlashStrength *
            _fadeWeight(t, _feedbackTuning.directHitPulse.fadeExponent),
      );
    }

    if (totalWeight <= 0.0 || totalAlpha <= 0.0) {
      paint.colorFilter = null;
      return;
    }

    final red = _channel255(weightedRed / totalWeight);
    final green = _channel255(weightedGreen / totalWeight);
    final blue = _channel255(weightedBlue / totalWeight);
    final alpha = totalAlpha.clamp(0.0, 1.0);
    final color = Color.fromARGB((alpha * 255.0).round(), red, green, blue);
    paint.colorFilter = ColorFilter.mode(color, BlendMode.srcATop);
    opacity = 1.0;
  }

  void _applyGhostVisualTint() {
    const ghostBaseAlpha = 0.72;
    var totalAlpha = ghostBaseAlpha;

    final statusOverlay = _statusOverlayForMask(_statusVisualMask);
    totalAlpha += statusOverlay.$2 * 0.35;

    if (_dotPulseSeconds > 0.0 && _dotPulseDurationSeconds > 0.0) {
      final t = (_dotPulseSeconds / _dotPulseDurationSeconds).clamp(0.0, 1.0);
      totalAlpha +=
          _dotPulseStrength *
          _fadeWeight(t, _feedbackTuning.dotPulse.fadeExponent) *
          0.30;
    }
    if (_resourcePulseSeconds > 0.0 && _resourcePulseDurationSeconds > 0.0) {
      final t = (_resourcePulseSeconds / _resourcePulseDurationSeconds).clamp(
        0.0,
        1.0,
      );
      totalAlpha +=
          _resourcePulseStrength *
          _fadeWeight(t, _feedbackTuning.resourcePulse.fadeExponent) *
          0.30;
    }
    if (_directHitFlashSeconds > 0.0 && _directHitFlashDurationSeconds > 0.0) {
      final t = (_directHitFlashSeconds / _directHitFlashDurationSeconds).clamp(
        0.0,
        1.0,
      );
      totalAlpha +=
          _directHitFlashStrength *
          _fadeWeight(t, _feedbackTuning.directHitPulse.fadeExponent) *
          0.40;
    }
    final alpha = totalAlpha.clamp(0.55, 0.92);
    paint.colorFilter = ColorFilter.mode(
      Color.fromARGB((alpha * 255.0).round(), 255, 255, 255),
      BlendMode.srcATop,
    );
    opacity = 1.0;
  }

  (Color, double) _statusOverlayForMask(int mask) {
    if (mask == EntityStatusVisualMask.none) {
      return (const Color(0xFFFFFFFF), 0.0);
    }

    var weightedRed = 0.0;
    var weightedGreen = 0.0;
    var weightedBlue = 0.0;
    var count = 0;

    void addForBit(int bit) {
      final color = _feedbackTuning.statusColorByMaskBit[bit];
      if (color == null) return;
      weightedRed += color.r;
      weightedGreen += color.g;
      weightedBlue += color.b;
      count += 1;
    }

    // Apply all configured status-color bits so newly added mask bits do not
    // require manual updates here.
    for (final bit in _feedbackTuning.statusColorByMaskBit.keys) {
      if ((mask & bit) != 0) {
        addForBit(bit);
      }
    }

    if (count == 0) {
      return (const Color(0xFFFFFFFF), 0.0);
    }

    final red = _channel255(weightedRed / count);
    final green = _channel255(weightedGreen / count);
    final blue = _channel255(weightedBlue / count);
    final alpha =
        (_feedbackTuning.statusBaseAlpha +
                ((count - 1) * _feedbackTuning.statusAdditionalAlphaPerEffect))
            .clamp(0.0, _feedbackTuning.statusMaxAlpha);
    return (Color.fromARGB(255, red, green, blue), alpha);
  }

  double _fadeWeight(double value, double exponent) {
    if (value <= 0.0) return 0.0;
    if (value >= 1.0) return 1.0;
    return dart_math.pow(value, exponent).toDouble();
  }

  int _channel255(double value01) {
    final scaled = (value01 * 255.0).round();
    if (scaled < 0) return 0;
    if (scaled > 255) return 255;
    return scaled;
  }
}
