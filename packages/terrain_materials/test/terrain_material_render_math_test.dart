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

  group('connected corner treatment', () {
    test('keeps the four cardinal rectangle cap roles', () {
      expect(
        terrainMaterialConnectedCornerTreatment(
          incomingInwardNormalX: 0,
          incomingInwardNormalY: 1,
          outgoingTangentX: 0,
          outgoingTangentY: 1,
          incomingOrientation: TerrainMaterialEdgeOrientation.top,
          outgoingOrientation: TerrainMaterialEdgeOrientation.rightWall,
          incomingEndCapAvailable: true,
          outgoingStartCapAvailable: false,
        ),
        TerrainMaterialConnectedCornerTreatment.incomingEndCap,
      );
      expect(
        terrainMaterialConnectedCornerTreatment(
          incomingInwardNormalX: 1,
          incomingInwardNormalY: 0,
          outgoingTangentX: 1,
          outgoingTangentY: 0,
          incomingOrientation: TerrainMaterialEdgeOrientation.leftWall,
          outgoingOrientation: TerrainMaterialEdgeOrientation.top,
          incomingEndCapAvailable: false,
          outgoingStartCapAvailable: true,
        ),
        TerrainMaterialConnectedCornerTreatment.outgoingStartCap,
      );
      expect(
        terrainMaterialConnectedCornerTreatment(
          incomingInwardNormalX: -1,
          incomingInwardNormalY: 0,
          outgoingTangentX: -1,
          outgoingTangentY: 0,
          incomingOrientation: TerrainMaterialEdgeOrientation.rightWall,
          outgoingOrientation: TerrainMaterialEdgeOrientation.underside,
          incomingEndCapAvailable: false,
          outgoingStartCapAvailable: true,
        ),
        TerrainMaterialConnectedCornerTreatment.outgoingStartCap,
      );
      expect(
        terrainMaterialConnectedCornerTreatment(
          incomingInwardNormalX: 0,
          incomingInwardNormalY: -1,
          outgoingTangentX: 0,
          outgoingTangentY: -1,
          incomingOrientation: TerrainMaterialEdgeOrientation.underside,
          outgoingOrientation: TerrainMaterialEdgeOrientation.leftWall,
          incomingEndCapAvailable: true,
          outgoingStartCapAvailable: false,
        ),
        TerrainMaterialConnectedCornerTreatment.incomingEndCap,
      );
    });

    test('uses fill backing for non-cardinal convex turns', () {
      expect(
        terrainMaterialConnectedCornerTreatment(
          incomingInwardNormalX: 1,
          incomingInwardNormalY: 5,
          outgoingTangentX: 5,
          outgoingTangentY: 1,
          incomingOrientation: TerrainMaterialEdgeOrientation.top,
          outgoingOrientation: TerrainMaterialEdgeOrientation.top,
          incomingEndCapAvailable: true,
          outgoingStartCapAvailable: true,
        ),
        TerrainMaterialConnectedCornerTreatment.fillBacking,
      );
      expect(
        terrainMaterialConnectedCornerTreatment(
          incomingInwardNormalX: 1,
          incomingInwardNormalY: 2,
          outgoingTangentX: 0,
          outgoingTangentY: 1,
          incomingOrientation: TerrainMaterialEdgeOrientation.top,
          outgoingOrientation: TerrainMaterialEdgeOrientation.rightWall,
          incomingEndCapAvailable: true,
          outgoingStartCapAvailable: false,
        ),
        TerrainMaterialConnectedCornerTreatment.fillBacking,
      );
    });

    test('missing canonical cap falls back to fill backing', () {
      expect(
        terrainMaterialConnectedCornerTreatment(
          incomingInwardNormalX: 0,
          incomingInwardNormalY: 1,
          outgoingTangentX: 0,
          outgoingTangentY: 1,
          incomingOrientation: TerrainMaterialEdgeOrientation.top,
          outgoingOrientation: TerrainMaterialEdgeOrientation.rightWall,
          incomingEndCapAvailable: false,
          outgoingStartCapAvailable: false,
        ),
        TerrainMaterialConnectedCornerTreatment.fillBacking,
      );
    });

    test('straight and concave joins do not receive outer corners', () {
      expect(
        terrainMaterialConnectedCornerTreatment(
          incomingInwardNormalX: 0,
          incomingInwardNormalY: 1,
          outgoingTangentX: 1,
          outgoingTangentY: 0,
          incomingOrientation: TerrainMaterialEdgeOrientation.top,
          outgoingOrientation: TerrainMaterialEdgeOrientation.top,
          incomingEndCapAvailable: true,
          outgoingStartCapAvailable: true,
        ),
        TerrainMaterialConnectedCornerTreatment.none,
      );
      expect(
        terrainMaterialConnectedCornerTreatment(
          incomingInwardNormalX: 0,
          incomingInwardNormalY: 1,
          outgoingTangentX: 1,
          outgoingTangentY: -1,
          incomingOrientation: TerrainMaterialEdgeOrientation.top,
          outgoingOrientation: TerrainMaterialEdgeOrientation.top,
          incomingEndCapAvailable: true,
          outgoingStartCapAvailable: true,
        ),
        TerrainMaterialConnectedCornerTreatment.none,
      );
    });

    test('invalid corner vectors fail closed', () {
      expect(
        () => terrainMaterialConnectedCornerTreatment(
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

  group('cap footprint', () {
    test('uses the same normalized bounds as cap painting', () {
      expect(
        terrainMaterialCapFootprint(
          edgeLength: 80,
          anchorX: 7,
          anchorY: 3,
          atEnd: false,
          orientation: TerrainMaterialEdgeOrientation.top,
          sourceWidth: 32,
          sourceHeight: 20,
        ),
        (left: -7, top: -3, width: 32, height: 20),
      );
      expect(
        terrainMaterialCapFootprint(
          edgeLength: 80,
          anchorX: 12,
          anchorY: 5,
          atEnd: true,
          orientation: TerrainMaterialEdgeOrientation.leftWall,
          sourceWidth: 12,
          sourceHeight: 24,
        ),
        (left: 68, top: -5, width: 24, height: 12),
      );
    });

    test('rejects invalid placement inputs', () {
      expect(
        () => terrainMaterialCapFootprint(
          edgeLength: 0,
          anchorX: 0,
          anchorY: 0,
          atEnd: false,
          orientation: TerrainMaterialEdgeOrientation.top,
          sourceWidth: 32,
          sourceHeight: 32,
        ),
        throwsArgumentError,
      );
    });
  });

  group('edge footprint', () {
    test('matches the normalized repeating-strip bounds', () {
      expect(
        terrainMaterialEdgeFootprint(
          edgeLength: 80,
          anchorY: 3,
          orientation: TerrainMaterialEdgeOrientation.top,
          sourceWidth: 32,
          sourceHeight: 20,
        ),
        (left: 0, top: -3, width: 80, height: 20),
      );
      expect(
        terrainMaterialEdgeFootprint(
          edgeLength: 40,
          anchorY: 5,
          orientation: TerrainMaterialEdgeOrientation.leftWall,
          sourceWidth: 12,
          sourceHeight: 24,
        ),
        (left: 0, top: -5, width: 40, height: 12),
      );
    });

    test('rejects invalid strip inputs', () {
      expect(
        () => terrainMaterialEdgeFootprint(
          edgeLength: double.nan,
          anchorY: 0,
          orientation: TerrainMaterialEdgeOrientation.top,
          sourceWidth: 32,
          sourceHeight: 32,
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
      expect(
        terrainMaterialEdgeRepeatSeamOffsets(
          startX: 0,
          startY: 0,
          tangentX: 1,
          tangentY: 0,
          edgeLength: 96,
          repeatWidth: 32,
        ),
        <double>[32, 64],
      );
      expect(
        terrainMaterialEdgeRepeatSeamOffsets(
          startX: 16,
          startY: 0,
          tangentX: 1,
          tangentY: 0,
          edgeLength: 80,
          repeatWidth: 32,
        ),
        <double>[16, 48],
      );
    },
  );

  test('invalid repeat inputs fail closed', () {
    expect(() => terrainMaterialPositiveModulo(0, 0), throwsArgumentError);
    expect(
      () => terrainMaterialPositiveModulo(double.nan, 32),
      throwsArgumentError,
    );
    expect(
      () => terrainMaterialEdgeRepeatSeamOffsets(
        startX: 0,
        startY: 0,
        tangentX: 1,
        tangentY: 0,
        edgeLength: 0,
        repeatWidth: 32,
      ),
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
