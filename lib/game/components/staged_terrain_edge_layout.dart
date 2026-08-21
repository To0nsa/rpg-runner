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
    required this.endJoinBackingDepth,
  });

  final TerrainEdge edge;
  final String materialKey;
  final TerrainMaterialEdgeOrientation orientation;
  final bool drawStartCap;
  final bool drawEndCap;

  /// Radius of the fill-backed generic join owned by this edge's end.
  final double? endJoinBackingDepth;
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
      final profile = _profileFor(material, orientation);
      if (profile == null) continue;
      final caps = capsFor(material, orientation);
      final startTreatment = _endpointTreatment(
        edge: edge,
        material: material,
        profile: profile,
        orientation: orientation,
        caps: caps,
        atStart: true,
        edgesById: edgesById,
      );
      final endTreatment = _endpointTreatment(
        edge: edge,
        material: material,
        profile: profile,
        orientation: orientation,
        caps: caps,
        atStart: false,
        edgesById: edgesById,
      );
      decorations.add(
        StagedTerrainEdgeDecoration(
          edge: edge,
          materialKey: materialKey,
          orientation: orientation,
          drawStartCap: startTreatment.drawCap,
          drawEndCap: endTreatment.drawCap,
          endJoinBackingDepth: endTreatment.fillBackingDepth,
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

typedef _EndpointTreatment = ({bool drawCap, double? fillBackingDepth});

_EndpointTreatment _endpointTreatment({
  required TerrainEdge edge,
  required TerrainMaterialSpec material,
  required TerrainMaterialEdgeProfileSpec profile,
  required TerrainMaterialEdgeOrientation orientation,
  required (TerrainMaterialCapSpec?, TerrainMaterialCapSpec?) caps,
  required bool atStart,
  required Map<TerrainEdgeId, TerrainEdge> edgesById,
}) {
  final cap = atStart ? caps.$1 : caps.$2;
  final join = atStart ? edge.startJoin : edge.endJoin;
  if (join == TerrainVertexJoin.exposed) {
    return (drawCap: cap != null, fillBackingDepth: null);
  }
  if (join == TerrainVertexJoin.smooth) {
    return (drawCap: false, fillBackingDepth: null);
  }

  final adjacentId = atStart ? edge.previousId : edge.nextId;
  final adjacent = adjacentId == null ? null : edgesById[adjacentId];
  if (adjacent == null) {
    throw StateError(
      'Connected terrain endpoint ${edge.id} has no adjacent edge.',
    );
  }
  if (adjacent.materialKey != edge.materialKey) {
    return (drawCap: cap != null, fillBackingDepth: null);
  }

  final adjacentOrientation = StagedTerrainEdgeLayout.orientationFor(adjacent);
  final adjacentProfile = _profileFor(material, adjacentOrientation);
  final adjacentCaps = _capsFor(material, adjacentOrientation);
  final incoming = atStart ? adjacent : edge;
  final outgoing = atStart ? edge : adjacent;
  final treatment = terrainMaterialConnectedCornerTreatment(
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
  final selectedCap = atStart
      ? TerrainMaterialConnectedCornerTreatment.outgoingStartCap
      : TerrainMaterialConnectedCornerTreatment.incomingEndCap;
  if (treatment == selectedCap) {
    return (drawCap: cap != null, fillBackingDepth: null);
  }
  if (treatment != TerrainMaterialConnectedCornerTreatment.fillBacking) {
    return (drawCap: false, fillBackingDepth: null);
  }
  final profileDepth = _profileDepth(profile, orientation);
  final adjacentDepth = adjacentProfile == null
      ? 0.0
      : _profileDepth(adjacentProfile, adjacentOrientation);
  return (
    drawCap: false,
    fillBackingDepth: profileDepth > adjacentDepth
        ? profileDepth
        : adjacentDepth,
  );
}

double _profileDepth(
  TerrainMaterialEdgeProfileSpec profile,
  TerrainMaterialEdgeOrientation orientation,
) => terrainMaterialEdgeTileHeight(
  orientation: orientation,
  sourceWidth: profile.base.region.width,
  sourceHeight: profile.base.region.height,
).toDouble();

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
