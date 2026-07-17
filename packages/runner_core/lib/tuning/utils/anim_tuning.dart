/// Animation tuning helper utilities (Core-owned, deterministic).
///
/// This module is intentionally generic so it can be reused by player/enemy
/// tuning without taking a dependency on any specific character system.
library;

import 'dart:math';

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

/// Converts an authored strip to the renderer's deterministic tick duration.
///
/// Each rendered frame occupies at least one tick, with its authored step time
/// rounded to the nearest fixed tick. Core lifecycle windows that are intended
/// to cover a complete strip must use this value so they end on the same tick
/// as the renderer's final frame.
int ticksForStrip({
  required int frameCount,
  required double stepTimeSeconds,
  required int tickHz,
}) {
  if (tickHz <= 0) {
    throw ArgumentError.value(tickHz, 'tickHz', 'must be > 0');
  }
  if (frameCount <= 0 || stepTimeSeconds <= 0) return 0;
  final ticksPerFrame = max(1, (stepTimeSeconds * tickHz).round());
  return frameCount * ticksPerFrame;
}

/// Resolves [ticksForStrip] from animation timing maps for [key].
int ticksForKey<K>({
  required K key,
  required Map<K, int> frameCounts,
  required Map<K, double> stepTimeSecondsByKey,
  required int tickHz,
  int defaultFrameCount = 1,
  double defaultStepTimeSeconds = 0.10,
}) {
  final frames = frameCounts[key] ?? defaultFrameCount;
  final step = stepTimeSecondsByKey[key] ?? defaultStepTimeSeconds;
  return ticksForStrip(
    frameCount: frames,
    stepTimeSeconds: step,
    tickHz: tickHz,
  );
}
