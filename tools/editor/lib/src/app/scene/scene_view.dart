part of '../editor_home_page.dart';

extension _SceneView on _EditorHomePageState {
  static const Size _fixedViewportSize = Size(800, 500);

  Widget _buildViewportPanel(ColliderEntry? selectedEntry) {
    if (selectedEntry == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Text('No collider entry selected.'),
        ),
      );
    }

    final scale = _sceneZoom;
    final resolvedReference = _resolveReferenceVisual(selectedEntry);
    final referenceAnimView = resolvedReference == null
        ? null
        : _effectiveReferenceAnimView(resolvedReference);
    if (referenceAnimView != null) {
      unawaited(_ensureReferenceImageLoaded(referenceAnimView.absolutePath));
    }
    final resolvedImage = referenceAnimView == null
        ? null
        : _referenceImageCache[referenceAnimView.absolutePath];
    final referenceRow = referenceAnimView == null
        ? 0
        : _effectiveReferenceRow(referenceAnimView);
    final referenceFrame = referenceAnimView == null
        ? 0
        : _effectiveReferenceFrame(referenceAnimView);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: _fixedViewportSize.width,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Scene View',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  _buildSceneZoomControls(),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: _fixedViewportSize.width,
              height: _fixedViewportSize.height,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF1B2A36)),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    const Positioned.fill(
                      child: ColoredBox(color: Color(0xFF111A22)),
                    ),
                    const CustomPaint(painter: _ViewportPixelGridPainter()),
                    if (resolvedReference != null &&
                        referenceAnimView != null &&
                        resolvedImage != null)
                      CustomPaint(
                        painter: _ReferenceFramePainter(
                          image: resolvedImage,
                          row: referenceRow,
                          frame: referenceFrame,
                          destinationRect: _referenceRect(
                            scale: scale,
                            viewportSize: _fixedViewportSize,
                            reference: resolvedReference,
                          ),
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
                      painter: _ColliderViewportPainter(
                        entry: selectedEntry,
                        scale: scale,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  _ResolvedReferenceVisual? _resolveReferenceVisual(ColliderEntry entry) {
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

  _ResolvedReferenceAnimView? _effectiveReferenceAnimView(
    _ResolvedReferenceVisual reference,
  ) {
    final key = reference.resolveAnimKey(null);
    if (key == null) {
      return null;
    }
    return reference.animViewsByKey[key];
  }

  int _effectiveReferenceRow(_ResolvedReferenceAnimView reference) {
    final row = reference.defaultRow;
    return row < 0 ? 0 : row;
  }

  int _effectiveReferenceFrame(_ResolvedReferenceAnimView reference) {
    final minFrame = reference.defaultFrameStart;
    final maxFrame = reference.maxFrameIndex ?? 9999;
    return reference.defaultFrameStart.clamp(minFrame, maxFrame);
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

class _ColliderViewportPainter extends CustomPainter {
  const _ColliderViewportPainter({required this.entry, required this.scale});

  final ColliderEntry entry;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    final colliderCenter = _ViewportGeometry.colliderCenter(
      size,
      entry.offsetX,
      entry.offsetY,
      scale,
    );
    final colliderRect = _ViewportGeometry.colliderRect(
      center: colliderCenter,
      halfX: entry.halfX,
      halfY: entry.halfY,
      scale: scale,
    );

    final fillPaint = Paint()..color = const Color(0x5522D3EE);
    canvas.drawRect(colliderRect, fillPaint);

    final strokePaint = Paint()
      ..color = const Color(0xFF7CE5FF)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawRect(colliderRect, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _ColliderViewportPainter oldDelegate) {
    return oldDelegate.entry.halfX != entry.halfX ||
        oldDelegate.entry.halfY != entry.halfY ||
        oldDelegate.entry.offsetX != entry.offsetX ||
        oldDelegate.entry.offsetY != entry.offsetY ||
        oldDelegate.scale != scale;
  }
}

class _ViewportGeometry {
  static Offset canvasCenter(Size size) =>
      Offset(size.width * 0.5, size.height * 0.5);

  static Offset colliderCenter(
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

  static Rect colliderRect({
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
}
