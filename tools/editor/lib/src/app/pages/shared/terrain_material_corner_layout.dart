import 'dart:ui';

import 'package:terrain_materials/terrain_materials.dart';

import '../../../terrain_authoring/terrain_source_models.dart';

/// Corner decoration selected for one authored source edge.
typedef TerrainMaterialEdgeCornerLayout = ({
  bool startCap,
  bool endCap,
  double? endJoinBackingDepth,
});

/// Cap pair authored for one world-facing edge orientation.
typedef TerrainMaterialOrientationCaps = ({
  TerrainMaterialCap? start,
  TerrainMaterialCap? end,
});

/// Returns the caps available to an edge after role normalization.
TerrainMaterialOrientationCaps terrainMaterialCapsForOrientation(
  TerrainMaterialDefinition material,
  TerrainMaterialEdgeOrientation orientation,
) => switch (orientation) {
  TerrainMaterialEdgeOrientation.top => (
    start: material.topStartCap,
    end: material.topEndCap,
  ),
  TerrainMaterialEdgeOrientation.underside => (
    start: material.undersideStartCap,
    end: material.undersideEndCap,
  ),
  TerrainMaterialEdgeOrientation.leftWall ||
  TerrainMaterialEdgeOrientation.rightWall => (start: null, end: null),
};

/// Resolves one non-overlapping cap/backing plan for a source polygon loop.
///
/// Solid and render-only loops treat every neighboring edge pair as connected.
/// One-way loops treat only top-facing runs as active, so the ends of each run
/// retain endpoint caps. Exact cardinal corners use authored rectangle caps;
/// other convex turns receive local fill backing. Concave and straight turns
/// remain band-only.
List<TerrainMaterialEdgeCornerLayout> resolveTerrainMaterialEdgeCornerLayout({
  required TerrainSourceShapeDef shape,
  required TerrainMaterialDefinition material,
  required List<TerrainMaterialEdgeOrientation> edgeOrientations,
}) {
  final edgeCount = shape.vertices.length;
  if (edgeOrientations.length != edgeCount) {
    throw ArgumentError(
      'Terrain edge orientation count must match the source loop.',
    );
  }
  final starts = List<bool>.filled(edgeCount, false);
  final ends = List<bool>.filled(edgeCount, false);
  final endJoinBackingDepths = List<double?>.filled(edgeCount, null);
  final active = <bool>[
    for (final orientation in edgeOrientations)
      shape.collisionMode != TerrainSourceCollisionMode.oneWay ||
          orientation == TerrainMaterialEdgeOrientation.top,
  ];
  final clockwise = _signedArea(shape.vertices) >= 0;

  for (var outgoingIndex = 0; outgoingIndex < edgeCount; outgoingIndex += 1) {
    final incomingIndex = (outgoingIndex - 1 + edgeCount) % edgeCount;
    final incomingActive = active[incomingIndex];
    final outgoingActive = active[outgoingIndex];
    final incomingCaps = terrainMaterialCapsForOrientation(
      material,
      edgeOrientations[incomingIndex],
    );
    final outgoingCaps = terrainMaterialCapsForOrientation(
      material,
      edgeOrientations[outgoingIndex],
    );
    if (!incomingActive && !outgoingActive) continue;
    if (!incomingActive) {
      starts[outgoingIndex] = outgoingCaps.start != null;
      continue;
    }
    if (!outgoingActive) {
      ends[incomingIndex] = incomingCaps.end != null;
      continue;
    }

    final incomingStart = _vertexOffset(shape.vertices[incomingIndex]);
    final join = _vertexOffset(shape.vertices[outgoingIndex]);
    final outgoingEnd = _vertexOffset(
      shape.vertices[(outgoingIndex + 1) % edgeCount],
    );
    final incomingTangent = join - incomingStart;
    final outgoingTangent = outgoingEnd - join;
    if (incomingTangent.distanceSquared == 0 ||
        outgoingTangent.distanceSquared == 0) {
      continue;
    }
    final incomingInwardNormal = clockwise
        ? Offset(-incomingTangent.dy, incomingTangent.dx)
        : Offset(incomingTangent.dy, -incomingTangent.dx);
    final treatment = terrainMaterialConnectedCornerTreatment(
      incomingInwardNormalX: incomingInwardNormal.dx,
      incomingInwardNormalY: incomingInwardNormal.dy,
      outgoingTangentX: outgoingTangent.dx,
      outgoingTangentY: outgoingTangent.dy,
      incomingOrientation: edgeOrientations[incomingIndex],
      outgoingOrientation: edgeOrientations[outgoingIndex],
      incomingEndCapAvailable: incomingCaps.end != null,
      outgoingStartCapAvailable: outgoingCaps.start != null,
    );
    switch (treatment) {
      case TerrainMaterialConnectedCornerTreatment.incomingEndCap:
        ends[incomingIndex] = true;
      case TerrainMaterialConnectedCornerTreatment.outgoingStartCap:
        starts[outgoingIndex] = true;
      case TerrainMaterialConnectedCornerTreatment.fillBacking:
        endJoinBackingDepths[incomingIndex] = _joinBackingDepth(
          material,
          edgeOrientations[incomingIndex],
          edgeOrientations[outgoingIndex],
        );
      case TerrainMaterialConnectedCornerTreatment.none:
        break;
    }
  }
  return List<TerrainMaterialEdgeCornerLayout>.unmodifiable(
    <TerrainMaterialEdgeCornerLayout>[
      for (var index = 0; index < edgeCount; index += 1)
        (
          startCap: starts[index],
          endCap: ends[index],
          endJoinBackingDepth: endJoinBackingDepths[index],
        ),
    ],
  );
}

double _joinBackingDepth(
  TerrainMaterialDefinition material,
  TerrainMaterialEdgeOrientation incoming,
  TerrainMaterialEdgeOrientation outgoing,
) {
  final incomingDepth = _profileDepth(material, incoming);
  final outgoingDepth = _profileDepth(material, outgoing);
  return incomingDepth > outgoingDepth ? incomingDepth : outgoingDepth;
}

double _profileDepth(
  TerrainMaterialDefinition material,
  TerrainMaterialEdgeOrientation orientation,
) {
  final profile = switch (orientation) {
    TerrainMaterialEdgeOrientation.top => material.top,
    TerrainMaterialEdgeOrientation.leftWall => material.leftWall,
    TerrainMaterialEdgeOrientation.rightWall => material.rightWall,
    TerrainMaterialEdgeOrientation.underside => material.underside,
  };
  if (profile == null) return 0;
  return terrainMaterialEdgeTileHeight(
    orientation: orientation,
    sourceWidth: profile.base.region.width,
    sourceHeight: profile.base.region.height,
  ).toDouble();
}

Offset _vertexOffset(TerrainSourceVertexDef vertex) =>
    Offset(vertex.xHalfPixels * 0.5, vertex.yHalfPixels * 0.5);

double _signedArea(List<TerrainSourceVertexDef> vertices) {
  var area = 0.0;
  for (var index = 0; index < vertices.length; index += 1) {
    final left = vertices[index];
    final right = vertices[(index + 1) % vertices.length];
    area +=
        left.xHalfPixels * right.yHalfPixels -
        right.xHalfPixels * left.yHalfPixels;
  }
  return area;
}
