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
  static const assetPath = 'assets/Théodonis.jpg';

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
    // Keep the middle of the artwork free for building pins. Shallow viewports
    // use two columns; portrait labels have the full width for localized text.
    final wide = viewport.width > viewport.height;
    Offset labelAt(double x, double y) => Offset(
      visibleMap.left + visibleMap.width * x,
      visibleMap.top + visibleMap.height * y,
    );
    final store = wide ? labelAt(.23, .12) : labelAt(.5, .27);
    final library = wide ? labelAt(.77, .12) : labelAt(.5, .09);
    return [
      for (final service in [
        (at(.35, .49), context.l10n.townEquipmentMarker, onStorePressed),
        (at(.465, .60), context.l10n.townTrainingMarker, onTrainingPressed),
        (at(.47, .405), context.l10n.uiLibraryMarker, onLibraryPressed),
        (
          at(.395, .708),
          context.l10n.uiHallOfHonourMarker,
          onAchievementsPressed,
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
          onStorePressed,
          'town-store-marker',
          at(.35, .49),
        ),
        (
          wide ? labelAt(.77, .88) : labelAt(.5, .94),
          context.l10n.townTraining,
          Icons.school_outlined,
          onTrainingPressed,
          'town-training-marker',
          at(.465, .60),
        ),
        (
          library,
          context.l10n.uiLibrary,
          Icons.menu_book,
          onLibraryPressed,
          'town-library-marker',
          at(.47, .405),
        ),
        (
          wide ? labelAt(.23, .88) : labelAt(.5, .79),
          context.l10n.uiHallOfHonour,
          Icons.account_balance,
          onAchievementsPressed,
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
                hasAchievementRewards,
            semanticLabel: context.l10n.uiAchievementRewardsAvailable,
            child: MapLabelButton(
              key: ValueKey(service.$5),
              label: service.$2,
              icon: service.$3,
              onPressed: service.$4,
            ),
          ),
        ),
    ];
  }
}
