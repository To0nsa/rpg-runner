part of '../entities_editor_page.dart';

/// Viewport composition for the entities scene authoring surface.
///
/// This extension builds the scene UI tree only; input handling, reference
/// resolution, and painting primitives live in sibling scene part files.
extension _EntitySceneView on _EntitiesEditorPageState {
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
    final frameCount = referenceAnimView == null
        ? 1
        : _effectiveReferenceFrameCount(referenceAnimView);
    final frameIndex = _effectiveReferenceFrameIndex(frameCount);
    final resolvedImage = referenceAnimView == null
        ? null
        : _referenceImageCache.imageFor(referenceAnimView.absolutePath);
    final referenceRow = referenceAnimView == null
        ? 0
        : _effectiveReferenceRow(referenceAnimView);
    final referenceFrame = referenceAnimView == null
        ? 0
        : _effectiveReferenceFrame(referenceAnimView, frameIndex: frameIndex);

    return LayoutBuilder(
      builder: (context, constraints) {
        final panelWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : _entitySceneDefaultViewportSize.width;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: panelWidth,
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
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, viewportConstraints) {
                      final viewportSize = Size(
                        viewportConstraints.maxWidth.isFinite
                            ? viewportConstraints.maxWidth
                            : panelWidth,
                        viewportConstraints.maxHeight.isFinite
                            ? viewportConstraints.maxHeight
                            : _entitySceneDefaultViewportSize.height,
                      );
                      final sceneCanvasSize = _sceneCanvasSize(
                        selectedEntry: selectedEntry,
                        reference: resolvedReference,
                        scale: scale,
                        viewportSize: viewportSize,
                      );
                      return EditorSceneViewportFrame(
                        width: viewportSize.width,
                        height: viewportSize.height,
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
                      );
                    },
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
            CustomPaint(painter: EditorViewportGridPainter(zoom: scale)),
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
                handleRadius: _entityColliderHandleRadius,
                activeHandle: _activeColliderHandle(activeHandle),
                anchorHandleCenter: anchorHandleCenter,
                anchorHandleRadius: _entityAnchorHandleRadius,
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
    required Size viewportSize,
  }) {
    // Extra padding allows ctrl-drag panning room around the authored object so
    // handles stay editable even near edges.
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

    final minViewportWidth =
        viewportSize.width.isFinite && viewportSize.width > 0
        ? viewportSize.width
        : _entitySceneDefaultViewportSize.width;
    final minViewportHeight =
        viewportSize.height.isFinite && viewportSize.height > 0
        ? viewportSize.height
        : _entitySceneDefaultViewportSize.height;

    final width = math.max(minViewportWidth, (halfSpanX + panPadding) * 2);
    final height = math.max(minViewportHeight, (halfSpanY + panPadding) * 2);
    return Size(width.ceilToDouble(), height.ceilToDouble());
  }
}
