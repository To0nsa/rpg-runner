import 'package:flutter/material.dart';

import '../../../../core/accessories/accessory_id.dart';
import '../../../../core/meta/gear_slot.dart';
import '../../../../core/projectiles/projectile_item_id.dart';
import '../../../../core/spells/spell_book_id.dart';
import '../../../../core/weapons/weapon_id.dart';
import '../../../icons/throwing_weapon_asset.dart';
import '../../../icons/ui_icon_coords.dart';
import '../../../icons/ui_icon_tile.dart';

/// Tiny status marker used for selected/equipped indicators.
class StateDot extends StatelessWidget {
  const StateDot({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// Shared gear icon renderer used by both left and right panels.
///
/// The mapping from slot/id to asset source is centralized here so visual
/// changes apply consistently across the gear picker.
class GearIcon extends StatelessWidget {
  const GearIcon({
    super.key,
    required this.slot,
    required this.id,
    this.size = 32,
  });

  final GearSlot slot;
  final Object id;
  final double size;

  @override
  Widget build(BuildContext context) {
    Widget child;
    switch (slot) {
      case GearSlot.mainWeapon:
      case GearSlot.offhandWeapon:
        final weaponId = id as WeaponId;
        final coords = uiIconCoordsForWeapon(weaponId);
        child = coords == null
            ? const SizedBox.shrink()
            : UiIconTile(coords: coords, size: size);
        break;
      case GearSlot.spellBook:
        final bookId = id as SpellBookId;
        final coords = uiIconCoordsForSpellBook(bookId);
        child = coords == null
            ? const SizedBox.shrink()
            : UiIconTile(coords: coords, size: size);
        break;
      case GearSlot.accessory:
        final accessoryId = id as AccessoryId;
        final coords = uiIconCoordsForAccessory(accessoryId);
        child = coords == null
            ? const SizedBox.shrink()
            : UiIconTile(coords: coords, size: size);
        break;
      case GearSlot.throwingWeapon:
        final itemId = id as ProjectileItemId;
        final path = throwingWeaponAssetPath(itemId);
        child = path == null
            ? const SizedBox.shrink()
            : Image.asset(path, width: size, height: size);
        break;
    }

    return SizedBox.square(dimension: size, child: child);
  }
}

/// Layout parameters for the fixed-size candidate grid.
class CandidateGridSpec {
  const CandidateGridSpec({
    required this.crossAxisCount,
    required this.mainAxisExtent,
    required this.spacing,
  });

  final int crossAxisCount;
  final double mainAxisExtent;
  final double spacing;
}

/// Computes a dense, non-scrollable grid spec for the right panel.
///
/// Tiles use a fixed extent; only column count adapts to available width.
CandidateGridSpec candidateGridSpecForAvailableSpace({
  required int itemCount,
  required double availableWidth,
  required double availableHeight,
  required double spacing,
}) {
  const tileExtent = 64.0;
  if (itemCount <= 0 || availableWidth <= 0 || availableHeight <= 0) {
    return CandidateGridSpec(
      crossAxisCount: 1,
      mainAxisExtent: tileExtent,
      spacing: spacing,
    );
  }

  const minTileWidth = tileExtent;
  final maxColumnsByWidth =
      ((availableWidth + spacing) / (minTileWidth + spacing)).floor().clamp(
        1,
        999,
      );

  return CandidateGridSpec(
    crossAxisCount: maxColumnsByWidth,
    mainAxisExtent: tileExtent,
    spacing: spacing,
  );
}
