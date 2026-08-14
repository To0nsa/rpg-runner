import 'package:terrain_materials/terrain_materials.dart';
import 'package:test/test.dart';

void main() {
  const source = '''
{
  "schemaVersion": 2,
  "materials": [
    {
      "key": "grass_dirt",
      "displayName": "Grass / Dirt",
      "revision": 1,
      "fill": {
        "assetPath": "assets/images/terrain/tx_tileset_ground/atlas.png",
        "x": 32,
        "y": 32,
        "width": 32,
        "height": 32
      },
      "top": {
        "base": {
          "region": {
            "assetPath": "assets/images/terrain/tx_tileset_ground/atlas.png",
            "x": 32,
            "y": 0,
            "width": 32,
            "height": 32
          },
          "anchorY": 12
        }
      },
      "topStartCap": {
        "region": {
          "assetPath": "assets/images/terrain/tx_tileset_ground/atlas.png",
          "x": 0,
          "y": 0,
          "width": 32,
          "height": 32
        },
        "anchorX": 0,
        "anchorY": 12
      },
      "topEndCap": {
        "region": {
          "assetPath": "assets/images/terrain/tx_tileset_ground/atlas.png",
          "x": 64,
          "y": 0,
          "width": 32,
          "height": 32
        },
        "anchorX": 32,
        "anchorY": 12
      }
    }
  ]
}
''';

  test('strict v2 decoder round-trips canonical regions', () {
    final result = decodeTerrainMaterialCatalog(source);

    expect(result.issues, isEmpty);
    final material = result.catalog!.materials.single;
    expect(material.key, 'grass_dirt');
    expect(material.fill.x, 32);
    expect(material.top.base.region.y, 0);
    expect(material.topEndCap?.anchorX, 32);
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

  test('region traversal deduplicates identities and paths stably', () {
    final material = decodeTerrainMaterialCatalog(
      source,
    ).catalog!.materials.single;

    expect(terrainMaterialRegions(material), <TerrainMaterialImageRegion>[
      material.fill,
      material.top.base.region,
      material.topStartCap!.region,
      material.topEndCap!.region,
    ]);
    expect(terrainMaterialAssetPaths(material), <String>[
      'assets/images/terrain/tx_tileset_ground/atlas.png',
    ]);
  });

  test('consumer dimensions validate exact region bounds', () {
    final catalog = decodeTerrainMaterialCatalog(source).catalog!;
    final issues = validateTerrainMaterialImageDimensions(
      catalog,
      dimensionsFor: (_) =>
          const TerrainMaterialImageDimensions(width: 80, height: 48),
    );

    expect(issues.map((issue) => issue.path), <String>[
      'grass_dirt.fill.region',
      'grass_dirt.topEndCap.region',
    ]);
    expect(
      issues.map((issue) => issue.code),
      everyElement('terrain_material_region_out_of_bounds'),
    );
  });

  test('anchors accept region boundaries and reject values beyond them', () {
    expect(decodeTerrainMaterialCatalog(source).issues, isEmpty);

    final invalid = decodeTerrainMaterialCatalog(
      source
          .replaceFirst('"anchorY": 12', '"anchorY": 33')
          .replaceFirst('"anchorX": 32', '"anchorX": 33'),
    );

    expect(invalid.catalog, isNull);
    expect(
      invalid.issues.map((issue) => issue.code),
      everyElement('terrain_material_anchor_out_of_bounds'),
    );
  });

  test('wall anchors use normalized source width', () {
    final withNarrowWall = source.replaceFirst(
      '"topStartCap": {',
      '''"leftWall": {
        "base": {
          "region": {
            "assetPath": "assets/images/terrain/tx_tileset_ground/atlas.png",
            "x": 0,
            "y": 0,
            "width": 12,
            "height": 24
          },
          "anchorY": 12
        }
      },
      "topStartCap": {''',
    );

    expect(decodeTerrainMaterialCatalog(withNarrowWall).issues, isEmpty);
    final invalid = decodeTerrainMaterialCatalog(
      withNarrowWall.replaceFirst(
        '''"anchorY": 12
        }
      },
      "topStartCap"''',
        '''"anchorY": 13
        }
      },
      "topStartCap"''',
      ),
    );
    expect(
      invalid.issues.map((issue) => issue.code),
      contains('terrain_material_anchor_out_of_bounds'),
    );
  });

  test('v1 and legacy whole-image fields are rejected without conversion', () {
    final result = decodeTerrainMaterialCatalog('''
{
  "schemaVersion": 1,
  "materials": [
    {
      "key": "legacy",
      "displayName": "Legacy",
      "revision": 1,
      "fillAssetPath": "assets/images/terrain/legacy/fill.png",
      "top": {
        "base": {
          "assetPath": "assets/images/terrain/legacy/top.png",
          "anchorY": 0
        }
      }
    }
  ]
}
''');

    expect(result.catalog, isNull);
    expect(
      result.issues.map((issue) => issue.code),
      containsAll(<String>[
        'invalid_schema_version',
        'unknown_field',
        'invalid_region',
        'unknown_field',
      ]),
    );
  });

  test('invalid region numbers and non-normalized paths fail closed', () {
    for (final path in <String>[
      r'assets\\images\\terrain\\atlas.png',
      'assets/images/terrain/bad path/atlas.png',
      'assets/images/terrain//atlas.png',
      'assets/images/terrain/./atlas.png',
      'assets/images/terrain/../atlas.png',
      '/assets/images/terrain/atlas.png',
      'assets/images/terrain/atlas.PNG',
    ]) {
      final result = decodeTerrainMaterialCatalog(
        source.replaceFirst(
          'assets/images/terrain/tx_tileset_ground/atlas.png',
          path,
        ),
      );
      expect(result.catalog, isNull, reason: path);
      expect(
        result.issues.map((issue) => issue.code),
        contains('invalid_asset_path'),
        reason: path,
      );
    }

    final result = decodeTerrainMaterialCatalog(
      source
          .replaceFirst('"x": 32', '"x": -1')
          .replaceFirst('"width": 32', '"width": 0')
          .replaceFirst('"height": 32', '"height": 32.5'),
    );
    expect(result.catalog, isNull);
    expect(
      result.issues.map((issue) => issue.code),
      everyElement('invalid_region_coordinate'),
    );
  });
}
