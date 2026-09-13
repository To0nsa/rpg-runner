import 'package:flutter/material.dart';
import 'package:runner_core/terrain/water_region.dart';

import '../../shared/terrain_polygon_scene_painter.dart';
import 'chunk_water_drawing.dart';

/// Whole-pixel water bounds and the current snap target above the material art.
class ChunkWaterOverlayPainter extends CustomPainter {
  const ChunkWaterOverlayPainter({
    required this.regions,
    this.selectedId,
    this.resizingId,
    required this.transform,
    required this.draft,
    required this.invalid,
    required this.snappedNeighbor,
  });

  final List<WaterRegionData> regions;
  final String? selectedId;
  final String? resizingId;
  final TerrainPolygonViewportTransform transform;
  final Rect? draft;
  final bool invalid;
  final Offset? snappedNeighbor;

  @override
  void paint(Canvas canvas, Size size) {
    const style = TerrainPolygonSceneStyle();
    Offset toCanvas(Offset point) => transform.origin + point * transform.zoom;
    void rectangle(
      Rect rect,
      Color color, {
      bool fill = false,
      bool handles = false,
    }) {
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
      for (final corner in ChunkWaterCorner.values) {
        final point = corner.position(bounds);
        if (handles) {
          final handle = Rect.fromCenter(center: point, width: 10, height: 10);
          canvas.drawRect(handle, Paint()..color = style.vertexFill);
          canvas.drawRect(
            handle,
            Paint()
              ..color = color
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2,
          );
        } else {
          canvas.drawCircle(point, 3, Paint()..color = color);
        }
      }
    }

    for (final region in regions) {
      if (region.id == resizingId) continue;
      rectangle(
        waterRegionBounds(region),
        region.id == selectedId ? style.selectedStroke : style.solidStroke,
        fill: region.id == selectedId,
        handles: region.id == selectedId,
      );
    }
    if (draft != null) {
      rectangle(
        draft!,
        invalid ? Colors.redAccent : style.draftStroke,
        fill: true,
        handles: resizingId != null,
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
      oldDelegate.selectedId != selectedId ||
      oldDelegate.resizingId != resizingId ||
      oldDelegate.transform != transform ||
      oldDelegate.draft != draft ||
      oldDelegate.invalid != invalid ||
      oldDelegate.snappedNeighbor != snappedNeighbor;
}
