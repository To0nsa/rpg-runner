import '../../ecs/entity_id.dart';
import '../damage_credit.dart';
import '../../traps/trap_placement.dart';
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
  offenseBuff,
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
  focus,
  poisonOnHit,
}

/// Stable identifiers for deterministic self-purge profiles.
enum PurgeProfileId { none, cleanse }

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
    this.critBonusBp,
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
  /// - Slow/Haste/Weaken/Drench/Vulnerable/DamageReduction: basis points (100 = 1%)
  /// - DoT: damage per second in fixed-point (100 = 1.0)
  /// - ResourceOverTime: basis points restored over the duration (`100 = 1%` of max).
  /// - OffenseBuff: power bonus in basis points (100 = 1%).
  final int magnitude;

  /// Total duration (seconds).
  final double durationSeconds;

  /// Tick period for DoT effects (seconds). Resource restoration is continuous
  /// per tick and does not use this period for its cadence.
  final double periodSeconds;

  /// Whether to scale magnitude by damage resistance/vulnerability.
  final bool scaleByDamageType;

  /// Damage type dealt by [StatusEffectType.dot]. Ignored for non-DoTs.
  final DamageType? dotDamageType;

  /// Resource restored by [StatusEffectType.resourceOverTime].
  final StatusResourceType? resourceType;

  /// Crit chance bonus for [StatusEffectType.offenseBuff] in basis points.
  final int? critBonusBp;

  /// Restores an additional full magnitude immediately for resource effects.
  final bool applyOnApply;

  StatusApplication copyWith({
    StatusEffectType? type,
    int? magnitude,
    double? durationSeconds,
    double? periodSeconds,
    bool? scaleByDamageType,
    DamageType? dotDamageType,
    StatusResourceType? resourceType,
    int? critBonusBp,
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
      critBonusBp: critBonusBp ?? this.critBonusBp,
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
    int? critBonusBp,
  }) {
    return _baseline.copyWith(
      magnitude: magnitude,
      durationSeconds: durationSeconds,
      periodSeconds: periodSeconds,
      scaleByDamageType: scaleByDamageType,
      dotDamageType: dotDamageType,
      critBonusBp: critBonusBp,
    );
  }
}

/// Optional overrides for one effect, using [StatusApplication]'s units.
///
/// Null retains the preset value; zero and false are explicit overrides.
/// Effect identity is fixed by the preset. Stun/silence use duration for their
/// strength; their positive magnitude is an enable flag. Existing runtime caps,
/// immunity, stacking, and tick quantization still apply.
class StatusApplicationTuning {
  const StatusApplicationTuning({
    this.magnitude,
    this.durationSeconds,
    this.periodSeconds,
    this.scaleByDamageType,
    this.dotDamageType,
    this.resourceType,
    this.critBonusBp,
    this.applyOnApply,
  }) : assert(magnitude == null || magnitude >= 0),
       assert(
         durationSeconds == null ||
             (durationSeconds >= 0 && durationSeconds < double.infinity),
       ),
       assert(
         periodSeconds == null ||
             (periodSeconds > 0 && periodSeconds < double.infinity),
       ),
       assert(critBonusBp == null || critBonusBp >= 0);

  final int? magnitude;
  final double? durationSeconds;
  final double? periodSeconds;
  final bool? scaleByDamageType;
  final DamageType? dotDamageType;
  final StatusResourceType? resourceType;
  final int? critBonusBp;
  final bool? applyOnApply;

  /// Returns an independent application without mutating the shared preset.
  StatusApplication applyTo(StatusApplication baseline) => baseline.copyWith(
    magnitude: magnitude,
    durationSeconds: durationSeconds,
    periodSeconds: periodSeconds,
    scaleByDamageType: scaleByDamageType,
    dotDamageType: dotDamageType,
    resourceType: resourceType,
    critBonusBp: critBonusBp,
    applyOnApply: applyOnApply,
  );
}

/// Immutable per-effect tuning for a selected status profile.
///
/// Bundled effects are independent: tuning poison's DoT does not change its
/// slow. Only effects already present in the selected profile may be tuned;
/// [StatusProfileCatalog.resolve] rejects mismatches rather than ignoring them.
class StatusProfileTuning {
  const StatusProfileTuning({
    this.dot,
    this.slow,
    this.stun,
    this.haste,
    this.damageReduction,
    this.vulnerable,
    this.weaken,
    this.drench,
    this.silence,
    this.resourceOverTime,
    this.offenseBuff,
  });

  final StatusApplicationTuning? dot;
  final StatusApplicationTuning? slow;
  final StatusApplicationTuning? stun;
  final StatusApplicationTuning? haste;
  final StatusApplicationTuning? damageReduction;
  final StatusApplicationTuning? vulnerable;
  final StatusApplicationTuning? weaken;
  final StatusApplicationTuning? drench;
  final StatusApplicationTuning? silence;
  final StatusApplicationTuning? resourceOverTime;
  final StatusApplicationTuning? offenseBuff;

  StatusApplicationTuning? forType(StatusEffectType type) => switch (type) {
    StatusEffectType.dot => dot,
    StatusEffectType.slow => slow,
    StatusEffectType.stun => stun,
    StatusEffectType.haste => haste,
    StatusEffectType.damageReduction => damageReduction,
    StatusEffectType.vulnerable => vulnerable,
    StatusEffectType.weaken => weaken,
    StatusEffectType.drench => drench,
    StatusEffectType.silence => silence,
    StatusEffectType.resourceOverTime => resourceOverTime,
    StatusEffectType.offenseBuff => offenseBuff,
  };

  bool get isEmpty =>
      dot == null &&
      slow == null &&
      stun == null &&
      haste == null &&
      damageReduction == null &&
      vulnerable == null &&
      weaken == null &&
      drench == null &&
      silence == null &&
      resourceOverTime == null &&
      offenseBuff == null;
}

/// Shared presets used by [StatusProfileCatalog] to avoid duplicated literals.
class StatusApplicationPresets {
  const StatusApplicationPresets._();

  static const StatusApplicationPreset slowOnHit = StatusApplicationPreset(
    StatusApplication(
      type: StatusEffectType.slow,
      magnitude: 2500, // 25%
      durationSeconds: 5.0,
      scaleByDamageType: true,
    ),
  );

  static const StatusApplicationPreset onHitDot = StatusApplicationPreset(
    StatusApplication(
      type: StatusEffectType.dot,
      magnitude: 300, // 3.0 DPS
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
      magnitude: 5000, // -50% outgoing damage.
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

  static const StatusApplicationPreset arcaneWard = StatusApplicationPreset(
    StatusApplication(
      type: StatusEffectType.damageReduction,
      magnitude: 4000, // 40% direct-hit mitigation
      durationSeconds: 5.0,
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

  static const StatusApplicationPreset focus = StatusApplicationPreset(
    StatusApplication(
      type: StatusEffectType.offenseBuff,
      magnitude: 2500, // +25% power
      critBonusBp: 1500, // +15% crit chance
      durationSeconds: 5.0,
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

  /// Resolves local tuning over shared defaults for both gameplay and UI.
  ///
  /// Throws [ArgumentError] if tuning names an effect absent from the profile.
  /// Application order is preserved, including profiles with multiple effects.
  StatusProfile resolve(
    StatusProfileId id, {
    StatusProfileTuning tuning = const StatusProfileTuning(),
  }) {
    final baseline = get(id);
    if (tuning.isEmpty) return baseline;
    for (final type in StatusEffectType.values) {
      if (tuning.forType(type) != null &&
          !baseline.applications.any((app) => app.type == type)) {
        throw ArgumentError('Cannot tune $type in status profile $id.');
      }
    }
    return StatusProfile(
      List<StatusApplication>.unmodifiable([
        for (final app in baseline.applications)
          tuning.forType(app.type)?.applyTo(app) ?? app,
      ]),
    );
  }

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
      case StatusProfileId.poisonOnHit:
        return StatusProfile(<StatusApplication>[
          StatusApplicationPresets.onHitDot.build(
            magnitude: 200,
            dotDamageType: DamageType.poison,
          ),
          StatusApplicationPresets.slowOnHit.baseline,
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
      case StatusProfileId.focus:
        return StatusProfile(<StatusApplication>[
          StatusApplicationPresets.focus.baseline,
        ]);
    }
  }
}

/// Runtime request for applying a status profile to a target.
class StatusRequest {
  const StatusRequest({
    required this.target,
    required this.profileId,
    this.tuning = const StatusProfileTuning(),
    this.damageType = DamageType.physical,
    this.acceptedHitTick,
    this.sourceTrap,
    this.credit = DamageCredit.none,
  });

  final EntityId target;
  final StatusProfileId profileId;

  /// Captured source tuning; no live ability/gear lookup is needed on impact.
  final StatusProfileTuning tuning;
  final DamageType damageType;

  /// DamageSystem's acceptance tick for on-hit/on-crit effects on the victim.
  ///
  /// Only same-tick requests retain the hit's invulnerability eligibility;
  /// standalone, delayed, and attacker-targeted effects use apply-time gating.
  final int? acceptedHitTick;
  final TrapSourceRef? sourceTrap;
  final DamageCredit credit;
}

/// Runtime request for purging status/control effects from a target.
class PurgeRequest {
  const PurgeRequest({required this.target, required this.profileId});

  final EntityId target;
  final PurgeProfileId profileId;
}
