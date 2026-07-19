/// Converts an authoritative simulation tick to whole elapsed seconds.
///
/// Partial seconds are truncated. This matches deterministic score timing and
/// gives the client, validator, and leaderboard tie-breaker one conversion
/// rule.
int canonicalRunDurationSeconds({required int tick, required int tickHz}) {
  if (tick < 0) {
    throw ArgumentError.value(tick, 'tick', 'must be non-negative');
  }
  if (tickHz <= 0) {
    throw ArgumentError.value(tickHz, 'tickHz', 'must be positive');
  }
  return tick ~/ tickHz;
}
