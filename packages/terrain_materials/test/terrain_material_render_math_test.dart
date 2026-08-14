import 'package:terrain_materials/terrain_materials.dart';
import 'package:test/test.dart';

void main() {
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
