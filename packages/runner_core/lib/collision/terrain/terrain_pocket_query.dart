import 'dart:math' as math;

import 'capsule_segment_kernel.dart';
import 'terrain_capsule_controller.dart';
import 'terrain_edge.dart';
import 'terrain_edge_id.dart';
import 'terrain_edge_index.dart';
import 'terrain_geometry.dart';
import 'terrain_motion_request.dart';
import 'terrain_numeric.dart';
import 'terrain_polygon.dart';
import 'terrain_traversal_profile.dart';

/// Local fall-trap evidence for one capsule, in physics ticks.
///
/// [outline] marks the narrowing space between exposed solid faces; [center]
/// is a verified unsupported resting position. This is not route reachability
/// evidence and says nothing about optional air jumps or teleport abilities.
final class TerrainPocket {
  TerrainPocket({
    required this.leftEdgeId,
    required this.rightEdgeId,
    required this.center,
    required Iterable<TerrainPoint> outline,
  }) : outline = List.unmodifiable(outline);

  final TerrainEdgeId leftEdgeId;
  final TerrainEdgeId rightEdgeId;
  final TerrainPoint center;
  final List<TerrainPoint> outline;
}

/// Authoring query for gravity-driven capsules wedged between steep faces.
///
/// Uses exposed compiled edges and the production controller. Candidate face
/// offsets are only a broad phase: full-capsule clearance, finite-face contact,
/// and repeated unsupported downward blocking must all agree. Does not mutate
/// geometry, actors, or runtime policy. Flying and kinematic policies return no
/// fall traps. Endpoint-only pinches and grounded pits require other checks.
final class TerrainPocketQuery {
  TerrainPocketQuery(this.geometry)
    : _index = TerrainEdgeIndex(edges: geometry.edges);

  final TerrainGeometry geometry;
  final TerrainEdgeIndex _index;

  /// Returns immutable fall-wedge evidence for this capsule and actor policy.
  /// Capsule dimensions and returned positions use 1/1024-world-unit ticks.
  List<TerrainPocket> find({
    required int radiusTicks,
    required int verticalHalfSegmentTicks,
    required TerrainTraversalProfile profile,
  }) {
    if (radiusTicks <= 0 || verticalHalfSegmentTicks < 0) {
      throw ArgumentError('Pocket queries require a positive upright capsule.');
    }
    if (!profile.enabled ||
        profile.isKinematic ||
        !profile.useGravity ||
        profile.gravityScaleBp == 0 ||
        !profile.collideLeftWalls ||
        !profile.collideRightWalls) {
      return const [];
    }
    final steep =
        geometry.edges
            .where(
              (edge) =>
                  edge.collisionMode == TerrainCollisionMode.solid &&
                  edge.outwardNormal.yTicks <= 0 &&
                  !profile.isWalkableSupport(edge),
            )
            .toList()
          ..sort((a, b) => a.id.compareTo(b.id));
    final controller = TerrainCapsuleController(
      geometry: geometry,
      index: _index,
      profile: profile,
    );
    final result = <TerrainPocket>[];
    for (final left in steep.where((edge) => edge.outwardNormal.xTicks > 0)) {
      for (final right in steep.where(
        (edge) => edge.outwardNormal.xTicks < 0,
      )) {
        final top = math.max(left.bounds.minY, right.bounds.minY);
        final bottom = math.min(left.bounds.maxY, right.bounds.maxY);
        if (top >= bottom) continue;
        final leftTop = _xAtY(left, top);
        final rightTop = _xAtY(right, top);
        if (leftTop >= rightTop) continue;

        final center = _offsetIntersection(
          left,
          right,
          radiusTicks,
          verticalHalfSegmentTicks,
        );
        if (center == null) continue;
        if (!_touchesFace(
              left,
              center,
              radiusTicks,
              verticalHalfSegmentTicks,
            ) ||
            !_touchesFace(
              right,
              center,
              radiusTicks,
              verticalHalfSegmentTicks,
            )) {
          continue;
        }
        final verified = _verify(
          controller,
          center,
          left,
          right,
          radiusTicks,
          verticalHalfSegmentTicks,
        );
        if (verified == null) continue;
        var endY = bottom;
        final bottomGap = _xAtY(right, bottom) - _xAtY(left, bottom);
        if (bottomGap < 0) {
          final topGap = rightTop - leftTop;
          endY = top + ((bottom - top) * topGap / (topGap - bottomGap)).floor();
        }
        result.add(
          TerrainPocket(
            leftEdgeId: left.id,
            rightEdgeId: right.id,
            center: verified,
            outline: [
              TerrainPoint(leftTop, top),
              TerrainPoint(rightTop, top),
              TerrainPoint(_xAtY(right, endY), endY),
              TerrainPoint(_xAtY(left, endY), endY),
            ],
          ),
        );
      }
    }
    return List.unmodifiable(result);
  }

  TerrainPoint? _offsetIntersection(
    TerrainEdge left,
    TerrainEdge right,
    int radius,
    int halfSegment,
  ) {
    // Raw normals retain exact face direction. Quantized unit normals are for
    // policy classification, not for locating the geometric intersection.
    final ax = left.dyTicks.toDouble();
    final ay = -left.dxTicks.toDouble();
    final bx = right.dyTicks.toDouble();
    final by = -right.dxTicks.toDouble();
    final determinant = ax * by - ay * bx;
    if (determinant.abs() < terrainParametricGuard) return null;
    final clearance = radius + terrainCollisionSkinTicks;
    final a =
        ax * left.start.xTicks +
        ay * left.start.yTicks +
        clearance * math.sqrt(ax * ax + ay * ay) +
        halfSegment * ay.abs();
    final b =
        bx * right.start.xTicks +
        by * right.start.yTicks +
        clearance * math.sqrt(bx * bx + by * by) +
        halfSegment * by.abs();
    final x = (a * by - ay * b) / determinant;
    final y = (ax * b - a * bx) / determinant;
    if (!x.isFinite ||
        !y.isFinite ||
        x.abs() > terrainMaxAbsPhysicsTicks ||
        y.abs() > terrainMaxAbsPhysicsTicks) {
      return null;
    }
    return TerrainPoint(x.round(), y.round());
  }

  bool _touchesFace(
    TerrainEdge edge,
    TerrainPoint center,
    int radius,
    int half,
  ) {
    final contact = CapsuleSegmentContact();
    CapsuleSegmentKernel().evaluateAtCenter(
      centerXTicks: center.xTicks,
      centerYTicks: center.yTicks,
      radiusTicks: radius,
      verticalHalfSegmentTicks: half,
      edge: edge,
      out: contact,
    );
    return contact.feature == TerrainSegmentFeature.face &&
        (contact.signedSeparationTicks - terrainCollisionSkinTicks).abs() <=
            terrainContactEpsilonTicks * 2;
  }

  TerrainPoint? _verify(
    TerrainCapsuleController controller,
    TerrainPoint center,
    TerrainEdge left,
    TerrainEdge right,
    int radius,
    int half,
  ) {
    final out = TerrainCapsuleMotionResult();
    // Approach from one world unit above the candidate to reject buried or
    // ceiling-occluded capsules; no overlap recovery may manufacture a warning.
    var x = center.xTicks;
    var y = center.yTicks - terrainPhysicsTicksPerWorldUnit;
    var stationaryTicks = 0;
    for (var tick = 0; tick < 16; tick++) {
      controller.moveAtValues(
        centerXTicks: x,
        centerYTicks: y,
        radiusTicks: radius,
        verticalHalfSegmentTicks: half,
        displacementXTicks: 0,
        displacementYTicks: terrainPhysicsTicksPerWorldUnit,
        mode: TerrainMotionMode.worldSpace,
        beganGrounded: false,
        out: out,
      );
      if (out.grounded || out.usedRecovery) return null;
      final movement =
          (out.finalCenterXTicks - x).abs() + (out.finalCenterYTicks - y).abs();
      final bothFaces =
          out.contactEdgeIds.take(out.contactCount).contains(left.id) &&
          out.contactEdgeIds.take(out.contactCount).contains(right.id);
      stationaryTicks = bothFaces && movement <= terrainContactEpsilonTicks * 2
          ? stationaryTicks + 1
          : 0;
      x = out.finalCenterXTicks;
      y = out.finalCenterYTicks;
      // Four successive blocked requests distinguish a persistent wedge from
      // one transient collision while sliding toward an ordinary floor.
      if (stationaryTicks >= 4) return TerrainPoint(x, y);
    }
    return null;
  }
}

int _xAtY(TerrainEdge edge, int y) =>
    edge.start.xTicks +
    ((y - edge.start.yTicks) * edge.dxTicks / edge.dyTicks).round();
