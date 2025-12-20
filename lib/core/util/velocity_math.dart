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
