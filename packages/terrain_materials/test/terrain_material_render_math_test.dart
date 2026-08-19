import 'package:terrain_materials/terrain_materials.dart';
import 'package:test/test.dart';

void main() {
  test('edge paint order keeps source order while drawing top edges last', () {
    expect(
      terrainMaterialEdgePaintOrder(const <TerrainMaterialEdgeOrientation>[
        TerrainMaterialEdgeOrientation.top,
        TerrainMaterialEdgeOrientation.rightWall,
        TerrainMaterialEdgeOrientation.top,
        TerrainMaterialEdgeOrientation.underside,
        TerrainMaterialEdgeOrientation.leftWall,
      ]),
      <int>[1, 3, 4, 0, 2],
    );
  });

  group('join underlap factor', () {
    test('extends the earlier flat edge beneath a rising edge', () {
      expect(
        terrainMaterialJoinUnderlapFactor(
          endpoint: TerrainMaterialJoinEndpoint.end,
          lowerTangentX: 1,
          lowerTangentY: 0,
          lowerInwardNormalX: 0,
          lowerInwardNormalY: 1,
          upperTangentX: 4,
          upperTangentY: -1,
        ),
        closeTo(0.25, 0.000001),
      );
    });

    test('supports the earlier edge starting at a wrapped join', () {
      expect(
        terrainMaterialJoinUnderlapFactor(
          endpoint: TerrainMaterialJoinEndpoint.start,
          lowerTangentX: 4,
          lowerTangentY: -1,
          lowerInwardNormalX: 1,
          lowerInwardNormalY: 4,
          upperTangentX: 1,
          upperTangentY: 0,
        ),
        closeTo(0.25, 0.000001),
      );
    });

    test('does not extend straight or converging joins', () {
      expect(
        terrainMaterialJoinUnderlapFactor(
          endpoint: TerrainMaterialJoinEndpoint.end,
          lowerTangentX: 1,
          lowerTangentY: 0,
          lowerInwardNormalX: 0,
          lowerInwardNormalY: 1,
          upperTangentX: 1,
          upperTangentY: 0,
        ),
        0,
      );
      expect(
        terrainMaterialJoinUnderlapFactor(
          endpoint: TerrainMaterialJoinEndpoint.end,
          lowerTangentX: 4,
          lowerTangentY: -1,
          lowerInwardNormalX: 1,
          lowerInwardNormalY: 4,
          upperTangentX: 1,
          upperTangentY: 0,
        ),
        0,
      );
    });

    test('fails closed for sharp reversals and invalid vectors', () {
      expect(
        terrainMaterialJoinUnderlapFactor(
          endpoint: TerrainMaterialJoinEndpoint.end,
          lowerTangentX: 1,
          lowerTangentY: 0,
          lowerInwardNormalX: 0,
          lowerInwardNormalY: 1,
          upperTangentX: -1,
          upperTangentY: -1,
        ),
        0,
      );
      expect(
        () => terrainMaterialJoinUnderlapFactor(
          endpoint: TerrainMaterialJoinEndpoint.end,
          lowerTangentX: double.nan,
          lowerTangentY: 0,
          lowerInwardNormalX: 0,
          lowerInwardNormalY: 1,
          upperTangentX: 1,
          upperTangentY: 0,
        ),
        throwsArgumentError,
      );
    });
  });

  test(
    'repeat helpers preserve world phase for positive and negative space',
    () {
      expect(terrainMaterialPositiveModulo(-1, 32), 31);
      expect(terrainMaterialTileStart(47, 32), 32);
      expect(terrainMaterialTileStart(-1, 32), -32);
      expect(
        terrainMaterialEdgeRepeatPhase(
          startX: 16,
          startY: 16,
          tangentX: 0.5,
          tangentY: 0.5,
          repeatWidth: 32,
        ),
        16,
      );
    },
  );

  test('invalid repeat inputs fail closed', () {
    expect(() => terrainMaterialPositiveModulo(0, 0), throwsArgumentError);
    expect(
      () => terrainMaterialPositiveModulo(double.nan, 32),
      throwsArgumentError,
    );
  });

  test('world-facing roles normalize to the edge tangent', () {
    expect(
      terrainMaterialEdgeNormalizationQuarterTurns(
        TerrainMaterialEdgeOrientation.top,
      ),
      0,
    );
    expect(
      terrainMaterialEdgeNormalizationQuarterTurns(
        TerrainMaterialEdgeOrientation.leftWall,
      ),
      1,
    );
    expect(
      terrainMaterialEdgeNormalizationQuarterTurns(
        TerrainMaterialEdgeOrientation.rightWall,
      ),
      3,
    );
    expect(
      terrainMaterialEdgeNormalizationQuarterTurns(
        TerrainMaterialEdgeOrientation.underside,
      ),
      2,
    );
    expect(
      terrainMaterialEdgeTileWidth(
        orientation: TerrainMaterialEdgeOrientation.leftWall,
        sourceWidth: 12,
        sourceHeight: 24,
      ),
      24,
    );
    expect(
      terrainMaterialEdgeTileHeight(
        orientation: TerrainMaterialEdgeOrientation.leftWall,
        sourceWidth: 12,
        sourceHeight: 24,
      ),
      12,
    );
  });
}
