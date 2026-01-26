import '../../ecs/entity_id.dart';
import '../damage_type.dart';

/// Runtime status effect categories.
enum StatusEffectType {
  burn,
  slow,
  bleed,
  stun,
}

/// Stable identifiers for status application profiles.
enum StatusProfileId {
  none,
  iceBolt,
  fireBolt,
  meleeBleed,
  stunOnHit,
}

/// A single status application inside a profile.
class StatusApplication {
  const StatusApplication({
    required this.type,
    required this.magnitude,
    required this.durationSeconds,
    this.periodSeconds = 0.0,
    this.scaleByDamageType = false,
  });

  final StatusEffectType type;

  /// Effect strength:
  /// - Slow: basis points (100 = 1%)
  /// - DoT: damage per second in fixed-point (100 = 1.0)
  final int magnitude;

  /// Total duration (seconds).
  final double durationSeconds;

  /// Tick period for DoT effects (seconds). Ignored for non-DoTs.
  final double periodSeconds;

  /// Whether to scale magnitude by damage resistance/vulnerability.
  final bool scaleByDamageType;
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
      case StatusProfileId.iceBolt:
        return const StatusProfile(
          <StatusApplication>[
            StatusApplication(
              type: StatusEffectType.slow,
              magnitude: 2500, // 25%
              durationSeconds: 3.0,
              scaleByDamageType: true,
            ),
          ],
        );
      case StatusProfileId.meleeBleed:
        return const StatusProfile(
          <StatusApplication>[
            StatusApplication(
              type: StatusEffectType.bleed,
              magnitude: 300, // 3.0 DPS
              durationSeconds: 4.0,
              periodSeconds: 1.0,
              scaleByDamageType: true,
            ),
          ],
        );
      case StatusProfileId.fireBolt:
        return const StatusProfile(
          <StatusApplication>[
            StatusApplication(
              type: StatusEffectType.burn,
              magnitude: 500, // 5.0 DPS
              durationSeconds: 5.0,
              periodSeconds: 1.0,
              scaleByDamageType: true,
            ),
          ],
        );
      case StatusProfileId.stunOnHit:
        return const StatusProfile(
          <StatusApplication>[
            StatusApplication(
              type: StatusEffectType.stun,
              magnitude: 100, // placeholder (stun uses duration ticks)
              durationSeconds: 0.5,
              scaleByDamageType: false,
            ),
          ],
        );
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
