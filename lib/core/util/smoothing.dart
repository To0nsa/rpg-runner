/// Smoothing utilities for frame-rate-independent interpolation.
///
/// Provides exponential smoothing factors that behave consistently
/// regardless of tick rate, useful for camera follow, UI animations, etc.
library;

import 'dart:math';

/// Returns an exponential smoothing factor α in \[0, 1\].
///
/// Given responsiveness [k] (1/seconds) and tick duration [dtSeconds],
/// computes `α = 1 − e^(−k·dt)`. Use as: `value += α * (target − value)`.
///
/// Matches the common pattern: `alpha = 1 - exp(-k * dt)`.
double expSmoothingFactor(double k, double dtSeconds) {
  if (k <= 0) return 0.0;
  if (dtSeconds <= 0) return 0.0;
  return 1.0 - exp(-k * dtSeconds);
}

