import 'package:rpg_runner/ui/l10n/app_localization.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:runner_core/levels/level_id.dart';

import '../../codex/codex_catalog.dart';
import '../../components/map_label_button.dart';
import '../../state/ownership/codex_progress.dart';
import '../../theme/ui_tokens.dart';
import '../../theme/ui_world_palette.dart';
import '../town/map_callout.dart';

/// Places Flutter labels and discovery targets over the unlabelled regional map.
class LocationMap extends StatelessWidget {
  const LocationMap({
    super.key,
    required this.progress,
    required this.onLocationPressed,
  });

  static const assetPath = 'assets/images/maps/theodonis_region_unlabelled.png';
  static const aspectRatio = 1361 / 1156;

  final CodexProgress progress;
  final ValueChanged<LevelId> onLocationPressed;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => _LocationMapViewport(
      viewport: constraints.biggest,
      progress: progress,
      onLocationPressed: onLocationPressed,
    ),
  );
}

class _LocationMapViewport extends StatefulWidget {
  const _LocationMapViewport({
    required this.viewport,
    required this.progress,
    required this.onLocationPressed,
  });

  final Size viewport;
  final CodexProgress progress;
  final ValueChanged<LevelId> onLocationPressed;

  @override
  State<_LocationMapViewport> createState() => _LocationMapViewportState();
}

class _LocationMapViewportState extends State<_LocationMapViewport> {
  late final TransformationController _transform;

  Size get _scene {
    final width = math.max(
      widget.viewport.width,
      widget.viewport.height * LocationMap.aspectRatio,
    );
    return Size(width, width / LocationMap.aspectRatio);
  }

  Matrix4 get _initialTransform {
    final scene = _scene;
    final x = (widget.viewport.width - scene.width) / 2;
    final focusY = widget.viewport.height / 2 - scene.height * .39;
    final y = focusY.clamp(widget.viewport.height - scene.height, 0.0);
    return Matrix4.identity()..setTranslationRaw(x, y, 0);
  }

  @override
  void initState() {
    super.initState();
    _transform = TransformationController(_initialTransform);
  }

  @override
  void didUpdateWidget(covariant _LocationMapViewport oldWidget) {
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
    final initial = _initialTransform;
    // Keep initial labels outside the toolbar and navigation rail; their pins
    // retain image coordinates and can be revealed by panning cropped edges.
    final visibleMap = MediaQuery.paddingOf(context)
        .deflateRect(
          Rect.fromLTWH(
            -initial.storage[12],
            -initial.storage[13],
            widget.viewport.width,
            widget.viewport.height,
          ),
        )
        .deflate(ui.space.xs);

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
              width: scene.width,
              height: scene.height,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    LocationMap.assetPath,
                    fit: BoxFit.fill,
                    excludeFromSemantics: true,
                    errorBuilder: (_, _, _) =>
                        ColoredBox(color: ui.colors.background),
                  ),
                  MapCallout(
                    anchor: at(.16, .145),
                    labelCenter: at(.16, .35),
                    visibleMap: visibleMap,
                    child: IgnorePointer(
                      child: SizedBox(
                        width: 160,
                        height: 36,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: _MapText(context.l10n.townName, size: 20),
                        ),
                      ),
                    ),
                  ),
                  for (final place in [
                    (LevelId.field, at(.34, .145), at(.43, .22)),
                    (LevelId.forest, at(.80, .595), at(.68, .52)),
                  ]) ...[
                    MapCallout(
                      anchor: place.$2,
                      labelCenter: place.$3,
                      visibleMap: visibleMap,
                      child: MapLabelButton(
                        key: ValueKey('codex-level-${place.$1.name}'),
                        label: CodexCatalog.levelName(place.$1, context.l10n),
                        icon:
                            CodexCatalog.levelUnlocked(
                              widget.progress,
                              place.$1,
                            )
                            ? Icons.place_outlined
                            : Icons.lock_outline,
                        semanticsLabel: context.l10n.codexLocationSemantics(
                          level: CodexCatalog.levelName(place.$1, context.l10n),
                          state:
                              CodexCatalog.levelUnlocked(
                                widget.progress,
                                place.$1,
                              )
                              ? 'open'
                              : 'locked',
                        ),
                        onPressed: () => widget.onLocationPressed(place.$1),
                      ),
                    ),
                    Positioned(
                      left: place.$2.dx - 32,
                      top: place.$2.dy - 32,
                      child: Semantics(
                        label: context.l10n.codexMapMarker(
                          level: CodexCatalog.levelName(place.$1, context.l10n),
                        ),
                        button: true,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => widget.onLocationPressed(place.$1),
                          child: const SizedBox(width: 64, height: 64),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
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

class _MapText extends StatelessWidget {
  const _MapText(this.text, {required this.size});

  final String text;
  final double size;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: context.ui.text.headline.copyWith(
      fontSize: size,
      fontWeight: FontWeight.w700,
      color: UiWorldPalette.mist200,
      shadows: mapLabelShadows,
    ),
  );
}
