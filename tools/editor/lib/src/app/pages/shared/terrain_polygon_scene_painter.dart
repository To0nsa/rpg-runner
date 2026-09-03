import 'package:flutter/material.dart';

import '../../../terrain_authoring/terrain_polygon_interaction.dart';
import '../../../terrain_authoring/terrain_polygon_scene_projection.dart';
import '../../../terrain_authoring/terrain_source_models.dart';

/// Mirrors Core's one-way edge exposure rule for clockwise Y-down source
/// loops: only edges travelling toward positive X have an upward normal.
bool terrainSourceEdgeIsActiveOneWay(
  TerrainSourceVertexDef start,
  TerrainSourceVertexDef end,
) => end.xHalfPixels > start.xHalfPixels;

/// One-way mapping between exact source ticks and display-only canvas space.
///
/// [zoom] is canvas pixels per source pixel, so one half-pixel source tick is
/// `zoom / 2` canvas pixels. Inverse pointer coordinates remain fractional and
/// must pass through a [TerrainPolygonSnapPolicy] before entering source state.
@immutable
final class TerrainPolygonViewportTransform {
  factory TerrainPolygonViewportTransform({
    required Offset origin,
    required double zoom,
  }) {
    if (!origin.dx.isFinite || !origin.dy.isFinite) {
      throw ArgumentError.value(origin, 'origin', 'Origin must be finite.');
    }
    if (!zoom.isFinite || zoom <= 0) {
      throw ArgumentError.value(zoom, 'zoom', 'Zoom must be finite and > 0.');
    }
    return TerrainPolygonViewportTransform._(origin: origin, zoom: zoom);
  }

  const TerrainPolygonViewportTransform._({
    required this.origin,
    required this.zoom,
  });

  final Offset origin;
  final double zoom;

  double get canvasPixelsPerHalfPixel => zoom * 0.5;

  Offset sourceVertexToCanvas(TerrainSourceVertexDef vertex) => Offset(
    origin.dx + vertex.xHalfPixels * canvasPixelsPerHalfPixel,
    origin.dy + vertex.yHalfPixels * canvasPixelsPerHalfPixel,
  );

  TerrainPolygonScenePoint canvasToSource(Offset canvasPoint) {
    if (!canvasPoint.dx.isFinite || !canvasPoint.dy.isFinite) {
      throw ArgumentError.value(
        canvasPoint,
        'canvasPoint',
        'Canvas point must be finite.',
      );
    }
    return TerrainPolygonScenePoint(
      (canvasPoint.dx - origin.dx) / canvasPixelsPerHalfPixel,
      (canvasPoint.dy - origin.dy) / canvasPixelsPerHalfPixel,
    );
  }

  double canvasRadiusToSourceHalfPixels(double canvasRadius) {
    if (!canvasRadius.isFinite || canvasRadius < 0) {
      throw ArgumentError.value(
        canvasRadius,
        'canvasRadius',
        'Canvas radius must be finite and >= 0.',
      );
    }
    return canvasRadius / canvasPixelsPerHalfPixel;
  }

  @override
  bool operator ==(Object other) =>
      other is TerrainPolygonViewportTransform &&
      origin == other.origin &&
      zoom == other.zoom;

  @override
  int get hashCode => Object.hash(origin, zoom);
}

/// Semantic visual tokens for the shared polygon overlay.
@immutable
final class TerrainPolygonSceneStyle {
  const TerrainPolygonSceneStyle({
    this.solidFill = const Color(0x4422D3EE),
    this.solidStroke = const Color(0xFF4BB5CF),
    this.oneWayFill = const Color(0x44FFC857),
    this.oneWayStroke = const Color(0xFFE4A72C),
    this.renderOnlyFill = const Color(0x442F3440),
    this.renderOnlyStroke = const Color(0xFF8993A4),
    this.selectedStroke = const Color(0xFF7CE5FF),
    this.previewStroke = const Color(0xFFFF78D1),
    this.selectedEdgeStroke = const Color(0xFFFFD166),
    this.vertexFill = const Color(0xFFE8F4FF),
    this.selectedVertexFill = const Color(0xFFFFD97A),
    this.draftStroke = const Color(0xFF74E39A),
    this.activeOneWayStroke = const Color(0xFF5CF2A4),
    this.outlineWidth = 1.25,
    this.selectedOutlineWidth = 2,
    this.selectedEdgeWidth = 3,
    this.vertexRadius = 3,
    this.selectedVertexRadius = 5,
  });

  final Color solidFill;
  final Color solidStroke;
  final Color oneWayFill;
  final Color oneWayStroke;
  final Color renderOnlyFill;
  final Color renderOnlyStroke;
  final Color selectedStroke;
  final Color previewStroke;
  final Color selectedEdgeStroke;
  final Color vertexFill;
  final Color selectedVertexFill;
  final Color draftStroke;
  final Color activeOneWayStroke;
  final double outlineWidth;
  final double selectedOutlineWidth;
  final double selectedEdgeWidth;
  final double vertexRadius;
  final double selectedVertexRadius;

  @override
  bool operator ==(Object other) =>
      other is TerrainPolygonSceneStyle &&
      solidFill == other.solidFill &&
      solidStroke == other.solidStroke &&
      oneWayFill == other.oneWayFill &&
      oneWayStroke == other.oneWayStroke &&
      renderOnlyFill == other.renderOnlyFill &&
      renderOnlyStroke == other.renderOnlyStroke &&
      selectedStroke == other.selectedStroke &&
      previewStroke == other.previewStroke &&
      selectedEdgeStroke == other.selectedEdgeStroke &&
      vertexFill == other.vertexFill &&
      selectedVertexFill == other.selectedVertexFill &&
      draftStroke == other.draftStroke &&
      activeOneWayStroke == other.activeOneWayStroke &&
      outlineWidth == other.outlineWidth &&
      selectedOutlineWidth == other.selectedOutlineWidth &&
      selectedEdgeWidth == other.selectedEdgeWidth &&
      vertexRadius == other.vertexRadius &&
      selectedVertexRadius == other.selectedVertexRadius;

  @override
  int get hashCode => Object.hash(
    solidFill,
    solidStroke,
    oneWayFill,
    oneWayStroke,
    renderOnlyFill,
    renderOnlyStroke,
    selectedStroke,
    previewStroke,
    selectedEdgeStroke,
    vertexFill,
    selectedVertexFill,
    draftStroke,
    activeOneWayStroke,
    outlineWidth,
    selectedOutlineWidth,
    selectedEdgeWidth,
    vertexRadius,
    selectedVertexRadius,
  );
}

/// Shared painter for polygon fills, boundaries, vertices, and creation drafts.
///
/// It renders source loops only. Compiled collision-edge diagnostics remain a
/// separate overlay supplied by the future Core compiler preview adapter; this
/// painter never derives collision authority from its fill paths.
final class TerrainPolygonScenePainter extends CustomPainter {
  const TerrainPolygonScenePainter({
    required this.projection,
    required this.transform,
    this.style = const TerrainPolygonSceneStyle(),
    this.showActiveOneWayEdges = false,
  });

  final TerrainPolygonSceneProjection projection;
  final TerrainPolygonViewportTransform transform;
  final TerrainPolygonSceneStyle style;
  final bool showActiveOneWayEdges;

  @override
  void paint(Canvas canvas, Size size) {
    for (final sceneShape in projection.shapes) {
      _paintShape(canvas, sceneShape);
    }
    final draft = projection.draft;
    if (draft != null) _paintDraft(canvas, draft);
  }

  void _paintShape(Canvas canvas, TerrainPolygonSceneShape sceneShape) {
    final vertices = sceneShape.shape.vertices;
    if (vertices.isEmpty) return;
    final points = vertices
        .map(transform.sourceVertexToCanvas)
        .toList(growable: false);
    final path = _path(points, close: vertices.length >= 3);
    final mode = sceneShape.shape.collisionMode;
    if (vertices.length >= 3) {
      canvas.drawPath(
        path,
        Paint()
          ..color = switch (mode) {
            TerrainSourceCollisionMode.solid => style.solidFill,
            TerrainSourceCollisionMode.oneWay => style.oneWayFill,
            TerrainSourceCollisionMode.none => style.renderOnlyFill,
          }
          ..style = PaintingStyle.fill,
      );
    }
    final strokeColor = sceneShape.isGesturePreview
        ? style.previewStroke
        : sceneShape.isSelected
        ? style.selectedStroke
        : switch (mode) {
            TerrainSourceCollisionMode.solid => style.solidStroke,
            TerrainSourceCollisionMode.oneWay => style.oneWayStroke,
            TerrainSourceCollisionMode.none => style.renderOnlyStroke,
          };
    canvas.drawPath(
      path,
      Paint()
        ..color = strokeColor
        ..strokeWidth = sceneShape.isSelected
            ? style.selectedOutlineWidth
            : style.outlineWidth
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );

    if (showActiveOneWayEdges &&
        mode == TerrainSourceCollisionMode.oneWay &&
        points.length >= 2) {
      final activePaint = Paint()
        ..color = style.activeOneWayStroke
        ..strokeWidth = style.selectedEdgeWidth
        ..strokeCap = StrokeCap.round;
      for (var index = 0; index < vertices.length; index += 1) {
        final start = vertices[index];
        final end = vertices[(index + 1) % vertices.length];
        // For Core's clockwise Y-down loops, a positive horizontal direction
        // has an outward normal with negative Y and is physically one-way.
        if (terrainSourceEdgeIsActiveOneWay(start, end)) {
          canvas.drawLine(
            points[index],
            points[(index + 1) % points.length],
            activePaint,
          );
        }
      }
    }

    final selectedEdgeIndex = sceneShape.selectedEdgeIndex;
    if (selectedEdgeIndex != null &&
        selectedEdgeIndex >= 0 &&
        selectedEdgeIndex < points.length) {
      canvas.drawLine(
        points[selectedEdgeIndex],
        points[(selectedEdgeIndex + 1) % points.length],
        Paint()
          ..color = style.selectedEdgeStroke
          ..strokeWidth = style.selectedEdgeWidth
          ..strokeCap = StrokeCap.round,
      );
    }

    for (var index = 0; index < points.length; index++) {
      final selected = sceneShape.selectedVertexIndex == index;
      canvas.drawCircle(
        points[index],
        selected ? style.selectedVertexRadius : style.vertexRadius,
        Paint()
          ..color = selected ? style.selectedVertexFill : style.vertexFill
          ..style = PaintingStyle.fill,
      );
    }
  }

  void _paintDraft(Canvas canvas, TerrainPolygonSceneDraft draft) {
    if (draft.vertices.isEmpty) return;
    final points = draft.vertices
        .map(transform.sourceVertexToCanvas)
        .toList(growable: false);
    canvas.drawPath(
      _path(points, close: draft.isClosed),
      Paint()
        ..color = style.draftStroke
        ..strokeWidth = style.selectedOutlineWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );
    for (var index = 0; index < points.length; index++) {
      final selected = draft.selectedVertexIndex == index;
      canvas.drawCircle(
        points[index],
        selected ? style.selectedVertexRadius : style.vertexRadius,
        Paint()
          ..color = selected ? style.selectedVertexFill : style.draftStroke
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(covariant TerrainPolygonScenePainter oldDelegate) =>
      oldDelegate.projection != projection ||
      oldDelegate.transform != transform ||
      oldDelegate.style != style ||
      oldDelegate.showActiveOneWayEdges != showActiveOneWayEdges;
}

Path _path(List<Offset> points, {required bool close}) {
  final path = Path()..moveTo(points.first.dx, points.first.dy);
  for (final point in points.skip(1)) {
    path.lineTo(point.dx, point.dy);
  }
  if (close) path.close();
  return path;
}
