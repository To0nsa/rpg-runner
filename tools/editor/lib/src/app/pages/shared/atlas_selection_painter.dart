import 'package:flutter/material.dart';

import '../../../prefabs/models/models.dart';

/// Draws atlas selection highlight rectangles over zoomed atlas previews.
///
/// Input geometry is expressed in source image pixels; painter applies current
/// zoom to map into canvas coordinates. Existing slice bounds render first so
/// atlas authors can see occupied regions before drawing a new selection.
class AtlasSelectionPainter extends CustomPainter {
  const AtlasSelectionPainter({
    required this.zoom,
    required this.selectionRectInImagePixels,
    required this.existingSlices,
    required this.selectedSliceId,
  });

  final double zoom;
  final Rect? selectionRectInImagePixels;
  final List<AtlasSliceDef> existingSlices;
  final String? selectedSliceId;

  @override
  void paint(Canvas canvas, Size size) {
    _paintExistingSlices(canvas);
    _paintSelection(canvas);
  }

  void _paintExistingSlices(Canvas canvas) {
    final occupiedFill = Paint()
      ..color = const Color(0x1FECB365)
      ..style = PaintingStyle.fill;
    final occupiedStroke = Paint()
      ..color = const Color(0xFFE0A14A)
      ..strokeWidth = 1.25
      ..style = PaintingStyle.stroke;
    final selectedFill = Paint()
      ..color = const Color(0x3389F3B7)
      ..style = PaintingStyle.fill;
    final selectedStroke = Paint()
      ..color = const Color(0xFF89F3B7)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    for (final slice in existingSlices) {
      if (slice.width <= 0 || slice.height <= 0) {
        continue;
      }
      final scaledRect = Rect.fromLTWH(
        slice.x * zoom,
        slice.y * zoom,
        slice.width * zoom,
        slice.height * zoom,
      );
      final isSelected = selectedSliceId != null && selectedSliceId == slice.id;
      canvas.drawRect(scaledRect, isSelected ? selectedFill : occupiedFill);
      canvas.drawRect(scaledRect, isSelected ? selectedStroke : occupiedStroke);
    }
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
        oldDelegate.selectionRectInImagePixels != selectionRectInImagePixels ||
        oldDelegate.selectedSliceId != selectedSliceId ||
        oldDelegate.existingSlices != existingSlices;
  }
}
