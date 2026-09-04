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
      'assets/images/level/atlases/tiny_swords/ground.png',
    );
    expect(
      material?.top.base.region.assetPath,
      'assets/images/level/atlases/tiny_swords/ground.png',
    );
    expect(material?.top.detail?.region.assetPath, isNull);
    expect(
      (
        material?.top.base.region.x,
        material?.top.base.region.y,
        material?.top.base.region.width,
        material?.top.base.region.height,
      ),
      (32, 1, 32, 31),
    );
    expect(
      (
        material?.leftWall?.base.region.x,
        material?.leftWall?.base.region.width,
      ),
      (193, 31),
    );
    expect(material?.rightWall?.base.region.width, 31);
    expect(material?.underside?.base.region.height, 31);
    expect(material?.top.base.anchorY, 0);
    expect(material?.leftWall?.base.anchorY, 0);
    expect(material?.rightWall?.base.anchorY, 0);
    expect(material?.underside?.base.anchorY, 0);
    expect(material?.topStartCap?.anchorY, 0);
    expect(material?.topEndCap?.anchorY, 0);
    expect(material?.undersideStartCap?.anchorY, 0);
    expect(material?.undersideEndCap?.anchorY, 0);
    expect(
      (
        material?.topStartCap?.region.x,
        material?.topStartCap?.region.y,
        material?.topStartCap?.region.height,
      ),
      (0, 1, 31),
    );
    expect(
      (
        material?.topEndCap?.region.x,
        material?.topEndCap?.region.y,
        material?.topEndCap?.region.height,
      ),
      (64, 1, 31),
    );
    expect(
      (
        material?.undersideStartCap?.region.x,
        material?.undersideStartCap?.region.height,
      ),
      (64, 31),
    );
    expect(
      (
        material?.undersideEndCap?.region.x,
        material?.undersideEndCap?.region.height,
      ),
      (0, 31),
    );
    expect(decoded.catalog?.materials.map((entry) => entry.key), <String>[
      'grass_dirt',
    ]);
    expect(terrainSurfaceKindOptions, <String>['ground', 'obstacle']);
    expect(terrainMaterialPreviewForKey(decoded.catalog, 'missing'), isNull);
  });
}
