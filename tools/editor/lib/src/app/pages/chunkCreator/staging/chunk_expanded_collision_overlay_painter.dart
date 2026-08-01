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
  });

  final ChunkV2CollisionExpansion expansion;
  final TerrainPolygonViewportTransform transform;

  @override
  void paint(Canvas canvas, Size size) {
    for (final shape in expansion.expandedPrefabShapes) {
      if (shape.vertices.length < 3) continue;
      final path = Path()..moveToPoint(_toCanvas(shape.vertices.first));
      for (final point in shape.vertices.skip(1)) {
        path.lineToPoint(_toCanvas(point));
      }
      path.close();
      final color = shape.collisionMode == TerrainCollisionMode.oneWay
          ? const Color(0xFFFFD166)
          : const Color(0xFF67E8F9);
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
          ..strokeWidth = 1.5
          ..color = color.withValues(alpha: 0.9),
      );
    }
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
      transform.zoom != oldDelegate.transform.zoom;
}

extension on Path {
  void moveToPoint(Offset point) => moveTo(point.dx, point.dy);

  void lineToPoint(Offset point) => lineTo(point.dx, point.dy);
}
