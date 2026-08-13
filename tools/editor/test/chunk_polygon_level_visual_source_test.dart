import 'package:flutter_test/flutter_test.dart';
import 'package:runner_editor/src/app/pages/shared/terrain_material_preview_catalog.dart';

void main() {
  test(
    'resolves the runtime grass-dirt preview assets from terrain metadata',
    () {
      final material = terrainMaterialPreviewAssetsForKey(' grass_dirt ');

      expect(
        material?.fillAssetPath,
        'assets/images/terrain/grass_dirt/fill.png',
      );
      expect(
        material?.surfaceAssetPath,
        'assets/images/terrain/grass_dirt/surface.png',
      );
      expect(
        material?.foregroundAssetPath,
        'assets/images/terrain/grass_dirt/foreground.png',
      );
      expect(material?.surfaceAnchorY, 12);
      expect(
        terrainMaterialPreviewCatalog.map((entry) => entry.materialKey),
        <String>['grass_dirt'],
      );
      expect(terrainSurfaceKindOptions, <String>['ground', 'obstacle']);
      expect(terrainMaterialPreviewAssetsForKey('missing'), isNull);
    },
  );
}
