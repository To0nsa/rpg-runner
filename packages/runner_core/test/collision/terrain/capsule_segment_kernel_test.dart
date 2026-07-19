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
  });

  test('equal-time hit tie uses canonical edge identity', () {
    final earlier = CapsuleSweepHit()
      ..hit = true
      ..timeOfImpact = 0.5
      ..edgeId = const TerrainEdgeId(
        chunkIndex: 0,
        chunkKey: 'chunk',
        shapeId: 'a',
        localEdgeIndex: 0,
      );
    final later = CapsuleSweepHit()
      ..hit = true
      ..timeOfImpact =
          0.5 + terrainContactEpsilonTicks / terrainPhysicsTicksPerWorldUnit / 2
      ..edgeId = const TerrainEdgeId(
        chunkIndex: 0,
        chunkKey: 'chunk',
        shapeId: 'b',
        localEdgeIndex: 0,
      );

    expect(kernel.compareHits(earlier, later), lessThan(0));
  });
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
