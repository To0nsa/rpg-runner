import '../types/nav_tolerances.dart';

/// Physics parameters for simulating a jump arc.
///
/// Used to precompute reachability templates for AI pathfinding.
class JumpProfile {
  const JumpProfile({
    required this.jumpSpeed,
    required this.gravityY,
    required this.maxAirTicks,
    required this.airSpeedX,
    required this.dtSeconds,
    required this.agentHalfWidth,
    this.agentHalfHeight,
    this.collideCeilings = true,
    this.collideLeftWalls = true,
    this.collideRightWalls = true,
  }) : assert(maxAirTicks > 0),
       assert(dtSeconds > 0),
       assert(agentHalfWidth > 0.0),
       assert(agentHalfHeight == null || agentHalfHeight > 0.0);

  /// Instantaneous vertical speed at jump start (negative = upward).
  final double jumpSpeed;

  /// Gravity acceleration (positive = downward, e.g., 980 for ~10m/s²).
  final double gravityY;

  /// Fixed timestep in seconds (e.g., 1/60 for 60Hz).
  final double dtSeconds;

  /// Maximum ticks to simulate (limits arc length for performance).
  final int maxAirTicks;

  /// Assumed constant horizontal speed while airborne.
  final double airSpeedX;

  /// Agent's collider half-width (for landing overlap calculations).
  final double agentHalfWidth;

  /// Agent's collider half-height for jump obstruction checks.
  ///
  /// If not provided, [agentHalfWidth] is used.
  final double? agentHalfHeight;

  /// Whether jump arc validation should treat ceiling bottoms as blocking.
  final bool collideCeilings;

  /// Whether jump arc validation should treat left-side body collisions as active.
  final bool collideLeftWalls;

  /// Whether jump arc validation should treat right-side body collisions as active.
  final bool collideRightWalls;

  /// Effective half-height used by jump obstruction checks.
  double get effectiveHalfHeight => agentHalfHeight ?? agentHalfWidth;
}

/// A single sample point along a precomputed jump arc.
class JumpSample {
  const JumpSample({
    required this.tick,
    required this.prevY,
    required this.y,
    required this.velY,
    required this.maxDx,
  });

  /// Tick number (1-based, 0 = takeoff).
  final int tick;

  /// Y position at the end of the previous tick.
  final double prevY;

  /// Y position at the end of this tick.
  final double y;

  /// Vertical velocity at the end of this tick.
  final double velY;

  /// Maximum horizontal displacement reachable by this tick.
  final double maxDx;
}

/// Result of a successful landing query.
class JumpLanding {
  const JumpLanding({required this.tick, required this.maxDx});

  /// Tick at which landing occurs.
  final int tick;

  /// Maximum horizontal reach at landing time.
  final double maxDx;
}

/// Precomputed jump arc template for reachability queries.
///
/// **Usage**:
/// - Built once from a [JumpProfile] (at startup or when physics change).
/// - Queried during graph construction to find valid jump edges.
///
/// **Physics**:
/// - Uses semi-implicit Euler integration: `vel += g*dt`, then `pos += vel*dt`.
/// - Matches the runtime physics in [GravitySystem].
class JumpReachabilityTemplate {
  JumpReachabilityTemplate._({
    required this.profile,
    required this.samples,
    required this.minDy,
    required this.maxDy,
    required this.maxDx,
  });

  /// The physics profile used to build this template.
  final JumpProfile profile;

  /// Sampled arc positions (tick 1 to maxAirTicks).
  final List<JumpSample> samples;

  /// Lowest Y offset reached (negative = above origin).
  final double minDy;

  /// Highest Y offset reached (positive = below origin, after fall).
  final double maxDy;

  /// Maximum horizontal distance reachable.
  final double maxDx;

  /// Builds a reachability template by simulating [profile.maxAirTicks] of flight.
  factory JumpReachabilityTemplate.build(JumpProfile profile) {
    final samples = <JumpSample>[];

    var y = 0.0;
    var velY = -profile.jumpSpeed; // Negative = upward
    final dt = profile.dtSeconds;
    var minDy = 0.0;
    var maxDy = 0.0;
    var maxDxOverall = 0.0;

    for (var tick = 1; tick <= profile.maxAirTicks; tick += 1) {
      final prevY = y;

      // Semi-implicit Euler: update velocity first, then position.
      velY += profile.gravityY * dt;
      y += velY * dt;

      // Horizontal reach increases linearly with time.
      final maxDx = profile.airSpeedX * dt * tick;

      // Track bounding box.
      if (y < minDy) minDy = y;
      if (y > maxDy) maxDy = y;
      if (maxDx > maxDxOverall) maxDxOverall = maxDx;

      samples.add(
        JumpSample(tick: tick, prevY: prevY, y: y, velY: velY, maxDx: maxDx),
      );
    }

    return JumpReachabilityTemplate._(
      profile: profile,
      samples: List<JumpSample>.unmodifiable(samples),
      minDy: minDy,
      maxDy: maxDy,
      maxDx: maxDxOverall,
    );
  }

  /// Finds the earliest tick at which a jump can land at vertical offset [dy].
  ///
  /// **Parameters**:
  /// - [dy]: Target vertical offset (positive = below takeoff, negative = above).
  /// - [dxMin], [dxMax]: Required horizontal range for a valid landing.
  ///
  /// **Returns**: [JumpLanding] if reachable, null otherwise.
  ///
  /// **Logic**:
  /// 1. Skip ascending samples (velY < 0).
  /// 2. Check if [dy] is crossed between prevY and y.
  /// 3. Check if horizontal range overlaps [dxMin, dxMax].
  JumpLanding? findFirstLanding({
    required double dy,
    required double dxMin,
    required double dxMax,
    double eps = navGeomEps,
  }) {
    if (dxMin > dxMax) return null;

    for (final sample in samples) {
      // Only consider descending phase.
      if (sample.velY < 0) continue;

      // Check vertical crossing: prevY <= dy <= y (with tolerance).
      final crosses = (sample.prevY <= dy + eps) && (sample.y >= dy - eps);
      if (!crosses) continue;

      // Check horizontal reachability.
      final maxDx = sample.maxDx;
      if (dxMin > maxDx + eps) continue; // Target too far right.
      if (dxMax < -maxDx - eps) continue; // Target too far left.

      return JumpLanding(tick: sample.tick, maxDx: maxDx);
    }

    return null;
  }
}

/// Estimates the number of ticks to fall a given vertical distance.
///
/// Used for "drop" edges (walking off a ledge without jumping).
///
/// **Parameters**:
/// - [dy]: Distance to fall (positive = downward).
/// - [gravityY]: Gravity acceleration.
/// - [dtSeconds]: Timestep.
/// - [maxTicks]: Upper bound to prevent infinite loops.
int estimateFallTicks({
  required double dy,
  required double gravityY,
  required double dtSeconds,
  required int maxTicks,
}) {
  if (dy <= 0) return 0;

  var y = 0.0;
  var velY = 0.0;

  for (var tick = 1; tick <= maxTicks; tick += 1) {
    velY += gravityY * dtSeconds;
    y += velY * dtSeconds;
    if (y >= dy) return tick;
  }

  return maxTicks;
}
