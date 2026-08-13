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
      material?.fillAssetPath,
      'assets/images/terrain/grass_dirt/fill.png',
    );
    expect(
      material?.top.base.assetPath,
      'assets/images/terrain/grass_dirt/surface.png',
    );
    expect(
      material?.top.detail?.assetPath,
      'assets/images/terrain/grass_dirt/foreground.png',
    );
    expect(material?.top.base.anchorY, 12);
    expect(material?.topStartCap?.assetPath, endsWith('cap_left.png'));
    expect(material?.topEndCap?.assetPath, endsWith('cap_right.png'));
    expect(decoded.catalog?.materials.map((entry) => entry.key), <String>[
      'grass_dirt',
    ]);
    expect(terrainSurfaceKindOptions, <String>['ground', 'obstacle']);
    expect(terrainMaterialPreviewForKey(decoded.catalog, 'missing'), isNull);
  });
}
