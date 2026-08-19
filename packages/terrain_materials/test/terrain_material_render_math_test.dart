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

  group('connected corner ownership', () {
    test('selects the only available cap at a convex corner', () {
      expect(
        terrainMaterialConnectedCornerOwner(
          incomingInwardNormalX: 0,
          incomingInwardNormalY: 1,
          outgoingTangentX: 0,
          outgoingTangentY: 1,
          incomingOrientation: TerrainMaterialEdgeOrientation.top,
          outgoingOrientation: TerrainMaterialEdgeOrientation.rightWall,
          incomingEndCapAvailable: true,
          outgoingStartCapAvailable: false,
        ),
        TerrainMaterialCornerOwner.incomingEnd,
      );
      expect(
        terrainMaterialConnectedCornerOwner(
          incomingInwardNormalX: 1,
          incomingInwardNormalY: 0,
          outgoingTangentX: 1,
          outgoingTangentY: 0,
          incomingOrientation: TerrainMaterialEdgeOrientation.leftWall,
          outgoingOrientation: TerrainMaterialEdgeOrientation.top,
          incomingEndCapAvailable: false,
          outgoingStartCapAvailable: true,
        ),
        TerrainMaterialCornerOwner.outgoingStart,
      );
    });

    test('top-facing cap wins and equal-priority ties use incoming end', () {
      expect(
        terrainMaterialConnectedCornerOwner(
          incomingInwardNormalX: 0,
          incomingInwardNormalY: 1,
          outgoingTangentX: 1,
          outgoingTangentY: 1,
          incomingOrientation: TerrainMaterialEdgeOrientation.underside,
          outgoingOrientation: TerrainMaterialEdgeOrientation.top,
          incomingEndCapAvailable: true,
          outgoingStartCapAvailable: true,
        ),
        TerrainMaterialCornerOwner.outgoingStart,
      );
      expect(
        terrainMaterialConnectedCornerOwner(
          incomingInwardNormalX: 0,
          incomingInwardNormalY: 1,
          outgoingTangentX: 1,
          outgoingTangentY: 1,
          incomingOrientation: TerrainMaterialEdgeOrientation.top,
          outgoingOrientation: TerrainMaterialEdgeOrientation.top,
          incomingEndCapAvailable: true,
          outgoingStartCapAvailable: true,
        ),
        TerrainMaterialCornerOwner.incomingEnd,
      );
    });

    test('straight and concave joins do not receive outer corners', () {
      expect(
        terrainMaterialConnectedCornerOwner(
          incomingInwardNormalX: 0,
          incomingInwardNormalY: 1,
          outgoingTangentX: 1,
          outgoingTangentY: 0,
          incomingOrientation: TerrainMaterialEdgeOrientation.top,
          outgoingOrientation: TerrainMaterialEdgeOrientation.top,
          incomingEndCapAvailable: true,
          outgoingStartCapAvailable: true,
        ),
        isNull,
      );
      expect(
        terrainMaterialConnectedCornerOwner(
          incomingInwardNormalX: 0,
          incomingInwardNormalY: 1,
          outgoingTangentX: 1,
          outgoingTangentY: -1,
          incomingOrientation: TerrainMaterialEdgeOrientation.top,
          outgoingOrientation: TerrainMaterialEdgeOrientation.top,
          incomingEndCapAvailable: true,
          outgoingStartCapAvailable: true,
        ),
        isNull,
      );
    });

    test('invalid corner vectors fail closed', () {
      expect(
        () => terrainMaterialConnectedCornerOwner(
          incomingInwardNormalX: 0,
          incomingInwardNormalY: 0,
          outgoingTangentX: 1,
          outgoingTangentY: 0,
          incomingOrientation: TerrainMaterialEdgeOrientation.top,
          outgoingOrientation: TerrainMaterialEdgeOrientation.top,
          incomingEndCapAvailable: true,
          outgoingStartCapAvailable: true,
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
