import 'package:flutter/material.dart';

import 'item_icon_ids.dart';
import 'projectile_icon_frame.dart';
import 'ui_icon_coords.dart';
import 'ui_icon_tile.dart';

/// Preview a canonical art choice before an authored item ID has been compiled.
/// Art choices are independent from other items' current icon assignments.
class CanonicalItemIcon extends StatelessWidget {
  const CanonicalItemIcon({
    super.key,
    required this.category,
    required this.icon,
    this.size = 40,
  });
  final String category, icon;
  final double size;
  @override
  Widget build(BuildContext context) {
    if (category == 'projectile') {
      return ProjectileIconFrame.canonical(
        icon: CanonicalProjectileIcon.values.byName(icon),
        size: size,
      );
    }
    final UiWeaponIconSpec spec;
    if (category == 'weapon') {
      spec = canonicalWeaponIconSpec(CanonicalWeaponIcon.values.byName(icon));
    } else if (category == 'spellBook') {
      final choice = CanonicalSpellBookIcon.values.byName(icon),
          image = canonicalSpellBookImage(choice);
      spec = image != null
          ? UiWeaponIconSpec.image(image)
          : UiWeaponIconSpec.sprite(
              coords: canonicalSpellBookIconCoords(choice),
              spriteAssetPath:
                  'assets/images/icons/gear-icons/sword/transparentIcons.png',
            );
    } else {
      return UiIconTile(
        coords: canonicalAccessoryIconCoords(
          CanonicalAccessoryIcon.values.byName(icon),
        )!,
        size: size,
      );
    }
    if (spec.imageAssetPath case final path?) {
      return Image.asset(
        path,
        width: size,
        height: size,
        filterQuality: FilterQuality.none,
      );
    }
    return UiIconTile(
      coords: spec.coords!,
      assetPath: spec.spriteAssetPath!,
      tilePx: spec.tilePx,
      size: size,
    );
  }
}
