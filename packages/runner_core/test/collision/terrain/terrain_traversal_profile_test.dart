import 'package:runner_core/collision/terrain/terrain_edge.dart';
import 'package:runner_core/collision/terrain/terrain_edge_id.dart';
import 'package:runner_core/collision/terrain/terrain_geometry.dart';
import 'package:runner_core/collision/terrain/terrain_numeric.dart';
import 'package:runner_core/collision/terrain/terrain_polygon.dart';
import 'package:runner_core/collision/terrain/terrain_traversal_cache.dart';
import 'package:runner_core/collision/terrain/terrain_traversal_profile.dart';
import 'package:test/test.dart';

void main() {
  group('integer slope angle cache', () {
    test('snaps exact 0/30/45/60/90 direction thresholds', () {
      expect(_angleFor(1, 0), 0);
      expect(_angleFor(97, 56), 30 * terrainSlopeAngleUnitsPerDegree);
      expect(_angleFor(1, 1), 45 * terrainSlopeAngleUnitsPerDegree);
      expect(_angleFor(56, 97), 60 * terrainSlopeAngleUnitsPerDegree);
      expect(_angleFor(0, 1), 90 * terrainSlopeAngleUnitsPerDegree);
    });

    test('24-iteration result is deterministic, mirrored, and monotonic', () {
      final deltas = <(int, int)>[
        (10, 1),
        (10, 2),
        (10, 3),
        (10, 4),
        (10, 5),
        (10, 6),
        (10, 7),
        (10, 8),
        (10, 9),
        (10, 10),
      ];
      final first = [
        for (final delta in deltas)
          terrainAbsoluteSlopeAngleUnits(
            dxTicks: delta.$1 * terrainPhysicsTicksPerWorldUnit,
            dyTicks: delta.$2 * terrainPhysicsTicksPerWorldUnit,
          ),
      ];
      final second = [
        for (final delta in deltas)
          terrainAbsoluteSlopeAngleUnits(
            dxTicks: -delta.$1 * terrainPhysicsTicksPerWorldUnit,
            dyTicks: -delta.$2 * terrainPhysicsTicksPerWorldUnit,
          ),
      ];

      expect(second, orderedEquals(first));
      for (var index = 1; index < first.length; index += 1) {
        expect(first[index], greaterThan(first[index - 1]));
      }
    });

    test(
      'cache follows canonical geometry order without changing identity',
      () {
        final descending = _edge(
          localEdgeIndex: 1,
          dx: 56,
          dy: 97,
          normalDx: -97,
          normalDy: 56,
        );
        final ascending = _edge(
          localEdgeIndex: 0,
          dx: 56,
          dy: -97,
          normalDx: -97,
          normalDy: -56,
        );
        final geometry = TerrainGeometry(
          version: 7,
          polygons: const <TerrainPolygon>[],
          edges: [descending, ascending],
        );

        final cache = TerrainTraversalCache.fromGeometry(geometry);

        expect(cache.geometryVersion, 7);
        expect(
          cache.entries.map((entry) => entry.edgeId),
          orderedEquals(geometry.edges.map((edge) => edge.id)),
        );
        expect(
          cache[ascending.id].absoluteSlopeAngleUnits,
          60 * terrainSlopeAngleUnitsPerDegree,
        );
        expect(
          cache[descending.id].absoluteSlopeAngleUnits,
          60 * terrainSlopeAngleUnitsPerDegree,
        );
      },
    );
  });

  group('Éloïse traversal profile', () {
    final profile = _profile();

    test('freezes the inclusive support, step, snap, and one-way policy', () {
      final inclusive = _edge(
        localEdgeIndex: 0,
        dx: 56,
        dy: -97,
        normalDx: -97,
        normalDy: -56,
      );
      final overLimit = _edge(
        localEdgeIndex: 1,
        dx: 55,
        dy: -97,
        normalDx: -97,
        normalDy: -55,
      );

      expect(profile.maxWalkableSlopeAngleUnits, 60 * 1024);
      expect(profile.stepHeightTicks, 4 * 1024);
      expect(profile.snapDistanceTicks, 4 * 1024);
      expect(profile.oneWaySupportEnabled, isTrue);
      expect(profile.dropThroughEnabled, isFalse);
      expect(profile.isWalkableSupport(inclusive), isTrue);
      expect(profile.isWalkableSupport(overLimit), isFalse);
    });

    test('interpolates continuous uphill and downhill basis points', () {
      final cases = <(int, int, int)>[
        (0, 10000, 10000),
        (15 * 1024, 9750, 10250),
        (30 * 1024, 9500, 10500),
        (37 * 1024 + 512, 9000, 10750),
        (45 * 1024, 8500, 11000),
        (52 * 1024 + 512, 8000, 11250),
        (60 * 1024, 7500, 11500),
      ];

      for (final value in cases) {
        expect(
          profile.slopeMultiplierBp(absoluteAngleUnits: value.$1, uphill: true),
          value.$2,
        );
        expect(
          profile.slopeMultiplierBp(
            absoluteAngleUnits: value.$1,
            uphill: false,
          ),
          value.$3,
        );
      }
    });

    test('uphill classification ignores canonical edge direction', () {
      final forward = _edge(
        localEdgeIndex: 0,
        dx: 64,
        dy: -32,
        normalDx: -32,
        normalDy: -64,
      );
      final reverse = _edge(
        localEdgeIndex: 1,
        dx: -64,
        dy: 32,
        normalDx: -32,
        normalDy: -64,
      );

      expect(profile.isUphill(forward, 100), isTrue);
      expect(profile.isUphill(reverse, 100), isTrue);
      expect(profile.isUphill(forward, -100), isFalse);
      expect(profile.isUphill(reverse, -100), isFalse);
    });

    test('rejects unordered, incomplete, and non-positive curves', () {
      TerrainTraversalProfile build(List<TerrainSlopeSpeedPoint> points) =>
          TerrainTraversalProfile(
            enabled: true,
            isKinematic: false,
            useGravity: true,
            gravityScaleBp: 10000,
            collideCeilings: true,
            collideLeftWalls: true,
            collideRightWalls: true,
            maxWalkableSlopeAngleUnits: 60 * 1024,
            minimumSupportUpComponent: 512,
            stepHeightTicks: 4096,
            snapDistanceTicks: 4096,
            oneWaySupportEnabled: true,
            dropThroughEnabled: false,
            groundedMobilityHelpersEnabled: true,
            slopeSpeedPoints: points,
          );

      expect(
        () => build(const [
          TerrainSlopeSpeedPoint(
            angleUnits: 1,
            uphillMultiplierBp: 10000,
            downhillMultiplierBp: 10000,
          ),
          TerrainSlopeSpeedPoint(
            angleUnits: 60 * 1024,
            uphillMultiplierBp: 7500,
            downhillMultiplierBp: 11500,
          ),
        ]),
        throwsArgumentError,
      );
      expect(
        () => build(const [
          TerrainSlopeSpeedPoint(
            angleUnits: 0,
            uphillMultiplierBp: 10000,
            downhillMultiplierBp: 10000,
          ),
          TerrainSlopeSpeedPoint(
            angleUnits: 30 * 1024,
            uphillMultiplierBp: 9500,
            downhillMultiplierBp: 10500,
          ),
          TerrainSlopeSpeedPoint(
            angleUnits: 30 * 1024,
            uphillMultiplierBp: 8500,
            downhillMultiplierBp: 11000,
          ),
          TerrainSlopeSpeedPoint(
            angleUnits: 60 * 1024,
            uphillMultiplierBp: 7500,
            downhillMultiplierBp: 11500,
          ),
        ]),
        throwsArgumentError,
      );
      expect(
        () => build(const [
          TerrainSlopeSpeedPoint(
            angleUnits: 0,
            uphillMultiplierBp: 0,
            downhillMultiplierBp: 10000,
          ),
          TerrainSlopeSpeedPoint(
            angleUnits: 60 * 1024,
            uphillMultiplierBp: 7500,
            downhillMultiplierBp: 11500,
          ),
        ]),
        throwsArgumentError,
      );
    });
  });
}

TerrainTraversalProfile _profile() => createEloiseTerrainTraversalProfile(
  enabled: true,
  isKinematic: false,
  useGravity: true,
  gravityScale: 1,
  collideCeilings: true,
  collideLeftWalls: true,
  collideRightWalls: true,
);

int _angleFor(int dx, int dy) {
  final tangent = TerrainDirection.fromDelta(dx, dy);
  return terrainAbsoluteSlopeAngleUnits(
    dxTicks: dx,
    dyTicks: dy,
    tangentXTicks: tangent.xTicks,
    tangentYTicks: tangent.yTicks,
  );
}

TerrainEdge _edge({
  required int localEdgeIndex,
  required int dx,
  required int dy,
  required int normalDx,
  required int normalDy,
}) {
  final start = TerrainPoint(0, 0);
  final end = TerrainPoint(dx * 1024, dy * 1024);
  return TerrainEdge(
    id: TerrainEdgeId(
      chunkIndex: 0,
      chunkKey: 'test',
      shapeId: 'slope',
      localEdgeIndex: localEdgeIndex,
    ),
    start: start,
    end: end,
    tangent: TerrainDirection.fromDelta(dx, dy),
    outwardNormal: TerrainDirection.fromDelta(normalDx, normalDy),
    collisionMode: TerrainCollisionMode.solid,
    surfaceKind: null,
    materialKey: null,
    previousId: null,
    nextId: null,
    startJoin: TerrainVertexJoin.exposed,
    endJoin: TerrainVertexJoin.exposed,
    bounds: TerrainAabb(
      minX: start.xTicks < end.xTicks ? start.xTicks : end.xTicks,
      minY: start.yTicks < end.yTicks ? start.yTicks : end.yTicks,
      maxX: start.xTicks > end.xTicks ? start.xTicks : end.xTicks,
      maxY: start.yTicks > end.yTicks ? start.yTicks : end.yTicks,
    ),
  );
}
