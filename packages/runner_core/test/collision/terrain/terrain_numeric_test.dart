import 'package:runner_core/collision/terrain/terrain_numeric.dart';
import 'package:test/test.dart';

void main() {
  group('source and physics quantization', () {
    test('positive and negative half-pixel values round-trip exactly', () {
      for (final value in <double>[-10.5, -0.5, 0, 0.5, 12.5]) {
        final point = SourceTerrainPoint.fromWorld(value, -value);
        expect(point.xTicks / terrainSourceTicksPerWorldUnit, equals(value));
        expect(point.toPhysicsPoint().x, equals(value));
      }
    });

    test('rejects non-half-grid, non-finite, and out-of-range input', () {
      expect(() => SourceTerrainPoint.fromWorld(0.25, 0), throwsArgumentError);
      expect(() => TerrainPoint.fromWorld(double.nan, 0), throwsArgumentError);
      expect(
        () => TerrainPoint.fromWorld(terrainMaxAbsPhysicsTicks.toDouble(), 0),
        throwsRangeError,
      );
      expect(
        () => TerrainPoint(terrainMaxAbsPhysicsTicks + 1, 0),
        throwsRangeError,
      );
      expect(
        SourceTerrainPoint(terrainMaxAbsSourceTicks, -terrainMaxAbsSourceTicks),
        isA<SourceTerrainPoint>(),
      );
      expect(
        () => SourceTerrainPoint(terrainMaxAbsSourceTicks + 1, 0),
        throwsRangeError,
      );
      expect(() => SourceTerrainPoint(1 << 55, 0), throwsRangeError);
      expect(
        () => sourceCoordinateToTicks(
          (terrainMaxAbsSourceTicks + 1) / terrainSourceTicksPerWorldUnit,
        ),
        throwsRangeError,
      );
      expect(
        () => TerrainAabb(minX: 1, minY: 0, maxX: 0, maxY: 1),
        throwsArgumentError,
      );
      expect(() => TerrainDirection(1, 0), throwsArgumentError);
      expect(
        () => TerrainDirection.fromVector(double.infinity, 0),
        throwsArgumentError,
      );
      expect(
        () => terrainPhysicsTickValueToInt(double.nan),
        throwsArgumentError,
      );
      expect(
        () => terrainQuantizeDirectionComponent(1, 0),
        throwsArgumentError,
      );
    });

    test('physics quantization ties are symmetric', () {
      final halfTick = 0.5 / terrainPhysicsTicksPerWorldUnit;
      expect(physicsCoordinateToTicks(halfTick), 1);
      expect(physicsCoordinateToTicks(-halfTick), -1);
    });

    test(
      'transform order mirrors, scales, translates, then quantizes once',
      () {
        final result = const TerrainSourceTransform(
          anchorXSourceTicks: 4,
          anchorYSourceTicks: 2,
          reflectX: true,
          scaleNumerator: 3,
          scaleDenominator: 2,
          translateXSourceTicks: 20,
          translateYSourceTicks: -8,
        ).apply(SourceTerrainPoint(8, 6));

        expect(result, TerrainPoint.fromWorld(7, -1));
      },
    );

    test('exact scale quantization rounds half ticks away from zero', () {
      const transform = TerrainSourceTransform(
        scaleNumerator: 3,
        scaleDenominator: 10,
      );

      expect(transform.apply(SourceTerrainPoint(1, 0)).xTicks, 154);
      expect(transform.apply(SourceTerrainPoint(-1, 0)).xTicks, -154);
    });

    test('asymmetric reflection and rational placement order is exact', () {
      const transform = TerrainSourceTransform(
        anchorXSourceTicks: 2,
        anchorYSourceTicks: -4,
        reflectX: true,
        reflectY: true,
        scaleNumerator: 7,
        scaleDenominator: 10,
        translateXSourceTicks: 6,
        translateYSourceTicks: -8,
      );

      expect(
        transform.apply(SourceTerrainPoint(5, 3)),
        TerrainPoint(1997, -6605),
      );
    });

    test('transform rejects off-step and out-of-range authored scales', () {
      for (final transform in <TerrainSourceTransform>[
        const TerrainSourceTransform(scaleNumerator: 1, scaleDenominator: 3),
        const TerrainSourceTransform(scaleNumerator: 1, scaleDenominator: 5),
        const TerrainSourceTransform(scaleNumerator: 31, scaleDenominator: 10),
        const TerrainSourceTransform(scaleNumerator: 0),
        const TerrainSourceTransform(scaleNumerator: 0x7fffffffffffffff),
      ]) {
        expect(
          () => transform.apply(SourceTerrainPoint(0, 0)),
          throwsArgumentError,
        );
      }
    });
  });

  test('floor division is stable for negative cell coordinates', () {
    expect(terrainFloorDiv(63, 64), 0);
    expect(terrainFloorDiv(64, 64), 1);
    expect(terrainFloorDiv(-1, 64), -1);
    expect(terrainFloorDiv(-64, 64), -1);
    expect(terrainFloorDiv(-65, 64), -2);
  });

  test('accepted slope-limit vectors quantize on opposite sides', () {
    final inclusiveNormal = TerrainDirection.fromDelta(-97, -56);
    final overLimitNormal = TerrainDirection.fromDelta(-97, -55);

    expect(-inclusiveNormal.yTicks, terrainDirectionScale ~/ 2);
    expect(-overLimitNormal.yTicks, lessThan(terrainDirectionScale ~/ 2));
  });
}
