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
      final caps = capsFor(material, orientation);
      decorations.add(
        StagedTerrainEdgeDecoration(
          edge: edge,
          materialKey: materialKey,
          orientation: orientation,
          drawStartCap: _drawCap(
            edge: edge,
            material: material,
            orientation: orientation,
            caps: caps,
            atStart: true,
            edgesById: edgesById,
          ),
          drawEndCap: _drawCap(
            edge: edge,
            material: material,
            orientation: orientation,
            caps: caps,
            atStart: false,
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

  /// Returns the normalized start/end cap pair for one edge role.
  static (TerrainMaterialCapSpec?, TerrainMaterialCapSpec?) capsFor(
    TerrainMaterialSpec material,
    TerrainMaterialEdgeOrientation orientation,
  ) => _capsFor(material, orientation);
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

bool _drawCap({
  required TerrainEdge edge,
  required TerrainMaterialSpec material,
  required TerrainMaterialEdgeOrientation orientation,
  required (TerrainMaterialCapSpec?, TerrainMaterialCapSpec?) caps,
  required bool atStart,
  required Map<TerrainEdgeId, TerrainEdge> edgesById,
}) {
  final cap = atStart ? caps.$1 : caps.$2;
  if (cap == null) return false;
  final join = atStart ? edge.startJoin : edge.endJoin;
  if (join == TerrainVertexJoin.exposed) return true;
  if (join == TerrainVertexJoin.smooth) return false;

  final adjacentId = atStart ? edge.previousId : edge.nextId;
  final adjacent = adjacentId == null ? null : edgesById[adjacentId];
  if (adjacent == null) {
    throw StateError(
      'Connected terrain endpoint ${edge.id} has no adjacent edge.',
    );
  }
  if (adjacent.materialKey != edge.materialKey) {
    return true;
  }

  final adjacentOrientation = StagedTerrainEdgeLayout.orientationFor(adjacent);
  final adjacentCaps = _capsFor(material, adjacentOrientation);
  final incoming = atStart ? adjacent : edge;
  final outgoing = atStart ? edge : adjacent;
  final owner = terrainMaterialConnectedCornerOwner(
    incomingInwardNormalX: -incoming.outwardNormal.x,
    incomingInwardNormalY: -incoming.outwardNormal.y,
    outgoingTangentX: outgoing.tangent.x,
    outgoingTangentY: outgoing.tangent.y,
    incomingOrientation: atStart ? adjacentOrientation : orientation,
    outgoingOrientation: atStart ? orientation : adjacentOrientation,
    incomingEndCapAvailable: atStart
        ? adjacentCaps.$2 != null
        : caps.$2 != null,
    outgoingStartCapAvailable: atStart
        ? caps.$1 != null
        : adjacentCaps.$1 != null,
  );
  return owner ==
      (atStart
          ? TerrainMaterialCornerOwner.outgoingStart
          : TerrainMaterialCornerOwner.incomingEnd);
}

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
