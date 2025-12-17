import 'dart:math';

/// V0 movement/physics tuning for the Core simulation.
///
/// All units are expressed in world units ("virtual pixels") and seconds:
/// - speeds: world units / second
/// - acceleration: world units / second^2
/// - times: seconds (converted to fixed-tick counts at runtime)
///
/// The derived values are computed once per [tickHz] and then used in the hot
/// per-tick loop to keep the core allocation-light.
const int v0DefaultTickHz = 60;

int _ticksFromSeconds(double seconds, int tickHz) {
  if (seconds <= 0) return 0;
  return max(1, (seconds * tickHz).ceil());
}

/// Authoritative movement constants (expressed in seconds-based units).
class V0MovementTuning {
  const V0MovementTuning({
    this.playerRadius = 8,
    this.maxSpeedX = 500,
    this.accelerationX = 1200,
    this.decelerationX = 800,
    this.minMoveSpeed = 5,
    this.gravityY = 2400,
    this.maxVelX = 3000,
    this.maxVelY = 3000,
    this.jumpSpeed = 1200,
    this.coyoteTimeSeconds = 0.10,
    this.jumpBufferSeconds = 0.12,
    this.dashSpeedX = 1100,
    this.dashDurationSeconds = 0.20,
    this.dashCooldownSeconds = 3.0,
  });

  /// Player "collision" radius in world units (used for ground contact in V0).
  final double playerRadius;

  /// Target max horizontal speed when holding move input.
  final double maxSpeedX;
  final double accelerationX;
  final double decelerationX;
  final double minMoveSpeed;

  /// Gravity acceleration (positive is downward).
  final double gravityY;

  /// Speed clamps (safety caps).
  final double maxVelX;
  final double maxVelY;

  /// Instantaneous jump vertical speed (negative is upward).
  final double jumpSpeed;

  /// Jump forgiveness windows (platformer-style).
  final double coyoteTimeSeconds;
  final double jumpBufferSeconds;

  /// Dash parameters.
  final double dashSpeedX;
  final double dashDurationSeconds;
  final double dashCooldownSeconds;
}

/// Derived, tick-based tuning computed for a specific [tickHz].
class V0MovementTuningDerived {
  const V0MovementTuningDerived._({
    required this.tickHz,
    required this.dtSeconds,
    required this.base,
    required this.coyoteTicks,
    required this.jumpBufferTicks,
    required this.dashDurationTicks,
    required this.dashCooldownTicks,
  });

  factory V0MovementTuningDerived.from(
    V0MovementTuning base, {
    required int tickHz,
  }) {
    if (tickHz <= 0) {
      throw ArgumentError.value(tickHz, 'tickHz', 'must be > 0');
    }
    return V0MovementTuningDerived._(
      tickHz: tickHz,
      dtSeconds: 1.0 / tickHz,
      base: base,
      coyoteTicks: _ticksFromSeconds(base.coyoteTimeSeconds, tickHz),
      jumpBufferTicks: _ticksFromSeconds(base.jumpBufferSeconds, tickHz),
      dashDurationTicks: _ticksFromSeconds(base.dashDurationSeconds, tickHz),
      dashCooldownTicks: _ticksFromSeconds(base.dashCooldownSeconds, tickHz),
    );
  }

  final int tickHz;
  final double dtSeconds;
  final V0MovementTuning base;

  final int coyoteTicks;
  final int jumpBufferTicks;
  final int dashDurationTicks;
  final int dashCooldownTicks;
}
