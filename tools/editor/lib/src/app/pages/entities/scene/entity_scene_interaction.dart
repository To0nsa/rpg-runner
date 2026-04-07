part of '../entities_editor_page.dart';

/// Pointer interaction + drag mutation logic for entities scene editing.
///
/// Input semantics are intentionally aligned with shared editor controls:
/// `Ctrl+drag` pans, `Ctrl+scroll` zooms, primary drag edits handles.
extension _EntitySceneInteraction on _EntitiesEditorPageState {
  void _onSceneCanvasPointerDown(
    PointerDownEvent event, {
    required EntityEntry selectedEntry,
    required _ResolvedReferenceVisual? resolvedReference,
    required Size canvasSize,
    required double scale,
  }) {
    if (!SceneInputUtils.isPrimaryButtonPressed(event.buttons)) {
      return;
    }
    _sceneCtrlPanActive = SceneInputUtils.shouldPanWithPrimaryDrag(
      event.buttons,
    );
    if (_sceneCtrlPanActive) {
      _sceneHandleDrag = null;
      return;
    }
    final handle = _hitTestSceneHandle(
      pointerPosition: event.localPosition,
      selectedEntry: selectedEntry,
      resolvedReference: resolvedReference,
      canvasSize: canvasSize,
      scale: scale,
    );
    if (handle == null) {
      _sceneHandleDrag = null;
      return;
    }
    final referenceVisual = selectedEntry.referenceVisual;
    final startAnchorXPx =
        referenceVisual?.anchorXPx ??
        (resolvedReference == null
            ? 0.0
            : resolvedReference.anchorX * resolvedReference.frameWidth);
    final startAnchorYPx =
        referenceVisual?.anchorYPx ??
        (resolvedReference == null
            ? 0.0
            : resolvedReference.anchorY * resolvedReference.frameHeight);
    _sceneHandleDrag = _SceneHandleDrag(
      pointer: event.pointer,
      entryId: selectedEntry.id,
      handle: handle,
      startLocalPosition: event.localPosition,
      scale: scale,
      startHalfX: selectedEntry.halfX,
      startHalfY: selectedEntry.halfY,
      startOffsetX: selectedEntry.offsetX,
      startOffsetY: selectedEntry.offsetY,
      startAnchorXPx: startAnchorXPx,
      startAnchorYPx: startAnchorYPx,
      referenceFrameWidth: resolvedReference?.frameWidth ?? 1.0,
      referenceFrameHeight: resolvedReference?.frameHeight ?? 1.0,
      referenceRenderScale: resolvedReference?.renderScale ?? 1.0,
    );
    _updateState(() {});
  }

  void _onSceneCanvasPointerMove(PointerMoveEvent event) {
    final activeDrag = _sceneHandleDrag;
    if (activeDrag != null && event.pointer == activeDrag.pointer) {
      if (!SceneInputUtils.isPrimaryButtonPressed(event.buttons)) {
        _sceneHandleDrag = null;
        // End one coalesced undo unit when pointer-up/primary loss completes
        // an interactive drag sequence.
        widget.controller.commitCoalescedUndoStep();
        _updateState(() {});
        return;
      }
      _applySceneHandleDrag(activeDrag, event.localPosition);
      return;
    }
    if (!_sceneCtrlPanActive) {
      return;
    }
    if (!SceneInputUtils.isPrimaryButtonPressed(event.buttons)) {
      _sceneCtrlPanActive = false;
      return;
    }
    SceneInputUtils.panScrollControllers(
      horizontal: _sceneHorizontalScrollController,
      vertical: _sceneVerticalScrollController,
      pointerDelta: event.delta,
    );
  }

  void _onSceneCanvasPointerEnd(PointerEvent event) {
    final activeDrag = _sceneHandleDrag;
    if (activeDrag != null && event.pointer == activeDrag.pointer) {
      _sceneHandleDrag = null;
      // Mirror pointer-move termination so undo remains one-step per drag.
      widget.controller.commitCoalescedUndoStep();
      _updateState(() {});
    }
    _sceneCtrlPanActive = false;
  }

  void _onSceneCanvasPointerSignal(PointerSignalEvent event) {
    final signedSteps = SceneInputUtils.signedZoomStepsFromCtrlScroll(event);
    if (signedSteps == 0) {
      return;
    }
    final steps = signedSteps.abs();
    for (var i = 0; i < steps; i += 1) {
      if (signedSteps > 0) {
        _zoomIn();
      } else {
        _zoomOut();
      }
    }
  }

  _SceneHandleType? _activeSceneHandle(String entryId) {
    final activeDrag = _sceneHandleDrag;
    if (activeDrag == null || activeDrag.entryId != entryId) {
      return null;
    }
    return activeDrag.handle;
  }

  _SceneColliderHandle? _activeColliderHandle(_SceneHandleType? handle) {
    if (handle == null || handle == _SceneHandleType.anchor) {
      return null;
    }
    return handle.toColliderHandle();
  }

  _SceneHandleType? _hitTestSceneHandle({
    required Offset pointerPosition,
    required EntityEntry selectedEntry,
    required _ResolvedReferenceVisual? resolvedReference,
    required Size canvasSize,
    required double scale,
  }) {
    final canDragAnchor = _canDragReferenceAnchor(selectedEntry);
    if (canDragAnchor && resolvedReference != null) {
      final anchorCenter = _referenceAnchorHandleCenter(
        referenceRect: _referenceRect(
          scale: scale,
          viewportSize: canvasSize,
          reference: resolvedReference,
        ),
        reference: resolvedReference,
      );
      if (_isPointerWithinHandle(
        pointerPosition: pointerPosition,
        handleCenter: anchorCenter,
        hitRadius: _entityAnchorHandleHitRadius,
      )) {
        return _SceneHandleType.anchor;
      }
    }

    final handles = _ViewportGeometry.entityHandles(
      size: canvasSize,
      offsetX: selectedEntry.offsetX,
      offsetY: selectedEntry.offsetY,
      halfX: selectedEntry.halfX,
      halfY: selectedEntry.halfY,
      scale: scale,
    );
    for (final candidate in _SceneColliderHandle.values) {
      final center = handles.centerFor(candidate);
      if (_isPointerWithinHandle(
        pointerPosition: pointerPosition,
        handleCenter: center,
        hitRadius: _entityColliderHandleHitRadius,
      )) {
        return _SceneHandleTypeMapping.fromColliderHandle(candidate);
      }
    }
    return null;
  }

  bool _isPointerWithinHandle({
    required Offset pointerPosition,
    required Offset handleCenter,
    required double hitRadius,
  }) {
    final delta = handleCenter - pointerPosition;
    final distanceSquared = delta.dx * delta.dx + delta.dy * delta.dy;
    return distanceSquared <= hitRadius * hitRadius;
  }

  bool _canDragReferenceAnchor(EntityEntry entry) {
    final reference = entry.referenceVisual;
    return reference != null && reference.hasWritableAnchorPoint;
  }

  void _applySceneHandleDrag(_SceneHandleDrag drag, Offset pointerPosition) {
    if (_selectedEntryId != drag.entryId || drag.scale <= 0) {
      return;
    }

    if (drag.handle == _SceneHandleType.anchor) {
      _applySceneAnchorDrag(drag: drag, pointerPosition: pointerPosition);
      return;
    }

    final delta = pointerPosition - drag.startLocalPosition;
    final deltaWorldX = delta.dx / drag.scale;
    final deltaWorldY = delta.dy / drag.scale;

    var nextHalfX = drag.startHalfX;
    var nextHalfY = drag.startHalfY;
    var nextOffsetX = drag.startOffsetX;
    var nextOffsetY = drag.startOffsetY;

    switch (drag.handle.toColliderHandle()) {
      case _SceneColliderHandle.center:
        nextOffsetX = _snapToPixel(drag.startOffsetX + deltaWorldX);
        nextOffsetY = _snapToPixel(drag.startOffsetY + deltaWorldY);
        break;
      case _SceneColliderHandle.top:
        final startTop = drag.startOffsetY - drag.startHalfY;
        final fixedBottom = drag.startOffsetY + drag.startHalfY;
        final maxTop = fixedBottom - (_entityMinColliderHalfExtent * 2);
        var nextTop = _snapToPixel(startTop + deltaWorldY);
        if (nextTop > maxTop) {
          nextTop = maxTop;
        }
        nextHalfY = (fixedBottom - nextTop) * 0.5;
        nextOffsetY = nextTop + nextHalfY;
        break;
      case _SceneColliderHandle.right:
        final fixedLeft = drag.startOffsetX - drag.startHalfX;
        final startRight = drag.startOffsetX + drag.startHalfX;
        final minRight = fixedLeft + (_entityMinColliderHalfExtent * 2);
        var nextRight = _snapToPixel(startRight + deltaWorldX);
        if (nextRight < minRight) {
          nextRight = minRight;
        }
        nextHalfX = (nextRight - fixedLeft) * 0.5;
        nextOffsetX = fixedLeft + nextHalfX;
        break;
    }

    if (!_colliderValuesChanged(
      halfX: nextHalfX,
      halfY: nextHalfY,
      offsetX: nextOffsetX,
      offsetY: nextOffsetY,
      baseline: drag,
    )) {
      return;
    }

    _syncInspectorFromValues(
      halfX: nextHalfX,
      halfY: nextHalfY,
      offsetX: nextOffsetX,
      offsetY: nextOffsetY,
    );
    _applyEntryValuesCoalesced(
      drag.entryId,
      halfX: nextHalfX,
      halfY: nextHalfY,
      offsetX: nextOffsetX,
      offsetY: nextOffsetY,
    );
  }

  void _applySceneAnchorDrag({
    required _SceneHandleDrag drag,
    required Offset pointerPosition,
  }) {
    final canvasUnitsPerAnchorX = drag.referenceRenderScale * drag.scale;
    final canvasUnitsPerAnchorY = drag.referenceRenderScale * drag.scale;
    if (canvasUnitsPerAnchorX <= 0 || canvasUnitsPerAnchorY <= 0) {
      return;
    }

    final delta = pointerPosition - drag.startLocalPosition;
    final nextAnchorXPx = _snapToPixel(
      (drag.startAnchorXPx + (delta.dx / canvasUnitsPerAnchorX)).clamp(
        0.0,
        drag.referenceFrameWidth,
      ),
    );
    final nextAnchorYPx = _snapToPixel(
      (drag.startAnchorYPx + (delta.dy / canvasUnitsPerAnchorY)).clamp(
        0.0,
        drag.referenceFrameHeight,
      ),
    );

    if (!_anchorValuesChanged(
      anchorXPx: nextAnchorXPx,
      anchorYPx: nextAnchorYPx,
      baseline: drag,
    )) {
      return;
    }

    _anchorXPxController.text = nextAnchorXPx.toStringAsFixed(3);
    _anchorYPxController.text = nextAnchorYPx.toStringAsFixed(3);
    _applyEntryValuesCoalesced(
      drag.entryId,
      halfX: drag.startHalfX,
      halfY: drag.startHalfY,
      offsetX: drag.startOffsetX,
      offsetY: drag.startOffsetY,
      anchorXPx: nextAnchorXPx,
      anchorYPx: nextAnchorYPx,
    );
  }

  double _snapToPixel(double value) {
    if (!value.isFinite) {
      return 0;
    }
    return value.roundToDouble();
  }

  bool _colliderValuesChanged({
    required double halfX,
    required double halfY,
    required double offsetX,
    required double offsetY,
    required _SceneHandleDrag baseline,
  }) {
    return (halfX - baseline.startHalfX).abs() > 0.000001 ||
        (halfY - baseline.startHalfY).abs() > 0.000001 ||
        (offsetX - baseline.startOffsetX).abs() > 0.000001 ||
        (offsetY - baseline.startOffsetY).abs() > 0.000001;
  }

  bool _anchorValuesChanged({
    required double anchorXPx,
    required double anchorYPx,
    required _SceneHandleDrag baseline,
  }) {
    return (anchorXPx - baseline.startAnchorXPx).abs() > 0.000001 ||
        (anchorYPx - baseline.startAnchorYPx).abs() > 0.000001;
  }

  void _scheduleSceneViewportCentering() {
    EditorSceneViewUtils.scheduleViewportCentering(
      context: context,
      horizontal: _sceneHorizontalScrollController,
      vertical: _sceneVerticalScrollController,
    );
  }

  void _syncInspectorFromValues({
    required double halfX,
    required double halfY,
    required double offsetX,
    required double offsetY,
  }) {
    _halfXController.text = halfX.toStringAsFixed(2);
    _halfYController.text = halfY.toStringAsFixed(2);
    _offsetXController.text = offsetX.toStringAsFixed(2);
    _offsetYController.text = offsetY.toStringAsFixed(2);
  }
}
