import 'dart:math';

/// Returns a stable exponential smoothing factor in [0, 1] for the given
/// responsiveness `k` (per-second) and fixed tick dt.
///
/// Matches the common pattern: `alpha = 1 - exp(-k * dt)`.
double expSmoothingFactor(double k, double dtSeconds) {
  if (k <= 0) return 0.0;
  if (dtSeconds <= 0) return 0.0;
  return 1.0 - exp(-k * dtSeconds);
}

