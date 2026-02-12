import '../../ecs/entity_id.dart';
import '../damage_type.dart';

/// Runtime status effect categories.
enum StatusEffectType { dot, slow, stun, haste, vulnerable }

/// Stable identifiers for status application profiles.
enum StatusProfileId {
  none,
  slowOnHit,
  burnOnHit,
  acidOnHit,
  meleeBleed,
  stunOnHit,
  speedBoost,
}

/// A single status application inside a profile.
class StatusApplication {
  const StatusApplication({
    required this.type,
    required this.magnitude,
    required this.durationSeconds,
    this.periodSeconds = 1.0,
    this.scaleByDamageType = false,
    this.dotDamageType,
  }) : assert(
         type != StatusEffectType.dot || dotDamageType != null,
         'dotDamageType is required when type is StatusEffectType.dot.',
       );

  final StatusEffectType type;

  /// Effect strength:
  /// - Slow/Haste: basis points (100 = 1%)
  /// - DoT: damage per second in fixed-point (100 = 1.0)
  final int magnitude;

  /// Total duration (seconds).
  final double durationSeconds;

  /// Tick period for DoT effects (seconds). Ignored for non-DoTs.
  final double periodSeconds;

  /// Whether to scale magnitude by damage resistance/vulnerability.
  final bool scaleByDamageType;

  /// Damage type dealt by [StatusEffectType.dot]. Ignored for non-DoTs.
  final DamageType? dotDamageType;

  StatusApplication copyWith({
    StatusEffectType? type,
    int? magnitude,
    double? durationSeconds,
    double? periodSeconds,
    bool? scaleByDamageType,
    DamageType? dotDamageType,
  }) {
    return StatusApplication(
      type: type ?? this.type,
      magnitude: magnitude ?? this.magnitude,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      periodSeconds: periodSeconds ?? this.periodSeconds,
      scaleByDamageType: scaleByDamageType ?? this.scaleByDamageType,
      dotDamageType: dotDamageType ?? this.dotDamageType,
    );
  }
}

/// Reusable baseline status applications with optional tuning overrides.
class StatusApplicationPreset {
  const StatusApplicationPreset(this._baseline);

  final StatusApplication _baseline;

  StatusApplication get baseline => _baseline;

  StatusApplication build({
    int? magnitude,
    double? durationSeconds,
    double? periodSeconds,
    bool? scaleByDamageType,
    DamageType? dotDamageType,
  }) {
    return _baseline.copyWith(
      magnitude: magnitude,
      durationSeconds: durationSeconds,
      periodSeconds: periodSeconds,
      scaleByDamageType: scaleByDamageType,
      dotDamageType: dotDamageType,
    );
  }
}

/// Shared presets used by [StatusProfileCatalog] to avoid duplicated literals.
class StatusApplicationPresets {
  const StatusApplicationPresets._();

  static const StatusApplicationPreset slowOnHit = StatusApplicationPreset(
    StatusApplication(
      type: StatusEffectType.slow,
      magnitude: 2500, // 25%
      durationSeconds: 3.0,
      scaleByDamageType: true,
    ),
  );

  static const StatusApplicationPreset onHitDot = StatusApplicationPreset(
    StatusApplication(
      type: StatusEffectType.dot,
      magnitude: 500, // 5.0 DPS
      durationSeconds: 5.0,
      scaleByDamageType: true,
      dotDamageType: DamageType.fire,
    ),
  );

  static const StatusApplicationPreset vulnerableOnHit =
      StatusApplicationPreset(
        StatusApplication(
          type: StatusEffectType.vulnerable,
          magnitude: 2000, // +20% incoming damage.
          durationSeconds: 5.0,
          scaleByDamageType: false,
        ),
      );

  static const StatusApplicationPreset stunOnHit = StatusApplicationPreset(
    StatusApplication(
      type: StatusEffectType.stun,
      magnitude: 100, // placeholder (stun uses only duration ticks)
      durationSeconds: 1.0,
      scaleByDamageType: false,
    ),
  );

  static const StatusApplicationPreset speedBoost = StatusApplicationPreset(
    StatusApplication(
      type: StatusEffectType.haste,
      magnitude: 5000, // +50% move speed
      durationSeconds: 5.0,
      scaleByDamageType: false,
    ),
  );
}

/// A bundle of status applications applied on hit.
class StatusProfile {
  const StatusProfile(this.applications);

  final List<StatusApplication> applications;
}

/// Lookup table for status profiles.
class StatusProfileCatalog {
  const StatusProfileCatalog();

  StatusProfile get(StatusProfileId id) {
    switch (id) {
      case StatusProfileId.none:
        return const StatusProfile(<StatusApplication>[]);
      case StatusProfileId.slowOnHit:
        return StatusProfile(<StatusApplication>[
          StatusApplicationPresets.slowOnHit.baseline,
        ]);
      case StatusProfileId.meleeBleed:
        return StatusProfile(<StatusApplication>[
          StatusApplicationPresets.onHitDot.build(
            magnitude: 300, // 3.0 DPS
            dotDamageType: DamageType.physical,
          ),
        ]);
      case StatusProfileId.burnOnHit:
        return StatusProfile(<StatusApplication>[
          StatusApplicationPresets.onHitDot.build(
            dotDamageType: DamageType.fire,
          ),
        ]);
      case StatusProfileId.acidOnHit:
        return StatusProfile(<StatusApplication>[
          StatusApplicationPresets.vulnerableOnHit.baseline,
        ]);
      case StatusProfileId.stunOnHit:
        return StatusProfile(<StatusApplication>[
          StatusApplicationPresets.stunOnHit.baseline,
        ]);
      case StatusProfileId.speedBoost:
        return StatusProfile(<StatusApplication>[
          StatusApplicationPresets.speedBoost.baseline,
        ]);
    }
  }
}

/// Runtime request for applying a status profile to a target.
class StatusRequest {
  const StatusRequest({
    required this.target,
    required this.profileId,
    this.damageType = DamageType.physical,
  });

  final EntityId target;
  final StatusProfileId profileId;
  final DamageType damageType;
}
