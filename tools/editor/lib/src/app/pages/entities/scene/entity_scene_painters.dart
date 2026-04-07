part of '../entities_editor_page.dart';

/// Paints one resolved reference sprite frame into scene space.
class _ReferenceFramePainter extends CustomPainter {
  const _ReferenceFramePainter({
    required this.image,
    required this.row,
    required this.frame,
    required this.destinationRect,
    required this.anchorX,
    required this.anchorY,
    required this.showReferencePoints,
    required this.frameWidth,
    required this.frameHeight,
    required this.gridColumns,
    this.drawMarkerLabels = true,
  });

  final ui.Image image;
  final int row;
  final int frame;
  final Rect destinationRect;
  final double anchorX;
  final double anchorY;
  final bool showReferencePoints;
  final double frameWidth;
  final double frameHeight;
  final int? gridColumns;
  final bool drawMarkerLabels;

  @override
  void paint(Canvas canvas, Size size) {
    final safeFrameWidth = math.max(1.0, frameWidth);
    final safeFrameHeight = math.max(1.0, frameHeight);

    final maxColumns = math.max(1, (image.width / safeFrameWidth).floor());
    final maxRows = math.max(1, (image.height / safeFrameHeight).floor());
    final requestedFrame = frame < 0 ? 0 : frame;
    final requestedRow = row < 0 ? 0 : row;

    final columns = gridColumns != null && gridColumns! > 0
        ? gridColumns!
        : maxColumns;
    final rowOffset = requestedFrame ~/ columns;
    final columnIndex = requestedFrame % columns;
    final sourceRow = (requestedRow + rowOffset).clamp(0, maxRows - 1);
    final sourceColumn = columnIndex.clamp(0, maxColumns - 1);
    final sourceRect = Rect.fromLTWH(
      sourceColumn * safeFrameWidth,
      sourceRow * safeFrameHeight,
      safeFrameWidth,
      safeFrameHeight,
    );
    if (destinationRect.width <= 0 || destinationRect.height <= 0) {
      return;
    }
    canvas.drawImageRect(
      image,
      sourceRect,
      destinationRect,
      Paint()
        // Use filtered minification in editor preview so zoomed-out frames keep
        // a stable visual centroid instead of "pixel-drop" apparent drift.
        ..filterQuality = FilterQuality.medium
        ..isAntiAlias = true,
    );
    final frameBorderPaint = Paint()
      ..color = const Color(0xCCFFFFFF)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawRect(destinationRect, frameBorderPaint);

    if (!showReferencePoints) {
      return;
    }

    final clampedAnchorX = anchorX.clamp(0.0, 1.0);
    final clampedAnchorY = anchorY.clamp(0.0, 1.0);
    final anchorPoint = Offset(
      destinationRect.left + destinationRect.width * clampedAnchorX,
      destinationRect.top + destinationRect.height * clampedAnchorY,
    );
    final frameCenter = destinationRect.center;

    final guidePaint = Paint()
      ..color = const Color(0xCCFFD85A)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(frameCenter, anchorPoint, guidePaint);

    final centerFill = Paint()..color = const Color(0xCC9AD9FF);
    final centerStroke = Paint()
      ..color = const Color(0xFF0B141C)
      ..strokeWidth = 1.1
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(frameCenter, 3.8, centerFill);
    canvas.drawCircle(frameCenter, 3.8, centerStroke);

    final anchorStroke = Paint()
      ..color = const Color(0xFFFFE07D)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    const arm = 5.0;
    canvas.drawLine(
      Offset(anchorPoint.dx - arm, anchorPoint.dy),
      Offset(anchorPoint.dx + arm, anchorPoint.dy),
      anchorStroke,
    );
    canvas.drawLine(
      Offset(anchorPoint.dx, anchorPoint.dy - arm),
      Offset(anchorPoint.dx, anchorPoint.dy + arm),
      anchorStroke,
    );
    canvas.drawCircle(anchorPoint, 4.8, anchorStroke);
    if (drawMarkerLabels) {
      _paintPointLabel(canvas, frameCenter, 'F', const Color(0xFF9AD9FF));
      _paintPointLabel(canvas, anchorPoint, 'A', const Color(0xFFFFE07D));
    }
  }

  void _paintPointLabel(
    Canvas canvas,
    Offset point,
    String label,
    Color color,
  ) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          shadows: const <Shadow>[
            Shadow(
              color: Color(0xFF0B141C),
              blurRadius: 2,
              offset: Offset(0, 0),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final labelOffset = point + const Offset(7, -14);
    textPainter.paint(canvas, labelOffset);
  }

  @override
  bool shouldRepaint(covariant _ReferenceFramePainter oldDelegate) {
    return oldDelegate.image != image ||
        oldDelegate.row != row ||
        oldDelegate.frame != frame ||
        oldDelegate.destinationRect != destinationRect ||
        oldDelegate.anchorX != anchorX ||
        oldDelegate.anchorY != anchorY ||
        oldDelegate.showReferencePoints != showReferencePoints ||
        oldDelegate.frameWidth != frameWidth ||
        oldDelegate.frameHeight != frameHeight ||
        oldDelegate.gridColumns != gridColumns ||
        oldDelegate.drawMarkerLabels != drawMarkerLabels;
  }
}

class _EntityBoundsPainter extends CustomPainter {
  /// Paints collider bounds and drag handles for the currently selected entry.
  const _EntityBoundsPainter({
    required this.entry,
    required this.scale,
    required this.handleRadius,
    required this.anchorHandleRadius,
    required this.anchorSelected,
    this.anchorHandleCenter,
    this.activeHandle,
  });

  final EntityEntry entry;
  final double scale;
  final double handleRadius;
  final double anchorHandleRadius;
  final bool anchorSelected;
  final Offset? anchorHandleCenter;
  final _SceneColliderHandle? activeHandle;

  @override
  void paint(Canvas canvas, Size size) {
    final handles = _ViewportGeometry.entityHandles(
      size: size,
      offsetX: entry.offsetX,
      offsetY: entry.offsetY,
      halfX: entry.halfX,
      halfY: entry.halfY,
      scale: scale,
    );
    final entityRect = _ViewportGeometry.entityRect(
      center: handles.center,
      halfX: entry.halfX,
      halfY: entry.halfY,
      scale: scale,
    );

    final fillPaint = Paint()..color = const Color(0x5522D3EE);
    canvas.drawRect(entityRect, fillPaint);

    final strokePaint = Paint()
      ..color = const Color(0xFF7CE5FF)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawRect(entityRect, strokePaint);

    _paintHandle(
      canvas,
      center: handles.center,
      selected: activeHandle == _SceneColliderHandle.center,
    );
    _paintHandle(
      canvas,
      center: handles.top,
      selected: activeHandle == _SceneColliderHandle.top,
    );
    _paintHandle(
      canvas,
      center: handles.right,
      selected: activeHandle == _SceneColliderHandle.right,
    );
    final anchorCenter = anchorHandleCenter;
    if (anchorCenter != null) {
      _paintAnchorHandle(
        canvas,
        center: anchorCenter,
        selected: anchorSelected,
      );
    }
  }

  void _paintHandle(
    Canvas canvas, {
    required Offset center,
    required bool selected,
  }) {
    final fillPaint = Paint()
      ..color = selected ? const Color(0xFFFFD97A) : const Color(0xFFE8F4FF);
    final strokePaint = Paint()
      ..color = selected ? const Color(0xFFE59E00) : const Color(0xFF0F1D28)
      ..strokeWidth = 1.3
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, handleRadius, fillPaint);
    canvas.drawCircle(center, handleRadius, strokePaint);
  }

  void _paintAnchorHandle(
    Canvas canvas, {
    required Offset center,
    required bool selected,
  }) {
    final fillPaint = Paint()
      ..color = selected ? const Color(0xFFFF7A7A) : const Color(0xFFFF3D3D);
    final strokePaint = Paint()
      ..color = const Color(0xFF2A0B0B)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, anchorHandleRadius, fillPaint);
    canvas.drawCircle(center, anchorHandleRadius, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _EntityBoundsPainter oldDelegate) {
    return oldDelegate.entry.halfX != entry.halfX ||
        oldDelegate.entry.halfY != entry.halfY ||
        oldDelegate.entry.offsetX != entry.offsetX ||
        oldDelegate.entry.offsetY != entry.offsetY ||
        oldDelegate.scale != scale ||
        oldDelegate.handleRadius != handleRadius ||
        oldDelegate.anchorHandleRadius != anchorHandleRadius ||
        oldDelegate.anchorSelected != anchorSelected ||
        oldDelegate.anchorHandleCenter != anchorHandleCenter ||
        oldDelegate.activeHandle != activeHandle;
  }
}

class _ViewportGeometry {
  /// Shared viewport/world geometry helpers for scene rendering and hit-testing.
  static Offset canvasCenter(Size size) =>
      Offset(size.width * 0.5, size.height * 0.5);

  static Offset entityCenter(
    Size size,
    double offsetX,
    double offsetY,
    double scale,
  ) {
    final canvasMid = canvasCenter(size);
    return Offset(
      canvasMid.dx + offsetX * scale,
      // Match runtime convention (Core + Flame): Y increases downward.
      canvasMid.dy + offsetY * scale,
    );
  }

  static Rect entityRect({
    required Offset center,
    required double halfX,
    required double halfY,
    required double scale,
  }) {
    final halfWidth = halfX * scale;
    final halfHeight = halfY * scale;
    return Rect.fromLTRB(
      center.dx - halfWidth,
      center.dy - halfHeight,
      center.dx + halfWidth,
      center.dy + halfHeight,
    );
  }

  static _ViewportEntityHandles entityHandles({
    required Size size,
    required double offsetX,
    required double offsetY,
    required double halfX,
    required double halfY,
    required double scale,
  }) {
    final center = entityCenter(size, offsetX, offsetY, scale);
    final rect = entityRect(
      center: center,
      halfX: halfX,
      halfY: halfY,
      scale: scale,
    );
    return _ViewportEntityHandles(
      center: center,
      top: Offset(rect.center.dx, rect.top),
      right: Offset(rect.right, rect.center.dy),
    );
  }
}
