import 'package:flutter/material.dart';

/// Reusable grid painter for editor viewports.
///
/// Supports two modes:
/// - centered: infinite-looking grid around viewport center
/// - world: grid aligned to explicit world rect/origin coordinates
class EditorViewportGridPainter extends CustomPainter {
  static const Color minorGridColor = Color(0x0D9FB4C7);
  static const Color gridColor = Color(0x1E9FB4C7);
  static const Color majorGridColor = Color(0x389FB4C7);
  static const Color axisColor = Color(0xCC9FB4C7);

  const EditorViewportGridPainter({required this.zoom})
    : _mode = _GridPainterMode.centered,
      worldRect = null,
      worldOrigin = null,
      worldSpacingPx = null,
      majorWorldSpacingPx = null,
      worldGridColor = null,
      worldMajorGridColor = null,
      worldAxisColor = null,
      showWorldAxes = false;

  const EditorViewportGridPainter.world({
    required this.zoom,
    required this.worldRect,
    required this.worldOrigin,
    required this.worldSpacingPx,
    this.majorWorldSpacingPx,
    this.worldGridColor = gridColor,
    this.worldMajorGridColor = majorGridColor,
    this.worldAxisColor = axisColor,
    this.showWorldAxes = false,
  }) : _mode = _GridPainterMode.world;

  static const double _minSpacingToPaint = 1.0;
  static const double _axisStrokeWidth = 2.0;
  static const double _gridStrokeWidth = 1.0;

  final double zoom;
  final _GridPainterMode _mode;
  final Rect? worldRect;
  final Offset? worldOrigin;
  final double? worldSpacingPx;
  final double? majorWorldSpacingPx;
  final Color? worldGridColor;
  final Color? worldMajorGridColor;
  final Color? worldAxisColor;
  final bool showWorldAxes;

  @override
  void paint(Canvas canvas, Size size) {
    if (_mode == _GridPainterMode.world) {
      _paintWorldGrid(canvas, size);
      return;
    }
    _paintGridLayer(
      canvas,
      size,
      worldSpacingPx: 1,
      color: minorGridColor,
    );
    _paintGridLayer(
      canvas,
      size,
      worldSpacingPx: 16,
      color: gridColor,
    );
    _paintGridLayer(
      canvas,
      size,
      worldSpacingPx: 32,
      color: majorGridColor,
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
      ..strokeWidth = _gridStrokeWidth;

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
      ..color = axisColor
      ..strokeWidth = _axisStrokeWidth;

    final axisX = center.dx.floorToDouble() + 0.5;
    final axisY = center.dy.floorToDouble() + 0.5;
    canvas.drawLine(Offset(axisX, 0), Offset(axisX, size.height), paint);
    canvas.drawLine(Offset(0, axisY), Offset(size.width, axisY), paint);
  }

  void _paintWorldGrid(Canvas canvas, Size size) {
    final worldRect = this.worldRect;
    final worldOrigin = this.worldOrigin;
    final worldSpacingPx = this.worldSpacingPx;
    if (worldRect == null ||
        worldOrigin == null ||
        worldSpacingPx == null ||
        worldSpacingPx <= 0 ||
        zoom <= 0) {
      return;
    }

    _paintWorldLayer(
      canvas,
      size,
      worldRect: worldRect,
      worldOrigin: worldOrigin,
      spacingWorldPx: worldSpacingPx,
      color: worldGridColor ?? gridColor,
    );

    final majorSpacing = majorWorldSpacingPx;
    if (majorSpacing != null && majorSpacing > 0) {
      _paintWorldLayer(
        canvas,
        size,
        worldRect: worldRect,
        worldOrigin: worldOrigin,
        spacingWorldPx: majorSpacing,
        color: worldMajorGridColor ?? majorGridColor,
      );
    }

    // Axes are optional in world mode so pages can choose between a cleaner
    // preview and stronger spatial orientation cues.
    if (!showWorldAxes) {
      return;
    }
    final axisPaint = Paint()
      ..color = worldAxisColor ?? axisColor
      ..strokeWidth = _axisStrokeWidth;

    final axisCanvasX = _worldToCanvasX(
      worldX: 0,
      worldRect: worldRect,
      worldOrigin: worldOrigin,
    );
    if (axisCanvasX >= 0 && axisCanvasX <= size.width) {
      final alignedX = axisCanvasX.floorToDouble() + 0.5;
      canvas.drawLine(
        Offset(alignedX, 0),
        Offset(alignedX, size.height),
        axisPaint,
      );
    }

    final axisCanvasY = _worldToCanvasY(
      worldY: 0,
      worldRect: worldRect,
      worldOrigin: worldOrigin,
    );
    if (axisCanvasY >= 0 && axisCanvasY <= size.height) {
      final alignedY = axisCanvasY.floorToDouble() + 0.5;
      canvas.drawLine(
        Offset(0, alignedY),
        Offset(size.width, alignedY),
        axisPaint,
      );
    }
  }

  void _paintWorldLayer(
    Canvas canvas,
    Size size, {
    required Rect worldRect,
    required Offset worldOrigin,
    required double spacingWorldPx,
    required Color color,
  }) {
    if (spacingWorldPx <= 0) {
      return;
    }
    final spacingCanvasPx = spacingWorldPx * zoom;
    if (spacingCanvasPx < _minSpacingToPaint) {
      return;
    }

    final paint = Paint()
      ..color = color
      ..strokeWidth = _gridStrokeWidth;

    final startWorldX =
        (worldRect.left / spacingWorldPx).floor() * spacingWorldPx;
    final endWorldX =
        (worldRect.right / spacingWorldPx).ceil() * spacingWorldPx;
    for (
      var worldX = startWorldX;
      worldX <= endWorldX + 0.001;
      worldX += spacingWorldPx
    ) {
      final x = _worldToCanvasX(
        worldX: worldX,
        worldRect: worldRect,
        worldOrigin: worldOrigin,
      );
      if (x < 0 || x > size.width) {
        continue;
      }
      final alignedX = x.floorToDouble() + 0.5;
      canvas.drawLine(
        Offset(alignedX, 0),
        Offset(alignedX, size.height),
        paint,
      );
    }

    final startWorldY =
        (worldRect.top / spacingWorldPx).floor() * spacingWorldPx;
    final endWorldY =
        (worldRect.bottom / spacingWorldPx).ceil() * spacingWorldPx;
    for (
      var worldY = startWorldY;
      worldY <= endWorldY + 0.001;
      worldY += spacingWorldPx
    ) {
      final y = _worldToCanvasY(
        worldY: worldY,
        worldRect: worldRect,
        worldOrigin: worldOrigin,
      );
      if (y < 0 || y > size.height) {
        continue;
      }
      final alignedY = y.floorToDouble() + 0.5;
      canvas.drawLine(Offset(0, alignedY), Offset(size.width, alignedY), paint);
    }
  }

  double _worldToCanvasX({
    required double worldX,
    required Rect worldRect,
    required Offset worldOrigin,
  }) {
    return worldOrigin.dx + ((worldX - worldRect.left) * zoom);
  }

  double _worldToCanvasY({
    required double worldY,
    required Rect worldRect,
    required Offset worldOrigin,
  }) {
    return worldOrigin.dy + ((worldY - worldRect.top) * zoom);
  }

  @override
  bool shouldRepaint(covariant EditorViewportGridPainter oldDelegate) {
    return oldDelegate.zoom != zoom ||
        oldDelegate._mode != _mode ||
        oldDelegate.worldRect != worldRect ||
        oldDelegate.worldOrigin != worldOrigin ||
        oldDelegate.worldSpacingPx != worldSpacingPx ||
        oldDelegate.majorWorldSpacingPx != majorWorldSpacingPx ||
        oldDelegate.worldGridColor != worldGridColor ||
        oldDelegate.worldMajorGridColor != worldMajorGridColor ||
        oldDelegate.worldAxisColor != worldAxisColor ||
        oldDelegate.showWorldAxes != showWorldAxes;
  }
}

enum _GridPainterMode { centered, world }
