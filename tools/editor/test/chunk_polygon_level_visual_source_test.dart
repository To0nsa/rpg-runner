import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:runner_editor/src/app/pages/shared/terrain_material_preview_catalog.dart';

void main() {
  test('loads terrain previews from the canonical authored manifest', () {
    final workspaceRoot = p.normalize(
      p.absolute(p.join(Directory.current.path, '..', '..')),
    );
    final decoded = loadTerrainMaterialPreviewCatalog(workspaceRoot);
    final material = terrainMaterialPreviewForKey(
      decoded.catalog,
      ' grass_dirt ',
    );

    expect(decoded.issues, isEmpty);
    expect(
      material?.fill.assetPath,
      'assets/images/terrain/tx_tileset_ground/atlas.png',
    );
    expect(
      material?.top.base.region.assetPath,
      'assets/images/terrain/tx_tileset_ground/atlas.png',
    );
    expect(material?.top.detail?.region.assetPath, isNull);
    expect(material?.top.base.anchorY, 12);
    expect(material?.topStartCap?.region.x, 0);
    expect(material?.topEndCap?.region.x, 64);
    expect(decoded.catalog?.materials.map((entry) => entry.key), <String>[
      'grass_dirt',
    ]);
    expect(terrainSurfaceKindOptions, <String>['ground', 'obstacle']);
    expect(terrainMaterialPreviewForKey(decoded.catalog, 'missing'), isNull);
  });
}
