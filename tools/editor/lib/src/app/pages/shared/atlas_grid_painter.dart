import 'package:flutter/material.dart';

import '../../../atlas/atlas_grid.dart';

/// Paints complete auto-slice cells and leaves gutters/trailing pixels clear.
class AtlasGridPainter extends CustomPainter {
  const AtlasGridPainter({
    required this.zoom,
    required this.imageWidth,
    required this.imageHeight,
    required this.settings,
  });

  final double zoom;
  final int imageWidth;
  final int imageHeight;
  final AtlasGridSettings settings;

  @override
  void paint(Canvas canvas, Size size) {
    if (zoom <= 0) return;
    final columns = AtlasGridGeometry.completeColumnCount(
      settings: settings,
      imageWidth: imageWidth,
    );
    final rows = AtlasGridGeometry.completeRowCount(
      settings: settings,
      imageHeight: imageHeight,
    );
    final paint = Paint()
      ..color = const Color(0x999FB4C7)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    for (var row = 0; row < rows; row += 1) {
      for (var column = 0; column < columns; column += 1) {
        final rect = AtlasGridGeometry.rectForRange(
          settings: settings,
          first: AtlasGridCell(column: column, row: row),
          second: AtlasGridCell(column: column, row: row),
        );
        canvas.drawRect(
          Rect.fromLTWH(
            rect.x * zoom,
            rect.y * zoom,
            rect.width * zoom,
            rect.height * zoom,
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant AtlasGridPainter oldDelegate) =>
      oldDelegate.zoom != zoom ||
      oldDelegate.imageWidth != imageWidth ||
      oldDelegate.imageHeight != imageHeight ||
      oldDelegate.settings != settings;
}
