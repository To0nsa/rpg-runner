import 'dart:math' as math;

import 'package:flutter/material.dart';

class AtlasSelectionPainter extends CustomPainter {
  const AtlasSelectionPainter({
    required this.zoom,
    required this.selectionRectInImagePixels,
  });

  final double zoom;
  final Rect? selectionRectInImagePixels;

  @override
  void paint(Canvas canvas, Size size) {
    _paintGrid(canvas, size);
    _paintSelection(canvas);
  }

  void _paintGrid(Canvas canvas, Size size) {
    final spacing = _gridSpacingForZoom(zoom);
    final lineColor = const Color(0x4D87A3B8);
    final axisColor = const Color(0x88C8DAE8);
    final paint = Paint()
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    for (var x = 0.0; x <= size.width; x += spacing) {
      final isAxis = x == 0.0;
      paint.color = isAxis ? axisColor : lineColor;
      final alignedX = x.floorToDouble() + 0.5;
      canvas.drawLine(Offset(alignedX, 0), Offset(alignedX, size.height), paint);
    }
    for (var y = 0.0; y <= size.height; y += spacing) {
      final isAxis = y == 0.0;
      paint.color = isAxis ? axisColor : lineColor;
      final alignedY = y.floorToDouble() + 0.5;
      canvas.drawLine(Offset(0, alignedY), Offset(size.width, alignedY), paint);
    }
  }

  double _gridSpacingForZoom(double currentZoom) {
    if (currentZoom >= 16) {
      return currentZoom;
    }
    if (currentZoom >= 8) {
      return currentZoom * 2;
    }
    if (currentZoom >= 4) {
      return currentZoom * 4;
    }
    return math.max(1.0, currentZoom * 8);
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
