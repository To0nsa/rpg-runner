import 'dart:math' as math;

/// A normalized launch direction and its earliest predicted intercept time.
/// Time is seconds from release; speed and gravity remain caller-owned tuning.
typedef BallisticAim = ({double dirX, double dirY, double flightSeconds});

/// Solves the low, earliest arc against a target moving at constant velocity.
///
/// Positions and muzzle offset use world pixels, speed pixels/second, and
/// gravity pixels/second squared (positive downward). Windup precedes release.
/// The gravity term matches Core's gravity-before-motion integration at
/// [tickHz]; terrain contacts, velocity caps and subpixel rounding are excluded.
/// [originOffset] moves the muzzle along the solved direction. Returns null
/// when no intercept exists within [maxFlightSeconds]; it never widens reach.
BallisticAim? solveBallisticAim({
  required double sourceX,
  required double sourceY,
  required double targetX,
  required double targetY,
  required double targetVelX,
  required double targetVelY,
  required double speed,
  required double gravityY,
  required int tickHz,
  required double maxFlightSeconds,
  double windupSeconds = 0,
  double originOffset = 0,
}) {
  if (tickHz <= 0 ||
      speed <= 0 ||
      maxFlightSeconds <= 0 ||
      originOffset < 0 ||
      windupSeconds < 0 ||
      ![
        sourceX,
        sourceY,
        targetX,
        targetY,
        targetVelX,
        targetVelY,
        speed,
        gravityY,
        maxFlightSeconds,
        windupSeconds,
        originOffset,
      ].every((value) => value.isFinite)) {
    throw ArgumentError(
      'Ballistic aim requires finite motion and positive bounds.',
    );
  }
  final dx = targetX + targetVelX * windupSeconds - sourceX;
  final dy = targetY + targetVelY * windupSeconds - sourceY;
  final vx = targetVelX;
  final vy = targetVelY - gravityY / (2 * tickHz);
  // |target(t) - gravityDrop(t)| = muzzleOffset + speed * t.
  final coefficients = [
    dx * dx + dy * dy - originOffset * originOffset,
    2 * (dx * vx + dy * vy - originOffset * speed),
    vx * vx + vy * vy - gravityY * dy - speed * speed,
    -gravityY * vy,
    gravityY * gravityY / 4,
  ];
  final roots = _rootsInInterval(coefficients, 0, maxFlightSeconds);
  for (final time in roots) {
    final reach = originOffset + speed * time;
    if (reach <= 1e-9) continue;
    final x = dx + vx * time;
    final y = dy + vy * time - gravityY * time * time / 2;
    final length = math.sqrt(x * x + y * y);
    if (length <= 1e-9) continue;
    return (dirX: x / length, dirY: y / length, flightSeconds: time);
  }
  return null;
}

// Derivative roots partition the quartic into monotonic intervals, so both
// ordinary crossings and tangent (maximum-range) solutions are retained.
List<double> _rootsInInterval(
  List<double> coefficients,
  double min,
  double max,
) {
  while (coefficients.length > 1 && coefficients.last == 0) {
    coefficients.removeLast();
  }
  if (coefficients.length == 1) return const [];
  if (coefficients.length == 2) {
    final root = -coefficients[0] / coefficients[1];
    return root >= min && root <= max ? [root] : const [];
  }
  final turningPoints = _rootsInInterval(
    [for (var i = 1; i < coefficients.length; i++) i * coefficients[i]],
    min,
    max,
  );
  final boundaries = [min, ...turningPoints, max];
  final roots = <double>[];
  for (var i = 0; i < boundaries.length; i++) {
    final start = boundaries[i];
    final startValue = _evaluate(coefficients, start);
    var magnitude = 0.0;
    var power = 1.0;
    for (final coefficient in coefficients) {
      magnitude += coefficient.abs() * power;
      power *= start.abs();
    }
    if (startValue.abs() <= math.max(1, magnitude) * 1e-12) {
      if (roots.isEmpty || (start - roots.last).abs() > 1e-9) roots.add(start);
    }
    if (i == boundaries.length - 1) continue;
    var low = start;
    var high = boundaries[i + 1];
    final endValue = _evaluate(coefficients, high);
    if (startValue == 0 || endValue == 0 || startValue.sign == endValue.sign) {
      continue;
    }
    // Fixed work and stable ascending intervals avoid platform/time-dependent
    // search termination and select the earliest reachable arc deterministically.
    for (var iteration = 0; iteration < 56; iteration++) {
      final middle = (low + high) / 2;
      if (_evaluate(coefficients, middle).sign == startValue.sign) {
        low = middle;
      } else {
        high = middle;
      }
    }
    final root = (low + high) / 2;
    if (roots.isEmpty || (root - roots.last).abs() > 1e-9) roots.add(root);
  }
  return roots;
}

double _evaluate(List<double> coefficients, double value) {
  var result = coefficients.last;
  for (var i = coefficients.length - 2; i >= 0; i--) {
    result = result * value + coefficients[i];
  }
  return result;
}
