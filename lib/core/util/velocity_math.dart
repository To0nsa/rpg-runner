/// Velocity ramping utilities.
///
/// Helpers for smoothly accelerating/decelerating toward a target speed,
/// used by player and enemy movement systems.
library;

/// Ramps [current] velocity toward [desired] using asymmetric accel/decel.
///
/// - Accelerates at [accelPerSecond] when moving toward non-zero [desired].
/// - Decelerates at [decelPerSecond] when [desired] is zero.
/// - Snaps to zero if `|current| <= minStopSpeed` and `desired == 0`.
///
/// Returns the updated velocity after [dtSeconds].
double applyAccelDecel({
  required double current,
  required double desired,
  required double dtSeconds,
  required double accelPerSecond,
  required double decelPerSecond,
  double minStopSpeed = 0.0,
}) {
  if (dtSeconds <= 0.0) return current;
  if (desired == 0.0 && current.abs() <= minStopSpeed) return 0.0;

  final accel = desired == 0.0 ? decelPerSecond : accelPerSecond;
  final maxDelta = accel * dtSeconds;
  final delta = desired - current;
  if (delta.abs() > maxDelta) {
    return current + (delta > 0.0 ? maxDelta : -maxDelta);
  }
  return desired;
}
