/// Navigation-wide numeric tolerances.
///
/// **Design**:
/// - [navEps] is kept very small for geometric comparisons and deterministic
///   tie-breaking.
/// - [navSpatialEps] is intentionally larger to make runtime surface detection
///   robust against tiny simulation drift (world units are pixels).
///
/// **Warning**: Changing these values affects pathfinding determinism.
library;

/// Default epsilon for equality checks and tie-breaks (1e-6 world units).
const double navEps = 1e-6;

/// Epsilon for geometric equality checks (e.g., "are these two points the same?").
const double navGeomEps = navEps;

/// Epsilon for spatial queries (surface containment, overlap thickness).
const double navSpatialEps = 1.0;

/// Epsilon for deterministic tie-breaking in A* (f-cost and g-cost comparisons).
const double navTieEps = navEps;
