/// Animation tuning helper utilities (Core-owned, deterministic).
///
/// This module is intentionally generic so it can be reused by player/enemy
/// tuning without taking a dependency on any specific character system.
library;

/// Computes a recommended duration for a strip based on frame count and step time.
double secondsForStrip({
  required int frameCount,
  required double stepTimeSeconds,
}) {
  if (frameCount <= 0 || stepTimeSeconds <= 0) return 0.0;
  return frameCount * stepTimeSeconds;
}

/// Computes strip duration for a specific [key] from tuning maps.
///
/// Works with any key type (enums, ints, strings) to keep it reusable.
double secondsForKey<K>({
  required K key,
  required Map<K, int> frameCounts,
  required Map<K, double> stepTimeSecondsByKey,
  int defaultFrameCount = 1,
  double defaultStepTimeSeconds = 0.10,
}) {
  final frames = frameCounts[key] ?? defaultFrameCount;
  final step = stepTimeSecondsByKey[key] ?? defaultStepTimeSeconds;
  return secondsForStrip(frameCount: frames, stepTimeSeconds: step);
}

