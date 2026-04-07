import 'package:flutter/material.dart';

/// Draws atlas selection highlight rectangles over zoomed atlas previews.
///
/// Input rect is expressed in source image pixels; painter applies current zoom
/// to map into canvas coordinates.
class AtlasSelectionPainter extends CustomPainter {
  const AtlasSelectionPainter({
    required this.zoom,
    required this.selectionRectInImagePixels,
  });

  final double zoom;
  final Rect? selectionRectInImagePixels;

  @override
  void paint(Canvas canvas, Size size) {
    _paintSelection(canvas);
  }

  void _paintSelection(Canvas canvas) {
    final selection = selectionRectInImagePixels;
    if (selection == null || selection.width <= 0 || selection.height <= 0) {
      return;
    }
    final scaledRect = Rect.fromLTWH(
      selection.left * zoom,
      selection.top * zoom,
      selection.width * zoom,
      selection.height * zoom,
    );
    final fill = Paint()
      ..color = const Color(0x5546C3FF)
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = const Color(0xFF8AD8FF)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawRect(scaledRect, fill);
    canvas.drawRect(scaledRect, stroke);
  }

  @override
  bool shouldRepaint(covariant AtlasSelectionPainter oldDelegate) {
    return oldDelegate.zoom != zoom ||
        oldDelegate.selectionRectInImagePixels != selectionRectInImagePixels;
  }
}
