import 'package:flutter/material.dart';

import '../../core/accessories/accessory_id.dart';
import '../../core/meta/gear_slot.dart';
import '../../core/projectiles/projectile_item_id.dart';
import '../../core/spells/spell_book_id.dart';
import '../../core/weapons/weapon_id.dart';
import '../icons/throwing_weapon_asset.dart';
import '../icons/ui_icon_coords.dart';
import '../icons/ui_icon_tile.dart';

/// Shared gear icon renderer for loadout screens and gear picker UI.
///
/// The [id] type depends on [slot]:
/// - main/offhand -> [WeaponId]
/// - throwing -> [ProjectileItemId]
/// - spellbook -> [SpellBookId]
/// - accessory -> [AccessoryId]
class GearIcon extends StatelessWidget {
  const GearIcon({
    super.key,
    required this.slot,
    required this.id,
    this.size = 40,
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
