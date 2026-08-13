import 'package:terrain_materials/terrain_materials.dart';
import 'package:test/test.dart';

void main() {
  const source = '''
{
  "schemaVersion": 1,
  "materials": [
    {
      "key": "grass_dirt",
      "displayName": "Grass / Dirt",
      "revision": 1,
      "fillAssetPath": "assets/images/terrain/grass_dirt/fill.png",
      "top": {
        "base": {
          "assetPath": "assets/images/terrain/grass_dirt/surface.png",
          "anchorY": 12
        },
        "detail": {
          "assetPath": "assets/images/terrain/grass_dirt/foreground.png",
          "anchorY": 0
        }
      },
      "topStartCap": {
        "assetPath": "assets/images/terrain/grass_dirt/cap_left.png",
        "anchorX": 0,
        "anchorY": 12
      },
      "topEndCap": {
        "assetPath": "assets/images/terrain/grass_dirt/cap_right.png",
        "anchorX": 128,
        "anchorY": 12
      }
    }
  ]
}
''';

  test('strict decoder round-trips canonical material coverage', () {
    final result = decodeTerrainMaterialCatalog(source);

    expect(result.issues, isEmpty);
    final material = result.catalog!.materials.single;
    expect(material.key, 'grass_dirt');
    expect(material.top.detail?.anchorY, 0);
    expect(material.leftWall, isNull);
    expect(material.topEndCap?.anchorX, 128);
    expect(
      decodeTerrainMaterialCatalog(result.catalog!.toCanonicalJson()).catalog,
      isNotNull,
    );
  });

  test('catalog ordering and numeric encoding are canonical', () {
    final original = decodeTerrainMaterialCatalog(
      source,
    ).catalog!.materials.single;
    final catalog = TerrainMaterialCatalog(
      materials: <TerrainMaterialDefinition>[
        original.copyWith(key: 'stone', displayName: 'Stone'),
        original,
      ],
    );

    expect(catalog.materials.map((material) => material.key), <String>[
      'grass_dirt',
      'stone',
    ]);
    expect(catalog.toCanonicalJson(), contains('"anchorY": 12'));
    expect(catalog.toCanonicalJson(), isNot(contains('12.0')));
  });

  test('image anchors are checked against consumer-supplied dimensions', () {
    final catalog = decodeTerrainMaterialCatalog(source).catalog!;

    final issues = validateTerrainMaterialImageDimensions(
      catalog,
      dimensionsFor: (assetPath) => assetPath.endsWith('cap_right.png')
          ? const TerrainMaterialImageDimensions(width: 64, height: 92)
          : const TerrainMaterialImageDimensions(width: 256, height: 10),
    );

    expect(
      issues.map((issue) => issue.code),
      everyElement('terrain_material_anchor_out_of_bounds'),
    );
    expect(issues.map((issue) => issue.path), <String>[
      'grass_dirt.top.base.anchorY',
      'grass_dirt.topEndCap',
      'grass_dirt.topStartCap',
    ]);
  });

  test(
    'invalid keys, paths, unknown fields, and unpaired caps fail closed',
    () {
      final result = decodeTerrainMaterialCatalog(
        source
            .replaceFirst('"grass_dirt"', '"Grass Dirt"')
            .replaceFirst(
              '"assets/images/terrain/grass_dirt/fill.png"',
              '"../fill.jpg"',
            )
            .replaceFirst('"topEndCap": {', '"unknown": true, "removed": {'),
      );

      expect(result.catalog, isNull);
      expect(
        result.issues.map((issue) => issue.code),
        containsAll(<String>[
          'invalid_material_key',
          'invalid_asset_path',
          'unknown_field',
          'unpaired_top_caps',
        ]),
      );
    },
  );
}
