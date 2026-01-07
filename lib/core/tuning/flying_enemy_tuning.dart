/// Flying enemy AI tuning (steering, attacks).
library;

import '../util/tick_math.dart';

class FlyingEnemyTuning {
  const FlyingEnemyTuning({
    this.flyingEnemyHoverOffsetY = 150.0,
    this.flyingEnemyDesiredRangeMin = 50.0,
    this.flyingEnemyDesiredRangeMax = 90.0,
    this.flyingEnemyDesiredRangeHoldMinSeconds = 0.60,
    this.flyingEnemyDesiredRangeHoldMaxSeconds = 1.40,
    this.flyingEnemyHoldSlack = 20.0,
    this.flyingEnemyMaxSpeedX = 300.0,
    this.flyingEnemySlowRadiusX = 80.0,
    this.flyingEnemyAccelX = 600.0,
    this.flyingEnemyDecelX = 400.0,
    this.flyingEnemyMinHeightAboveGround = 100.0,
    this.flyingEnemyMaxHeightAboveGround = 240.0,
    this.flyingEnemyFlightTargetHoldMinSeconds = 1.5,
    this.flyingEnemyFlightTargetHoldMaxSeconds = 3.0,
    this.flyingEnemyMaxSpeedY = 300.0,
    this.flyingEnemyVerticalKp = 4.0,
    this.flyingEnemyVerticalDeadzone = 20.0,
    this.flyingEnemyAimLeadMinSeconds = 0.08,
    this.flyingEnemyAimLeadMaxSeconds = 0.40,
    this.flyingEnemyCastCooldownSeconds = 2.0,
    this.flyingEnemyCastOriginOffset = 20.0,
  });

  // ── Steering ──

  /// Vertical offset above player when hovering (world units).
  final double flyingEnemyHoverOffsetY;

  /// Min horizontal range to maintain from player (world units).
  final double flyingEnemyDesiredRangeMin;

  /// Max horizontal range to maintain from player (world units).
  final double flyingEnemyDesiredRangeMax;

  /// Min time to hold a desired range before picking new (seconds).
  final double flyingEnemyDesiredRangeHoldMinSeconds;

  /// Max time to hold a desired range (seconds).
  final double flyingEnemyDesiredRangeHoldMaxSeconds;

  /// Slack distance before recalculating position (world units).
  final double flyingEnemyHoldSlack;

  /// Max horizontal speed (world units/sec).
  final double flyingEnemyMaxSpeedX;

  /// Distance from target where decel starts (world units).
  final double flyingEnemySlowRadiusX;

  /// Horizontal acceleration (world units/sec²).
  final double flyingEnemyAccelX;

  /// Horizontal deceleration (world units/sec²).
  final double flyingEnemyDecelX;

  /// Min height above ground (world units).
  final double flyingEnemyMinHeightAboveGround;

  /// Max height above ground (world units).
  final double flyingEnemyMaxHeightAboveGround;

  /// Min time to hold a flight target (seconds).
  final double flyingEnemyFlightTargetHoldMinSeconds;

  /// Max time to hold a flight target (seconds).
  final double flyingEnemyFlightTargetHoldMaxSeconds;

  /// Max vertical speed (world units/sec).
  final double flyingEnemyMaxSpeedY;

  /// Proportional gain for vertical steering.
  final double flyingEnemyVerticalKp;

  /// Deadzone for vertical error (world units).
  final double flyingEnemyVerticalDeadzone;

  // ── Attacks ──

  /// Min lead time when aiming at player (seconds).
  final double flyingEnemyAimLeadMinSeconds;

  /// Max lead time when aiming at player (seconds).
  final double flyingEnemyAimLeadMaxSeconds;

  /// Cooldown between casts (seconds).
  final double flyingEnemyCastCooldownSeconds;

  /// Projectile spawn offset from center (world units).
  final double flyingEnemyCastOriginOffset;
}

class FlyingEnemyTuningDerived {
  const FlyingEnemyTuningDerived._({
    required this.tickHz,
    required this.base,
    required this.flyingEnemyCastCooldownTicks,
  });

  factory FlyingEnemyTuningDerived.from(
    FlyingEnemyTuning base, {
    required int tickHz,
  }) {
    if (tickHz <= 0) {
      throw ArgumentError.value(tickHz, 'tickHz', 'must be > 0');
    }

    return FlyingEnemyTuningDerived._(
      tickHz: tickHz,
      base: base,
      flyingEnemyCastCooldownTicks: ticksFromSecondsCeil(
        base.flyingEnemyCastCooldownSeconds,
        tickHz,
      ),
    );
  }

  final int tickHz;
  final FlyingEnemyTuning base;

  final int flyingEnemyCastCooldownTicks;
}
