import 'package:rpg_runner/ui/l10n/app_localization.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../components/map_label_button.dart';
import '../../components/attention_marker.dart';
import '../../theme/ui_tokens.dart';
import '../../theme/ui_world_palette.dart';
import 'map_callout.dart';

/// Artwork and service anchors share one pannable scene, including cropped edges.
class TownMap extends StatelessWidget {
  const TownMap({
    super.key,
    required this.onStorePressed,
    required this.onTrainingPressed,
    required this.onLibraryPressed,
    required this.onAchievementsPressed,
    this.hasAchievementRewards = false,
  });
  final VoidCallback onStorePressed;
  final VoidCallback onTrainingPressed;
  final VoidCallback onLibraryPressed;
  final VoidCallback onAchievementsPressed;
  final bool hasAchievementRewards;
  static const assetPath = 'assets/Théodonis.jpg';

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => _TownMapViewport(
      viewport: constraints.biggest,
      onStorePressed: onStorePressed,
      onTrainingPressed: onTrainingPressed,
      onLibraryPressed: onLibraryPressed,
      onAchievementsPressed: onAchievementsPressed,
      hasAchievementRewards: hasAchievementRewards,
    ),
  );
}

class _TownMapViewport extends StatefulWidget {
  const _TownMapViewport({
    required this.viewport,
    required this.onStorePressed,
    required this.onTrainingPressed,
    required this.onLibraryPressed,
    required this.onAchievementsPressed,
    required this.hasAchievementRewards,
  });
  final Size viewport;
  final VoidCallback onStorePressed, onLibraryPressed, onTrainingPressed;
  final VoidCallback onAchievementsPressed;
  final bool hasAchievementRewards;

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
    // Inset the initial callouts below the overlay toolbar while the artwork
    // continues to fill the entire viewport.
    final visibleMap = MediaQuery.paddingOf(context)
        .deflateRect(
          Rect.fromCenter(
            center: scene.center(Offset.zero),
            width: widget.viewport.width,
            height: widget.viewport.height,
          ),
        )
        .deflate(ui.space.xs);
    // Keep the middle of the artwork free for building pins. Shallow viewports
    // use two columns; portrait labels have the full width for localized text.
    final wide = widget.viewport.width > widget.viewport.height;
    Offset labelAt(double x, double y) => Offset(
      visibleMap.left + visibleMap.width * x,
      visibleMap.top + visibleMap.height * y,
    );
    final store = wide ? labelAt(.23, .12) : labelAt(.5, .27);
    final library = wide ? labelAt(.77, .12) : labelAt(.5, .09);
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
                    at(.35, .49),
                    context.l10n.townEquipmentMarker,
                    widget.onStorePressed,
                  ),
                  (
                    at(.465, .60),
                    context.l10n.townTrainingMarker,
                    widget.onTrainingPressed,
                  ),
                  (
                    at(.47, .405),
                    context.l10n.uiLibraryMarker,
                    widget.onLibraryPressed,
                  ),
                  (
                    at(.395, .708),
                    context.l10n.uiHallOfHonourMarker,
                    widget.onAchievementsPressed,
                  ),
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
                for (final service in [
                  (
                    store,
                    context.l10n.townEquipment,
                    Icons.storefront,
                    widget.onStorePressed,
                    'town-store-marker',
                    at(.35, .49),
                  ),
                  (
                    wide ? labelAt(.77, .88) : labelAt(.5, .94),
                    context.l10n.townTraining,
                    Icons.school_outlined,
                    widget.onTrainingPressed,
                    'town-training-marker',
                    at(.465, .60),
                  ),
                  (
                    library,
                    context.l10n.uiLibrary,
                    Icons.menu_book,
                    widget.onLibraryPressed,
                    'town-library-marker',
                    at(.47, .405),
                  ),
                  (
                    wide ? labelAt(.23, .88) : labelAt(.5, .79),
                    context.l10n.uiHallOfHonour,
                    Icons.account_balance,
                    widget.onAchievementsPressed,
                    'town-achievements-marker',
                    // Southern courtyard building selected by the owner.
                    at(.395, .708),
                  ),
                ])
                  MapCallout(
                    anchor: service.$6,
                    labelCenter: service.$1,
                    visibleMap: visibleMap,
                    maxLabelWidth: wide ? visibleMap.width * .44 : null,
                    child: AttentionMarker(
                      visible:
                          service.$5 == 'town-achievements-marker' &&
                          widget.hasAchievementRewards,
                      semanticLabel: context.l10n.uiAchievementRewardsAvailable,
                      child: MapLabelButton(
                        key: ValueKey(service.$5),
                        label: service.$2,
                        icon: service.$3,
                        onPressed: service.$4,
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
    );
  }
}
