/// Fixed-point math helpers for deterministic simulation.
///
/// Units:
/// - Fixed100: 100 = 1.00
/// - Basis Points (bp): 100 = 1%, 10000 = 100%
library;

import 'dart:math';

const int fixedScale = 100;
const int bpScale = 10000;

/// Default subpixel scale for the fixed-point physics pilot.
///
/// `1024` means positions/velocities are quantized to 1/1024 world units.
const int defaultPhysicsSubpixelScale = 1024;

/// Converts a double to fixed-point (100 = 1.0).
int toFixed100(double value) => (value * fixedScale).round();

/// Converts a double to basis points (100 = 1%).
int toBp(double value) => (value * bpScale).round();

/// Converts fixed-point (100 = 1.0) to double.
double fromFixed100(int value) => value / fixedScale;

/// Quantizes a floating-point value to a fixed [scale] grid.
double quantizeToScale(double value, int scale) {
  assert(scale > 0);
  return (value * scale).round() / scale;
}

/// Integrates `position += velocity * dt` using deterministic fixed-point math.
///
/// [velocityPerSecond] is in world units per second.
/// [tickHz] is the fixed simulation tick rate.
double integratePerTickFixed({
  required double position,
  required double velocityPerSecond,
  required int tickHz,
  required int scale,
}) {
  assert(tickHz > 0);
  assert(scale > 0);
  final posScaled = (position * scale).round();
  final velScaled = (velocityPerSecond * scale).round();
  final deltaScaled = _divideRoundNearest(velScaled, tickHz);
  return (posScaled + deltaScaled) / scale;
}

/// Computes per-tick velocity delta from acceleration using fixed-point math.
///
/// [accelerationPerSecondSq] is in world units per second squared.
double accelerationDeltaPerTickFixed({
  required double accelerationPerSecondSq,
  required int tickHz,
  required int scale,
}) {
  assert(tickHz > 0);
  assert(scale > 0);
  final accelScaled = (accelerationPerSecondSq * scale).round();
  final deltaScaled = _divideRoundNearest(accelScaled, tickHz);
  return deltaScaled / scale;
}

/// Clamps [v] to the range [lo, hi].
int clampInt(int v, int lo, int hi) => max(lo, min(hi, v));

/// Scales [value] by a basis-point modifier.
///
/// Example: value=1000, bonusBp=2000 (+20%) -> 1200.
int applyBp(int value, int bonusBp) =>
    (value * (bpScale + bonusBp)) ~/ bpScale;

int _divideRoundNearest(int numerator, int denominator) {
  assert(denominator > 0);
  final half = denominator ~/ 2;
  if (numerator >= 0) {
    return (numerator + half) ~/ denominator;
  }
  return -((-numerator + half) ~/ denominator);
}

