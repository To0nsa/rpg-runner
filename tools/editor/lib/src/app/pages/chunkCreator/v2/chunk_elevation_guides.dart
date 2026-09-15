import 'package:flutter/material.dart';
import 'package:runner_core/levels/terrain_elevation.dart';

import '../../shared/terrain_polygon_scene_painter.dart';

/// Read-only guides drawn with the same world transform as authored terrain.
class ChunkElevationGuides extends CustomPainter {
  const ChunkElevationGuides({
    required this.presets,
    required this.transform,
    required this.chunkWidth,
    required this.color,
  });
  final TerrainElevationPresets presets;
  final TerrainPolygonViewportTransform transform;
  final int chunkWidth;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: .6)
      ..strokeWidth = 1;
    for (final elevation in TerrainElevation.values) {
      final y = transform.origin.dy + presets.yFor(elevation) * transform.zoom;
      canvas.drawLine(
        Offset(transform.origin.dx, y),
        Offset(transform.origin.dx + chunkWidth * transform.zoom, y),
        paint,
      );
      final text = TextPainter(
        text: TextSpan(
          text: '${elevation.name} · ${presets.yFor(elevation)}',
          style: TextStyle(color: color, fontSize: 11),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, Offset(transform.origin.dx + 4, y - text.height - 2));
    }
  }

  @override
  bool shouldRepaint(covariant ChunkElevationGuides oldDelegate) =>
      presets.groundTopY != oldDelegate.presets.groundTopY ||
      presets.stepPx != oldDelegate.presets.stepPx ||
      transform != oldDelegate.transform ||
      chunkWidth != oldDelegate.chunkWidth ||
      color != oldDelegate.color;
}
