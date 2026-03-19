/// Ground enemy AI tuning grouped by navigation/engagement/locomotion/combat.
library;

const double _defaultGroundEnemyMeleeStandOffRatio = 2.0 / 3.0;

class GroundEnemyTuning {
  const GroundEnemyTuning({
    this.navigation = const GroundEnemyNavigationTuning(),
    this.engagement = const GroundEnemyEngagementTuning(),
    this.locomotion = const GroundEnemyLocomotionTuning(),
    this.combat = const GroundEnemyCombatTuning(),
  });

  final GroundEnemyNavigationTuning navigation;
  final GroundEnemyEngagementTuning engagement;
  final GroundEnemyLocomotionTuning locomotion;
  final GroundEnemyCombatTuning combat;
}

/// Navigation tuning (chase offset + speed variance).
class GroundEnemyNavigationTuning {
  const GroundEnemyNavigationTuning({
    this.chaseOffsetMaxX = 18.0,
    this.chaseOffsetMinAbsX = 6.0,
    this.chaseOffsetMeleeX = 3.0,
    this.chaseSpeedScaleMin = 0.92,
    this.chaseSpeedScaleMax = 1.08,
    this.chaseTargetDelayTicks = 6,
  });

  /// Max random chase offset from player (world units).
  final double chaseOffsetMaxX;

  /// Min absolute chase offset (prevents clumping).
  final double chaseOffsetMinAbsX;

  /// Chase offset when in melee range (world units).
  final double chaseOffsetMeleeX;

  /// Min speed scale for chase variance.
  final double chaseSpeedScaleMin;

  /// Max speed scale for chase variance.
  final double chaseSpeedScaleMax;

  /// Fixed reaction delay (in simulation ticks) applied to chase targeting.
  ///
  /// The navigation system will chase the player's (or predicted) target X from
  /// `delayTicks` ago, producing a deterministic "reaction time" feel.
  ///
  /// Example: At 60 Hz, `6` ticks ≈ 100ms.
  final int chaseTargetDelayTicks;
}

/// Engagement tuning (slot selection + melee state movement).
class GroundEnemyEngagementTuning {
  const GroundEnemyEngagementTuning({
    this.meleeEngageBufferX = 4.0,
    this.meleeEngageHysteresisX = 2.0,
    this.meleeArriveSlowRadiusX = 12.0,
    this.meleeStrikeSpeedMul = 0.25,
    this.meleeRecoverSpeedMul = 0.5,
    this.meleeStandOffRatio = _defaultGroundEnemyMeleeStandOffRatio,
  });

  /// Extra buffer beyond melee range to enter engage state.
  final double meleeEngageBufferX;

  /// Hysteresis added to engage buffer for disengage threshold.
  final double meleeEngageHysteresisX;

  /// Radius within which arrival steering slows to zero.
  final double meleeArriveSlowRadiusX;

  /// Speed multiplier during strike state.
  final double meleeStrikeSpeedMul;

  /// Speed multiplier during recover state.
  final double meleeRecoverSpeedMul;

  /// Preferred stand-off ratio of authored melee hitbox width.
  ///
  /// Effective stand-off distance is resolved as:
  /// `abilityMeleeHitboxWidth * meleeStandOffRatio`, then clamped to
  /// [GroundEnemyCombatTuning.meleeRangeX].
  final double meleeStandOffRatio;
}

/// Locomotion tuning (movement + jump).
class GroundEnemyLocomotionTuning {
  const GroundEnemyLocomotionTuning({
    this.speedX = 300.0,
    this.stopDistanceX = 6.0,
    this.accelX = 600.0,
    this.decelX = 400.0,
    this.jumpSpeed = 500.0,
  });

  /// Target horizontal speed (world units/sec).
  final double speedX;

  /// Distance at which enemy stops chasing (world units).
  final double stopDistanceX;

  /// Horizontal acceleration (world units/sec^2).
  final double accelX;

  /// Horizontal deceleration (world units/sec^2).
  final double decelX;

  /// Jump velocity (world units/sec, positive = upward).
  final double jumpSpeed;
}

/// Combat tuning (range gating).
///
/// Per-strike timing, hitbox size, damage, and cooldown are authored on
/// enemy ability definitions.
class GroundEnemyCombatTuning {
  const GroundEnemyCombatTuning({this.meleeRangeX = 52.0});

  /// Horizontal range to trigger melee strike (world units).
  final double meleeRangeX;
}

class GroundEnemyTuningDerived {
  const GroundEnemyTuningDerived._({
    required this.tickHz,
    required this.base,
    required this.navigation,
    required this.engagement,
    required this.locomotion,
    required this.combat,
  });

  factory GroundEnemyTuningDerived.from(
    GroundEnemyTuning base, {
    required int tickHz,
  }) {
    if (tickHz <= 0) {
      throw ArgumentError.value(tickHz, 'tickHz', 'must be > 0');
    }

    final combat = base.combat;
    final engagement = base.engagement;

    final meleeStandOffRatio = () {
      final desired = engagement.meleeStandOffRatio;
      if (desired.isNaN || desired.isInfinite) return 0.0;
      return desired < 0.0 ? 0.0 : desired;
    }();

    return GroundEnemyTuningDerived._(
      tickHz: tickHz,
      base: base,
      navigation: base.navigation,
      engagement: GroundEnemyEngagementTuning(
        meleeEngageBufferX: engagement.meleeEngageBufferX,
        meleeEngageHysteresisX: engagement.meleeEngageHysteresisX,
        meleeArriveSlowRadiusX: engagement.meleeArriveSlowRadiusX,
        meleeStrikeSpeedMul: engagement.meleeStrikeSpeedMul,
        meleeRecoverSpeedMul: engagement.meleeRecoverSpeedMul,
        meleeStandOffRatio: meleeStandOffRatio,
      ),
      locomotion: base.locomotion,
      combat: GroundEnemyCombatTuning(meleeRangeX: combat.meleeRangeX),
    );
  }

  final int tickHz;
  final GroundEnemyTuning base;
  final GroundEnemyNavigationTuning navigation;
  final GroundEnemyEngagementTuning engagement;
  final GroundEnemyLocomotionTuning locomotion;
  final GroundEnemyCombatTuning combat;
}
