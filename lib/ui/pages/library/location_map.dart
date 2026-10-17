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

  double get _fitScale => math.min(
    widget.viewport.width / _scene.width,
    widget.viewport.height / _scene.height,
  );

  Matrix4 get _initialTransform {
    final scene = _scene;
    final scale = widget.viewport.width < widget.viewport.height
        ? _fitScale
        : 1.0;
    final x = (widget.viewport.width - scene.width * scale) / 2;
    final centeredY = (widget.viewport.height - scene.height * scale) / 2;
    final focusY = widget.viewport.height / 2 - scene.height * .39 * scale;
    final y = scale == 1
        ? focusY.clamp(widget.viewport.height - scene.height, 0.0)
        : centeredY;
    return Matrix4.identity()
      ..setEntry(0, 0, scale)
      ..setEntry(1, 1, scale)
      ..setTranslationRaw(x, y, 0);
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

    return ColoredBox(
      color: ui.colors.background,
      child: Stack(
        fit: StackFit.expand,
        children: [
          InteractiveViewer(
            transformationController: _transform,
            constrained: false,
            alignment: Alignment.topLeft,
            minScale: _fitScale,
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
                  _MapLabel(
                    center: at(.16, .145),
                    text: 'Théodonis',
                    width: 160,
                  ),
                  _MapLabel(
                    center: at(.35, .035),
                    text: 'Quartier Est',
                    width: 170,
                  ),
                  _MapLabel(center: at(.31, .43), text: 'Hagen', width: 100),
                  _MapLabel(
                    center: at(.39, .545),
                    text: 'Veymeringen',
                    width: 180,
                  ),
                  _MapLabel(
                    center: at(.77, .78),
                    text: 'Mont aux Étoiles',
                    width: 220,
                  ),
                  Positioned(
                    left: scene.width * .2 - 20,
                    top: scene.height * .36,
                    child: const IgnorePointer(
                      child: RotatedBox(
                        quarterTurns: 1,
                        child: _MapText('Vosga', size: 20),
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
                      visibleMap: Offset.zero & scene,
                      child: MapLabelButton(
                        key: ValueKey('codex-level-${place.$1.name}'),
                        label: CodexCatalog.levelName(place.$1),
                        icon:
                            CodexCatalog.levelUnlocked(
                              widget.progress,
                              place.$1,
                            )
                            ? Icons.place_outlined
                            : Icons.lock_outline,
                        semanticsLabel:
                            '${CodexCatalog.levelName(place.$1)}, ${CodexCatalog.levelUnlocked(widget.progress, place.$1) ? 'open' : 'locked'}',
                        onPressed: () => widget.onLocationPressed(place.$1),
                      ),
                    ),
                    Positioned(
                      left: place.$2.dx - 32,
                      top: place.$2.dy - 32,
                      child: Semantics(
                        label: '${CodexCatalog.levelName(place.$1)} map marker',
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
            child: IconButton(
              tooltip: 'Reset map',
              onPressed: () => _transform.value = _initialTransform,
              icon: const Icon(
                Icons.center_focus_strong,
                color: UiWorldPalette.mist200,
                shadows: mapLabelShadows,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapLabel extends StatelessWidget {
  const _MapLabel({
    required this.center,
    required this.text,
    required this.width,
  });

  final Offset center;
  final String text;
  final double width;

  @override
  Widget build(BuildContext context) => Positioned(
    left: center.dx - width / 2,
    top: center.dy - 18,
    width: width,
    height: 36,
    child: IgnorePointer(
      child: FittedBox(fit: BoxFit.scaleDown, child: _MapText(text, size: 20)),
    ),
  );
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
