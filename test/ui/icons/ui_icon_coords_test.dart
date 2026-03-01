import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/core/weapons/weapon_id.dart';
import 'package:rpg_runner/ui/icons/ui_icon_coords.dart';

void main() {
  group('ui weapon icon mapping', () {
    test('maps sprite-sheet swords using authored coordinates', () {
      final plainsteel = uiIconSpecForWeapon(WeaponId.plainsteel);
      final cinderedge = uiIconSpecForWeapon(WeaponId.cinderedge);
      final sunlitVow = uiIconSpecForWeapon(WeaponId.sunlitVow);

      expect(plainsteel.imageAssetPath, isNull);
      expect(plainsteel.coords?.row, 5);
      expect(plainsteel.coords?.col, 1);
      expect(
        plainsteel.spriteAssetPath,
        'assets/images/icons/gear-icons/sword/transparentIcons.png',
      );

      expect(cinderedge.coords?.row, 5);
      expect(cinderedge.coords?.col, 7);
      expect(sunlitVow.coords?.row, 5);
      expect(sunlitVow.coords?.col, 4);
    });

    test('maps dedicated sword png assets', () {
      final waspfang = uiIconSpecForWeapon(WeaponId.waspfang);
      final graveglass = uiIconSpecForWeapon(WeaponId.graveglass);
      final duelistsOath = uiIconSpecForWeapon(WeaponId.duelistsOath);

      expect(waspfang.coords, isNull);
      expect(
        waspfang.imageAssetPath,
        'assets/images/icons/gear-icons/sword/waspfang.png',
      );
      expect(
        graveglass.imageAssetPath,
        'assets/images/icons/gear-icons/sword/graveglass.png',
      );
      expect(
        duelistsOath.imageAssetPath,
        'assets/images/icons/gear-icons/sword/duelistsOath.png',
      );
    });
  });
}
