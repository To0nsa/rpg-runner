import 'package:flutter/material.dart';

import '../../../../prefabs/models/models.dart';
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
    required this.colliderRects,
    required this.selectedColliderIndex,
    required this.selectedColliderRect,
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
    final colliderRects = <Rect>[];
    for (final collider in values.colliders) {
      final colliderCenter = Offset(
        anchorHandleCenter.dx + (collider.offsetX * zoom),
        anchorHandleCenter.dy + (collider.offsetY * zoom),
      );
      final halfW = collider.width * 0.5 * zoom;
      final halfH = collider.height * 0.5 * zoom;
      colliderRects.add(
        Rect.fromLTRB(
          colliderCenter.dx - halfW,
          colliderCenter.dy - halfH,
          colliderCenter.dx + halfW,
          colliderCenter.dy + halfH,
        ),
      );
    }
    final selectedColliderIndex = values.normalizedSelectedColliderIndex;
    final selectedColliderRect = selectedColliderIndex == null
        ? null
        : colliderRects[selectedColliderIndex];
    return PrefabOverlayHandleGeometry(
      anchorHandleCenter: anchorHandleCenter,
      colliderRects: colliderRects,
      selectedColliderIndex: selectedColliderIndex,
      selectedColliderRect: selectedColliderRect,
      colliderCenterHandle: selectedColliderRect?.center,
      colliderTopHandle: selectedColliderRect == null
          ? null
          : Offset(selectedColliderRect.center.dx, selectedColliderRect.top),
      colliderRightHandle: selectedColliderRect == null
          ? null
          : Offset(selectedColliderRect.right, selectedColliderRect.center.dy),
    );
  }

  final Offset anchorHandleCenter;
  final List<Rect> colliderRects;
  final int? selectedColliderIndex;
  final Rect? selectedColliderRect;
  final Offset? colliderCenterHandle;
  final Offset? colliderTopHandle;
  final Offset? colliderRightHandle;
}

final class PrefabOverlayHitTest {
  PrefabOverlayHitTest._();

  static PrefabOverlayHandleType? hitTestHandle({
    required Offset point,
    required PrefabOverlayHandleGeometry geometry,
    required double anchorHandleHitRadius,
    required double colliderHandleHitRadius,
    bool includeColliderHandles = true,
  }) {
    if (_distanceSquared(point, geometry.anchorHandleCenter) <=
        anchorHandleHitRadius * anchorHandleHitRadius) {
      return PrefabOverlayHandleType.anchor;
    }
    if (!includeColliderHandles) {
      return null;
    }
    final colliderCenterHandle = geometry.colliderCenterHandle;
    if (colliderCenterHandle != null &&
        _distanceSquared(point, colliderCenterHandle) <=
            colliderHandleHitRadius * colliderHandleHitRadius) {
      return PrefabOverlayHandleType.colliderCenter;
    }
    final colliderTopHandle = geometry.colliderTopHandle;
    if (colliderTopHandle != null &&
        _distanceSquared(point, colliderTopHandle) <=
            colliderHandleHitRadius * colliderHandleHitRadius) {
      return PrefabOverlayHandleType.colliderTop;
    }
    final colliderRightHandle = geometry.colliderRightHandle;
    if (colliderRightHandle != null &&
        _distanceSquared(point, colliderRightHandle) <=
            colliderHandleHitRadius * colliderHandleHitRadius) {
      return PrefabOverlayHandleType.colliderRight;
    }
    return null;
  }

  static int? hitTestColliderIndex({
    required Offset point,
    required PrefabOverlayHandleGeometry geometry,
  }) {
    final selectedIndex = geometry.selectedColliderIndex;
    final selectedRect = geometry.selectedColliderRect;
    if (selectedIndex != null &&
        selectedRect != null &&
        selectedRect.contains(point)) {
      return selectedIndex;
    }

    for (var i = geometry.colliderRects.length - 1; i >= 0; i -= 1) {
      if (i == selectedIndex) {
        continue;
      }
      if (geometry.colliderRects[i].contains(point)) {
        return i;
      }
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

  static PrefabSceneValues valuesWithSelectedCollider({
    required PrefabSceneValues values,
    required int selectedColliderIndex,
  }) {
    if (selectedColliderIndex < 0 ||
        selectedColliderIndex >= values.colliders.length ||
        values.normalizedSelectedColliderIndex == selectedColliderIndex) {
      return values;
    }
    return PrefabSceneValues(
      anchorX: values.anchorX,
      anchorY: values.anchorY,
      colliders: values.colliders,
      selectedColliderIndex: selectedColliderIndex,
    );
  }

  static PrefabSceneValues valuesFromDrag({
    required PrefabOverlayDragState drag,
    required Offset currentLocal,
  }) {
    final delta = currentLocal - drag.startLocal;
    final deltaX = delta.dx / drag.zoom;
    final deltaY = delta.dy / drag.zoom;
    final start = drag.startValues;
    final selectedCollider = start.selectedCollider;

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
          colliders: start.colliders,
          selectedColliderIndex: start.normalizedSelectedColliderIndex,
        );
      case PrefabOverlayHandleType.colliderCenter:
        if (selectedCollider == null) {
          return start;
        }
        return _replaceSelectedCollider(
          start,
          selectedCollider.copyWith(
            offsetX: (selectedCollider.offsetX + deltaX).round(),
            offsetY: (selectedCollider.offsetY + deltaY).round(),
          ),
        );
      case PrefabOverlayHandleType.colliderTop:
        if (selectedCollider == null) {
          return start;
        }
        final startCenterY = start.anchorY + selectedCollider.offsetY;
        final startHalfH = selectedCollider.height * 0.5;
        final bottom = startCenterY + startHalfH;
        var nextTop = (startCenterY - startHalfH) + deltaY;
        if (nextTop > bottom - 1) {
          nextTop = bottom - 1;
        }
        final nextHalf = (bottom - nextTop) * 0.5;
        final nextCenterY = nextTop + nextHalf;
        return _replaceSelectedCollider(
          start,
          selectedCollider.copyWith(
            offsetY: (nextCenterY - start.anchorY).round(),
            height: (nextHalf * 2).round().clamp(1, 99999),
          ),
        );
      case PrefabOverlayHandleType.colliderRight:
        if (selectedCollider == null) {
          return start;
        }
        final startCenterX = start.anchorX + selectedCollider.offsetX;
        final startHalfW = selectedCollider.width * 0.5;
        final left = startCenterX - startHalfW;
        var nextRight = (startCenterX + startHalfW) + deltaX;
        if (nextRight < left + 1) {
          nextRight = left + 1;
        }
        final nextHalf = (nextRight - left) * 0.5;
        final nextCenterX = left + nextHalf;
        return _replaceSelectedCollider(
          start,
          selectedCollider.copyWith(
            offsetX: (nextCenterX - start.anchorX).round(),
            width: (nextHalf * 2).round().clamp(1, 99999),
          ),
        );
    }
  }

  static PrefabSceneValues _replaceSelectedCollider(
    PrefabSceneValues values,
    PrefabColliderDef collider,
  ) {
    final index = values.normalizedSelectedColliderIndex;
    if (index == null) {
      return values;
    }
    final colliders = values.colliders.toList(growable: false);
    colliders[index] = collider;
    return PrefabSceneValues(
      anchorX: values.anchorX,
      anchorY: values.anchorY,
      colliders: colliders,
      selectedColliderIndex: index,
    );
  }
}

final class PrefabOverlayPainter {
  PrefabOverlayPainter._();

  static void paint({
    required Canvas canvas,
    required PrefabOverlayHandleGeometry geometry,
    PrefabOverlayHandleType? activeHandle,
    bool showCollider = true,
    bool drawHandles = true,
  }) {
    if (showCollider) {
      final colliderFill = Paint()
        ..color = const Color(0x4422D3EE)
        ..style = PaintingStyle.fill;
      final colliderStroke = Paint()
        ..color = const Color(0xFF4BB5CF)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;
      final selectedColliderStroke = Paint()
        ..color = const Color(0xFF7CE5FF)
        ..strokeWidth = 1.8
        ..style = PaintingStyle.stroke;
      for (var i = 0; i < geometry.colliderRects.length; i += 1) {
        final rect = geometry.colliderRects[i];
        canvas.drawRect(rect, colliderFill);
        canvas.drawRect(
          rect,
          geometry.selectedColliderIndex == i
              ? selectedColliderStroke
              : colliderStroke,
        );
      }
    }

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

    if (showCollider) {
      final colliderCenterHandle = geometry.colliderCenterHandle;
      if (colliderCenterHandle != null) {
        _paintHandle(
          canvas,
          colliderCenterHandle,
          activeHandle == PrefabOverlayHandleType.colliderCenter,
          const Color(0xFFE8F4FF),
          const Color(0xFF0F1D28),
        );
      }
      final colliderTopHandle = geometry.colliderTopHandle;
      if (colliderTopHandle != null) {
        _paintHandle(
          canvas,
          colliderTopHandle,
          activeHandle == PrefabOverlayHandleType.colliderTop,
          const Color(0xFFE8F4FF),
          const Color(0xFF0F1D28),
        );
      }
      final colliderRightHandle = geometry.colliderRightHandle;
      if (colliderRightHandle != null) {
        _paintHandle(
          canvas,
          colliderRightHandle,
          activeHandle == PrefabOverlayHandleType.colliderRight,
          const Color(0xFFE8F4FF),
          const Color(0xFF0F1D28),
        );
      }
    }
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
