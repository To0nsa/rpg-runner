const int _mask32 = 0xffffffff;
const int _nonZeroSeed = 0x6d2b79f5;

/// 32-bit mixing helper for deterministic seeds.
int mix32(int x) {
  var v = x & _mask32;
  v ^= (v >> 16);
  v = (v * 0x7feb352d) & _mask32;
  v ^= (v >> 15);
  v = (v * 0x846ca68b) & _mask32;
  v ^= (v >> 16);
  return v & _mask32;
}

/// Builds a non-zero 32-bit RNG state from a base seed and salt.
int seedFrom(int seed, int salt) {
  final mixed = mix32(seed ^ salt);
  return mixed == 0 ? _nonZeroSeed : mixed;
}

/// Xorshift32 step. Returns the next 32-bit state.
int nextUint32(int state) {
  var x = state & _mask32;
  if (x == 0) x = _nonZeroSeed;
  x ^= (x << 13) & _mask32;
  x ^= (x >> 17);
  x ^= (x << 5) & _mask32;
  return x & _mask32;
}

/// Converts a 32-bit state to a [0, 1] double (inclusive).
double uint32ToUnitDouble(int value) {
  return (value & _mask32) / _mask32;
}

/// Maps a 32-bit state to a [min, max] double range.
double rangeDouble(int value, double min, double max) {
  final lo = min <= max ? min : max;
  final hi = min <= max ? max : min;
  return lo + (hi - lo) * uint32ToUnitDouble(value);
}
