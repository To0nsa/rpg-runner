import '../collision/static_world_geometry.dart';
import '../ecs/spatial/grid_index_2d.dart';
import 'utils/jump_template.dart';
import 'types/nav_tolerances.dart';
import 'surface_extractor.dart';
import 'types/surface_graph.dart';
import 'utils/surface_spatial_index.dart';
import 'types/walk_surface.dart';

/// Result of [SurfaceGraphBuilder.build].
class SurfaceGraphBuildResult {
  const SurfaceGraphBuildResult({
    required this.graph,
    required this.spatialIndex,
  });

  /// The navigation graph (surfaces + edges in CSR format).
  final SurfaceGraph graph;

  /// Spatial index for fast surface lookups during runtime navigation.
  final SurfaceSpatialIndex spatialIndex;
}

/// Builds a [SurfaceGraph] from world geometry and jump physics.
///
/// **Pipeline**:
/// 1. Extract [WalkSurface]s from tiles via [SurfaceExtractor].
/// 2. Build spatial index for candidate queries.
/// 3. For each surface, generate edges:
///    - **Drop edges**: Walk off ledge, fall to surface below.
///    - **Jump edges**: Sample takeoff points, find reachable surfaces.
/// 4. Pack into CSR (Compressed Sparse Row) format.
///
/// **Configuration**:
/// - [standableEps]: Tolerance for standable range calculations.
/// - [dropSampleOffset]: Nudge takeoff past ledge for drop edges.
/// - [takeoffSampleMaxStep]: Maximum spacing between takeoff samples.
class SurfaceGraphBuilder {
  SurfaceGraphBuilder({
    required GridIndex2D surfaceGrid,
    SurfaceExtractor? extractor,
    this.standableEps = navGeomEps,
    this.dropSampleOffset = navSpatialEps,
    this.takeoffSampleMaxStep = 64.0,
  })  : _surfaceGrid = surfaceGrid,
        _extractor = extractor ?? SurfaceExtractor();

  /// Grid for spatial index bucket allocation.
  final GridIndex2D _surfaceGrid;

  /// Surface extractor (default: standard tile-based extraction).
  final SurfaceExtractor _extractor;

  /// Tolerance for standable range width check.
  final double standableEps;

  /// Offset past ledge for drop takeoff (ensures entity actually falls).
  final double dropSampleOffset;

  /// Maximum step between takeoff sample points.
  final double takeoffSampleMaxStep;

  /// Builds a navigation graph from world geometry.
  ///
  /// **Parameters**:
  /// - [geometry]: Static collision geometry (tile-based).
  /// - [jumpTemplate]: Precomputed jump arc for reachability queries.
  ///
  /// **Returns**: [SurfaceGraphBuildResult] with graph and spatial index.
  SurfaceGraphBuildResult build({
    required StaticWorldGeometry geometry,
    required JumpReachabilityTemplate jumpTemplate,
  }) {
    // -------------------------------------------------------------------------
    // Step 1: Extract surfaces and build spatial index.
    // -------------------------------------------------------------------------
    final surfaces = _extractor.extract(geometry);
    final spatialIndex = SurfaceSpatialIndex(index: _surfaceGrid);
    spatialIndex.rebuild(surfaces);

    // Build surface ID → index lookup.
    final indexById = <int, int>{};
    for (var i = 0; i < surfaces.length; i += 1) {
      indexById[surfaces[i].id] = i;
    }

    // -------------------------------------------------------------------------
    // Step 2: Generate edges for each surface.
    // -------------------------------------------------------------------------
    final edges = <SurfaceEdge>[];
    final edgeOffsets = List<int>.filled(surfaces.length + 1, 0);
    final tempCandidates = <int>[];

    for (var i = 0; i < surfaces.length; i += 1) {
      edgeOffsets[i] = edges.length;
      final from = surfaces[i];

      // Compute standable range (agent center positions that fit on surface).
      final standable = _standableRange(
        from,
        jumpTemplate.profile.agentHalfWidth,
        standableEps,
      );
      if (standable == null) {
        // Surface too narrow for agent.
        edgeOffsets[i + 1] = edges.length;
        continue;
      }

      // -----------------------------------------------------------------------
      // Step 2a: Generate drop edges (walk off ledge).
      // -----------------------------------------------------------------------
      final dropSamples = _dropSamples(standable.min, standable.max);
      final dropMid = (standable.min + standable.max) * 0.5;
      for (final dropX in dropSamples) {
        final landingIndex = _findFirstSurfaceBelow(
          surfaces,
          dropX,
          from.yTop,
          jumpTemplate.profile.agentHalfWidth,
        );
        if (landingIndex == null) continue;

        final landingSurface = surfaces[landingIndex];
        final dy = landingSurface.yTop - from.yTop;
        final fallTicks = estimateFallTicks(
          dy: dy,
          gravityY: jumpTemplate.profile.gravityY,
          dtSeconds: jumpTemplate.profile.dtSeconds,
          maxTicks: jumpTemplate.profile.maxAirTicks,
        );

        // Nudge takeoff past ledge so agent actually walks off.
        final offset = dropX <= dropMid ? -dropSampleOffset : dropSampleOffset;
        final takeoffX = dropX + offset;

        final edge = SurfaceEdge(
          to: landingIndex,
          kind: SurfaceEdgeKind.drop,
          takeoffX: takeoffX,
          landingX: _clamp(
            dropX,
            landingSurface.xMin + jumpTemplate.profile.agentHalfWidth,
            landingSurface.xMax - jumpTemplate.profile.agentHalfWidth,
          ),
          travelTicks: fallTicks,
          cost: fallTicks * jumpTemplate.profile.dtSeconds,
        );
        edges.add(edge);
      }

      // -----------------------------------------------------------------------
      // Step 2b: Generate jump edges (sample takeoff points).
      // -----------------------------------------------------------------------
      final takeoffXs = _takeoffSamples(
        standable.min,
        standable.max,
        jumpTemplate.maxDx,
        takeoffSampleMaxStep,
      );

      for (final takeoffX in takeoffXs) {
        // Query reachable surfaces within jump arc bounding box.
        final minX = takeoffX - jumpTemplate.maxDx;
        final maxX = takeoffX + jumpTemplate.maxDx;
        final minY = from.yTop + jumpTemplate.minDy;
        final maxY = from.yTop + jumpTemplate.maxDy;

        spatialIndex.queryAabb(
          minX: minX,
          minY: minY,
          maxX: maxX,
          maxY: maxY,
          outSurfaceIndices: tempCandidates,
        );

        // Sort for deterministic edge ordering.
        tempCandidates.sort(
          (a, b) => surfaces[a].id.compareTo(surfaces[b].id),
        );

        for (final targetIndex in tempCandidates) {
          if (targetIndex == i) continue; // Skip self.
          final target = surfaces[targetIndex];

          final landing = _standableRange(
            target,
            jumpTemplate.profile.agentHalfWidth,
            standableEps,
          );
          if (landing == null) continue; // Target too narrow.

          // Check if jump arc can reach target surface.
          final dy = target.yTop - from.yTop;
          final dxMin = landing.min - takeoffX;
          final dxMax = landing.max - takeoffX;
          final landingTick = jumpTemplate.findFirstLanding(
            dy: dy,
            dxMin: dxMin,
            dxMax: dxMax,
          );
          if (landingTick == null) continue; // Not reachable.

          // Compute actual landing range (intersection of reach and surface).
          final reachMin = takeoffX - landingTick.maxDx;
          final reachMax = takeoffX + landingTick.maxDx;
          final low = reachMin > landing.min ? reachMin : landing.min;
          final high = reachMax < landing.max ? reachMax : landing.max;
          if (low > high + standableEps) continue; // No overlap.

          final edge = SurfaceEdge(
            to: targetIndex,
            kind: SurfaceEdgeKind.jump,
            takeoffX: takeoffX,
            landingX: (low + high) * 0.5, // Center of landing range.
            travelTicks: landingTick.tick,
            cost: landingTick.tick * jumpTemplate.profile.dtSeconds,
          );
          edges.add(edge);
        }
      }

      edgeOffsets[i + 1] = edges.length;
    }

    // -------------------------------------------------------------------------
    // Step 3: Pack into graph and return.
    // -------------------------------------------------------------------------
    return SurfaceGraphBuildResult(
      graph: SurfaceGraph(
        surfaces: surfaces,
        edgeOffsets: edgeOffsets,
        edges: edges,
        indexById: indexById,
      ),
      spatialIndex: spatialIndex,
    );
  }
}

// =============================================================================
// Helper types and functions
// =============================================================================

/// A horizontal range [min, max].
class _Range {
  const _Range(this.min, this.max);

  final double min;
  final double max;
}

/// Computes the standable X range for an agent on a surface.
///
/// The agent's center must be at least [halfWidth] from each edge.
/// Returns `null` if the surface is too narrow.
_Range? _standableRange(WalkSurface surface, double halfWidth, double eps) {
  final min = surface.xMin + halfWidth;
  final max = surface.xMax - halfWidth;
  if (min > max + eps) return null;
  return _Range(min, max);
}

/// Generates takeoff sample points across a standable range.
///
/// - Returns [min, mid, max] for narrow surfaces.
/// - Returns evenly-spaced samples (at most [maxStep] apart) for wide surfaces.
/// - Deduplicates samples within [navGeomEps].
List<double> _takeoffSamples(
  double min,
  double max,
  double maxDx,
  double maxStep,
) {
  if (max <= min) {
    return <double>[min];
  }

  var step = maxDx;
  if (maxStep > 0 && step > maxStep) {
    step = maxStep;
  }

  // Narrow surface: just sample endpoints and midpoint.
  if (step <= navGeomEps || (max - min) <= step) {
    final mid = (min + max) * 0.5;
    return _dedupeSamples(<double>[min, mid, max]);
  }

  // Wide surface: evenly-spaced samples.
  final samples = <double>[];
  for (var x = min; x <= max; x += step) {
    samples.add(x);
  }
  // Ensure max is included.
  if ((max - samples.last).abs() > navGeomEps) {
    samples.add(max);
  }
  return _dedupeSamples(samples);
}

/// Generates drop sample points (only at ledge endpoints).
List<double> _dropSamples(double min, double max) {
  final samples = <double>[min, max];
  return _dedupeSamples(samples);
}

/// Removes duplicate samples within [eps] tolerance.
List<double> _dedupeSamples(
  List<double> samples, {
  double eps = navGeomEps,
}) {
  samples.sort();
  final deduped = <double>[];
  for (final s in samples) {
    if (deduped.isEmpty || (s - deduped.last).abs() > eps) {
      deduped.add(s);
    }
  }
  return deduped;
}

/// Finds the first (highest) surface directly below a point.
///
/// **Parameters**:
/// - [x]: Horizontal position to check.
/// - [fromY]: Starting Y (surfaces must be below this).
/// - [halfWidth]: Agent half-width for standability check.
///
/// **Returns**: Surface index, or `null` if no surface below.
int? _findFirstSurfaceBelow(
  List<WalkSurface> surfaces,
  double x,
  double fromY,
  double halfWidth,
) {
  int? bestIndex;
  double? bestY;

  for (var i = 0; i < surfaces.length; i += 1) {
    final s = surfaces[i];
    // Must be below starting point.
    if (s.yTop <= fromY) continue;
    // Must be standable at this X.
    final minX = s.xMin + halfWidth;
    final maxX = s.xMax - halfWidth;
    if (minX > maxX) continue;
    if (x < minX || x > maxX) continue;

    // Prefer highest surface (lowest yTop).
    if (bestY == null || s.yTop < bestY) {
      bestY = s.yTop;
      bestIndex = i;
    } else if ((s.yTop - bestY).abs() < navTieEps) {
      // Tie-break by ID for determinism.
      if (s.id < surfaces[bestIndex!].id) {
        bestIndex = i;
      }
    }
  }

  return bestIndex;
}

/// Clamps [v] to the range [min, max].
double _clamp(double v, double min, double max) {
  if (v < min) return min;
  if (v > max) return max;
  return v;
}
