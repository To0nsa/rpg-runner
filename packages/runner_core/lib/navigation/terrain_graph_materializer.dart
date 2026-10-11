import '../collision/terrain/terrain_geometry.dart';
import 'types/terrain_navigation_surface.dart';
import 'types/terrain_surface_graph.dart';

/// Trusted host cache lookup. Null means rebuild from the exact Core inputs.
/// Implementations must bind data to geometry, surfaces, every profile input
/// and the graph algorithm version; client-provided data is never authority.
typedef TerrainGraphLookup = TerrainSurfaceGraph? Function(
  TerrainGeometry geometry,
  TerrainSurfaceSet surfaces,
  TerrainSurfaceGraphBuildProfile profile,
);

/// Selects when identical immutable graphs are materialized, never their rules.
/// Live candidates remain eager; offline replay may omit unused profile work.
final class TerrainGraphMaterializer {
  const TerrainGraphMaterializer.eager({this.lookup}) : deferred = false;
  const TerrainGraphMaterializer.onDemand({this.lookup}) : deferred = true;

  final bool deferred;
  final TerrainGraphLookup? lookup;
}
