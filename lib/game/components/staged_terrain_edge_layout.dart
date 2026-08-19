export 'package:terrain_materials/terrain_materials.dart'
    show TerrainMaterialEdgeOrientation;

import 'package:runner_core/collision/terrain/terrain_edge.dart';
import 'package:runner_core/snapshots/staged_terrain_render_snapshot.dart';
import 'package:terrain_materials/terrain_materials.dart';

import '../themes/terrain_material_registry.dart';

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
    final decorations = <StagedTerrainEdgeDecoration>[];
    for (final edge in snapshot.edges) {
      final materialKey = edge.materialKey;
      if (materialKey == null) continue;
      final material = TerrainMaterialRegistry.require(materialKey);
      final orientation = orientationFor(edge);
      if (_profileFor(material, orientation) == null) continue;
      final caps = _capsFor(material, orientation);
      decorations.add(
        StagedTerrainEdgeDecoration(
          edge: edge,
          materialKey: materialKey,
          orientation: orientation,
          drawStartCap:
              caps.$1 != null && edge.startJoin == TerrainVertexJoin.exposed,
          drawEndCap:
              caps.$2 != null && edge.endJoin == TerrainVertexJoin.exposed,
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

(TerrainMaterialCapSpec?, TerrainMaterialCapSpec?) _capsFor(
  TerrainMaterialSpec material,
  TerrainMaterialEdgeOrientation orientation,
) => switch (orientation) {
  TerrainMaterialEdgeOrientation.top => (
    material.topStartCap,
    material.topEndCap,
  ),
  TerrainMaterialEdgeOrientation.underside => (
    material.undersideStartCap,
    material.undersideEndCap,
  ),
  TerrainMaterialEdgeOrientation.leftWall ||
  TerrainMaterialEdgeOrientation.rightWall => (null, null),
};
