part of '../../home/editor_home_page.dart';

extension _SceneView on _EditorHomePageState {
  static const Size _fixedViewportSize = Size(800, 500);
  static const double _colliderHandleRadius = 6.0;
  static const double _colliderHandleHitRadius = 14.0;
  static const double _anchorHandleRadius = 4.5;
  static const double _anchorHandleHitRadius = 8.0;
  static const double _minColliderHalfExtent = 1.0;

  Widget _buildViewportPanel(EntityEntry? selectedEntry) {
    if (selectedEntry == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Text('No entity selected.'),
        ),
      );
    }

    final scale = _sceneZoom;
    final resolvedReference = _resolveReferenceVisual(selectedEntry);
    final animKeys = resolvedReference == null
        ? const <String>[]
        : _sortedAnimKeys(resolvedReference);
    final activeAnimKey = resolvedReference?.resolveAnimKey(_sceneAnimKey);
    final referenceAnimView = resolvedReference == null
        ? null
        : _effectiveReferenceAnimView(
            resolvedReference,
            selectedAnimKey: activeAnimKey,
          );
    if (referenceAnimView != null) {
      unawaited(_ensureReferenceImageLoaded(referenceAnimView.absolutePath));
    }
    final frameCount = referenceAnimView == null
        ? 1
        : _effectiveReferenceFrameCount(referenceAnimView);
    final frameIndex = _effectiveReferenceFrameIndex(frameCount);
    final resolvedImage = referenceAnimView == null
        ? null
        : _referenceImageCache[referenceAnimView.absolutePath];
    final referenceRow = referenceAnimView == null
        ? 0
        : _effectiveReferenceRow(referenceAnimView);
    final referenceFrame = referenceAnimView == null
        ? 0
        : _effectiveReferenceFrame(referenceAnimView, frameIndex: frameIndex);
    final sceneCanvasSize = _sceneCanvasSize(
      selectedEntry: selectedEntry,
      reference: resolvedReference,
      scale: scale,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportWidth = constraints.maxWidth.isFinite
            ? math.min(_fixedViewportSize.width, constraints.maxWidth)
            : _fixedViewportSize.width;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: viewportWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Entity Scene View',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: _buildSceneZoomControls(),
                            ),
                          ),
                        ],
                      ),
                      if (animKeys.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: _buildSceneAnimControls(
                              animKeys: animKeys,
                              activeAnimKey: activeAnimKey,
                              frameIndex: frameIndex,
                              frameCount: frameCount,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: viewportWidth,
                  height: _fixedViewportSize.height,
                  child: _buildScrollableSceneCanvas(
                    canvasSize: sceneCanvasSize,
                    scale: scale,
                    selectedEntry: selectedEntry,
                    resolvedReference: resolvedReference,
                    referenceAnimView: referenceAnimView,
                    resolvedImage: resolvedImage,
                    referenceRow: referenceRow,
                    referenceFrame: referenceFrame,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildScrollableSceneCanvas({
    required Size canvasSize,
    required double scale,
    required EntityEntry selectedEntry,
    required _ResolvedReferenceVisual? resolvedReference,
    required _ResolvedReferenceAnimView? referenceAnimView,
    required ui.Image? resolvedImage,
    required int referenceRow,
    required int referenceFrame,
  }) {
    final canvas = Listener(
      onPointerDown: (event) {
        _onSceneCanvasPointerDown(
          event,
          selectedEntry: selectedEntry,
          resolvedReference: resolvedReference,
          canvasSize: canvasSize,
          scale: scale,
        );
      },
      onPointerMove: (event) {
        _onSceneCanvasPointerMove(event);
      },
      onPointerUp: (event) {
        _onSceneCanvasPointerEnd(event);
      },
      onPointerCancel: (event) {
        _onSceneCanvasPointerEnd(event);
      },
      onPointerSignal: _onSceneCanvasPointerSignal,
      child: SizedBox(
        width: canvasSize.width,
        height: canvasSize.height,
        child: _buildSceneCanvas(
          canvasSize: canvasSize,
          scale: scale,
          selectedEntry: selectedEntry,
          resolvedReference: resolvedReference,
          referenceAnimView: referenceAnimView,
          resolvedImage: resolvedImage,
          referenceRow: referenceRow,
          referenceFrame: referenceFrame,
        ),
      ),
    );

    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: SingleChildScrollView(
        controller: _sceneVerticalScrollController,
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          controller: _sceneHorizontalScrollController,
          scrollDirection: Axis.horizontal,
          child: canvas,
        ),
      ),
    );
  }

  Widget _buildSceneCanvas({
    required Size canvasSize,
    required double scale,
    required EntityEntry selectedEntry,
    required _ResolvedReferenceVisual? resolvedReference,
    required _ResolvedReferenceAnimView? referenceAnimView,
    required ui.Image? resolvedImage,
    required int referenceRow,
    required int referenceFrame,
  }) {
    final referenceRect = resolvedReference == null
        ? null
        : _referenceRect(
            scale: scale,
            viewportSize: canvasSize,
            reference: resolvedReference,
          );
    final anchorHandleCenter =
        resolvedReference == null || referenceRect == null
        ? null
        : _referenceAnchorHandleCenter(
            referenceRect: referenceRect,
            reference: resolvedReference,
          );
    final activeHandle = _activeSceneHandle(selectedEntry.id);

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF1B2A36)),
      ),
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            const Positioned.fill(child: ColoredBox(color: Color(0xFF111A22))),
            CustomPaint(painter: _ViewportPixelGridPainter(zoom: scale)),
            if (resolvedReference != null &&
                referenceAnimView != null &&
                resolvedImage != null)
              CustomPaint(
                painter: _ReferenceFramePainter(
                  image: resolvedImage,
                  row: referenceRow,
                  frame: referenceFrame,
                  destinationRect: referenceRect!,
                  anchorX: resolvedReference.anchorX,
                  anchorY: resolvedReference.anchorY,
                  showReferencePoints: false,
                  frameWidth: resolvedReference.frameWidth,
                  frameHeight: resolvedReference.frameHeight,
                  gridColumns: referenceAnimView.defaultGridColumns,
                  drawMarkerLabels: false,
                ),
              ),
            CustomPaint(
              painter: _EntityBoundsPainter(
                entry: selectedEntry,
                scale: scale,
                handleRadius: _colliderHandleRadius,
                activeHandle: _activeColliderHandle(activeHandle),
                anchorHandleCenter: anchorHandleCenter,
                anchorHandleRadius: _anchorHandleRadius,
                anchorSelected: activeHandle == _SceneHandleType.anchor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Size _sceneCanvasSize({
    required EntityEntry selectedEntry,
    required _ResolvedReferenceVisual? reference,
    required double scale,
  }) {
    const panPadding = 280.0;
    var halfSpanX =
        selectedEntry.offsetX.abs() * scale + selectedEntry.halfX * scale;
    var halfSpanY =
        selectedEntry.offsetY.abs() * scale + selectedEntry.halfY * scale;

    if (reference != null) {
      final frameWidth = reference.frameWidth * reference.renderScale * scale;
      final frameHeight = reference.frameHeight * reference.renderScale * scale;
      final frameHalfSpanX = math.max(
        reference.anchorX * frameWidth,
        (1.0 - reference.anchorX) * frameWidth,
      );
      final frameHalfSpanY = math.max(
        reference.anchorY * frameHeight,
        (1.0 - reference.anchorY) * frameHeight,
      );
      if (frameHalfSpanX > halfSpanX) {
        halfSpanX = frameHalfSpanX;
      }
      if (frameHalfSpanY > halfSpanY) {
        halfSpanY = frameHalfSpanY;
      }
    }

    final width = math.max(
      _fixedViewportSize.width,
      (halfSpanX + panPadding) * 2,
    );
    final height = math.max(
      _fixedViewportSize.height,
      (halfSpanY + panPadding) * 2,
    );
    return Size(width.ceilToDouble(), height.ceilToDouble());
  }

  void _onSceneCanvasPointerDown(
    PointerDownEvent event, {
    required EntityEntry selectedEntry,
    required _ResolvedReferenceVisual? resolvedReference,
    required Size canvasSize,
    required double scale,
  }) {
    final isPrimaryMouseDown = (event.buttons & kPrimaryButton) != 0;
    if (!isPrimaryMouseDown) {
      return;
    }
    _sceneCtrlPanActive =
        isPrimaryMouseDown && HardwareKeyboard.instance.isControlPressed;
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
      if ((event.buttons & kPrimaryButton) == 0) {
        _sceneHandleDrag = null;
        _updateState(() {});
        return;
      }
      _applySceneHandleDrag(activeDrag, event.localPosition);
      return;
    }
    if (!_sceneCtrlPanActive) {
      return;
    }
    if ((event.buttons & kPrimaryButton) == 0) {
      _sceneCtrlPanActive = false;
      return;
    }
    _panSceneViewportBy(delta: event.delta);
  }

  void _onSceneCanvasPointerEnd(PointerEvent event) {
    final activeDrag = _sceneHandleDrag;
    if (activeDrag != null && event.pointer == activeDrag.pointer) {
      _sceneHandleDrag = null;
      _updateState(() {});
    }
    _sceneCtrlPanActive = false;
  }

  void _onSceneCanvasPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) {
      return;
    }
    if (!HardwareKeyboard.instance.isControlPressed) {
      return;
    }
    final deltaY = event.scrollDelta.dy;
    if (deltaY.abs() <= 0.0) {
      return;
    }
    // Mouse wheels usually emit ~120 px "notches". Trackpads emit smaller
    // continuous deltas, so normalize to at least one zoom step.
    final rawSteps = (deltaY.abs() / 120.0).round();
    final steps = rawSteps < 1 ? 1 : rawSteps;
    for (var i = 0; i < steps; i += 1) {
      if (deltaY < 0) {
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
        hitRadius: _anchorHandleHitRadius,
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
        hitRadius: _colliderHandleHitRadius,
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
    return reference != null && reference.anchorBinding != null;
  }

  Offset _referenceAnchorHandleCenter({
    required Rect referenceRect,
    required _ResolvedReferenceVisual reference,
  }) {
    return Offset(
      referenceRect.left + referenceRect.width * reference.anchorX,
      referenceRect.top + referenceRect.height * reference.anchorY,
    );
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
        final maxTop = fixedBottom - (_minColliderHalfExtent * 2);
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
        final minRight = fixedLeft + (_minColliderHalfExtent * 2);
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
    _applyEntryValues(
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
    _applyEntryValues(
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

  void _panSceneViewportBy({required Offset delta}) {
    if (!_sceneHorizontalScrollController.hasClients ||
        !_sceneVerticalScrollController.hasClients) {
      return;
    }
    final horizontalPosition = _sceneHorizontalScrollController.position;
    final verticalPosition = _sceneVerticalScrollController.position;
    final nextX = (_sceneHorizontalScrollController.offset - delta.dx).clamp(
      0.0,
      horizontalPosition.maxScrollExtent,
    );
    final nextY = (_sceneVerticalScrollController.offset - delta.dy).clamp(
      0.0,
      verticalPosition.maxScrollExtent,
    );
    _sceneHorizontalScrollController.jumpTo(nextX);
    _sceneVerticalScrollController.jumpTo(nextY);
  }

  void _scheduleSceneViewportCentering() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !_sceneHorizontalScrollController.hasClients ||
          !_sceneVerticalScrollController.hasClients) {
        return;
      }
      final horizontalPosition = _sceneHorizontalScrollController.position;
      final verticalPosition = _sceneVerticalScrollController.position;
      final targetX = horizontalPosition.maxScrollExtent * 0.5;
      final targetY = verticalPosition.maxScrollExtent * 0.5;
      _sceneHorizontalScrollController.jumpTo(targetX);
      _sceneVerticalScrollController.jumpTo(targetY);
    });
  }

  _ResolvedReferenceVisual? _resolveReferenceVisual(EntityEntry entry) {
    final reference = entry.referenceVisual;
    final workspace = widget.controller.workspace;
    if (reference == null || workspace == null) {
      return null;
    }

    final frameWidth = reference.frameWidth;
    final frameHeight = reference.frameHeight;
    final resolvedFrameWidth = frameWidth != null && frameWidth > 0
        ? frameWidth
        : math.max(1.0, entry.halfX * 2.0);
    final resolvedFrameHeight = frameHeight != null && frameHeight > 0
        ? frameHeight
        : math.max(1.0, entry.halfY * 2.0);
    final resolvedRenderScale =
        reference.renderScale != null && reference.renderScale! > 0
        ? reference.renderScale!
        : 1.0;
    final resolvedAnchorX = _normalizeReferenceAnchor(
      reference.anchorXPx,
      resolvedFrameWidth,
    );
    final resolvedAnchorY = _normalizeReferenceAnchor(
      reference.anchorYPx,
      resolvedFrameHeight,
    );

    _ResolvedReferenceAnimView? resolveAnimView({
      required String key,
      required String assetPath,
      required int row,
      required int frameStart,
      required int? frameCount,
      required int? gridColumns,
    }) {
      final normalizedAssetPath = assetPath.replaceAll('\\', '/');
      final relativeImagePath = 'assets/images/$normalizedAssetPath';
      final absoluteImagePath = workspace.resolve(relativeImagePath);
      final file = File(absoluteImagePath);
      if (!file.existsSync()) {
        return null;
      }
      return _ResolvedReferenceAnimView(
        key: key,
        absolutePath: absoluteImagePath,
        displayPath: relativeImagePath.replaceAll('\\', '/'),
        defaultRow: row,
        defaultFrameStart: frameStart,
        defaultFrameCount: frameCount,
        defaultGridColumns: gridColumns,
      );
    }

    final animViewsByKey = <String, _ResolvedReferenceAnimView>{};
    if (reference.animViewsByKey.isNotEmpty) {
      for (final animView in reference.animViewsByKey.values) {
        final resolvedView = resolveAnimView(
          key: animView.key,
          assetPath: animView.assetPath,
          row: animView.row,
          frameStart: animView.frameStart,
          frameCount: animView.frameCount,
          gridColumns: animView.gridColumns,
        );
        if (resolvedView != null) {
          animViewsByKey[animView.key] = resolvedView;
        }
      }
    } else {
      final fallbackKey = reference.defaultAnimKey ?? 'idle';
      final fallbackView = resolveAnimView(
        key: fallbackKey,
        assetPath: reference.assetPath,
        row: reference.defaultRow,
        frameStart: reference.defaultFrameStart,
        frameCount: reference.defaultFrameCount,
        gridColumns: reference.defaultGridColumns,
      );
      if (fallbackView != null) {
        animViewsByKey[fallbackKey] = fallbackView;
      }
    }
    if (animViewsByKey.isEmpty) {
      return null;
    }

    return _ResolvedReferenceVisual(
      frameWidth: resolvedFrameWidth,
      frameHeight: resolvedFrameHeight,
      renderScale: resolvedRenderScale,
      anchorX: resolvedAnchorX,
      anchorY: resolvedAnchorY,
      defaultAnimKey: reference.defaultAnimKey,
      animViewsByKey: animViewsByKey,
    );
  }

  double _normalizeReferenceAnchor(double? anchorPx, double frameSize) {
    if (anchorPx == null || !anchorPx.isFinite || frameSize <= 0) {
      return 0.5;
    }
    return (anchorPx / frameSize).clamp(0.0, 1.0);
  }

  List<String> _sortedAnimKeys(_ResolvedReferenceVisual reference) {
    final keys = reference.animViewsByKey.keys.toList(growable: false);
    keys.sort();
    return keys;
  }

  _ResolvedReferenceAnimView? _effectiveReferenceAnimView(
    _ResolvedReferenceVisual reference, {
    required String? selectedAnimKey,
  }) {
    final key = reference.resolveAnimKey(selectedAnimKey);
    if (key == null) {
      return null;
    }
    return reference.animViewsByKey[key];
  }

  int _effectiveReferenceFrameCount(_ResolvedReferenceAnimView reference) {
    final count = reference.defaultFrameCount;
    if (count == null || count <= 0) {
      return 1;
    }
    return count;
  }

  int _effectiveReferenceFrameIndex(int frameCount) {
    if (frameCount <= 1) {
      return 0;
    }
    return _sceneAnimFrameIndex.clamp(0, frameCount - 1);
  }

  int _effectiveReferenceRow(_ResolvedReferenceAnimView reference) {
    final row = reference.defaultRow;
    return row < 0 ? 0 : row;
  }

  int _effectiveReferenceFrame(
    _ResolvedReferenceAnimView reference, {
    required int frameIndex,
  }) {
    final absoluteFrame = reference.defaultFrameStart + frameIndex;
    final minFrame = reference.defaultFrameStart;
    final maxFrame = reference.maxFrameIndex ?? absoluteFrame;
    return absoluteFrame.clamp(minFrame, maxFrame);
  }

  Future<void> _ensureReferenceImageLoaded(String absolutePath) async {
    if (_referenceImageCache.containsKey(absolutePath) ||
        _referenceImageLoading.contains(absolutePath) ||
        _referenceImageFailed.contains(absolutePath)) {
      return;
    }
    _referenceImageLoading.add(absolutePath);
    try {
      final bytes = await File(absolutePath).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      codec.dispose();
      if (!mounted) {
        frame.image.dispose();
        return;
      }
      _updateState(() {
        _referenceImageCache[absolutePath] = frame.image;
        _referenceImageLoading.remove(absolutePath);
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      _updateState(() {
        _referenceImageLoading.remove(absolutePath);
        _referenceImageFailed.add(absolutePath);
      });
    }
  }

  Rect _referenceRect({
    required double scale,
    required Size viewportSize,
    required _ResolvedReferenceVisual reference,
  }) {
    final origin = _ViewportGeometry.canvasCenter(viewportSize);
    final width = math.max(
      1.0,
      reference.frameWidth * reference.renderScale * scale,
    );
    final height = math.max(
      1.0,
      reference.frameHeight * reference.renderScale * scale,
    );
    final left = origin.dx - (reference.anchorX * width);
    final top = origin.dy - (reference.anchorY * height);
    return Rect.fromLTWH(left, top, width, height);
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

enum _SceneColliderHandle { center, top, right }

enum _SceneHandleType { colliderCenter, colliderTop, colliderRight, anchor }

extension _SceneHandleTypeMapping on _SceneHandleType {
  static _SceneHandleType fromColliderHandle(_SceneColliderHandle handle) {
    switch (handle) {
      case _SceneColliderHandle.center:
        return _SceneHandleType.colliderCenter;
      case _SceneColliderHandle.top:
        return _SceneHandleType.colliderTop;
      case _SceneColliderHandle.right:
        return _SceneHandleType.colliderRight;
    }
  }

  _SceneColliderHandle toColliderHandle() {
    switch (this) {
      case _SceneHandleType.colliderCenter:
        return _SceneColliderHandle.center;
      case _SceneHandleType.colliderTop:
        return _SceneColliderHandle.top;
      case _SceneHandleType.colliderRight:
        return _SceneColliderHandle.right;
      case _SceneHandleType.anchor:
        throw StateError('Anchor handle does not map to collider handle.');
    }
  }
}

class _SceneHandleDrag {
  const _SceneHandleDrag({
    required this.pointer,
    required this.entryId,
    required this.handle,
    required this.startLocalPosition,
    required this.scale,
    required this.startHalfX,
    required this.startHalfY,
    required this.startOffsetX,
    required this.startOffsetY,
    required this.startAnchorXPx,
    required this.startAnchorYPx,
    required this.referenceFrameWidth,
    required this.referenceFrameHeight,
    required this.referenceRenderScale,
  });

  final int pointer;
  final String entryId;
  final _SceneHandleType handle;
  final Offset startLocalPosition;
  final double scale;
  final double startHalfX;
  final double startHalfY;
  final double startOffsetX;
  final double startOffsetY;
  final double startAnchorXPx;
  final double startAnchorYPx;
  final double referenceFrameWidth;
  final double referenceFrameHeight;
  final double referenceRenderScale;
}

class _ViewportEntityHandles {
  const _ViewportEntityHandles({
    required this.center,
    required this.top,
    required this.right,
  });

  final Offset center;
  final Offset top;
  final Offset right;

  Offset centerFor(_SceneColliderHandle handle) {
    switch (handle) {
      case _SceneColliderHandle.center:
        return center;
      case _SceneColliderHandle.top:
        return top;
      case _SceneColliderHandle.right:
        return right;
    }
  }
}

class _ResolvedReferenceVisual {
  const _ResolvedReferenceVisual({
    required this.frameWidth,
    required this.frameHeight,
    required this.renderScale,
    required this.anchorX,
    required this.anchorY,
    required this.defaultAnimKey,
    required this.animViewsByKey,
  });

  final double frameWidth;
  final double frameHeight;
  final double renderScale;
  final double anchorX;
  final double anchorY;
  final String? defaultAnimKey;
  final Map<String, _ResolvedReferenceAnimView> animViewsByKey;

  String? resolveAnimKey(String? preferredKey) {
    if (preferredKey != null && animViewsByKey.containsKey(preferredKey)) {
      return preferredKey;
    }
    final fallbackKey = defaultAnimKey;
    if (fallbackKey != null && animViewsByKey.containsKey(fallbackKey)) {
      return fallbackKey;
    }
    if (animViewsByKey.isEmpty) {
      return null;
    }
    return animViewsByKey.keys.first;
  }
}

class _ResolvedReferenceAnimView {
  const _ResolvedReferenceAnimView({
    required this.key,
    required this.absolutePath,
    required this.displayPath,
    required this.defaultRow,
    required this.defaultFrameStart,
    required this.defaultFrameCount,
    required this.defaultGridColumns,
  });

  final String key;
  final String absolutePath;
  final String displayPath;
  final int defaultRow;
  final int defaultFrameStart;
  final int? defaultFrameCount;
  final int? defaultGridColumns;

  int? get maxFrameIndex {
    final count = defaultFrameCount;
    if (count == null || count <= 0) {
      return null;
    }
    return defaultFrameStart + count - 1;
  }
}

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
