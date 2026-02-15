/// Flying enemy AI tuning (steering, strikes).
library;

import '../util/tick_math.dart';

class UnocoDemonTuning {
  const UnocoDemonTuning({
    this.unocoDemonHoverOffsetY = 150.0,
    this.unocoDemonDesiredRangeMin = 50.0,
    this.unocoDemonDesiredRangeMax = 90.0,
    this.unocoDemonDesiredRangeHoldMinSeconds = 0.60,
    this.unocoDemonDesiredRangeHoldMaxSeconds = 1.40,
    this.unocoDemonHoldSlack = 20.0,
    this.unocoDemonMaxSpeedX = 300.0,
    this.unocoDemonSlowRadiusX = 80.0,
    this.unocoDemonAccelX = 600.0,
    this.unocoDemonDecelX = 400.0,
    this.unocoDemonMinHeightAboveGround = 100.0,
    this.unocoDemonMaxHeightAboveGround = 240.0,
    this.unocoDemonFlightTargetHoldMinSeconds = 1.5,
    this.unocoDemonFlightTargetHoldMaxSeconds = 3.0,
    this.unocoDemonMaxSpeedY = 300.0,
    this.unocoDemonVerticalKp = 4.0,
    this.unocoDemonVerticalDeadzone = 20.0,
    this.unocoDemonAimLeadMinSeconds = 0.08,
    this.unocoDemonAimLeadMaxSeconds = 0.40,
    this.unocoDemonCastCooldownSeconds = 2.5,
    this.unocoDemonCastOriginOffset = 20.0,
  });

  // ── Steering ──

  /// Vertical offset above player when hovering (world units).
  final double unocoDemonHoverOffsetY;

  /// Min horizontal range to maintain from player (world units).
  final double unocoDemonDesiredRangeMin;

  /// Max horizontal range to maintain from player (world units).
  final double unocoDemonDesiredRangeMax;

  /// Min time to hold a desired range before picking new (seconds).
  final double unocoDemonDesiredRangeHoldMinSeconds;

  /// Max time to hold a desired range (seconds).
  final double unocoDemonDesiredRangeHoldMaxSeconds;

  /// Slack distance before recalculating position (world units).
  final double unocoDemonHoldSlack;

  /// Max horizontal speed (world units/sec).
  final double unocoDemonMaxSpeedX;

  /// Distance from target where decel starts (world units).
  final double unocoDemonSlowRadiusX;

  /// Horizontal acceleration (world units/sec²).
  final double unocoDemonAccelX;

  /// Horizontal deceleration (world units/sec²).
  final double unocoDemonDecelX;

  /// Min height above ground (world units).
  final double unocoDemonMinHeightAboveGround;

  /// Max height above ground (world units).
  final double unocoDemonMaxHeightAboveGround;

  /// Min time to hold a flight target (seconds).
  final double unocoDemonFlightTargetHoldMinSeconds;

  /// Max time to hold a flight target (seconds).
  final double unocoDemonFlightTargetHoldMaxSeconds;

  /// Max vertical speed (world units/sec).
  final double unocoDemonMaxSpeedY;

  /// Proportional gain for vertical steering.
  final double unocoDemonVerticalKp;

  /// Deadzone for vertical error (world units).
  final double unocoDemonVerticalDeadzone;

  // ── Strikes ──

  /// Min lead time when aiming at player (seconds).
  final double unocoDemonAimLeadMinSeconds;

  /// Max lead time when aiming at player (seconds).
  final double unocoDemonAimLeadMaxSeconds;

  /// Cooldown between casts (seconds).
  final double unocoDemonCastCooldownSeconds;

  /// Projectile spawn offset from center (world units).
  final double unocoDemonCastOriginOffset;
}

class UnocoDemonTuningDerived {
  const UnocoDemonTuningDerived._({
    required this.tickHz,
    required this.base,
    required this.unocoDemonCastCooldownTicks,
  });

  factory UnocoDemonTuningDerived.from(
    UnocoDemonTuning base, {
    required int tickHz,
  }) {
    if (tickHz <= 0) {
      throw ArgumentError.value(tickHz, 'tickHz', 'must be > 0');
    }

    return UnocoDemonTuningDerived._(
      tickHz: tickHz,
      base: base,
      unocoDemonCastCooldownTicks: ticksFromSecondsCeil(
        base.unocoDemonCastCooldownSeconds,
        tickHz,
      ),
    );
  }

  final int tickHz;
  final UnocoDemonTuning base;

  final int unocoDemonCastCooldownTicks;
}
