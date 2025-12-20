import '../util/tick_math.dart';

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

/// Authoritative movement constants (expressed in seconds-based units).
class V0MovementTuning {
  const V0MovementTuning({
    this.playerRadius = 8,
    this.maxSpeedX = 250,
    this.accelerationX = 600,
    this.decelerationX = 400,
    this.minMoveSpeed = 5,
    this.gravityY = 1200,
    this.maxVelX = 1500,
    this.maxVelY = 1500,
    this.jumpSpeed = 600,
    this.coyoteTimeSeconds = 0.10,
    this.jumpBufferSeconds = 0.12,
    this.dashSpeedX = 550,
    this.dashDurationSeconds = 0.20,
    this.dashCooldownSeconds = 2.0,
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
      coyoteTicks: ticksFromSecondsCeil(base.coyoteTimeSeconds, tickHz),
      jumpBufferTicks: ticksFromSecondsCeil(base.jumpBufferSeconds, tickHz),
      dashDurationTicks: ticksFromSecondsCeil(base.dashDurationSeconds, tickHz),
      dashCooldownTicks: ticksFromSecondsCeil(base.dashCooldownSeconds, tickHz),
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
