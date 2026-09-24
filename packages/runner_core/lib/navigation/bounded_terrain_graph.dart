import '../collision/terrain/terrain_motion_request.dart';
import 'types/terrain_surface_graph.dart';

/// Restricts an actor's graph while retaining the publication's shared nodes.
/// Both facing offsets must fit, so a turn cannot move a capsule across a bound.
TerrainSurfaceGraph restrictTerrainGraph(
  TerrainSurfaceGraph graph,
  TerrainHorizontalBounds bounds,
) {
  final margin =
      graph.buildProfile.radiusTicks +
      graph.buildProfile.authoredOffsetXTicks.abs();
  final minimum = bounds.minXTicks + margin;
  final maximum = bounds.maxXTicks - margin;
  final eligible = [
    for (var i = 0; i < graph.surfaces.length; i++)
      graph.eligibility[i] &&
          minimum <= maximum &&
          graph.surfaces[i].xMaxTicks >= minimum &&
          graph.surfaces[i].xMinTicks <= maximum,
  ];
  final edges = <TerrainSurfaceGraphEdge>[];
  final offsets = <int>[0];
  for (var i = 0; i < graph.surfaces.length; i++) {
    if (eligible[i]) {
      for (final edge in graph.edgesFor(i)) {
        if (eligible[edge.to] &&
            edge.takeoffPoint.xTicks >= minimum &&
            edge.takeoffPoint.xTicks <= maximum &&
            edge.landingPoint.xTicks >= minimum &&
            edge.landingPoint.xTicks <= maximum) {
          edges.add(edge);
        }
      }
    }
    offsets.add(edges.length);
  }
  return TerrainSurfaceGraph(
    surfaceSet: graph.surfaceSet,
    buildProfile: graph.buildProfile,
    eligibility: eligible,
    edgeOffsets: offsets,
    edges: edges,
  );
}
