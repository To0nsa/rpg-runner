import 'package:flutter/material.dart';
import 'package:runner_core/collision/terrain/terrain_numeric.dart';
import 'package:runner_core/collision/terrain/terrain_polygon.dart';

import '../../../../chunks/chunk_v2_collision_expansion.dart';
import '../../shared/terrain_polygon_scene_painter.dart';

/// Read-only painter for Core-expanded prefab collision in chunk physics space.
///
/// This projection deliberately has no hit-test or editing API. Prefab-owned
/// source remains editable only in the Prefab workflow.
class ChunkExpandedCollisionOverlayPainter extends CustomPainter {
  const ChunkExpandedCollisionOverlayPainter({
    required this.expansion,
    required this.transform,
    this.hiddenPlacementKey,
    this.previewCollisionLoops = const <List<TerrainPoint>>[],
    this.previewTouchesTerrain = false,
  });

  final ChunkV2CollisionExpansion expansion;
  final TerrainPolygonViewportTransform transform;
  final String? hiddenPlacementKey;
  final List<List<TerrainPoint>> previewCollisionLoops;
  final bool previewTouchesTerrain;

  @override
  void paint(Canvas canvas, Size size) {
    for (final shape in expansion.expandedPrefabShapes) {
      if (shape.placementKey == hiddenPlacementKey) continue;
      final color = shape.collisionMode == TerrainCollisionMode.oneWay
          ? const Color(0xFFFFD166)
          : const Color(0xFF67E8F9);
      _paintLoop(canvas, shape.vertices, color);
    }
    final previewColor = previewTouchesTerrain
        ? const Color(0xFF4ADE80)
        : const Color(0xFFF59E0B);
    for (final loop in previewCollisionLoops) {
      _paintLoop(canvas, loop, previewColor, strokeWidth: 2);
    }
  }

  void _paintLoop(
    Canvas canvas,
    List<TerrainPoint> vertices,
    Color color, {
    double strokeWidth = 1.5,
  }) {
    if (vertices.length < 3) return;
    final path = Path()..moveToPoint(_toCanvas(vertices.first));
    for (final point in vertices.skip(1)) {
      path.lineToPoint(_toCanvas(point));
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.fill
        ..color = color.withValues(alpha: 0.16),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = color.withValues(alpha: 0.9),
    );
  }

  Offset _toCanvas(TerrainPoint point) => Offset(
    transform.origin.dx +
        point.xTicks / terrainPhysicsTicksPerWorldUnit * transform.zoom,
    transform.origin.dy +
        point.yTicks / terrainPhysicsTicksPerWorldUnit * transform.zoom,
  );

  @override
  bool shouldRepaint(
    covariant ChunkExpandedCollisionOverlayPainter oldDelegate,
  ) =>
      !identical(expansion, oldDelegate.expansion) ||
      transform.origin != oldDelegate.transform.origin ||
      transform.zoom != oldDelegate.transform.zoom ||
      hiddenPlacementKey != oldDelegate.hiddenPlacementKey ||
      !identical(previewCollisionLoops, oldDelegate.previewCollisionLoops) ||
      previewTouchesTerrain != oldDelegate.previewTouchesTerrain;
}

extension on Path {
  void moveToPoint(Offset point) => moveTo(point.dx, point.dy);

  void lineToPoint(Offset point) => lineTo(point.dx, point.dy);
}
