import 'package:flutter/material.dart';
import 'package:runner_core/terrain/water_region.dart';

import '../../shared/terrain_polygon_scene_painter.dart';

/// Whole-pixel water bounds and the current snap target above the material art.
class ChunkWaterOverlayPainter extends CustomPainter {
  const ChunkWaterOverlayPainter({
    required this.regions,
    required this.transform,
    required this.draft,
    required this.invalid,
    required this.snappedNeighbor,
  });

  final List<WaterRegionData> regions;
  final TerrainPolygonViewportTransform transform;
  final Rect? draft;
  final bool invalid;
  final Offset? snappedNeighbor;

  @override
  void paint(Canvas canvas, Size size) {
    Offset toCanvas(Offset point) => transform.origin + point * transform.zoom;
    void rectangle(Rect rect, Color color, {bool fill = false}) {
      final bounds = Rect.fromPoints(
        toCanvas(rect.topLeft),
        toCanvas(rect.bottomRight),
      );
      if (fill) {
        canvas.drawRect(bounds, Paint()..color = color.withValues(alpha: .18));
      }
      canvas.drawRect(
        bounds,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      for (final corner in [
        bounds.topLeft,
        bounds.topRight,
        bounds.bottomLeft,
        bounds.bottomRight,
      ]) {
        canvas.drawCircle(corner, 3, Paint()..color = color);
      }
    }

    for (final region in regions) {
      rectangle(
        Rect.fromLTWH(
          region.x.toDouble(),
          region.y.toDouble(),
          region.width.toDouble(),
          region.height.toDouble(),
        ),
        Colors.cyan,
      );
    }
    if (draft != null) {
      rectangle(
        draft!,
        invalid ? Colors.redAccent : Colors.cyanAccent,
        fill: true,
      );
    }
    if (snappedNeighbor != null) {
      canvas.drawCircle(
        toCanvas(snappedNeighbor!),
        7,
        Paint()
          ..color = Colors.amber
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant ChunkWaterOverlayPainter oldDelegate) =>
      oldDelegate.regions != regions ||
      oldDelegate.transform != transform ||
      oldDelegate.draft != draft ||
      oldDelegate.invalid != invalid ||
      oldDelegate.snappedNeighbor != snappedNeighbor;
}
