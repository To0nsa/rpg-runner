import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../components/attention_marker.dart';
import '../../components/map_callout.dart';
import '../../components/map_label_button.dart';
import '../../components/map_viewport.dart';
import '../../l10n/app_localization.dart';
import '../../theme/ui_tokens.dart';

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
  static const assetPath = 'assets/images/maps/theodonis.jpg';

  @override
  Widget build(BuildContext context) => MapViewport(
    assetPath: assetPath,
    aspectRatio: 4 / 3,
    cacheWidth: 2048,
    overlayBuilder: _buildOverlays,
  );

  List<Widget> _buildOverlays(
    BuildContext context,
    Size viewport,
    Size scene,
    Rect visibleMap,
  ) {
    final ui = context.ui;
    Offset at(double x, double y) => Offset(scene.width * x, scene.height * y);
    final wide = viewport.width > viewport.height;
    final westWidth = wide
        ? math.min(240.0, scene.width * .26)
        : visibleMap.width * .58;
    final eastWidth = math.min(240.0, visibleMap.width);
    final libraryWidth = wide ? 240.0 : visibleMap.width * .40;
    // Pair northern portrait labels so straight leaders cannot cross their text.
    final westX = wide
        ? scene.width * .28 - westWidth / 2 - ui.space.xs
        : visibleMap.left + westWidth / 2;
    final eastX = wide
        ? scene.width * .54 + eastWidth / 2 + ui.space.xs
        : visibleMap.right - eastWidth / 2;
    final services = [
      (
        anchor: at(.337, .63),
        labelCenter: Offset(westX, at(0, wide ? .63 : .12).dy),
        maxLabelWidth: westWidth,
        label: context.l10n.townEquipment,
        markerLabel: context.l10n.townEquipmentMarker,
        icon: Icons.storefront,
        onPressed: onStorePressed,
        key: 'town-store-marker',
      ),
      (
        anchor: at(.395, .708),
        labelCenter: wide ? Offset(eastX, at(0, .708).dy) : at(.395, .82),
        maxLabelWidth: 240.0,
        label: context.l10n.townTraining,
        markerLabel: context.l10n.townTrainingMarker,
        icon: Icons.school_outlined,
        onPressed: onTrainingPressed,
        key: 'town-training-marker',
      ),
      (
        anchor: at(.47, .405),
        labelCenter: wide
            ? at(.47, .31)
            : Offset(visibleMap.right - libraryWidth / 2, at(0, .30).dy),
        maxLabelWidth: libraryWidth,
        label: context.l10n.uiLibrary,
        markerLabel: context.l10n.uiLibraryMarker,
        icon: Icons.menu_book,
        onPressed: onLibraryPressed,
        key: 'town-library-marker',
      ),
      (
        anchor: at(.482, .48),
        labelCenter: Offset(eastX, at(0, wide ? .48 : .56).dy),
        maxLabelWidth: eastWidth,
        label: context.l10n.uiHallOfHonour,
        markerLabel: context.l10n.uiHallOfHonourMarker,
        icon: Icons.account_balance,
        onPressed: onAchievementsPressed,
        key: 'town-achievements-marker',
      ),
    ];
    return [
      for (final service in services)
        Positioned(
          left: service.anchor.dx - ui.sizes.tapTarget / 2,
          top: service.anchor.dy - ui.sizes.tapTarget / 2,
          child: Semantics(
            label: service.markerLabel,
            button: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: service.onPressed,
              child: SizedBox(
                width: ui.sizes.tapTarget,
                height: ui.sizes.tapTarget,
              ),
            ),
          ),
        ),
      for (final service in services)
        MapCallout(
          anchor: service.anchor,
          labelCenter: service.labelCenter,
          maxLabelWidth: service.maxLabelWidth,
          visibleMap: visibleMap,
          straightLeader: true,
          child: AttentionMarker(
            visible:
                service.key == 'town-achievements-marker' &&
                hasAchievementRewards,
            semanticLabel: context.l10n.uiAchievementRewardsAvailable,
            child: MapLabelButton(
              key: ValueKey(service.key),
              label: service.label,
              icon: service.icon,
              onPressed: service.onPressed,
            ),
          ),
        ),
    ];
  }
}
