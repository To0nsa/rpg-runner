import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:runner_core/levels/level_id.dart';

import '../../codex/codex_catalog.dart';
import '../../components/map_callout.dart';
import '../../components/map_label_button.dart';
import '../../components/map_viewport.dart';
import '../../l10n/app_localization.dart';
import '../../state/ownership/codex_progress.dart';
import '../../theme/ui_tokens.dart';
import '../../theme/ui_world_palette.dart';

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
  Widget build(BuildContext context) => MapViewport(
    assetPath: assetPath,
    aspectRatio: aspectRatio,
    initialFocus: const Offset(.5, .39),
    overlayBuilder: _buildOverlays,
  );

  List<Widget> _buildOverlays(
    BuildContext context,
    Size viewport,
    Size scene,
    Rect visibleMap,
  ) {
    Offset at(double x, double y) => Offset(scene.width * x, scene.height * y);
    return [
      MapCallout(
        anchor: at(.16, .145),
        labelCenter: at(.16, .28),
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
        (LevelId.field, at(.34, .145), at(.60, .14)),
        (LevelId.forest, at(.80, .595), at(.68, .52)),
      ]) ...[
        MapCallout(
          anchor: place.$2,
          labelCenter: place.$3,
          visibleMap: visibleMap,
          // Keep enlarged farm text clear of the nearby city label.
          maxLabelWidth: place.$1 == LevelId.field
              ? math.min(visibleMap.width, scene.width * .36)
              : null,
          child: MapLabelButton(
            key: ValueKey('codex-level-${place.$1.name}'),
            label: CodexCatalog.levelName(place.$1, context.l10n),
            icon: CodexCatalog.levelUnlocked(progress, place.$1)
                ? Icons.place_outlined
                : Icons.lock_outline,
            semanticsLabel: context.l10n.codexLocationSemantics(
              level: CodexCatalog.levelName(place.$1, context.l10n),
              state: CodexCatalog.levelUnlocked(progress, place.$1)
                  ? 'open'
                  : 'locked',
            ),
            onPressed: () => onLocationPressed(place.$1),
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
              onTap: () => onLocationPressed(place.$1),
              child: const SizedBox(width: 64, height: 64),
            ),
          ),
        ),
      ],
    ];
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
