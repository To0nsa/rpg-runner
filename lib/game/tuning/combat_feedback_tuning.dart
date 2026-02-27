/// Render-layer tuning for combat hit/status feedback colors and pulse timing.
library;

import 'package:flutter/widgets.dart';

import '../../core/combat/damage_type.dart';
import '../../core/combat/status/status.dart';
import '../../core/snapshots/entity_render_snapshot.dart';

@immutable
class FeedbackPulseTuning {
  const FeedbackPulseTuning({
    required this.minDurationSeconds,
    required this.maxDurationSeconds,
    required this.minAlpha,
    required this.maxAlpha,
    this.fadeExponent = 2.0,
  });

  final double minDurationSeconds;
  final double maxDurationSeconds;
  final double minAlpha;
  final double maxAlpha;
  final double fadeExponent;

  double durationForIntensity(double intensity01) {
    final t = intensity01.clamp(0.0, 1.0);
    return minDurationSeconds + ((maxDurationSeconds - minDurationSeconds) * t);
  }

  double alphaForIntensity(double intensity01) {
    final t = intensity01.clamp(0.0, 1.0);
    return minAlpha + ((maxAlpha - minAlpha) * t);
  }
}

@immutable
class CombatFeedbackTuning {
  const CombatFeedbackTuning({
    this.directHitColor = const Color(0xFFFFFFFF),
    this.directHitPulse = const FeedbackPulseTuning(
      minDurationSeconds: 0.14,
      maxDurationSeconds: 0.22,
      minAlpha: 0.35,
      maxAlpha: 0.65,
      fadeExponent: 2.0,
    ),
    this.dotPulse = const FeedbackPulseTuning(
      minDurationSeconds: 0.14,
      maxDurationSeconds: 0.22,
      minAlpha: 0.35,
      maxAlpha: 0.65,
      fadeExponent: 2.0,
    ),
    this.resourcePulse = const FeedbackPulseTuning(
      minDurationSeconds: 0.14,
      maxDurationSeconds: 0.22,
      minAlpha: 0.35,
      maxAlpha: 0.65,
      fadeExponent: 2.0,
    ),
    this.dotFallbackColor = const Color(0xFFE5E7EB),
    this.resourceFallbackColor = const Color(0xFFE5E7EB),
    this.dotColorByDamageType = _defaultDotColorByDamageType,
    this.resourceColorByType = _defaultResourceColorByType,
    this.statusColorByMaskBit = _defaultStatusColorByMaskBit,
    this.statusBaseAlpha = 0.35,
    this.statusAdditionalAlphaPerEffect = 0.025,
    this.statusMaxAlpha = 0.45,
  });

  final Color directHitColor;
  final FeedbackPulseTuning directHitPulse;
  final FeedbackPulseTuning dotPulse;
  final FeedbackPulseTuning resourcePulse;

  final Color dotFallbackColor;
  final Color resourceFallbackColor;
  final Map<DamageType, Color> dotColorByDamageType;
  final Map<StatusResourceType, Color> resourceColorByType;

  final Map<int, Color> statusColorByMaskBit;
  final double statusBaseAlpha;
  final double statusAdditionalAlphaPerEffect;
  final double statusMaxAlpha;

  Color dotColorFor(DamageType? damageType) {
    if (damageType == null) return dotFallbackColor;
    return dotColorByDamageType[damageType] ?? dotFallbackColor;
  }

  Color resourceColorFor(StatusResourceType? resourceType) {
    if (resourceType == null) return resourceFallbackColor;
    return resourceColorByType[resourceType] ?? resourceFallbackColor;
  }

  static const Map<DamageType, Color> _defaultDotColorByDamageType =
      <DamageType, Color>{
        DamageType.fire: Color(0xFFFF7A3D),
        DamageType.ice: Color(0xFF7DD3FC),
        DamageType.water: Color(0xFF38BDF8),
        DamageType.thunder: Color(0xFFFACC15),
        DamageType.acid: Color(0xFF84CC16),
        DamageType.dark: Color(0xFF8B5CF6),
        DamageType.bleed: Color(0xFFEF4444),
        DamageType.earth: Color(0xFFC08457),
        DamageType.holy: Color(0xFFFDE68A),
        DamageType.physical: Color(0xFFE5E7EB),
      };

  static const Map<StatusResourceType, Color> _defaultResourceColorByType =
      <StatusResourceType, Color>{
        StatusResourceType.health: Color(0xFF22C55E),
        StatusResourceType.mana: Color(0xFF3B82F6),
        StatusResourceType.stamina: Color(0xFFF59E0B),
      };

  static const Map<int, Color> _defaultStatusColorByMaskBit = <int, Color>{
    EntityStatusVisualMask.slow: Color(0xFF67E8F9),
    EntityStatusVisualMask.haste: Color(0xFF86EFAC),
    EntityStatusVisualMask.ward: Color(0xFF93C5FD),
    EntityStatusVisualMask.vulnerable: Color(0xFFF472B6),
    EntityStatusVisualMask.weaken: Color(0xFFF59E0B),
    EntityStatusVisualMask.drench: Color(0xFF60A5FA),
    EntityStatusVisualMask.stun: Color(0xFFEAB308),
    EntityStatusVisualMask.silence: Color(0xFFA78BFA),
  };
}
