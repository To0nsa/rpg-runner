import 'package:flutter/material.dart';

import '../../../../chunks/chunk_v2_file_data.dart';
import '../../../../terrain_authoring/terrain_source_models.dart';
import '../../shared/editor_viewport_grid_painter.dart';
import '../../shared/terrain_polygon_scene_painter.dart';

/// Paints the selected Chunk's authored tile grid inside its exact bounds.
class ChunkTileGridPainter extends CustomPainter {
  const ChunkTileGridPainter({required this.chunk, required this.transform});

  final ChunkV2FileData chunk;
  final TerrainPolygonViewportTransform transform;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Rect.fromLTWH(
      transform.origin.dx,
      transform.origin.dy,
      chunk.width * transform.zoom,
      chunk.height * transform.zoom,
    );
    canvas.save();
    canvas.clipRect(bounds);
    EditorViewportGridPainter.world(
      zoom: transform.zoom,
      worldRect: Rect.fromLTWH(
        0,
        0,
        chunk.width.toDouble(),
        chunk.height.toDouble(),
      ),
      worldOrigin: transform.origin,
      worldSpacingPx: chunk.tileSize.toDouble(),
      majorWorldSpacingPx: chunk.tileSize * 4.0,
    ).paint(canvas, size);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ChunkTileGridPainter oldDelegate) =>
      oldDelegate.chunk.width != chunk.width ||
      oldDelegate.chunk.height != chunk.height ||
      oldDelegate.chunk.tileSize != chunk.tileSize ||
      oldDelegate.transform.origin != transform.origin ||
      oldDelegate.transform.zoom != transform.zoom;
}

/// Paints the exact authored Chunk bounds, optionally including scene fill.
class ChunkBoundsPainter extends CustomPainter {
  const ChunkBoundsPainter({
    required this.chunk,
    required this.transform,
    this.paintFill = true,
  });

  final ChunkV2FileData chunk;
  final TerrainPolygonViewportTransform transform;
  final bool paintFill;

  @override
  void paint(Canvas canvas, Size size) {
    final topLeft = transform.sourceVertexToCanvas(
      const TerrainSourceVertexDef(xHalfPixels: 0, yHalfPixels: 0),
    );
    final bottomRight = transform.sourceVertexToCanvas(
      TerrainSourceVertexDef(
        xHalfPixels: chunk.width * 2,
        yHalfPixels: chunk.height * 2,
      ),
    );
    final bounds = Rect.fromPoints(topLeft, bottomRight);
    if (paintFill) {
      canvas.drawRect(bounds, Paint()..color = const Color(0xFF16232D));
    }
    canvas.drawRect(
      bounds,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = const Color(0xFF7DD3FC),
    );
  }

  @override
  bool shouldRepaint(covariant ChunkBoundsPainter oldDelegate) =>
      !identical(chunk, oldDelegate.chunk) ||
      paintFill != oldDelegate.paintFill ||
      transform.origin != oldDelegate.transform.origin ||
      transform.zoom != oldDelegate.transform.zoom;
}
