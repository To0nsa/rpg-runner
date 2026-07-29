import 'dart:math' as math;

import 'package:runner_core/collision/terrain/capsule_segment_kernel.dart';
import 'package:runner_core/collision/terrain/terrain_edge.dart';
import 'package:runner_core/collision/terrain/terrain_edge_id.dart';
import 'package:runner_core/collision/terrain/terrain_numeric.dart';
import 'package:runner_core/collision/terrain/terrain_polygon.dart';
import 'package:runner_core/collision/terrain/upright_capsule.dart';
import 'package:test/test.dart';

void main() {
  final kernel = CapsuleSegmentKernel();

  test('capsule rejects negative dimensions at runtime', () {
    expect(
      () => UprightCapsule(
        center: TerrainPoint.fromWorld(0, 0),
        radiusTicks: -1,
        verticalHalfSegmentTicks: 0,
      ),
      throwsArgumentError,
    );
  });

  test('closest point clamps to both endpoints and the finite face', () {
    final out = TerrainClosestPointResult();
    final start = TerrainPoint.fromWorld(0, 0);
    final end = TerrainPoint.fromWorld(10, 0);

    kernel.closestPointOnSegment(
      point: TerrainPoint.fromWorld(-2, 3),
      start: start,
      end: end,
      out: out,
    );
    expect(out.segmentT, 0);
    expect(out.pointXTicks, 0);

    kernel.closestPointOnSegment(
      point: TerrainPoint.fromWorld(5, 3),
      start: start,
      end: end,
      out: out,
    );
    expect(out.segmentT, closeTo(0.5, 1e-12));

    kernel.closestPointOnSegment(
      point: TerrainPoint.fromWorld(12, 3),
      start: start,
      end: end,
      out: out,
    );
    expect(out.segmentT, 1);
  });

  test('segment pair handles crossing, parallel, and point degeneracy', () {
    final out = TerrainSegmentPairResult();
    kernel.closestPointsBetweenSegments(
      firstStart: TerrainPoint.fromWorld(0, 0),
      firstEnd: TerrainPoint.fromWorld(10, 10),
      secondStart: TerrainPoint.fromWorld(0, 10),
      secondEnd: TerrainPoint.fromWorld(10, 0),
      out: out,
    );
    expect(out.squaredDistanceTicks, closeTo(0, 1e-6));

    kernel.closestPointsBetweenSegments(
      firstStart: TerrainPoint.fromWorld(0, 0),
      firstEnd: TerrainPoint.fromWorld(10, 0),
      secondStart: TerrainPoint.fromWorld(0, 5),
      secondEnd: TerrainPoint.fromWorld(10, 5),
      out: out,
    );
    expect(
      math.sqrt(out.squaredDistanceTicks) / terrainPhysicsTicksPerWorldUnit,
      closeTo(5, 1e-9),
    );

    kernel.closestPointsBetweenSegments(
      firstStart: TerrainPoint.fromWorld(20, 0),
      firstEnd: TerrainPoint.fromWorld(20, 0),
      secondStart: TerrainPoint.fromWorld(0, 0),
      secondEnd: TerrainPoint.fromWorld(10, 0),
      out: out,
    );
    expect(out.secondT, 1);
    expect(
      math.sqrt(out.squaredDistanceTicks) / terrainPhysicsTicksPerWorldUnit,
      closeTo(10, 1e-9),
    );
  });

  test('face, endpoint, and circle contacts use the correct normals', () {
    final edge = _edge(0, 0, 100, 200, 100);
    final contact = CapsuleSegmentContact();
    kernel.evaluate(
      capsule: UprightCapsule(
        center: TerrainPoint.fromWorld(100, 70),
        radiusTicks: 10 * terrainPhysicsTicksPerWorldUnit,
        verticalHalfSegmentTicks: 20 * terrainPhysicsTicksPerWorldUnit,
      ),
      edge: edge,
      out: contact,
    );
    expect(contact.feature, TerrainSegmentFeature.face);
    expect(contact.signedSeparationTicks, closeTo(0, 1e-9));
    expect(contact.normalXTicks, 0);
    expect(contact.normalYTicks, -terrainDirectionScale);

    kernel.evaluate(
      capsule: UprightCapsule(
        center: TerrainPoint.fromWorld(-6, 70),
        radiusTicks: 10 * terrainPhysicsTicksPerWorldUnit,
        verticalHalfSegmentTicks: 20 * terrainPhysicsTicksPerWorldUnit,
      ),
      edge: edge,
      out: contact,
    );
    expect(contact.feature, TerrainSegmentFeature.startEndpoint);
    expect(contact.normalXTicks, lessThan(0));
    expect(contact.normalYTicks, lessThan(0));

    kernel.evaluate(
      capsule: UprightCapsule(
        center: TerrainPoint.fromWorld(206, 70),
        radiusTicks: 10 * terrainPhysicsTicksPerWorldUnit,
        verticalHalfSegmentTicks: 20 * terrainPhysicsTicksPerWorldUnit,
      ),
      edge: edge,
      out: contact,
    );
    expect(contact.feature, TerrainSegmentFeature.endEndpoint);
    expect(contact.normalXTicks, greaterThan(0));
    expect(contact.normalYTicks, lessThan(0));

    kernel.evaluate(
      capsule: UprightCapsule(
        center: TerrainPoint.fromWorld(100, 130),
        radiusTicks: 10 * terrainPhysicsTicksPerWorldUnit,
        verticalHalfSegmentTicks: 20 * terrainPhysicsTicksPerWorldUnit,
      ),
      edge: _edge(1, 200, 100, 0, 100),
      out: contact,
    );
    expect(contact.feature, TerrainSegmentFeature.face);
    expect(contact.signedSeparationTicks, closeTo(0, 1e-9));
    expect(contact.normalYTicks, terrainDirectionScale);

    kernel.evaluate(
      capsule: UprightCapsule(
        center: TerrainPoint.fromWorld(100, 80),
        radiusTicks: 20 * terrainPhysicsTicksPerWorldUnit,
        verticalHalfSegmentTicks: 0,
      ),
      edge: edge,
      out: contact,
    );
    expect(contact.signedSeparationTicks, closeTo(0, 1e-9));
  });

  test('sloped face contact uses the precompiled outward normal', () {
    final edge = _edge(0, 0, 100, 100, 0);
    final contact = CapsuleSegmentContact();
    kernel.evaluate(
      capsule: UprightCapsule(
        center: TerrainPoint.fromWorld(42.9289, 42.9289),
        radiusTicks: 10 * terrainPhysicsTicksPerWorldUnit,
        verticalHalfSegmentTicks: 0,
      ),
      edge: edge,
      out: contact,
    );

    expect(contact.feature, TerrainSegmentFeature.face);
    expect(
      contact.signedSeparationTicks.abs(),
      lessThanOrEqualTo(terrainContactEpsilonTicks.toDouble()),
    );
    expect(contact.normalXTicks, edge.outwardNormal.xTicks);
    expect(contact.normalYTicks, edge.outwardNormal.yTicks);
  });

  test('recovery-only evaluation matches full integer contact facts', () {
    final edge = _edge(0, 0, 100, 100, 0);
    final center = TerrainPoint.fromWorld(42.75, 42.5);
    final full = CapsuleSegmentContact();
    final recovery = CapsuleSegmentContact();

    kernel.evaluateAtCenter(
      centerXTicks: center.xTicks,
      centerYTicks: center.yTicks,
      radiusTicks: 10 * terrainPhysicsTicksPerWorldUnit,
      verticalHalfSegmentTicks: 0,
      edge: edge,
      out: full,
    );
    kernel.evaluateRecoveryAtCenter(
      centerXTicks: center.xTicks,
      centerYTicks: center.yTicks,
      radiusTicks: 10 * terrainPhysicsTicksPerWorldUnit,
      verticalHalfSegmentTicks: 0,
      edge: edge,
      out: recovery,
    );

    expect(
      recovery.signedSeparationFloorTicks,
      full.signedSeparationTicks.floor(),
    );
    expect(
      recovery.collisionSkinCorrectionTicks,
      (terrainCollisionSkinTicks - full.signedSeparationTicks).ceil(),
    );
    expect(recovery.pointXTicks, full.pointXTicks);
    expect(recovery.pointYTicks, full.pointYTicks);
    expect(recovery.normalXTicks, full.normalXTicks);
    expect(recovery.normalYTicks, full.normalYTicks);
    expect(recovery.feature, full.feature);
    expect(recovery.edgeId, full.edgeId);
  });

  test('integer retained-support check matches full support distance', () {
    const radiusTicks = 10 * terrainPhysicsTicksPerWorldUnit;
    const verticalHalfSegmentTicks = 20 * terrainPhysicsTicksPerWorldUnit;
    const toleranceTicks = 2 * terrainPhysicsTicksPerWorldUnit;
    final cases = <(TerrainEdge, TerrainPoint)>[
      (_edge(10, 0, 100, 200, 100), TerrainPoint.fromWorld(100, 70)),
      (_edge(11, 0, 150, 100, 50), TerrainPoint.fromWorld(43, 73)),
      (_edge(12, 0, 100, 200, 100), TerrainPoint.fromWorld(-6, 70)),
      (_edge(13, 0, 100, 200, 100), TerrainPoint.fromWorld(206, 70)),
      (_edge(14, 0, 100, 200, 100), TerrainPoint.fromWorld(100, 67)),
    ];

    for (final benchmarkCase in cases) {
      final edge = benchmarkCase.$1;
      final center = benchmarkCase.$2;
      final full = CapsuleSegmentContact();
      final retained = CapsuleSegmentContact();
      kernel.evaluateAtCenter(
        centerXTicks: center.xTicks,
        centerYTicks: center.yTicks,
        radiusTicks: radiusTicks,
        verticalHalfSegmentTicks: verticalHalfSegmentTicks,
        edge: edge,
        out: full,
      );

      final within = kernel.evaluateSupportAtCenterWithin(
        centerXTicks: center.xTicks,
        centerYTicks: center.yTicks,
        radiusTicks: radiusTicks,
        verticalHalfSegmentTicks: verticalHalfSegmentTicks,
        edge: edge,
        maximumSeparationTicks: toleranceTicks,
        out: retained,
      );

      expect(
        within,
        full.signedSeparationTicks <= toleranceTicks,
        reason: edge.id.shapeId,
      );
      expect(retained.feature, full.feature, reason: edge.id.shapeId);
      expect(retained.pointXTicks, full.pointXTicks, reason: edge.id.shapeId);
      expect(retained.pointYTicks, full.pointYTicks, reason: edge.id.shapeId);
      expect(retained.edgeId, full.edgeId, reason: edge.id.shapeId);
    }
  });

  test('continuous sweep finds floor, wall, and high-speed contacts', () {
    final hit = CapsuleSweepHit();
    final capsule = UprightCapsule(
      center: TerrainPoint.fromWorld(100, 40),
      radiusTicks: 10 * terrainPhysicsTicksPerWorldUnit,
      verticalHalfSegmentTicks: 20 * terrainPhysicsTicksPerWorldUnit,
    );
    kernel.sweep(
      capsule: capsule,
      displacementXTicks: 0,
      displacementYTicks: 50 * terrainPhysicsTicksPerWorldUnit,
      edge: _edge(0, 0, 100, 200, 100),
      out: hit,
    );
    expect(hit.hit, isTrue);
    expect(hit.timeOfImpact, closeTo(0.6, 0.001));
    expect(hit.normalYTicks, -terrainDirectionScale);

    kernel.sweep(
      capsule: UprightCapsule(
        center: TerrainPoint.fromWorld(50, 100),
        radiusTicks: 10 * terrainPhysicsTicksPerWorldUnit,
        verticalHalfSegmentTicks: 20 * terrainPhysicsTicksPerWorldUnit,
      ),
      displacementXTicks: 100 * terrainPhysicsTicksPerWorldUnit,
      displacementYTicks: 0,
      edge: _edge(1, 100, 200, 100, 0),
      out: hit,
    );
    expect(hit.hit, isTrue);
    expect(hit.timeOfImpact, closeTo(0.4, 0.001));
    expect(hit.normalXTicks, -terrainDirectionScale);

    kernel.sweep(
      capsule: capsule,
      displacementXTicks: 0,
      displacementYTicks: 1000 * terrainPhysicsTicksPerWorldUnit,
      edge: _edge(2, 0, 100, 200, 100),
      out: hit,
    );
    expect(hit.hit, isTrue);
    expect(hit.timeOfImpact, closeTo(0.03, 0.001));
  });

  test('sweeps classify both endpoints and face on every surface axis', () {
    final fixtures = <(String, TerrainEdge)>[
      ('flat', _edge(10, 0, 100, 200, 100)),
      ('slope', _edge(11, 0, 150, 100, 50)),
      ('wall', _edge(12, 100, 200, 100, 0)),
      ('ceiling', _edge(13, 200, 100, 0, 100)),
    ];
    const radiusTicks = 10 * terrainPhysicsTicksPerWorldUnit;
    const approachTicks = 20 * terrainPhysicsTicksPerWorldUnit;
    final hit = CapsuleSweepHit();

    for (final fixture in fixtures) {
      final edge = fixture.$2;
      for (final feature in TerrainSegmentFeature.values) {
        final target = switch (feature) {
          TerrainSegmentFeature.startEndpoint => edge.start,
          TerrainSegmentFeature.face => TerrainPoint(
            (edge.start.xTicks + edge.end.xTicks) ~/ 2,
            (edge.start.yTicks + edge.end.yTicks) ~/ 2,
          ),
          TerrainSegmentFeature.endEndpoint => edge.end,
        };
        final startDistance = radiusTicks + approachTicks;
        final startX =
            target.xTicks +
            _scaleDirection(edge.outwardNormal.xTicks, startDistance);
        final startY =
            target.yTicks +
            _scaleDirection(edge.outwardNormal.yTicks, startDistance);

        kernel.sweepAtCenter(
          centerXTicks: startX,
          centerYTicks: startY,
          radiusTicks: radiusTicks,
          verticalHalfSegmentTicks: 0,
          displacementXTicks: _scaleDirection(
            -edge.outwardNormal.xTicks,
            approachTicks * 2,
          ),
          displacementYTicks: _scaleDirection(
            -edge.outwardNormal.yTicks,
            approachTicks * 2,
          ),
          edge: edge,
          out: hit,
        );

        expect(hit.hit, isTrue, reason: '${fixture.$1} $feature');
        expect(hit.feature, feature, reason: fixture.$1);
        expect(hit.startedOverlapping, isFalse, reason: fixture.$1);
      }
    }
  });

  test('near-parallel miss and endpoint grazing remain bounded', () {
    final edge = _edge(0, 0, 100, 200, 100);
    final hit = CapsuleSweepHit();
    kernel.sweep(
      capsule: UprightCapsule(
        center: TerrainPoint.fromWorld(20, 65),
        radiusTicks: 10 * terrainPhysicsTicksPerWorldUnit,
        verticalHalfSegmentTicks: 20 * terrainPhysicsTicksPerWorldUnit,
      ),
      displacementXTicks: 100 * terrainPhysicsTicksPerWorldUnit,
      displacementYTicks: terrainGeometryEpsilonTicks,
      edge: edge,
      out: hit,
    );
    expect(hit.hit, isFalse);

    kernel.sweep(
      capsule: UprightCapsule(
        center: TerrainPoint.fromWorld(-20, 90),
        radiusTicks: 10 * terrainPhysicsTicksPerWorldUnit,
        verticalHalfSegmentTicks: 0,
      ),
      displacementXTicks: 20 * terrainPhysicsTicksPerWorldUnit,
      displacementYTicks: 0,
      edge: edge,
      out: hit,
    );
    expect(hit.hit, isTrue);
    expect(hit.feature, TerrainSegmentFeature.startEndpoint);
    expect(hit.timeOfImpact, inInclusiveRange(0.98, 1));
    expect(
      hit.signedSeparationTicks,
      lessThanOrEqualTo(terrainContactEpsilonTicks),
    );
  });

  test('zero displacement misses and starting penetration is explicit', () {
    final edge = _edge(0, 0, 100, 200, 100);
    final hit = CapsuleSweepHit();
    kernel.sweep(
      capsule: UprightCapsule(
        center: TerrainPoint.fromWorld(100, 40),
        radiusTicks: 10 * terrainPhysicsTicksPerWorldUnit,
        verticalHalfSegmentTicks: 20 * terrainPhysicsTicksPerWorldUnit,
      ),
      displacementXTicks: 0,
      displacementYTicks: 0,
      edge: edge,
      out: hit,
    );
    expect(hit.hit, isFalse);

    kernel.sweep(
      capsule: UprightCapsule(
        center: TerrainPoint.fromWorld(100, 75),
        radiusTicks: 10 * terrainPhysicsTicksPerWorldUnit,
        verticalHalfSegmentTicks: 20 * terrainPhysicsTicksPerWorldUnit,
      ),
      displacementXTicks: 0,
      displacementYTicks: 0,
      edge: edge,
      out: hit,
    );
    expect(hit.hit, isTrue);
    expect(hit.startedOverlapping, isTrue);
    expect(hit.timeOfImpact, 0);
  });

  test('facing mirrors authored X offset without changing dimensions', () {
    final body = TerrainPoint.fromWorld(100, 50);
    final right = UprightCapsule.fromBody(
      bodyCenter: body,
      facing: TerrainFacing.right,
      offsetXTicks: 5 * terrainPhysicsTicksPerWorldUnit,
      offsetYTicks: 2 * terrainPhysicsTicksPerWorldUnit,
      radiusTicks: 10 * terrainPhysicsTicksPerWorldUnit,
      verticalHalfSegmentTicks: 4 * terrainPhysicsTicksPerWorldUnit,
    );
    final left = UprightCapsule.fromBody(
      bodyCenter: body,
      facing: TerrainFacing.left,
      offsetXTicks: 5 * terrainPhysicsTicksPerWorldUnit,
      offsetYTicks: 2 * terrainPhysicsTicksPerWorldUnit,
      radiusTicks: 10 * terrainPhysicsTicksPerWorldUnit,
      verticalHalfSegmentTicks: 4 * terrainPhysicsTicksPerWorldUnit,
    );

    expect(right.center.x, 105);
    expect(left.center.x, 95);
    expect(
      right.bounds.maxY - right.bounds.minY,
      left.bounds.maxY - left.bounds.minY,
    );
    expect(
      right.sweptBounds(
        -20 * terrainPhysicsTicksPerWorldUnit,
        10 * terrainPhysicsTicksPerWorldUnit,
      ),
      isA<TerrainAabb>()
          .having(
            (bounds) => bounds.minX,
            'minX',
            right.bounds.minX - 20 * terrainPhysicsTicksPerWorldUnit,
          )
          .having((bounds) => bounds.minY, 'minY', right.bounds.minY)
          .having((bounds) => bounds.maxX, 'maxX', right.bounds.maxX)
          .having(
            (bounds) => bounds.maxY,
            'maxY',
            right.bounds.maxY + 10 * terrainPhysicsTicksPerWorldUnit,
          ),
    );
  });

  test('equal-time hit tie uses canonical edge identity', () {
    final earlier = CapsuleSweepHit()
      ..hit = true
      ..timeOfImpact = 0.5
      ..edgeId = TerrainEdgeId(
        chunkIndex: 0,
        chunkKey: 'chunk',
        shapeId: 'a',
        localEdgeIndex: 0,
      );
    final later = CapsuleSweepHit()
      ..hit = true
      ..timeOfImpact =
          0.5 + terrainContactEpsilonTicks / terrainPhysicsTicksPerWorldUnit / 2
      ..edgeId = TerrainEdgeId(
        chunkIndex: 0,
        chunkKey: 'chunk',
        shapeId: 'b',
        localEdgeIndex: 0,
      );

    expect(kernel.compareHits(earlier, later), lessThan(0));
  });
}

int _scaleDirection(int direction, int distance) {
  final product = direction * distance;
  final magnitude =
      (product.abs() + terrainDirectionScale ~/ 2) ~/ terrainDirectionScale;
  return product < 0 ? -magnitude : magnitude;
}

TerrainEdge _edge(
  int id,
  double startX,
  double startY,
  double endX,
  double endY,
) {
  final start = TerrainPoint.fromWorld(startX, startY);
  final end = TerrainPoint.fromWorld(endX, endY);
  final dx = end.xTicks - start.xTicks;
  final dy = end.yTicks - start.yTicks;
  return TerrainEdge(
    id: TerrainEdgeId(
      chunkIndex: 0,
      chunkKey: 'chunk',
      shapeId: 'edge_$id',
      localEdgeIndex: 0,
    ),
    start: start,
    end: end,
    tangent: TerrainDirection.fromDelta(dx, dy),
    outwardNormal: TerrainDirection.fromDelta(dy, -dx),
    collisionMode: TerrainCollisionMode.solid,
    surfaceKind: 'terrain',
    materialKey: null,
    previousId: null,
    nextId: null,
    startJoin: TerrainVertexJoin.exposed,
    endJoin: TerrainVertexJoin.exposed,
    bounds: TerrainAabb(
      minX: math.min(start.xTicks, end.xTicks),
      minY: math.min(start.yTicks, end.yTicks),
      maxX: math.max(start.xTicks, end.xTicks),
      maxY: math.max(start.yTicks, end.yTicks),
    ),
  );
}
