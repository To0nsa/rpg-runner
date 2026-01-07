/// Tick/time conversion utilities.
///
/// Bridges between author-friendly seconds and simulation tick counts.
library;

import 'dart:math';

/// Converts [seconds] to tick count at [tickHz], rounding up.
///
/// Rules:
/// - `seconds <= 0` => `0` ticks
/// - otherwise `max(1, ceil(seconds * tickHz))`
int ticksFromSecondsCeil(double seconds, int tickHz) {
  if (tickHz <= 0) {
    throw ArgumentError.value(tickHz, 'tickHz', 'must be > 0');
  }
  if (seconds <= 0) return 0;
  return max(1, (seconds * tickHz).ceil());
}

