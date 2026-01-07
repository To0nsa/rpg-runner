/// Navigation-wide numeric tolerances.
///
/// **Design**:
/// - Currently uses a single epsilon ([navEps]) for simplicity.
/// - Semantic aliases exist to make callsites self-documenting.
/// - If tuning is needed later, individual values can diverge without code changes.
///
/// **Warning**: Changing these values affects pathfinding determinism.
library;

/// Default epsilon used across navigation (1 micron in world units).
const double navEps = 1e-6;

/// Epsilon for geometric equality checks (e.g., "are these two points the same?").
const double navGeomEps = navEps;

/// Epsilon for spatial queries (surface containment, overlap thickness).
const double navSpatialEps = navEps;

/// Epsilon for deterministic tie-breaking in A* (f-cost and g-cost comparisons).
const double navTieEps = navEps;
