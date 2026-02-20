import '../types/surface_graph.dart';
import 'surface_spatial_index.dart';

/// Prediction result for where an airborne entity will land.
class LandingPrediction {
  const LandingPrediction({
    required this.x,
    required this.bottomY,
    required this.surfaceIndex,
    required this.ticksToLand,
  });

  /// Predicted X position at landing.
  final double x;

  /// Predicted bottom Y position at landing (on surface).
  final double bottomY;

  /// Index of the surface in [SurfaceGraph.surfaces] where landing occurs.
  final int surfaceIndex;

  /// Number of ticks until landing.
  final int ticksToLand;
}

/// Predicts where an airborne entity will land.
///
/// **Purpose**:
/// Used by ground enemy AI to anticipate where an airborne player will land,
/// enabling pathfinding toward the predicted landing spot instead of the
/// player's current (airborne) position.
///
/// **Algorithm**:
/// Simulates the entity's trajectory tick-by-tick using semi-implicit Euler
/// integration (matching [GravitySystem]), checking for surface intersections
/// at each step.
///
/// **Usage**:
/// ```dart
/// final predictor = TrajectoryPredictor(
///   gravityY: physics.gravityY,
///   dtSeconds: movement.dtSeconds,
///   maxTicks: 120,
/// );
///
/// final prediction = predictor.predictLanding(
///   startX: playerX,
///   startBottomY: playerBottomY,
///   velX: playerVelX,
///   velY: playerVelY,
///   graph: surfaceGraph,
///   spatialIndex: surfaceSpatialIndex,
///   entityHalfWidth: playerHalfX,
/// );
/// ```
class TrajectoryPredictor {
  TrajectoryPredictor({
    required this.gravityY,
    required this.dtSeconds,
    required this.maxTicks,
  });

  /// Gravity acceleration (positive = downward).
  final double gravityY;

  /// Fixed timestep in seconds.
  final double dtSeconds;

  /// Maximum ticks to simulate before giving up.
  final int maxTicks;

  /// Reused candidate buffer for spatial queries (avoids per-call allocation).
  final List<int> _candidateBuffer = <int>[];

  /// Predicts landing position for an airborne entity.
  ///
  /// **Parameters**:
  /// - [startX], [startBottomY]: Current position (bottom of collider).
  /// - [velX], [velY]: Current velocity.
  /// - [graph]: Surface graph for landing candidates.
  /// - [spatialIndex]: Spatial index for fast surface queries.
  /// - [entityHalfWidth]: Half-width of the entity collider.
  ///
  /// **Returns**: [LandingPrediction] if a valid landing is found, null otherwise.
  ///
  /// **Edge Cases**:
  /// - Returns null if entity is moving upward and never descends (shouldn't happen with gravity).
  /// - Returns null if no surface intersects the trajectory within [maxTicks].
  /// - Returns the FIRST valid landing (earliest tick) if multiple surfaces are crossed.
  LandingPrediction? predictLanding({
    required double startX,
    required double startBottomY,
    required double velX,
    required double velY,
    required SurfaceGraph graph,
    required SurfaceSpatialIndex spatialIndex,
    required double entityHalfWidth,
  }) {
    if (graph.surfaces.isEmpty) return null;

    var x = startX;
    var y = startBottomY;
    var vy = velY;
    final dt = dtSeconds;

    for (var tick = 1; tick <= maxTicks; tick += 1) {
      final prevX = x;
      final prevY = y;

      // Semi-implicit Euler (matches GravitySystem).
      vy += gravityY * dt;
      y += vy * dt;
      x += velX * dt;

      // Only check for landing when descending (vy > 0 means moving downward).
      if (vy <= 0) continue;

      // Check if we crossed any surface between prevY and y.
      final landing = _findLandingSurface(
        graph: graph,
        spatialIndex: spatialIndex,
        candidates: _candidateBuffer,
        prevX: prevX,
        x: x,
        prevY: prevY,
        y: y,
        entityHalfWidth: entityHalfWidth,
        tick: tick,
      );

      if (landing != null) {
        return landing;
      }
    }

    return null;
  }

  /// Checks if the trajectory crossed a valid landing surface this tick.
  LandingPrediction? _findLandingSurface({
    required SurfaceGraph graph,
    required SurfaceSpatialIndex spatialIndex,
    required List<int> candidates,
    required double prevX,
    required double x,
    required double prevY,
    required double y,
    required double entityHalfWidth,
    required int tick,
  }) {
    // Query surfaces in the swept AABB traversed this tick.
    final minX = (prevX < x ? prevX : x) - entityHalfWidth;
    final maxX = (prevX > x ? prevX : x) + entityHalfWidth;
    final minY = prevY < y ? prevY : y;
    final maxY = prevY > y ? prevY : y;

    spatialIndex.queryAabb(
      minX: minX,
      minY: minY,
      maxX: maxX,
      maxY: maxY,
      outSurfaceIndices: candidates,
    );

    if (candidates.isEmpty) return null;

    // Find the highest surface (lowest yTop) that we crossed.
    // This handles cases where trajectory passes through multiple surfaces.
    int? bestIndex;
    double? bestYTop;
    double? bestLandingX;
    final dyStep = y - prevY;
    if (dyStep == 0.0) return null;

    for (final surfaceIndex in candidates) {
      final surface = graph.surfaces[surfaceIndex];

      // Check vertical crossing: prevY was above (or at) surface, y is at or below.
      // We want surfaces where prevY <= yTop <= y (crossed from above).
      final yTop = surface.yTop;
      if (prevY > yTop) continue; // Started below surface, can't land on it.
      if (y < yTop) continue; // Ended above surface, haven't reached it yet.

      // Interpolate horizontal position at the exact crossing time.
      final t = (yTop - prevY) / dyStep;
      final landingX = prevX + (x - prevX) * t;

      // Check standability at landing X.
      final standableMinX = surface.xMin + entityHalfWidth;
      final standableMaxX = surface.xMax - entityHalfWidth;
      if (standableMinX > standableMaxX) continue;
      if (landingX < standableMinX || landingX > standableMaxX) continue;

      // Valid landing candidate. Prefer highest surface (lowest yTop).
      if (bestYTop == null || yTop < bestYTop) {
        bestYTop = yTop;
        bestIndex = surfaceIndex;
        bestLandingX = landingX;
      }
    }

    if (bestIndex == null) return null;

    return LandingPrediction(
      x: bestLandingX!,
      bottomY: bestYTop!,
      surfaceIndex: bestIndex,
      ticksToLand: tick,
    );
  }
}
