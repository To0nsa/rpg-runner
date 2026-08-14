import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/terrain_material_generation.dart';

void main() {
  test(
    'authored terrain material manifest and generated registry are current',
    () async {
      final result = await buildTerrainMaterialRegistry();

      expect(result.issues, isEmpty);
      expect(
        result.catalog!.materials.map((material) => material.key),
        <String>['grass_dirt'],
      );
      expect(
        result.output!.content,
        File(terrainMaterialRegistryOutputPath).readAsStringSync(),
      );
    },
  );

  test('missing referenced images block registry generation', () async {
    final root = Directory.systemTemp.createTempSync('terrain_material_defs_');
    addTearDown(() => root.deleteSync(recursive: true));
    final defs = File('${root.path}/terrain_material_defs.json');
    await defs.writeAsString('''
{
  "schemaVersion": 3,
  "materials": [
    {
      "key": "stone",
      "displayName": "Stone",
      "revision": 1,
      "fill": {
        "assetPath": "assets/images/terrain/stone/atlas.png",
        "x": 0,
        "y": 0,
        "width": 16,
        "height": 16
      },
      "top": {
        "base": {
          "region": {
            "assetPath": "assets/images/terrain/stone/atlas.png",
            "x": 16,
            "y": 0,
            "width": 16,
            "height": 16
          },
          "anchorY": 0
        }
      }
    }
  ]
}
''');

    final result = await buildTerrainMaterialRegistry(defsPath: defs.path);

    expect(result.output, isNull);
    expect(
      result.issues.map((issue) => issue.code),
      everyElement('terrain_material_asset_missing'),
    );
  });
}
