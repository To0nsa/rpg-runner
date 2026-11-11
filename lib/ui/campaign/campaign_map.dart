import 'package:flutter/material.dart';

const campaignRegionalMapAsset =
    'assets/images/maps/theodonis_region_unlabelled.png';

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
