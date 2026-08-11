import 'dart:math' as math;

import 'terrain_polygon_interaction.dart';
import 'terrain_source_models.dart';

/// Render-facing view of one committed or gesture-preview polygon.
///
/// Coordinates remain exact half-pixel source ticks. Widget painters apply
/// viewport transforms later and never feed transformed doubles back into the
/// source model.
final class TerrainPolygonSceneShape {
  const TerrainPolygonSceneShape({
    required this.shape,
    required this.isGesturePreview,
    required this.isSelected,
    required this.selectedEdgeIndex,
    required this.selectedVertexIndex,
  });

  final TerrainSourceShapeDef shape;
  final bool isGesturePreview;
  final bool isSelected;
  final int? selectedEdgeIndex;
  final int? selectedVertexIndex;

  @override
  bool operator ==(Object other) =>
      other is TerrainPolygonSceneShape &&
      shape == other.shape &&
      isGesturePreview == other.isGesturePreview &&
      isSelected == other.isSelected &&
      selectedEdgeIndex == other.selectedEdgeIndex &&
      selectedVertexIndex == other.selectedVertexIndex;

  @override
  int get hashCode => Object.hash(
    shape,
    isGesturePreview,
    isSelected,
    selectedEdgeIndex,
    selectedVertexIndex,
  );
}

/// Render-facing view of an open creation draft.
final class TerrainPolygonSceneDraft {
  const TerrainPolygonSceneDraft({
    required this.shapeId,
    required this.vertices,
    required this.collisionMode,
    required this.surfaceKind,
    required this.materialKey,
    required this.isGesturePreview,
    required this.selectedVertexIndex,
  });

  final String shapeId;
  final List<TerrainSourceVertexDef> vertices;
  final TerrainSourceCollisionMode collisionMode;
  final String? surfaceKind;
  final String? materialKey;
  final bool isGesturePreview;
  final int? selectedVertexIndex;

  @override
  bool operator ==(Object other) =>
      other is TerrainPolygonSceneDraft &&
      shapeId == other.shapeId &&
      _listEquals(vertices, other.vertices) &&
      collisionMode == other.collisionMode &&
      surfaceKind == other.surfaceKind &&
      materialKey == other.materialKey &&
      isGesturePreview == other.isGesturePreview &&
      selectedVertexIndex == other.selectedVertexIndex;

  @override
  int get hashCode => Object.hash(
    shapeId,
    Object.hashAll(vertices),
    collisionMode,
    surfaceKind,
    materialKey,
    isGesturePreview,
    selectedVertexIndex,
  );
}

/// Deterministic scene projection shared by prefab and chunk painters.
final class TerrainPolygonSceneProjection {
  TerrainPolygonSceneProjection._({
    required Iterable<TerrainPolygonSceneShape> shapes,
    required this.draft,
  }) : shapes = List<TerrainPolygonSceneShape>.unmodifiable(shapes);

  factory TerrainPolygonSceneProjection.fromInteraction(
    TerrainPolygonInteractionState state,
  ) {
    final selection = state.selection;
    final gestureShapeId = state.gesture?.originalShape.shapeId;
    final shapes = <TerrainPolygonSceneShape>[
      for (final shape in state.visibleShapes)
        TerrainPolygonSceneShape(
          shape: shape,
          isGesturePreview: shape.shapeId == gestureShapeId,
          isSelected: selection?.shapeId == shape.shapeId,
          selectedEdgeIndex:
              selection?.shapeId == shape.shapeId &&
                  selection?.kind == TerrainPolygonSelectionKind.edge
              ? selection!.elementIndex
              : null,
          selectedVertexIndex:
              selection?.shapeId == shape.shapeId &&
                  selection?.kind == TerrainPolygonSelectionKind.vertex
              ? selection!.elementIndex
              : null,
        ),
    ];
    final sourceDraft = state.draft;
    final draftGesture =
        sourceDraft != null &&
            state.gesture?.originalShape.shapeId == sourceDraft.shapeId
        ? state.gesture
        : null;
    return TerrainPolygonSceneProjection._(
      shapes: shapes,
      draft: sourceDraft == null
          ? null
          : TerrainPolygonSceneDraft(
              shapeId: sourceDraft.shapeId,
              vertices:
                  draftGesture?.previewShape.vertices ?? sourceDraft.vertices,
              collisionMode: sourceDraft.collisionMode,
              surfaceKind: sourceDraft.surfaceKind,
              materialKey: sourceDraft.materialKey,
              isGesturePreview: draftGesture != null,
              selectedVertexIndex: draftGesture?.activeVertexIndex,
            ),
    );
  }

  final List<TerrainPolygonSceneShape> shapes;
  final TerrainPolygonSceneDraft? draft;

  @override
  bool operator ==(Object other) =>
      other is TerrainPolygonSceneProjection &&
      _listEquals(shapes, other.shapes) &&
      draft == other.draft;

  @override
  int get hashCode => Object.hash(Object.hashAll(shapes), draft);
}

/// UI-only source-space point used by deterministic polygon hit testing.
///
/// Fractional values are allowed because an inverse viewport transform may
/// land between authored ticks. Semantic edits still snap back to exact integer
/// half-pixel coordinates through [TerrainPolygonSnapPolicy].
final class TerrainPolygonScenePoint {
  const TerrainPolygonScenePoint(this.xHalfPixels, this.yHalfPixels);

  final double xHalfPixels;
  final double yHalfPixels;

  @override
  bool operator ==(Object other) =>
      other is TerrainPolygonScenePoint &&
      xHalfPixels == other.xHalfPixels &&
      yHalfPixels == other.yHalfPixels;

  @override
  int get hashCode => Object.hash(xHalfPixels, yHalfPixels);
}

/// Shared source-space hit testing for polygon vertices, edges, and fills.
///
/// Priority is vertex, then edge, then fill. Within a priority, the closest
/// feature wins; equal distances prefer the selected shape, then the visually
/// topmost canonical shape, then the lowest local element index.
abstract final class TerrainPolygonSceneHitTest {
  static TerrainPolygonSelection? hitTest({
    required TerrainPolygonSceneProjection projection,
    required TerrainPolygonScenePoint point,
    required double vertexRadiusHalfPixels,
    required double edgeRadiusHalfPixels,
    bool includeShapeFill = true,
  }) {
    _requireFinitePoint(point);
    _requireRadius(vertexRadiusHalfPixels, 'vertexRadiusHalfPixels');
    _requireRadius(edgeRadiusHalfPixels, 'edgeRadiusHalfPixels');
    final rankedShapes = _rankedShapes(projection.shapes);

    final vertex = _nearestVertex(rankedShapes, point, vertexRadiusHalfPixels);
    if (vertex != null) {
      return TerrainPolygonSelection.vertex(
        vertex.shapeId,
        vertex.elementIndex,
      );
    }

    final edge = _nearestEdge(rankedShapes, point, edgeRadiusHalfPixels);
    if (edge != null) {
      return TerrainPolygonSelection.edge(edge.shapeId, edge.elementIndex);
    }

    if (!includeShapeFill) return null;
    for (final ranked in rankedShapes) {
      if (_containsPoint(ranked.sceneShape.shape.vertices, point)) {
        return TerrainPolygonSelection.shape(ranked.sceneShape.shape.shapeId);
      }
    }
    return null;
  }

  static int? hitTestDraftVertex({
    required TerrainPolygonSceneProjection projection,
    required TerrainPolygonScenePoint point,
    required double radiusHalfPixels,
  }) {
    _requireFinitePoint(point);
    _requireRadius(radiusHalfPixels, 'radiusHalfPixels');
    final vertices = projection.draft?.vertices;
    if (vertices == null) return null;
    final maximumDistanceSquared = radiusHalfPixels * radiusHalfPixels;
    int? bestIndex;
    var bestDistanceSquared = double.infinity;
    for (var index = 0; index < vertices.length; index++) {
      final vertex = vertices[index];
      final distanceSquared = _distanceSquared(
        point.xHalfPixels,
        point.yHalfPixels,
        vertex.xHalfPixels.toDouble(),
        vertex.yHalfPixels.toDouble(),
      );
      if (distanceSquared > maximumDistanceSquared ||
          distanceSquared >= bestDistanceSquared) {
        continue;
      }
      bestIndex = index;
      bestDistanceSquared = distanceSquared;
    }
    return bestIndex;
  }

  static int? hitTestDraftEdge({
    required TerrainPolygonSceneProjection projection,
    required TerrainPolygonScenePoint point,
    required double radiusHalfPixels,
  }) {
    _requireFinitePoint(point);
    _requireRadius(radiusHalfPixels, 'radiusHalfPixels');
    final vertices = projection.draft?.vertices;
    if (vertices == null || vertices.length < 2) return null;
    final maximumDistanceSquared = radiusHalfPixels * radiusHalfPixels;
    int? bestIndex;
    var bestDistanceSquared = double.infinity;
    for (var index = 0; index < vertices.length - 1; index++) {
      final distanceSquared = _distanceToSegmentSquared(
        point,
        vertices[index],
        vertices[index + 1],
      );
      if (distanceSquared > maximumDistanceSquared ||
          distanceSquared >= bestDistanceSquared) {
        continue;
      }
      bestIndex = index;
      bestDistanceSquared = distanceSquared;
    }
    return bestIndex;
  }
}

List<_RankedSceneShape> _rankedShapes(List<TerrainPolygonSceneShape> shapes) {
  final selected = <TerrainPolygonSceneShape>[];
  final remaining = <TerrainPolygonSceneShape>[];
  for (final shape in shapes.reversed) {
    (shape.isSelected ? selected : remaining).add(shape);
  }
  final ordered = <TerrainPolygonSceneShape>[...selected, ...remaining];
  return <_RankedSceneShape>[
    for (var rank = 0; rank < ordered.length; rank++)
      _RankedSceneShape(sceneShape: ordered[rank], rank: rank),
  ];
}

_FeatureCandidate? _nearestVertex(
  List<_RankedSceneShape> shapes,
  TerrainPolygonScenePoint point,
  double radius,
) {
  final maximumDistanceSquared = radius * radius;
  _FeatureCandidate? best;
  for (final ranked in shapes) {
    final vertices = ranked.sceneShape.shape.vertices;
    for (var index = 0; index < vertices.length; index++) {
      final vertex = vertices[index];
      final distanceSquared = _distanceSquared(
        point.xHalfPixels,
        point.yHalfPixels,
        vertex.xHalfPixels.toDouble(),
        vertex.yHalfPixels.toDouble(),
      );
      if (distanceSquared > maximumDistanceSquared) continue;
      final candidate = _FeatureCandidate(
        shapeId: ranked.sceneShape.shape.shapeId,
        elementIndex: index,
        distanceSquared: distanceSquared,
        shapeRank: ranked.rank,
      );
      if (best == null || candidate.compareTo(best) < 0) best = candidate;
    }
  }
  return best;
}

_FeatureCandidate? _nearestEdge(
  List<_RankedSceneShape> shapes,
  TerrainPolygonScenePoint point,
  double radius,
) {
  final maximumDistanceSquared = radius * radius;
  _FeatureCandidate? best;
  for (final ranked in shapes) {
    final vertices = ranked.sceneShape.shape.vertices;
    for (var index = 0; index < vertices.length; index++) {
      final start = vertices[index];
      final end = vertices[(index + 1) % vertices.length];
      final distanceSquared = _distanceToSegmentSquared(point, start, end);
      if (distanceSquared > maximumDistanceSquared) continue;
      final candidate = _FeatureCandidate(
        shapeId: ranked.sceneShape.shape.shapeId,
        elementIndex: index,
        distanceSquared: distanceSquared,
        shapeRank: ranked.rank,
      );
      if (best == null || candidate.compareTo(best) < 0) best = candidate;
    }
  }
  return best;
}

double _distanceToSegmentSquared(
  TerrainPolygonScenePoint point,
  TerrainSourceVertexDef start,
  TerrainSourceVertexDef end,
) {
  final startX = start.xHalfPixels.toDouble();
  final startY = start.yHalfPixels.toDouble();
  final dx = end.xHalfPixels - start.xHalfPixels;
  final dy = end.yHalfPixels - start.yHalfPixels;
  final lengthSquared = (dx * dx + dy * dy).toDouble();
  if (lengthSquared == 0) {
    return _distanceSquared(
      point.xHalfPixels,
      point.yHalfPixels,
      startX,
      startY,
    );
  }
  final projection =
      ((point.xHalfPixels - startX) * dx + (point.yHalfPixels - startY) * dy) /
      lengthSquared;
  final clamped = projection.clamp(0.0, 1.0);
  return _distanceSquared(
    point.xHalfPixels,
    point.yHalfPixels,
    startX + clamped * dx,
    startY + clamped * dy,
  );
}

bool _containsPoint(
  List<TerrainSourceVertexDef> vertices,
  TerrainPolygonScenePoint point,
) {
  if (vertices.length < 3) return false;
  var inside = false;
  for (var index = 0; index < vertices.length; index++) {
    final start = vertices[index];
    final end = vertices[(index + 1) % vertices.length];
    if (_pointOnSegment(point, start, end)) return true;
    final startY = start.yHalfPixels.toDouble();
    final endY = end.yHalfPixels.toDouble();
    if ((startY > point.yHalfPixels) == (endY > point.yHalfPixels)) continue;
    final intersectionX =
        start.xHalfPixels +
        (point.yHalfPixels - startY) *
            (end.xHalfPixels - start.xHalfPixels) /
            (endY - startY);
    if (point.xHalfPixels < intersectionX) inside = !inside;
  }
  return inside;
}

bool _pointOnSegment(
  TerrainPolygonScenePoint point,
  TerrainSourceVertexDef start,
  TerrainSourceVertexDef end,
) {
  final dx = end.xHalfPixels - start.xHalfPixels;
  final dy = end.yHalfPixels - start.yHalfPixels;
  final cross =
      (point.xHalfPixels - start.xHalfPixels) * dy -
      (point.yHalfPixels - start.yHalfPixels) * dx;
  if (cross.abs() > 1e-9) return false;
  return point.xHalfPixels >= math.min(start.xHalfPixels, end.xHalfPixels) &&
      point.xHalfPixels <= math.max(start.xHalfPixels, end.xHalfPixels) &&
      point.yHalfPixels >= math.min(start.yHalfPixels, end.yHalfPixels) &&
      point.yHalfPixels <= math.max(start.yHalfPixels, end.yHalfPixels);
}

double _distanceSquared(
  double leftX,
  double leftY,
  double rightX,
  double rightY,
) {
  final dx = leftX - rightX;
  final dy = leftY - rightY;
  return dx * dx + dy * dy;
}

void _requireFinitePoint(TerrainPolygonScenePoint point) {
  if (!point.xHalfPixels.isFinite || !point.yHalfPixels.isFinite) {
    throw ArgumentError.value(point, 'point', 'Point must be finite.');
  }
}

void _requireRadius(double radius, String name) {
  if (!radius.isFinite || radius < 0) {
    throw ArgumentError.value(radius, name, 'Radius must be finite and >= 0.');
  }
}

bool _listEquals<T>(List<T> left, List<T> right) {
  if (identical(left, right)) return true;
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

final class _RankedSceneShape {
  const _RankedSceneShape({required this.sceneShape, required this.rank});

  final TerrainPolygonSceneShape sceneShape;
  final int rank;
}

final class _FeatureCandidate implements Comparable<_FeatureCandidate> {
  const _FeatureCandidate({
    required this.shapeId,
    required this.elementIndex,
    required this.distanceSquared,
    required this.shapeRank,
  });

  final String shapeId;
  final int elementIndex;
  final double distanceSquared;
  final int shapeRank;

  @override
  int compareTo(_FeatureCandidate other) {
    var order = distanceSquared.compareTo(other.distanceSquared);
    if (order != 0) return order;
    order = shapeRank.compareTo(other.shapeRank);
    if (order != 0) return order;
    order = elementIndex.compareTo(other.elementIndex);
    if (order != 0) return order;
    return shapeId.compareTo(other.shapeId);
  }
}
