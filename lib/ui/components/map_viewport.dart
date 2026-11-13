import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/app_localization.dart';
import '../theme/ui_tokens.dart';
import '../theme/ui_world_palette.dart';
import 'map_label_button.dart';

/// Builds scene overlays in logical pixels. [visibleMap] is the initial safe
/// viewport in scene coordinates, including toolbar, rail and system insets.
typedef MapOverlayBuilder = List<Widget> Function(
  BuildContext context,
  Size viewport,
  Size scene,
  Rect visibleMap,
);

/// Covers a bounded viewport with aspect-preserving map art, pan/zoom and reset.
///
/// Overlays move with the artwork. Their rebuilds retain the current transform;
/// changing the viewport, artwork or framing restores the initial crop.
class MapViewport extends StatelessWidget {
  const MapViewport({
    super.key,
    required this.assetPath,
    required this.aspectRatio,
    required this.overlayBuilder,
    this.initialFocus = const Offset(.5, .5),
    this.cacheWidth,
    this.imageProvider,
  }) : assert(aspectRatio > 0);

  final String assetPath;
  final double aspectRatio;
  final MapOverlayBuilder overlayBuilder;

  /// Normalized image point to center initially, clamped to avoid empty edges.
  final Offset initialFocus;

  /// Optional image decode width in pixels to bound artwork memory.
  final int? cacheWidth;

  /// Authoring previews may supply unsaved repository artwork while using the
  /// exact game framing and interaction. Normal game callers use bundled assets.
  final ImageProvider? imageProvider;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final viewport = constraints.biggest;
      final width = math.max(viewport.width, viewport.height * aspectRatio);
      final scene = Size(width, width / aspectRatio);
      final initialOffset = Offset(
        (viewport.width / 2 - scene.width * initialFocus.dx).clamp(
          viewport.width - scene.width,
          0.0,
        ),
        (viewport.height / 2 - scene.height * initialFocus.dy).clamp(
          viewport.height - scene.height,
          0.0,
        ),
      );
      final ui = context.ui;
      // Insets constrain initial labels, not artwork or geographic pins.
      final visibleMap = MediaQuery.paddingOf(context)
          .deflateRect(-initialOffset & viewport)
          .deflate(ui.space.xs);

      return _MapViewportScene(
        key: ValueKey(assetPath),
        viewport: viewport,
        scene: scene,
        initialOffset: initialOffset,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image(
              image: ResizeImage.resizeIfNeeded(
                cacheWidth,
                null,
                imageProvider ?? AssetImage(assetPath),
              ),
              fit: BoxFit.fill,
              excludeFromSemantics: true,
              errorBuilder: (_, _, _) =>
                  ColoredBox(color: ui.colors.background),
            ),
            ...overlayBuilder(context, viewport, scene, visibleMap),
          ],
        ),
      );
    },
  );
}

class _MapViewportScene extends StatefulWidget {
  const _MapViewportScene({
    super.key,
    required this.viewport,
    required this.scene,
    required this.initialOffset,
    required this.child,
  });

  final Size viewport, scene;
  final Offset initialOffset;
  final Widget child;

  @override
  State<_MapViewportScene> createState() => _MapViewportSceneState();
}

class _MapViewportSceneState extends State<_MapViewportScene> {
  late final TransformationController _transform;

  Matrix4 get _initialTransform => Matrix4.identity()
    ..setTranslationRaw(widget.initialOffset.dx, widget.initialOffset.dy, 0);

  @override
  void initState() {
    super.initState();
    _transform = TransformationController(_initialTransform);
  }

  @override
  void didUpdateWidget(covariant _MapViewportScene oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.viewport != oldWidget.viewport ||
        widget.scene != oldWidget.scene ||
        widget.initialOffset != oldWidget.initialOffset) {
      _transform.value = _initialTransform;
    }
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return ColoredBox(
      color: ui.colors.background,
      child: Stack(
        fit: StackFit.expand,
        children: [
          InteractiveViewer(
            transformationController: _transform,
            constrained: false,
            alignment: Alignment.topLeft,
            minScale: 1,
            maxScale: 3,
            child: SizedBox(
              width: widget.scene.width,
              height: widget.scene.height,
              child: widget.child,
            ),
          ),
          Positioned(
            right: ui.space.xs,
            top: ui.space.xs,
            child: SafeArea(
              child: IconButton(
                tooltip: context.l10n.uiResetMap,
                onPressed: () => _transform.value = _initialTransform,
                icon: const Icon(
                  Icons.center_focus_strong,
                  color: UiWorldPalette.mist200,
                  shadows: mapLabelShadows,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
