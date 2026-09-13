import 'dart:convert';

import 'package:terrain_materials/terrain_materials.dart';
import 'package:test/test.dart';

const region = TerrainMaterialImageRegion(
  assetPath: 'assets/images/level/atlases/fantasy_environment/mixed_biomes.png',
  x: 784,
  y: 432,
  width: 32,
  height: 32,
);
const next = TerrainMaterialImageRegion(
  assetPath: 'assets/images/level/atlases/fantasy_environment/mixed_biomes.png',
  x: 832,
  y: 432,
  width: 32,
  height: 32,
);

void main() {
  final material = TerrainMaterialDefinition(
    key: 'water',
    displayName: 'Water',
    revision: 1,
    fill: region,
    top: const TerrainMaterialEdgeProfile(
      base: TerrainMaterialEdgeLayer(
        region: region,
        anchorY: 6,
        additionalFrames: [next],
        frameDurationMs: 160,
      ),
    ),
  );

  test('animated source round trips and traverses every frame', () {
    final source = TerrainMaterialCatalog(materials: [material])
        .toCanonicalJson();
    final decoded = decodeTerrainMaterialCatalog(source);
    expect(decoded.issues, isEmpty);
    expect(decoded.catalog!.materials.single, material);
    expect(decoded.catalog!.toCanonicalJson(), source);
    expect(terrainMaterialRegions(material), [region, next]);
    final issues = validateTerrainMaterialImageDimensions(
      TerrainMaterialCatalog(materials: [material]),
      dimensionsFor: (_) =>
          const TerrainMaterialImageDimensions(width: 850, height: 700),
    );
    expect(
      issues,
      hasLength(1),
      reason: 'Later frames need PNG bounds validation too.',
    );
  });

  test('fixed tick frame selection respects pause, loop and tick rate', () {
    final layer = material.top.base;
    expect(layer.regionAtTick(0, 60), region);
    expect(layer.regionAtTick(9, 60), region);
    expect(layer.regionAtTick(10, 60), next);
    expect(layer.regionAtTick(10, 60), next);
    expect(layer.regionAtTick(20, 60), region);
    expect(layer.regionAtTick(5, 30), next);
    expect(layer.regionAtTick(19, 120), next);
  });

  test('invalid timing, frame sizes and explicit null fail closed', () {
    for (final replacement in [
      {
        'additionalFrames': [next.toJson()],
        'frameDurationMs': 0,
      },
      {'additionalFrames': [], 'frameDurationMs': 160},
      {'additionalFrames': null, 'frameDurationMs': 160},
      {
        'additionalFrames': [
          {...next.toJson(), 'width': 16},
        ],
        'frameDurationMs': 160,
      },
    ]) {
      final source = material.toJson();
      source['top'] = {
        'base': {'region': region.toJson(), 'anchorY': 6, ...replacement},
      };
      final result = decodeTerrainMaterialCatalog(
        jsonEncode({
          'schemaVersion': 3,
          'materials': [source],
        }),
      );
      expect(result.catalog, isNull);
      expect(result.issues, isNotEmpty);
    }
  });
}
