/// MurmurHash3 finalizer-style bit mixer for deterministic RNG.
///
/// Produces a pseudo-random 32-bit integer from an input hash.
/// Used for reproducible procedural generation (chunk selection, spawn rolls).
int mix32(int x) {
  var v = x & 0xffffffff;
  v ^= (v >> 16);
  v = (v * 0x7feb352d) & 0xffffffff; // Golden-ratio-derived multiplier.
  v ^= (v >> 15);
  v = (v * 0x846ca68b) & 0xffffffff;
  v ^= (v >> 16);
  return v & 0xffffffff;
}
