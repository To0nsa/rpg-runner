import '../../ecs/entity_id.dart';
import '../damage_type.dart';

/// Runtime status effect categories.
enum StatusEffectType {
  dot,
  slow,
  stun,
  haste,
  damageReduction,
  vulnerable,
  weaken,
  drench,
  silence,
  resourceOverTime,
}

/// Resources that can be restored through status effects.
enum StatusResourceType { health, mana, stamina }

/// Stable identifiers for status application profiles.
enum StatusProfileId {
  none,
  slowOnHit,
  burnOnHit,
  arcaneWard,
  acidOnHit,
  weakenOnHit,
  drenchOnHit,
  silenceOnHit,
  meleeBleed,
  stunOnHit,
  speedBoost,
  restoreHealth,
  restoreMana,
  restoreStamina,
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
    this.resourceType,
    this.applyOnApply = false,
  }) : assert(
         type != StatusEffectType.dot || dotDamageType != null,
         'dotDamageType is required when type is StatusEffectType.dot.',
       ),
       assert(
         type != StatusEffectType.resourceOverTime || resourceType != null,
         'resourceType is required when type is StatusEffectType.resourceOverTime.',
       ),
       assert(
         periodSeconds > 0,
         'periodSeconds must be > 0 for periodic status effects.',
       ),
       assert(durationSeconds >= 0, 'durationSeconds cannot be negative.');

  final StatusEffectType type;

  /// Effect strength:
  /// - Slow/Haste: basis points (100 = 1%)
  /// - DoT: damage per second in fixed-point (100 = 1.0)
  /// - ResourceOverTime: basis points restored per pulse (`100 = 1%` of max).
  final int magnitude;

  /// Total duration (seconds).
  final double durationSeconds;

  /// Tick period for DoT effects (seconds). Ignored for non-DoTs.
  final double periodSeconds;

  /// Whether to scale magnitude by damage resistance/vulnerability.
  final bool scaleByDamageType;

  /// Damage type dealt by [StatusEffectType.dot]. Ignored for non-DoTs.
  final DamageType? dotDamageType;

  /// Resource restored by [StatusEffectType.resourceOverTime].
  final StatusResourceType? resourceType;

  /// Applies one pulse immediately when the status is queued/applied.
  final bool applyOnApply;

  StatusApplication copyWith({
    StatusEffectType? type,
    int? magnitude,
    double? durationSeconds,
    double? periodSeconds,
    bool? scaleByDamageType,
    DamageType? dotDamageType,
    StatusResourceType? resourceType,
    bool? applyOnApply,
  }) {
    return StatusApplication(
      type: type ?? this.type,
      magnitude: magnitude ?? this.magnitude,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      periodSeconds: periodSeconds ?? this.periodSeconds,
      scaleByDamageType: scaleByDamageType ?? this.scaleByDamageType,
      dotDamageType: dotDamageType ?? this.dotDamageType,
      resourceType: resourceType ?? this.resourceType,
      applyOnApply: applyOnApply ?? this.applyOnApply,
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
          magnitude: 5000, // +50% incoming damage.
          durationSeconds: 5.0,
          scaleByDamageType: false,
        ),
      );

  static const StatusApplicationPreset weakenOnHit = StatusApplicationPreset(
    StatusApplication(
      type: StatusEffectType.weaken,
      magnitude: 3500, // -35% outgoing damage.
      durationSeconds: 5.0,
      scaleByDamageType: false,
    ),
  );

  static const StatusApplicationPreset drenchOnHit = StatusApplicationPreset(
    StatusApplication(
      type: StatusEffectType.drench,
      magnitude: 5000, // -50% attack/cast speed.
      durationSeconds: 5.0,
      scaleByDamageType: false,
    ),
  );

  static const StatusApplicationPreset silenceOnHit = StatusApplicationPreset(
    StatusApplication(
      type: StatusEffectType.silence,
      magnitude: 100, // placeholder (silence uses only duration ticks)
      durationSeconds: 3.0,
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

  static const StatusApplicationPreset arcaneWard = StatusApplicationPreset(
    StatusApplication(
      type: StatusEffectType.damageReduction,
      magnitude: 4000, // 40% direct-hit mitigation
      durationSeconds: 4.0,
    ),
  );

  static const StatusApplicationPreset healthRestore = StatusApplicationPreset(
    StatusApplication(
      type: StatusEffectType.resourceOverTime,
      magnitude: 3500, // 35% max health over full duration
      durationSeconds: 5.0,
      resourceType: StatusResourceType.health,
    ),
  );

  static const StatusApplicationPreset manaRestore = StatusApplicationPreset(
    StatusApplication(
      type: StatusEffectType.resourceOverTime,
      magnitude: 3500, // 35% max mana over full duration
      durationSeconds: 5.0,
      resourceType: StatusResourceType.mana,
    ),
  );

  static const StatusApplicationPreset staminaRestore = StatusApplicationPreset(
    StatusApplication(
      type: StatusEffectType.resourceOverTime,
      magnitude: 3500, // 35% max stamina over full duration
      durationSeconds: 5.0,
      resourceType: StatusResourceType.stamina,
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
      case StatusProfileId.arcaneWard:
        return StatusProfile(<StatusApplication>[
          StatusApplicationPresets.arcaneWard.baseline,
        ]);
      case StatusProfileId.acidOnHit:
        return StatusProfile(<StatusApplication>[
          StatusApplicationPresets.vulnerableOnHit.baseline,
        ]);
      case StatusProfileId.weakenOnHit:
        return StatusProfile(<StatusApplication>[
          StatusApplicationPresets.weakenOnHit.baseline,
        ]);
      case StatusProfileId.drenchOnHit:
        return StatusProfile(<StatusApplication>[
          StatusApplicationPresets.drenchOnHit.baseline,
        ]);
      case StatusProfileId.silenceOnHit:
        return StatusProfile(<StatusApplication>[
          StatusApplicationPresets.silenceOnHit.baseline,
        ]);
      case StatusProfileId.stunOnHit:
        return StatusProfile(<StatusApplication>[
          StatusApplicationPresets.stunOnHit.baseline,
        ]);
      case StatusProfileId.speedBoost:
        return StatusProfile(<StatusApplication>[
          StatusApplicationPresets.speedBoost.baseline,
        ]);
      case StatusProfileId.restoreHealth:
        return StatusProfile(<StatusApplication>[
          StatusApplicationPresets.healthRestore.baseline,
        ]);
      case StatusProfileId.restoreMana:
        return StatusProfile(<StatusApplication>[
          StatusApplicationPresets.manaRestore.baseline,
        ]);
      case StatusProfileId.restoreStamina:
        return StatusProfile(<StatusApplication>[
          StatusApplicationPresets.staminaRestore.baseline,
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
