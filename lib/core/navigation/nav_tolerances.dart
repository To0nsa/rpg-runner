/// Navigation-wide numeric tolerances.
///
/// Keep this intentionally small: for now we use one epsilon everywhere so
/// tuning stays straightforward. The aliases keep callsites semantically clear
/// and make it easy to split values later if needed.
library;

/// Default epsilon used across navigation.
const double navEps = 1e-6;

/// Epsilon for "these two world-space doubles should be equal" cases.
const double navGeomEps = navEps;

/// Epsilon used for runtime spatial queries / thickness.
const double navSpatialEps = navEps;

/// Epsilon used for deterministic tie-breaking in comparisons (e.g., A* f/g
/// ties).
const double navTieEps = navEps;
