import '../collision/static_world_geometry.dart';
import '../ecs/spatial/grid_index_2d.dart';
import 'jump_template.dart';
import 'nav_tolerances.dart';
import 'surface_extractor.dart';
import 'surface_graph.dart';
import 'surface_spatial_index.dart';
import 'walk_surface.dart';

class SurfaceGraphBuildResult {
  const SurfaceGraphBuildResult({
    required this.graph,
    required this.spatialIndex,
  });

  final SurfaceGraph graph;
  final SurfaceSpatialIndex spatialIndex;
}

class SurfaceGraphBuilder {
  SurfaceGraphBuilder({
    required GridIndex2D surfaceGrid,
    SurfaceExtractor? extractor,
    this.standableEps = navGeomEps,
    this.dropSampleOffset = navSpatialEps,
    this.takeoffSampleMaxStep = 64.0,
  })  : _surfaceGrid = surfaceGrid,
        _extractor = extractor ?? SurfaceExtractor();

  final GridIndex2D _surfaceGrid;
  final SurfaceExtractor _extractor;
  final double standableEps;
  final double dropSampleOffset;
  final double takeoffSampleMaxStep;

  SurfaceGraphBuildResult build({
    required StaticWorldGeometry geometry,
    required JumpReachabilityTemplate jumpTemplate,
  }) {
    final surfaces = _extractor.extract(geometry);
    final spatialIndex = SurfaceSpatialIndex(index: _surfaceGrid);
    spatialIndex.rebuild(surfaces);

    final indexById = <int, int>{};
    for (var i = 0; i < surfaces.length; i += 1) {
      indexById[surfaces[i].id] = i;
    }

    final edges = <SurfaceEdge>[];
    final edgeOffsets = List<int>.filled(surfaces.length + 1, 0);
    final tempCandidates = <int>[];

    for (var i = 0; i < surfaces.length; i += 1) {
      edgeOffsets[i] = edges.length;
      final from = surfaces[i];
      final standable = _standableRange(
        from,
        jumpTemplate.profile.agentHalfWidth,
        standableEps,
      );
      if (standable == null) {
        edgeOffsets[i + 1] = edges.length;
        continue;
      }

      final takeoffXs = _takeoffSamples(
        standable.min,
        standable.max,
        jumpTemplate.maxDx,
        takeoffSampleMaxStep,
      );

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

      for (final takeoffX in takeoffXs) {
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

        tempCandidates.sort(
          (a, b) => surfaces[a].id.compareTo(surfaces[b].id),
        );

        for (final targetIndex in tempCandidates) {
          if (targetIndex == i) continue;
          final target = surfaces[targetIndex];
          final landing = _standableRange(
            target,
            jumpTemplate.profile.agentHalfWidth,
            standableEps,
          );
          if (landing == null) continue;

          final dy = target.yTop - from.yTop;
          final dxMin = landing.min - takeoffX;
          final dxMax = landing.max - takeoffX;
          final landingTick = jumpTemplate.findFirstLanding(
            dy: dy,
            dxMin: dxMin,
            dxMax: dxMax,
          );
          if (landingTick == null) continue;

          final reachMin = takeoffX - landingTick.maxDx;
          final reachMax = takeoffX + landingTick.maxDx;
          final low = reachMin > landing.min ? reachMin : landing.min;
          final high = reachMax < landing.max ? reachMax : landing.max;
          if (low > high + standableEps) continue;

          final edge = SurfaceEdge(
            to: targetIndex,
            kind: SurfaceEdgeKind.jump,
            takeoffX: takeoffX,
            landingX: (low + high) * 0.5,
            travelTicks: landingTick.tick,
            cost: landingTick.tick * jumpTemplate.profile.dtSeconds,
          );
          edges.add(edge);
        }
      }

      edgeOffsets[i + 1] = edges.length;
    }

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

class _Range {
  const _Range(this.min, this.max);

  final double min;
  final double max;
}

_Range? _standableRange(WalkSurface surface, double halfWidth, double eps) {
  final min = surface.xMin + halfWidth;
  final max = surface.xMax - halfWidth;
  if (min > max + eps) return null;
  return _Range(min, max);
}

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

  if (step <= navGeomEps || (max - min) <= step) {
    final mid = (min + max) * 0.5;
    return _dedupeSamples(<double>[min, mid, max]);
  }

  final samples = <double>[];
  for (var x = min; x <= max; x += step) {
    samples.add(x);
  }
  if ((max - samples.last).abs() > navGeomEps) {
    samples.add(max);
  }
  return _dedupeSamples(samples);
}

List<double> _dropSamples(double min, double max) {
  final samples = <double>[min, max];
  return _dedupeSamples(samples);
}

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
    if (s.yTop <= fromY) continue;
    final minX = s.xMin + halfWidth;
    final maxX = s.xMax - halfWidth;
    if (minX > maxX) continue;
    if (x < minX || x > maxX) continue;
    if (bestY == null || s.yTop < bestY) {
      bestY = s.yTop;
      bestIndex = i;
    } else if ((s.yTop - bestY).abs() < navTieEps) {
      if (s.id < surfaces[bestIndex!].id) {
        bestIndex = i;
      }
    }
  }

  return bestIndex;
}

double _clamp(double v, double min, double max) {
  if (v < min) return min;
  if (v > max) return max;
  return v;
}
