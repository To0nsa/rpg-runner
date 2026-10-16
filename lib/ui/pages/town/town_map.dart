import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/ui_tokens.dart';
import '../../theme/ui_world_palette.dart';
import 'map_callout.dart';

/// Artwork and service anchors share one pannable scene, including cropped edges.
class TownMap extends StatelessWidget {
  const TownMap({
    super.key,
    required this.onStorePressed,
    required this.onLibraryPressed,
  });
  final VoidCallback onStorePressed;
  final VoidCallback onLibraryPressed;
  static const assetPath = 'assets/Théodonis.jpg';

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => _TownMapViewport(
      viewport: constraints.biggest,
      onStorePressed: onStorePressed,
      onLibraryPressed: onLibraryPressed,
    ),
  );
}

class _TownMapViewport extends StatefulWidget {
  const _TownMapViewport({
    required this.viewport,
    required this.onStorePressed,
    required this.onLibraryPressed,
  });
  final Size viewport;
  final VoidCallback onStorePressed, onLibraryPressed;

  @override
  State<_TownMapViewport> createState() => _TownMapViewportState();
}

class _TownMapViewportState extends State<_TownMapViewport> {
  late final TransformationController _transform;
  Size get _scene {
    final width = math.max(
      widget.viewport.width,
      widget.viewport.height * 4 / 3,
    );
    return Size(width, width * 3 / 4);
  }

  Matrix4 get _initialTransform => Matrix4.identity()
    ..setTranslationRaw(
      (widget.viewport.width - _scene.width) / 2,
      (widget.viewport.height - _scene.height) / 2,
      0,
    );

  @override
  void initState() {
    super.initState();
    _transform = TransformationController(_initialTransform);
  }

  @override
  void didUpdateWidget(covariant _TownMapViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.viewport != oldWidget.viewport) {
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
    final scene = _scene;
    Offset at(double x, double y) => Offset(scene.width * x, scene.height * y);
    final store = at(.25, .61);
    final library = at(.64, .41);
    final visibleMap = Rect.fromCenter(
      center: scene.center(Offset.zero),
      width: widget.viewport.width,
      height: widget.viewport.height,
    ).deflate(ui.space.xs);
    return Stack(
      fit: StackFit.expand,
      children: [
        InteractiveViewer(
          transformationController: _transform,
          constrained: false,
          alignment: Alignment.topLeft,
          minScale: 1,
          maxScale: 3,
          child: SizedBox(
            width: scene.width,
            height: scene.height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  TownMap.assetPath,
                  fit: BoxFit.fill,
                  cacheWidth: 2048,
                  excludeFromSemantics: true,
                  errorBuilder: (_, _, _) =>
                      ColoredBox(color: ui.colors.background),
                ),
                for (final service in [
                  (
                    store,
                    'Store',
                    Icons.storefront,
                    widget.onStorePressed,
                    'town-store-marker',
                    at(.35, .49),
                  ),
                  (
                    library,
                    'Library',
                    Icons.menu_book,
                    widget.onLibraryPressed,
                    'town-library-marker',
                    at(.47, .405),
                  ),
                ])
                  MapCallout(
                    anchor: service.$6,
                    labelCenter: service.$1,
                    visibleMap: visibleMap,
                    child: _MapService(
                      key: ValueKey(service.$5),
                      label: service.$2,
                      icon: service.$3,
                      onPressed: service.$4,
                    ),
                  ),
                for (final service in [
                  (at(.35, .49), 'Store marker', widget.onStorePressed),
                  (at(.47, .405), 'Library marker', widget.onLibraryPressed),
                ])
                  Positioned(
                    left: service.$1.dx - ui.sizes.tapTarget / 2,
                    top: service.$1.dy - ui.sizes.tapTarget / 2,
                    child: Semantics(
                      label: service.$2,
                      button: true,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: service.$3,
                        child: SizedBox(
                          width: ui.sizes.tapTarget,
                          height: ui.sizes.tapTarget,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Positioned(
          right: ui.space.xs,
          top: ui.space.xs,
          child: SafeArea(
            top: false,
            child: IconButton(
              tooltip: 'Reset map',
              onPressed: () => _transform.value = _initialTransform,
              icon: const Icon(
                Icons.center_focus_strong,
                color: UiWorldPalette.mist200,
                shadows: _mapShadows,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

const _mapShadows = [
  Shadow(color: UiWorldPalette.ink900, blurRadius: 3),
  Shadow(color: UiWorldPalette.ink900, blurRadius: 2, offset: Offset(0, 1)),
];

class _MapService extends StatelessWidget {
  const _MapService({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  });
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: UiWorldPalette.mist200,
        minimumSize: Size(ui.sizes.tapTarget, ui.sizes.tapTarget),
        padding: EdgeInsets.symmetric(horizontal: ui.space.xs),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22, shadows: _mapShadows),
          SizedBox(width: ui.space.xxs),
          Text(
            label,
            style: ui.text.headline.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: UiWorldPalette.mist200,
              shadows: _mapShadows,
            ),
          ),
        ],
      ),
    );
  }
}
