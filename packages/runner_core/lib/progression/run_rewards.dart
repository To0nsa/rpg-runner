/// Reward computation for completed runs.
///
/// Keep this module pure and deterministic so reward rules can evolve
/// without touching UI or render layers.
int computeGoldEarned({required int collectiblesCollected}) {
  return collectiblesCollected;
}
