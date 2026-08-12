import 'package:flutter_test/flutter_test.dart';
import 'package:runner_editor/src/app/pages/chunkCreator/v2/chunk_polygon_level_visual_source.dart';

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
      expect(terrainMaterialPreviewAssetsForKey('missing'), isNull);
    },
  );
}
