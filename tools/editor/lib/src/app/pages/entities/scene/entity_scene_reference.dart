part of '../entities_editor_page.dart';

/// Resolves entity reference visual metadata into render-ready scene values.
///
/// This is editor-side projection logic: it normalizes optional authored fields
/// (anchor/frame/scale), picks an animation view, and coordinates preview image
/// loading via the page image cache.
extension _EntitySceneReference on _EntitiesEditorPageState {
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
      // Only expose views with existing files so scene controls stay aligned
      // with what can actually be previewed in this workspace.
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
      for (final entry in reference.animViewsByKey.entries) {
        final animKey = entry.key;
        final animView = entry.value;
        final resolvedView = resolveAnimView(
          key: animKey,
          assetPath: animView.assetPath,
          row: animView.row,
          frameStart: animView.frameStart,
          frameCount: animView.frameCount,
          gridColumns: animView.gridColumns,
        );
        if (resolvedView != null) {
          animViewsByKey[animKey] = resolvedView;
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
    // Missing/invalid anchors default to centered pivot to preserve preview
    // usability and avoid surprising off-canvas placements.
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
    final image = await _referenceImageCache.ensureLoaded(absolutePath);
    if (!mounted || image == null) {
      return;
    }
    _updateState(() {});
  }

  void _ensureCurrentReferenceImageLoaded() {
    final scene = widget.controller.scene;
    if (scene is! EntityScene) {
      return;
    }
    final selected = _selectedEntry(scene);
    if (selected == null) {
      return;
    }
    final resolvedReference = _resolveReferenceVisual(selected);
    if (resolvedReference == null) {
      return;
    }
    final activeAnimKey = resolvedReference.resolveAnimKey(_sceneAnimKey);
    final referenceAnimView = _effectiveReferenceAnimView(
      resolvedReference,
      selectedAnimKey: activeAnimKey,
    );
    if (referenceAnimView == null) {
      return;
    }
    unawaited(_ensureReferenceImageLoaded(referenceAnimView.absolutePath));
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

  Offset _referenceAnchorHandleCenter({
    required Rect referenceRect,
    required _ResolvedReferenceVisual reference,
  }) {
    return Offset(
      referenceRect.left + referenceRect.width * reference.anchorX,
      referenceRect.top + referenceRect.height * reference.anchorY,
    );
  }
}
