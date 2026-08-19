import 'dart:ui';

import 'package:terrain_materials/terrain_materials.dart';

import '../../../terrain_authoring/terrain_source_models.dart';

/// Start/end cap decisions for one authored source edge.
typedef TerrainMaterialEdgeCornerCaps = ({bool start, bool end});

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

/// Resolves one non-overlapping cap/corner plan for a source polygon loop.
///
/// Solid and render-only loops treat every neighboring edge pair as connected.
/// One-way loops treat only top-facing runs as active, so the ends of each run
/// retain endpoint caps. Convex connected turns delegate to the shared material
/// resolver; concave and straight turns remain band-only.
List<TerrainMaterialEdgeCornerCaps> resolveTerrainMaterialEdgeCornerCaps({
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
    final owner = terrainMaterialConnectedCornerOwner(
      incomingInwardNormalX: incomingInwardNormal.dx,
      incomingInwardNormalY: incomingInwardNormal.dy,
      outgoingTangentX: outgoingTangent.dx,
      outgoingTangentY: outgoingTangent.dy,
      incomingOrientation: edgeOrientations[incomingIndex],
      outgoingOrientation: edgeOrientations[outgoingIndex],
      incomingEndCapAvailable: incomingCaps.end != null,
      outgoingStartCapAvailable: outgoingCaps.start != null,
    );
    switch (owner) {
      case TerrainMaterialCornerOwner.incomingEnd:
        ends[incomingIndex] = true;
      case TerrainMaterialCornerOwner.outgoingStart:
        starts[outgoingIndex] = true;
      case null:
        break;
    }
  }
  return List<TerrainMaterialEdgeCornerCaps>.unmodifiable(
    <TerrainMaterialEdgeCornerCaps>[
      for (var index = 0; index < edgeCount; index += 1)
        (start: starts[index], end: ends[index]),
    ],
  );
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
