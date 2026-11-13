import 'package:flutter/widgets.dart';
import 'package:runner_core/pickups/pickup_render_catalog.dart';
import 'package:runner_core/snapshots/entity_render_snapshot.dart';
import 'package:runner_core/snapshots/enums.dart';

import 'ui_icon_coords.dart';
import 'ui_icon_tile.dart';

/// Static first frame of the gameplay coin, sharing Flutter's asset image cache.
/// The containing amount/action supplies the currency's accessible label.
class GoldCoin extends StatelessWidget {
  const GoldCoin({super.key, required this.size});

  /// Square icon footprint in logical pixels; independent of gameplay scale.
  final double size;
  static final _art = const PickupRenderCatalog().get(
    PickupVariant.collectible,
  );

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: UiIconTile(
      coords: const UiIconCoords(0, 0),
      size: size,
      assetPath: 'assets/images/${_art.sourcesByKey[AnimKey.idle]!}',
      tilePx: _art.frameWidth,
    ),
  );
}
