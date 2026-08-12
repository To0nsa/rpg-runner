/// Immutable render data derived from staged terrain geometry.
library;

import '../collision/terrain/terrain_edge.dart';
import '../collision/terrain/terrain_numeric.dart';
import '../collision/terrain/terrain_polygon.dart';

/// One compiler-owned triangle indexing a polygon render loop.
final class StagedTerrainRenderTriangleSnapshot {
  const StagedTerrainRenderTriangleSnapshot({
    required this.first,
    required this.second,
    required this.third,
  });

  /// Index into the owning polygon's world-space [TerrainPoint] loop.
  final int first;

  /// Index into the owning polygon's world-space [TerrainPoint] loop.
  final int second;

  /// Index into the owning polygon's world-space [TerrainPoint] loop.
  final int third;
}

/// One world-space polygon and the generated triangles that fill it.
///
/// The renderer must use [vertices] and [triangles] exactly as supplied. It
/// may select a material from [materialKey], but must not normalize, split, or
/// triangulate the collision loop independently.
final class StagedTerrainPolygonRenderSnapshot {
  StagedTerrainPolygonRenderSnapshot({
    required this.sourceId,
    required Iterable<TerrainPoint> vertices,
    required Iterable<StagedTerrainRenderTriangleSnapshot> triangles,
    required this.materialKey,
  }) : vertices = List<TerrainPoint>.unmodifiable(vertices),
       triangles = List<StagedTerrainRenderTriangleSnapshot>.unmodifiable(
         triangles,
       );

  /// Streamed source lineage matching the collision polygon instance.
  final TerrainSourceIdentity sourceId;

  /// World-space vertices in `1/1024`-world-unit physics ticks.
  final List<TerrainPoint> vertices;

  /// Generator-owned fill triangles indexing [vertices].
  final List<StagedTerrainRenderTriangleSnapshot> triangles;

  /// Optional rendering material retained independently from collision mode.
  final String? materialKey;
}

/// Complete immutable render candidate sharing one Core geometry version.
///
/// [GameStateSnapshot] exposes this whole object for normal staged rendering
/// and terrain-harness publication. Its [geometryVersion] matches the
/// candidate's collision/support/navigation bundle even while normal gameplay
/// still uses the legacy motion authority during cutover.
final class StagedTerrainRenderSnapshot {
  StagedTerrainRenderSnapshot({
    required this.geometryVersion,
    required Iterable<StagedTerrainPolygonRenderSnapshot> polygons,
    required Iterable<TerrainEdge> edges,
  }) : polygons = List<StagedTerrainPolygonRenderSnapshot>.unmodifiable(
         polygons,
       ),
       edges = List<TerrainEdge>.unmodifiable(edges);

  /// Version of the exact terrain geometry that produced [polygons].
  final int geometryVersion;

  /// Canonically ordered staged terrain fill polygons.
  final List<StagedTerrainPolygonRenderSnapshot> polygons;

  /// Canonically ordered exposed collision edges for render diagnostics.
  ///
  /// These are the exact compiler-owned edge objects used by the matching
  /// collision/navigation bundle. Their IDs retain full chunk, placement, and
  /// shape lineage; render consumers must not derive substitute boundaries
  /// from [polygons].
  final List<TerrainEdge> edges;
}
