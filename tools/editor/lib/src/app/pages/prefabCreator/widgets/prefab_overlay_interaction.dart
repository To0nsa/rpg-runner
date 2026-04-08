import 'package:flutter/material.dart';

import 'prefab_scene_values.dart';

enum PrefabOverlayHandleType {
  anchor,
  colliderCenter,
  colliderTop,
  colliderRight,
}

class PrefabOverlayDragState {
  const PrefabOverlayDragState({
    required this.pointer,
    required this.handle,
    required this.startLocal,
    required this.startValues,
    required this.zoom,
    required this.boundsWidthPx,
    required this.boundsHeightPx,
  });

  final int pointer;
  final PrefabOverlayHandleType handle;
  final Offset startLocal;
  final PrefabSceneValues startValues;
  final double zoom;
  final int boundsWidthPx;
  final int boundsHeightPx;
}

class PrefabOverlayHandleGeometry {
  const PrefabOverlayHandleGeometry({
    required this.anchorHandleCenter,
    required this.colliderRect,
    required this.colliderCenterHandle,
    required this.colliderTopHandle,
    required this.colliderRightHandle,
  });

  factory PrefabOverlayHandleGeometry.fromValues({
    required PrefabSceneValues values,
    required Offset anchorCanvasBase,
    required double zoom,
  }) {
    final anchorHandleCenter = Offset(
      anchorCanvasBase.dx + (values.anchorX * zoom),
      anchorCanvasBase.dy + (values.anchorY * zoom),
    );
    final colliderCenter = Offset(
      anchorHandleCenter.dx + (values.colliderOffsetX * zoom),
      anchorHandleCenter.dy + (values.colliderOffsetY * zoom),
    );
    final halfW = values.colliderWidth * 0.5 * zoom;
    final halfH = values.colliderHeight * 0.5 * zoom;
    final colliderRect = Rect.fromLTRB(
      colliderCenter.dx - halfW,
      colliderCenter.dy - halfH,
      colliderCenter.dx + halfW,
      colliderCenter.dy + halfH,
    );
    return PrefabOverlayHandleGeometry(
      anchorHandleCenter: anchorHandleCenter,
      colliderRect: colliderRect,
      colliderCenterHandle: colliderCenter,
      colliderTopHandle: Offset(colliderRect.center.dx, colliderRect.top),
      colliderRightHandle: Offset(colliderRect.right, colliderRect.center.dy),
    );
  }

  final Offset anchorHandleCenter;
  final Rect colliderRect;
  final Offset colliderCenterHandle;
  final Offset colliderTopHandle;
  final Offset colliderRightHandle;
}

final class PrefabOverlayHitTest {
  PrefabOverlayHitTest._();

  static PrefabOverlayHandleType? hitTestHandle({
    required Offset point,
    required PrefabOverlayHandleGeometry geometry,
    required double anchorHandleHitRadius,
    required double colliderHandleHitRadius,
  }) {
    if (_distanceSquared(point, geometry.anchorHandleCenter) <=
        anchorHandleHitRadius * anchorHandleHitRadius) {
      return PrefabOverlayHandleType.anchor;
    }
    if (_distanceSquared(point, geometry.colliderCenterHandle) <=
        colliderHandleHitRadius * colliderHandleHitRadius) {
      return PrefabOverlayHandleType.colliderCenter;
    }
    if (_distanceSquared(point, geometry.colliderTopHandle) <=
        colliderHandleHitRadius * colliderHandleHitRadius) {
      return PrefabOverlayHandleType.colliderTop;
    }
    if (_distanceSquared(point, geometry.colliderRightHandle) <=
        colliderHandleHitRadius * colliderHandleHitRadius) {
      return PrefabOverlayHandleType.colliderRight;
    }
    return null;
  }

  static double _distanceSquared(Offset a, Offset b) {
    final dx = a.dx - b.dx;
    final dy = a.dy - b.dy;
    return dx * dx + dy * dy;
  }
}

final class PrefabOverlayInteraction {
  PrefabOverlayInteraction._();

  static PrefabSceneValues valuesFromDrag({
    required PrefabOverlayDragState drag,
    required Offset currentLocal,
  }) {
    final delta = currentLocal - drag.startLocal;
    final deltaX = delta.dx / drag.zoom;
    final deltaY = delta.dy / drag.zoom;
    final start = drag.startValues;

    switch (drag.handle) {
      case PrefabOverlayHandleType.anchor:
        final anchorX = (start.anchorX + deltaX).round().clamp(
          0,
          drag.boundsWidthPx,
        );
        final anchorY = (start.anchorY + deltaY).round().clamp(
          0,
          drag.boundsHeightPx,
        );
        return PrefabSceneValues(
          anchorX: anchorX,
          anchorY: anchorY,
          colliderOffsetX: start.colliderOffsetX,
          colliderOffsetY: start.colliderOffsetY,
          colliderWidth: start.colliderWidth,
          colliderHeight: start.colliderHeight,
        );
      case PrefabOverlayHandleType.colliderCenter:
        return PrefabSceneValues(
          anchorX: start.anchorX,
          anchorY: start.anchorY,
          colliderOffsetX: (start.colliderOffsetX + deltaX).round(),
          colliderOffsetY: (start.colliderOffsetY + deltaY).round(),
          colliderWidth: start.colliderWidth,
          colliderHeight: start.colliderHeight,
        );
      case PrefabOverlayHandleType.colliderTop:
        final startCenterY = start.anchorY + start.colliderOffsetY;
        final startHalfH = start.colliderHeight * 0.5;
        final bottom = startCenterY + startHalfH;
        var nextTop = (startCenterY - startHalfH) + deltaY;
        if (nextTop > bottom - 1) {
          nextTop = bottom - 1;
        }
        final nextHalf = (bottom - nextTop) * 0.5;
        final nextCenterY = nextTop + nextHalf;
        return PrefabSceneValues(
          anchorX: start.anchorX,
          anchorY: start.anchorY,
          colliderOffsetX: start.colliderOffsetX,
          colliderOffsetY: (nextCenterY - start.anchorY).round(),
          colliderWidth: start.colliderWidth,
          colliderHeight: (nextHalf * 2).round().clamp(1, 99999),
        );
      case PrefabOverlayHandleType.colliderRight:
        final startCenterX = start.anchorX + start.colliderOffsetX;
        final startHalfW = start.colliderWidth * 0.5;
        final left = startCenterX - startHalfW;
        var nextRight = (startCenterX + startHalfW) + deltaX;
        if (nextRight < left + 1) {
          nextRight = left + 1;
        }
        final nextHalf = (nextRight - left) * 0.5;
        final nextCenterX = left + nextHalf;
        return PrefabSceneValues(
          anchorX: start.anchorX,
          anchorY: start.anchorY,
          colliderOffsetX: (nextCenterX - start.anchorX).round(),
          colliderOffsetY: start.colliderOffsetY,
          colliderWidth: (nextHalf * 2).round().clamp(1, 99999),
          colliderHeight: start.colliderHeight,
        );
    }
  }
}

final class PrefabOverlayPainter {
  PrefabOverlayPainter._();

  static void paint({
    required Canvas canvas,
    required PrefabOverlayHandleGeometry geometry,
    PrefabOverlayHandleType? activeHandle,
    bool drawHandles = true,
  }) {
    final colliderFill = Paint()
      ..color = const Color(0x4422D3EE)
      ..style = PaintingStyle.fill;
    final colliderStroke = Paint()
      ..color = const Color(0xFF7CE5FF)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;
    canvas.drawRect(geometry.colliderRect, colliderFill);
    canvas.drawRect(geometry.colliderRect, colliderStroke);

    final anchorCross = Paint()
      ..color = const Color(0xFFFF6B6B)
      ..strokeWidth = 1.6;
    const arm = 6.0;
    canvas.drawLine(
      Offset(
        geometry.anchorHandleCenter.dx - arm,
        geometry.anchorHandleCenter.dy,
      ),
      Offset(
        geometry.anchorHandleCenter.dx + arm,
        geometry.anchorHandleCenter.dy,
      ),
      anchorCross,
    );
    canvas.drawLine(
      Offset(
        geometry.anchorHandleCenter.dx,
        geometry.anchorHandleCenter.dy - arm,
      ),
      Offset(
        geometry.anchorHandleCenter.dx,
        geometry.anchorHandleCenter.dy + arm,
      ),
      anchorCross,
    );

    if (!drawHandles) {
      return;
    }

    _paintHandle(
      canvas,
      geometry.colliderCenterHandle,
      activeHandle == PrefabOverlayHandleType.colliderCenter,
      const Color(0xFFE8F4FF),
      const Color(0xFF0F1D28),
    );
    _paintHandle(
      canvas,
      geometry.colliderTopHandle,
      activeHandle == PrefabOverlayHandleType.colliderTop,
      const Color(0xFFE8F4FF),
      const Color(0xFF0F1D28),
    );
    _paintHandle(
      canvas,
      geometry.colliderRightHandle,
      activeHandle == PrefabOverlayHandleType.colliderRight,
      const Color(0xFFE8F4FF),
      const Color(0xFF0F1D28),
    );
    _paintHandle(
      canvas,
      geometry.anchorHandleCenter,
      activeHandle == PrefabOverlayHandleType.anchor,
      const Color(0xFFFF6B6B),
      const Color(0xFF2A0B0B),
      radius: 5,
    );
  }

  static void _paintHandle(
    Canvas canvas,
    Offset center,
    bool selected,
    Color fillColor,
    Color strokeColor, {
    double radius = 6,
  }) {
    final fill = Paint()
      ..color = selected ? const Color(0xFFFFD97A) : fillColor
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = selected ? const Color(0xFFE59E00) : strokeColor
      ..strokeWidth = 1.3
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius, fill);
    canvas.drawCircle(center, radius, stroke);
  }
}
