import 'package:flutter/material.dart';
import 'package:runner_core/collision/terrain/terrain_edge_id.dart';
import 'package:runner_core/collision/terrain/terrain_numeric.dart';
import 'package:runner_core/collision/terrain/terrain_polygon.dart';

import '../../../../chunks/chunk_v2_collision_expansion.dart';
import '../../shared/terrain_polygon_scene_painter.dart';

/// Read-only debug painter for Core-compiled exposed collision edges.
class ChunkCompiledEdgeOverlayPainter extends CustomPainter {
  const ChunkCompiledEdgeOverlayPainter({
    required this.expansion,
    required this.transform,
    this.selectedEdgeId,
  });

  final ChunkV2CollisionExpansion expansion;
  final TerrainPolygonViewportTransform transform;
  final TerrainEdgeId? selectedEdgeId;

  @override
  void paint(Canvas canvas, Size size) {
    for (final edge in expansion.geometry.edges) {
      final selected = edge.id == selectedEdgeId;
      final color = selected
          ? const Color(0xFFFFFFFF)
          : edge.collisionMode == TerrainCollisionMode.oneWay
          ? const Color(0xFFFFD166)
          : const Color(0xFFFF78D1);
      canvas.drawLine(
        _toCanvas(edge.start),
        _toCanvas(edge.end),
        Paint()
          ..strokeWidth = selected ? 4 : 2
          ..strokeCap = StrokeCap.round
          ..color = color.withValues(alpha: selected ? 1 : 0.88),
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
  bool shouldRepaint(covariant ChunkCompiledEdgeOverlayPainter oldDelegate) =>
      !identical(expansion, oldDelegate.expansion) ||
      selectedEdgeId != oldDelegate.selectedEdgeId ||
      transform.origin != oldDelegate.transform.origin ||
      transform.zoom != oldDelegate.transform.zoom;
}
