export 'package:terrain_materials/terrain_materials.dart'
    show TerrainMaterialEdgeOrientation;

import 'package:runner_core/collision/terrain/terrain_edge.dart';
import 'package:runner_core/collision/terrain/terrain_edge_id.dart';
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
    required this.startUnderlapFactor,
    required this.endUnderlapFactor,
  });

  final TerrainEdge edge;
  final String materialKey;
  final TerrainMaterialEdgeOrientation orientation;
  final bool drawStartCap;
  final bool drawEndCap;
  final double startUnderlapFactor;
  final double endUnderlapFactor;
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
      final caps = _capsFor(material, orientation);
      decorations.add(
        StagedTerrainEdgeDecoration(
          edge: edge,
          materialKey: materialKey,
          orientation: orientation,
          drawStartCap:
              caps.$1 != null &&
              !_continuesOrientation(
                edge: edge,
                adjacentId: edge.previousId,
                orientation: orientation,
                edgesById: edgesById,
              ),
          drawEndCap:
              caps.$2 != null &&
              !_continuesOrientation(
                edge: edge,
                adjacentId: edge.nextId,
                orientation: orientation,
                edgesById: edgesById,
              ),
          startUnderlapFactor: 0,
          endUnderlapFactor: 0,
        ),
      );
    }
    return _withJoinUnderlaps(decorations);
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

  static bool _continuesOrientation({
    required TerrainEdge edge,
    required TerrainEdgeId? adjacentId,
    required TerrainMaterialEdgeOrientation orientation,
    required Map<TerrainEdgeId, TerrainEdge> edgesById,
  }) {
    final adjacent = adjacentId == null ? null : edgesById[adjacentId];
    return adjacent != null &&
        adjacent.materialKey == edge.materialKey &&
        orientationFor(adjacent) == orientation;
  }

  static List<StagedTerrainEdgeDecoration> _withJoinUnderlaps(
    List<StagedTerrainEdgeDecoration> decorations,
  ) {
    final indicesById = <TerrainEdgeId, int>{
      for (var index = 0; index < decorations.length; index += 1)
        decorations[index].edge.id: index,
    };
    final ranks = List<int>.filled(decorations.length, 0);
    final paintOrder = terrainMaterialEdgePaintOrder(
      decorations.map((decoration) => decoration.orientation),
    );
    for (var rank = 0; rank < paintOrder.length; rank += 1) {
      ranks[paintOrder[rank]] = rank;
    }
    final startFactors = List<double>.filled(decorations.length, 0);
    final endFactors = List<double>.filled(decorations.length, 0);

    for (
      var previousIndex = 0;
      previousIndex < decorations.length;
      previousIndex += 1
    ) {
      final previous = decorations[previousIndex];
      final nextId = previous.edge.nextId;
      final nextIndex = nextId == null ? null : indicesById[nextId];
      if (nextIndex == null) continue;
      final next = decorations[nextIndex];
      if (previous.materialKey != next.materialKey ||
          previous.orientation != next.orientation) {
        continue;
      }

      if (ranks[previousIndex] < ranks[nextIndex]) {
        endFactors[previousIndex] = terrainMaterialJoinUnderlapFactor(
          endpoint: TerrainMaterialJoinEndpoint.end,
          lowerTangentX: previous.edge.tangent.x,
          lowerTangentY: previous.edge.tangent.y,
          lowerInwardNormalX: -previous.edge.outwardNormal.x,
          lowerInwardNormalY: -previous.edge.outwardNormal.y,
          upperTangentX: next.edge.tangent.x,
          upperTangentY: next.edge.tangent.y,
        );
      } else {
        startFactors[nextIndex] = terrainMaterialJoinUnderlapFactor(
          endpoint: TerrainMaterialJoinEndpoint.start,
          lowerTangentX: next.edge.tangent.x,
          lowerTangentY: next.edge.tangent.y,
          lowerInwardNormalX: -next.edge.outwardNormal.x,
          lowerInwardNormalY: -next.edge.outwardNormal.y,
          upperTangentX: previous.edge.tangent.x,
          upperTangentY: previous.edge.tangent.y,
        );
      }
    }

    return List<StagedTerrainEdgeDecoration>.unmodifiable(
      <StagedTerrainEdgeDecoration>[
        for (var index = 0; index < decorations.length; index += 1)
          StagedTerrainEdgeDecoration(
            edge: decorations[index].edge,
            materialKey: decorations[index].materialKey,
            orientation: decorations[index].orientation,
            drawStartCap: decorations[index].drawStartCap,
            drawEndCap: decorations[index].drawEndCap,
            startUnderlapFactor: startFactors[index],
            endUnderlapFactor: endFactors[index],
          ),
      ],
    );
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
