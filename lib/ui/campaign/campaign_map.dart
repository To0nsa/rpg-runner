import 'package:flutter/material.dart';

import '../components/map_location_layer.dart';
import '../components/map_label_button.dart';
import '../components/map_viewport.dart';
import 'campaign_catalog.dart';

const campaignRegionalMapAsset =
    'assets/images/maps/theodonis_region_unlabelled.png';

/// Fills the viewport with pannable artwork and anchored chapter navigation.
/// Initial labels respect the overlay toolbar and system insets.
class CampaignRegionalMap extends StatelessWidget {
  const CampaignRegionalMap({super.key, required this.onChapterPressed});

  final ValueChanged<CampaignChapter> onChapterPressed;

  @override
  Widget build(BuildContext context) => MapViewport(
    assetPath: CampaignCatalog.mapAssetPath,
    aspectRatio: CampaignCatalog.mapAspectRatio,
    overlayBuilder: (context, viewport, scene, visibleMap) {
      final language = Localizations.localeOf(context).languageCode;
      return [
        MapLocationLayer(
          anchors: [
            for (final chapter in CampaignCatalog.chapters)
              Offset(scene.width * chapter.mapX, scene.height * chapter.mapY),
          ],
          visibleMap: visibleMap,
          children: [
            for (final chapter in CampaignCatalog.chapters)
              MapLabelButton(
                label: chapter.title(language),
                icon: Icons.flag_outlined,
                onPressed: () => onChapterPressed(chapter),
              ),
          ],
        ),
      ];
    },
  );
}

/// A stable crop centered on Val Outpost in the existing regional artwork.
class ValOutpostArtwork extends StatelessWidget {
  const ValOutpostArtwork({super.key});
  @override
  Widget build(BuildContext context) => ClipRect(
    child: FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: 460,
        height: 270,
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned(
              left: 230 - 1361 * .8,
              top: 135 - 1156 * .595,
              width: 1361,
              height: 1156,
              child: Image.asset(campaignRegionalMapAsset, fit: BoxFit.fill),
            ),
          ],
        ),
      ),
    ),
  );
}
