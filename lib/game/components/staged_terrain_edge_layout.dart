import 'package:runner_core/collision/terrain/terrain_edge.dart';
import 'package:runner_core/collision/terrain/terrain_edge_id.dart';
import 'package:runner_core/snapshots/staged_terrain_render_snapshot.dart';

import '../themes/terrain_material_registry.dart';

/// Material profile selected by an exact compiler-owned outward normal.
enum TerrainMaterialEdgeOrientation { top, leftWall, rightWall, underside }

/// Render decoration resolved for one exact exposed Core edge.
final class StagedTerrainEdgeDecoration {
  const StagedTerrainEdgeDecoration({
    required this.edge,
    required this.materialKey,
    required this.orientation,
    required this.drawStartCap,
    required this.drawEndCap,
  });

  final TerrainEdge edge;
  final String materialKey;
  final TerrainMaterialEdgeOrientation orientation;
  final bool drawStartCap;
  final bool drawEndCap;
}

/// Maps Core edges to authored render profiles without changing geometry.
abstract final class StagedTerrainEdgeLayout {
  static List<StagedTerrainEdgeDecoration> build(
    StagedTerrainRenderSnapshot snapshot,
  ) {
    final edgesById = <TerrainEdgeId, TerrainEdge>{
      for (final edge in snapshot.edges) edge.id: edge,
    };
    final decorations = <StagedTerrainEdgeDecoration>[];
    for (final edge in snapshot.edges) {
      final materialKey = edge.materialKey;
      if (materialKey == null) continue;
      final material = TerrainMaterialRegistry.require(materialKey);
      final orientation = orientationFor(edge);
      if (_profileFor(material, orientation) == null) continue;
      final isTop = orientation == TerrainMaterialEdgeOrientation.top;
      decorations.add(
        StagedTerrainEdgeDecoration(
          edge: edge,
          materialKey: materialKey,
          orientation: orientation,
          drawStartCap:
              isTop &&
              material.topStartCap != null &&
              !_continuesTop(
                edge: edge,
                adjacentId: edge.previousId,
                edgesById: edgesById,
              ),
          drawEndCap:
              isTop &&
              material.topEndCap != null &&
              !_continuesTop(
                edge: edge,
                adjacentId: edge.nextId,
                edgesById: edgesById,
              ),
        ),
      );
    }
    return List<StagedTerrainEdgeDecoration>.unmodifiable(decorations);
  }

  static TerrainMaterialEdgeOrientation orientationFor(TerrainEdge edge) {
    final normal = edge.outwardNormal;
    if (normal.yTicks < 0) return TerrainMaterialEdgeOrientation.top;
    if (normal.yTicks > 0) return TerrainMaterialEdgeOrientation.underside;
    return normal.xTicks < 0
        ? TerrainMaterialEdgeOrientation.leftWall
        : TerrainMaterialEdgeOrientation.rightWall;
  }

  static TerrainMaterialEdgeProfileSpec? profileFor(
    TerrainMaterialSpec material,
    TerrainMaterialEdgeOrientation orientation,
  ) => _profileFor(material, orientation);

  static bool _continuesTop({
    required TerrainEdge edge,
    required TerrainEdgeId? adjacentId,
    required Map<TerrainEdgeId, TerrainEdge> edgesById,
  }) {
    final adjacent = adjacentId == null ? null : edgesById[adjacentId];
    return adjacent != null &&
        adjacent.materialKey == edge.materialKey &&
        orientationFor(adjacent) == TerrainMaterialEdgeOrientation.top;
  }
}

TerrainMaterialEdgeProfileSpec? _profileFor(
  TerrainMaterialSpec material,
  TerrainMaterialEdgeOrientation orientation,
) => switch (orientation) {
  TerrainMaterialEdgeOrientation.top => material.top,
  TerrainMaterialEdgeOrientation.leftWall => material.leftWall,
  TerrainMaterialEdgeOrientation.rightWall => material.rightWall,
  TerrainMaterialEdgeOrientation.underside => material.underside,
};
