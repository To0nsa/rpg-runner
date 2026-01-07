/// Deterministic random number generation utilities.
///
/// Provides seedable, reproducible pseudo-random numbers for procedural
/// generation. Uses Xorshift32 (fast, small state) with MurmurHash3 mixing
/// for seed avalanche. All functions are pure and tick-deterministic.
library;

/// Bitmask for 32-bit unsigned integer operations.
const int _mask32 = 0xffffffff;

/// Fallback seed when mixing produces zero (Xorshift32 degenerates on zero).
const int _nonZeroSeed = 0x6d2b79f5;

/// MurmurHash3 finalizer-style bit mixer.
///
/// Produces a well-distributed 32-bit hash from any integer input.
/// Used to "avalanche" seed bits before RNG initialization.
int mix32(int x) {
  var v = x & _mask32;
  v ^= (v >> 16);
  v = (v * 0x7feb352d) & _mask32;
  v ^= (v >> 15);
  v = (v * 0x846ca68b) & _mask32;
  v ^= (v >> 16);
  return v & _mask32;
}

/// Derives a non-zero 32-bit RNG state from [seed] and [salt].
///
/// XORs seed with salt, then mixes. Guarantees non-zero output to
/// prevent Xorshift32 from degenerating into a constant sequence.
int seedFrom(int seed, int salt) {
  final mixed = mix32(seed ^ salt);
  return mixed == 0 ? _nonZeroSeed : mixed;
}

/// Advances [state] by one Xorshift32 step, returning the new state.
///
/// The returned value serves as both the next state and the random output.
/// Period: 2³²−1. Passes most statistical tests for game use.
int nextUint32(int state) {
  var x = state & _mask32;
  if (x == 0) x = _nonZeroSeed; // Guard against degenerate zero state.
  x ^= (x << 13) & _mask32;
  x ^= (x >> 17);
  x ^= (x << 5) & _mask32;
  return x & _mask32;
}

/// Converts a 32-bit unsigned [value] to a double in \[0, 1\].
///
/// Uses simple division for uniform distribution. Inclusive on both ends.
double uint32ToUnitDouble(int value) {
  return (value & _mask32) / _mask32;
}

/// Maps a 32-bit unsigned [value] to a double in \[[min], [max]\].
///
/// Automatically swaps [min]/[max] if inverted. Distribution is uniform.
double rangeDouble(int value, double min, double max) {
  final lo = min <= max ? min : max;
  final hi = min <= max ? max : min;
  return lo + (hi - lo) * uint32ToUnitDouble(value);
}
