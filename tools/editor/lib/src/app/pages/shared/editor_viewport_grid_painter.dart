import 'package:flutter/material.dart';

class EditorViewportGridPainter extends CustomPainter {
  const EditorViewportGridPainter({required this.zoom});

  static const double _minSpacingToPaint = 1.0;
  static const double _axisStrokeWidth = 2.0;

  final double zoom;

  @override
  void paint(Canvas canvas, Size size) {
    _paintGridLayer(
      canvas,
      size,
      worldSpacingPx: 1,
      color: const Color(0x0D9FB4C7),
    );
    _paintGridLayer(
      canvas,
      size,
      worldSpacingPx: 16,
      color: const Color(0x1E9FB4C7),
    );
    _paintGridLayer(
      canvas,
      size,
      worldSpacingPx: 32,
      color: const Color(0x389FB4C7),
    );
    _paintAxes(canvas, size);
  }

  void _paintGridLayer(
    Canvas canvas,
    Size size, {
    required double worldSpacingPx,
    required Color color,
  }) {
    if (worldSpacingPx <= 0 || zoom <= 0) {
      return;
    }
    final spacingPx = worldSpacingPx * zoom;
    if (spacingPx < _minSpacingToPaint) {
      return;
    }
    final center = Offset(size.width * 0.5, size.height * 0.5);
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    void drawVertical(double x) {
      if (x < 0 || x > size.width) {
        return;
      }
      final alignedX = x.floorToDouble() + 0.5;
      canvas.drawLine(
        Offset(alignedX, 0),
        Offset(alignedX, size.height),
        paint,
      );
    }

    void drawHorizontal(double y) {
      if (y < 0 || y > size.height) {
        return;
      }
      final alignedY = y.floorToDouble() + 0.5;
      canvas.drawLine(Offset(0, alignedY), Offset(size.width, alignedY), paint);
    }

    drawVertical(center.dx);
    for (var x = center.dx + spacingPx; x <= size.width; x += spacingPx) {
      drawVertical(x);
    }
    for (var x = center.dx - spacingPx; x >= 0; x -= spacingPx) {
      drawVertical(x);
    }

    drawHorizontal(center.dy);
    for (var y = center.dy + spacingPx; y <= size.height; y += spacingPx) {
      drawHorizontal(y);
    }
    for (var y = center.dy - spacingPx; y >= 0; y -= spacingPx) {
      drawHorizontal(y);
    }
  }

  void _paintAxes(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.5);
    final paint = Paint()
      ..color = const Color(0xCC9FB4C7)
      ..strokeWidth = _axisStrokeWidth;

    final axisX = center.dx.floorToDouble() + 0.5;
    final axisY = center.dy.floorToDouble() + 0.5;
    canvas.drawLine(Offset(axisX, 0), Offset(axisX, size.height), paint);
    canvas.drawLine(Offset(0, axisY), Offset(size.width, axisY), paint);
  }

  @override
  bool shouldRepaint(covariant EditorViewportGridPainter oldDelegate) =>
      oldDelegate.zoom != zoom;
}
