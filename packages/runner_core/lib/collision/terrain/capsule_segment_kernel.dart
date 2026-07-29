import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'terrain_edge.dart';
import 'terrain_edge_id.dart';
import 'terrain_numeric.dart';
import 'upright_capsule.dart';

/// Terrain feature selected by a closest-point or sweep query.
enum TerrainSegmentFeature {
  /// Radial contact with the directed edge's start point.
  startEndpoint,

  /// Contact with the finite edge interior using its compiled face normal.
  face,

  /// Radial contact with the directed edge's end point.
  endEndpoint,
}

/// Caller-owned closest-point output; coordinates are physics ticks.
final class TerrainClosestPointResult {
  final Float64List _values = Float64List(4);

  /// Closest horizontal coordinate in 1/1024-world-unit physics ticks.
  @pragma('vm:prefer-inline')
  double get pointXTicks => _values[0];
  @pragma('vm:prefer-inline')
  set pointXTicks(double value) => _values[0] = value;

  /// Closest vertical coordinate in 1/1024-world-unit physics ticks.
  @pragma('vm:prefer-inline')
  double get pointYTicks => _values[1];
  @pragma('vm:prefer-inline')
  set pointYTicks(double value) => _values[1] = value;

  /// Clamped parametric position on the segment in the inclusive range 0..1.
  @pragma('vm:prefer-inline')
  double get segmentT => _values[2];
  @pragma('vm:prefer-inline')
  set segmentT(double value) => _values[2] = value;

  /// Squared point-to-segment distance in physics ticks squared.
  @pragma('vm:prefer-inline')
  double get squaredDistanceTicks => _values[3];
  @pragma('vm:prefer-inline')
  set squaredDistanceTicks(double value) => _values[3] = value;
}

/// Caller-owned closest-points output for two finite segments.
final class TerrainSegmentPairResult {
  final Float64List _values = Float64List(7);

  /// Closest horizontal coordinate on the first segment, in physics ticks.
  @pragma('vm:prefer-inline')
  double get firstXTicks => _values[0];
  @pragma('vm:prefer-inline')
  set firstXTicks(double value) => _values[0] = value;

  /// Closest vertical coordinate on the first segment, in physics ticks.
  @pragma('vm:prefer-inline')
  double get firstYTicks => _values[1];
  @pragma('vm:prefer-inline')
  set firstYTicks(double value) => _values[1] = value;

  /// Closest horizontal coordinate on the second segment, in physics ticks.
  @pragma('vm:prefer-inline')
  double get secondXTicks => _values[2];
  @pragma('vm:prefer-inline')
  set secondXTicks(double value) => _values[2] = value;

  /// Closest vertical coordinate on the second segment, in physics ticks.
  @pragma('vm:prefer-inline')
  double get secondYTicks => _values[3];
  @pragma('vm:prefer-inline')
  set secondYTicks(double value) => _values[3] = value;

  /// Clamped first-segment parametric position in the inclusive range 0..1.
  @pragma('vm:prefer-inline')
  double get firstT => _values[4];
  @pragma('vm:prefer-inline')
  set firstT(double value) => _values[4] = value;

  /// Clamped second-segment parametric position in the inclusive range 0..1.
  @pragma('vm:prefer-inline')
  double get secondT => _values[5];
  @pragma('vm:prefer-inline')
  set secondT(double value) => _values[5] = value;

  /// Squared distance between the closest points, in physics ticks squared.
  @pragma('vm:prefer-inline')
  double get squaredDistanceTicks => _values[6];
  @pragma('vm:prefer-inline')
  set squaredDistanceTicks(double value) => _values[6] = value;
}

/// Caller-owned capsule/edge separation and overlap diagnostic.
final class CapsuleSegmentContact {
  CapsuleSegmentContact() {
    _values[0] = double.infinity;
  }

  final Float64List _values = Float64List(2);

  /// Surface separation in physics ticks; negative values are penetration.
  @pragma('vm:prefer-inline')
  double get signedSeparationTicks => _values[0];
  @pragma('vm:prefer-inline')
  set signedSeparationTicks(double value) => _values[0] = value;

  /// Non-negative penetration depth in physics ticks.
  @pragma('vm:prefer-inline')
  double get penetrationTicks => _values[1];
  @pragma('vm:prefer-inline')
  set penetrationTicks(double value) => _values[1] = value;

  /// Floor of the signed separation in physics ticks.
  ///
  /// Valid after either full or recovery-only evaluation.
  int signedSeparationFloorTicks = 0;

  /// Integer physics-tick correction needed to reach the collision skin.
  ///
  /// Valid after either full or recovery-only evaluation.
  int collisionSkinCorrectionTicks = 0;

  /// Contact point horizontal coordinate rounded to physics ticks.
  int pointXTicks = 0;

  /// Contact point vertical coordinate rounded to physics ticks.
  int pointYTicks = 0;

  /// Contact normal horizontal component using [terrainDirectionScale].
  int normalXTicks = 0;

  /// Contact normal vertical component using [terrainDirectionScale].
  int normalYTicks = 0;

  /// Finite edge feature that produced the closest contact.
  TerrainSegmentFeature feature = TerrainSegmentFeature.face;

  /// Stable source edge identity, populated after [CapsuleSegmentKernel.evaluate].
  TerrainEdgeId? edgeId;

  /// Whether separation lies inside the frozen inclusive contact tolerance.
  bool get overlaps => signedSeparationTicks <= terrainContactEpsilonTicks;

  /// Compares the current separation without exposing a boxed double.
  @pragma('vm:prefer-inline')
  bool separationLessThanTicks(int thresholdTicks) =>
      _values[0] < thresholdTicks;

  /// Compares the current separation without exposing a boxed double.
  @pragma('vm:prefer-inline')
  bool separationAtMostTicks(int thresholdTicks) =>
      _values[0] <= thresholdTicks;

  /// Signed separation converted to world units.
  double get signedSeparationWorld =>
      signedSeparationTicks / terrainPhysicsTicksPerWorldUnit;
}

/// Caller-owned result for a moving upright capsule against one terrain edge.
final class CapsuleSweepHit {
  CapsuleSweepHit() {
    _values[0] = 1;
    _values[1] = double.infinity;
  }

  final Float64List _values = Float64List(2);

  /// Whether continuous sweep found an accepted contact.
  bool hit = false;

  /// Whether the capsule began beyond the negative contact tolerance.
  bool startedOverlapping = false;

  /// Fraction of the supplied displacement in the inclusive range 0..1.
  @pragma('vm:prefer-inline')
  double get timeOfImpact => _values[0];
  @pragma('vm:prefer-inline')
  set timeOfImpact(double value) => _values[0] = value;

  /// Surface separation at [timeOfImpact], in physics ticks.
  @pragma('vm:prefer-inline')
  double get signedSeparationTicks => _values[1];
  @pragma('vm:prefer-inline')
  set signedSeparationTicks(double value) => _values[1] = value;

  /// Contact point horizontal coordinate rounded to physics ticks.
  int pointXTicks = 0;

  /// Contact point vertical coordinate rounded to physics ticks.
  int pointYTicks = 0;

  /// Contact normal horizontal component using [terrainDirectionScale].
  int normalXTicks = 0;

  /// Contact normal vertical component using [terrainDirectionScale].
  int normalYTicks = 0;

  /// Finite edge feature selected at [timeOfImpact].
  TerrainSegmentFeature feature = TerrainSegmentFeature.face;

  /// Stable source edge identity when [hit] is true.
  TerrainEdgeId? edgeId;

  /// Restores the no-hit state without replacing this caller-owned object.
  void reset() {
    hit = false;
    startedOverlapping = false;
    _values[0] = 1;
    _values[1] = double.infinity;
    pointXTicks = 0;
    pointYTicks = 0;
    normalXTicks = 0;
    normalYTicks = 0;
    feature = TerrainSegmentFeature.face;
    edgeId = null;
  }

  /// Copies a hit without exposing floating-point fields to the controller.
  @pragma('vm:prefer-inline')
  void copyFrom(CapsuleSweepHit source) {
    hit = source.hit;
    startedOverlapping = source.startedOverlapping;
    _values[0] = source._values[0];
    _values[1] = source._values[1];
    pointXTicks = source.pointXTicks;
    pointYTicks = source.pointYTicks;
    normalXTicks = source.normalXTicks;
    normalYTicks = source.normalYTicks;
    feature = source.feature;
    edgeId = source.edgeId;
  }

  /// Quantizes the supplied displacement remaining after this impact.
  @pragma('vm:prefer-inline')
  int displacementAfterImpactTicks(int displacementTicks) =>
      terrainPhysicsTickValueToInt(
        displacementTicks * (1 - _values[0]),
        name: 'displacementAfterImpact',
      );

  /// Advances to this impact while retaining [skinTicks] along the normal.
  ///
  /// [closingProjection] is the positive, direction-scaled displacement into
  /// the accepted constraint normal.
  @pragma('vm:prefer-inline')
  int displacementBeforeImpactTicks({
    required int displacementTicks,
    required int closingProjection,
    required int skinTicks,
  }) {
    if (closingProjection <= 0) return 0;
    final closingDistance = closingProjection / terrainDirectionScale;
    final safeFraction = math.max(
      0.0,
      _values[0] - skinTicks / closingDistance,
    );
    return terrainPhysicsTickValueToInt(
      displacementTicks * safeFraction,
      name: 'displacementBeforeImpact',
    );
  }
}

/// Allocation-free closest-distance and continuous capsule/segment primitives.
///
/// One instance owns mutable scratch state and must not be used concurrently.
/// It deliberately contains no grounding, one-way, or walkability policy.
class CapsuleSegmentKernel {
  final TerrainSegmentPairResult _pair = TerrainSegmentPairResult();

  /// Writes the closest point on finite segment `[start,end]` into [out].
  void closestPointOnSegment({
    required TerrainPoint point,
    required TerrainPoint start,
    required TerrainPoint end,
    required TerrainClosestPointResult out,
  }) {
    final dx = (end.xTicks - start.xTicks).toDouble();
    final dy = (end.yTicks - start.yTicks).toDouble();
    final lengthSq = dx * dx + dy * dy;
    var t = 0.0;
    if (lengthSq > 0) {
      t =
          ((point.xTicks - start.xTicks) * dx +
              (point.yTicks - start.yTicks) * dy) /
          lengthSq;
      t = t.clamp(0.0, 1.0);
    }
    out.pointXTicks = start.xTicks + dx * t;
    out.pointYTicks = start.yTicks + dy * t;
    out.segmentT = t;
    final separationX = point.xTicks - out.pointXTicks;
    final separationY = point.yTicks - out.pointYTicks;
    out.squaredDistanceTicks =
        separationX * separationX + separationY * separationY;
  }

  /// Writes closest points between two finite segments into [out].
  void closestPointsBetweenSegments({
    required TerrainPoint firstStart,
    required TerrainPoint firstEnd,
    required TerrainPoint secondStart,
    required TerrainPoint secondEnd,
    required TerrainSegmentPairResult out,
  }) {
    _closestSegmentPair(
      firstStart.xTicks.toDouble(),
      firstStart.yTicks.toDouble(),
      firstEnd.xTicks.toDouble(),
      firstEnd.yTicks.toDouble(),
      secondStart.xTicks.toDouble(),
      secondStart.yTicks.toDouble(),
      secondEnd.xTicks.toDouble(),
      secondEnd.yTicks.toDouble(),
      out,
    );
  }

  /// Evaluates signed capsule/edge separation at the capsule's current center.
  void evaluate({
    required UprightCapsule capsule,
    required TerrainEdge edge,
    required CapsuleSegmentContact out,
  }) {
    evaluateAtCenter(
      centerXTicks: capsule.center.xTicks,
      centerYTicks: capsule.center.yTicks,
      radiusTicks: capsule.radiusTicks,
      verticalHalfSegmentTicks: capsule.verticalHalfSegmentTicks,
      edge: edge,
      out: out,
    );
  }

  /// Primitive-center equivalent of [evaluate] for allocation-sensitive loops.
  @pragma('vm:prefer-inline')
  void evaluateAtCenter({
    required int centerXTicks,
    required int centerYTicks,
    required int radiusTicks,
    required int verticalHalfSegmentTicks,
    required TerrainEdge edge,
    required CapsuleSegmentContact out,
  }) {
    _evaluateAtCenter(
      centerXTicks: centerXTicks,
      centerYTicks: centerYTicks,
      radiusTicks: radiusTicks,
      verticalHalfSegmentTicks: verticalHalfSegmentTicks,
      edge: edge,
      out: out,
    );
  }

  /// Evaluates a walkable upward support with integer-only closest distance.
  ///
  /// The bottom endpoint of an upright capsule spine is always closest to an
  /// upward-facing support plane. Keeping this retained-support validation in
  /// integer space avoids one boxed floating value per dynamic body and tick.
  @pragma('vm:prefer-inline')
  bool evaluateSupportAtCenterWithin({
    required int centerXTicks,
    required int centerYTicks,
    required int radiusTicks,
    required int verticalHalfSegmentTicks,
    required TerrainEdge edge,
    required int maximumSeparationTicks,
    required CapsuleSegmentContact out,
  }) {
    if (edge.outwardNormal.yTicks >= 0) return false;
    final pointX = centerXTicks;
    final pointY = centerYTicks + verticalHalfSegmentTicks;
    final deltaX = pointX - edge.start.xTicks;
    final deltaY = pointY - edge.start.yTicks;
    final edgeLengthSquared = edge.lengthSquaredTicks;
    final projection = deltaX * edge.dxTicks + deltaY * edge.dyTicks;
    final maximumDistance = radiusTicks + maximumSeparationTicks;
    int closestX;
    int closestY;
    bool withinMaximumDistance;
    if (projection <= 0) {
      closestX = edge.start.xTicks;
      closestY = edge.start.yTicks;
      final x = pointX - closestX;
      final y = pointY - closestY;
      withinMaximumDistance =
          x * x + y * y <= maximumDistance * maximumDistance;
      out.feature = TerrainSegmentFeature.startEndpoint;
    } else if (projection >= edgeLengthSquared) {
      closestX = edge.end.xTicks;
      closestY = edge.end.yTicks;
      final x = pointX - closestX;
      final y = pointY - closestY;
      withinMaximumDistance =
          x * x + y * y <= maximumDistance * maximumDistance;
      out.feature = TerrainSegmentFeature.endEndpoint;
    } else {
      closestX =
          edge.start.xTicks +
          _roundedDivide(
            projection * edge.projectionXFactor,
            edge.projectionXDenominator,
          );
      closestY =
          edge.start.yTicks +
          _roundedDivide(
            projection * edge.projectionYFactor,
            edge.projectionYDenominator,
          );
      final cross = deltaX * edge.dyTicks - deltaY * edge.dxTicks;
      withinMaximumDistance =
          cross.abs() * terrainEdgeLengthFractionScale <=
          maximumDistance * edge.lengthScaledCeilTicks;
      out.feature = TerrainSegmentFeature.face;
    }
    out
      ..pointXTicks = closestX
      ..pointYTicks = closestY
      ..edgeId = edge.id;
    return withinMaximumDistance;
  }

  /// Writes only the integer facts needed by overlap recovery.
  ///
  /// Contact point, feature, normal, edge, separation floor, and collision-skin
  /// correction use physics ticks and match [evaluateAtCenter]. Floating
  /// separation and penetration fields are intentionally left unchanged.
  @pragma('vm:prefer-inline')
  void evaluateRecoveryAtCenter({
    required int centerXTicks,
    required int centerYTicks,
    required int radiusTicks,
    required int verticalHalfSegmentTicks,
    required TerrainEdge edge,
    required CapsuleSegmentContact out,
  }) {
    final centerX = centerXTicks.toDouble();
    final centerY = centerYTicks.toDouble();
    _closestSegmentPair(
      centerX,
      centerY - verticalHalfSegmentTicks,
      centerX,
      centerY + verticalHalfSegmentTicks,
      edge.start.xTicks.toDouble(),
      edge.start.yTicks.toDouble(),
      edge.end.xTicks.toDouble(),
      edge.end.yTicks.toDouble(),
      _pair,
    );
    final distance = math.sqrt(_pair.squaredDistanceTicks);
    final separation = distance - radiusTicks;
    out
      ..signedSeparationFloorTicks = separation.floor()
      ..collisionSkinCorrectionTicks = (terrainCollisionSkinTicks - separation)
          .ceil()
      ..pointXTicks = terrainPhysicsTickValueToInt(
        _pair.secondXTicks,
        name: 'contactPointX',
      )
      ..pointYTicks = terrainPhysicsTickValueToInt(
        _pair.secondYTicks,
        name: 'contactPointY',
      )
      ..feature = _featureFor(_pair.secondT)
      ..edgeId = edge.id;
    _writeContactNormal(
      edge,
      _pair.firstXTicks - _pair.secondXTicks,
      _pair.firstYTicks - _pair.secondYTicks,
      distance,
      out,
    );
  }

  /// Sweeps [capsule] by integer physics-tick displacement against [edge].
  ///
  /// Conservative advancement uses exactly eight advances and, after a
  /// bracket, eight bisection refinements. Discrete end overlap is diagnostic
  /// only and never converted into a successful sweep.
  void sweep({
    required UprightCapsule capsule,
    required int displacementXTicks,
    required int displacementYTicks,
    required TerrainEdge edge,
    required CapsuleSweepHit out,
  }) {
    sweepAtCenter(
      centerXTicks: capsule.center.xTicks,
      centerYTicks: capsule.center.yTicks,
      radiusTicks: capsule.radiusTicks,
      verticalHalfSegmentTicks: capsule.verticalHalfSegmentTicks,
      displacementXTicks: displacementXTicks,
      displacementYTicks: displacementYTicks,
      edge: edge,
      out: out,
    );
  }

  /// Primitive-center equivalent of [sweep] for allocation-sensitive loops.
  @pragma('vm:prefer-inline')
  void sweepAtCenter({
    required int centerXTicks,
    required int centerYTicks,
    required int radiusTicks,
    required int verticalHalfSegmentTicks,
    required int displacementXTicks,
    required int displacementYTicks,
    required TerrainEdge edge,
    required CapsuleSweepHit out,
  }) {
    out.reset();
    final speedTicks = math.sqrt(
      displacementXTicks.toDouble() * displacementXTicks +
          displacementYTicks.toDouble() * displacementYTicks,
    );

    var time = 0.0;
    var separation = _separationAt(
      centerXTicks,
      centerYTicks,
      radiusTicks,
      verticalHalfSegmentTicks,
      edge,
      displacementXTicks,
      displacementYTicks,
      time,
    );
    if (separation <= terrainContactEpsilonTicks) {
      _writeSweepHit(
        centerXTicks,
        centerYTicks,
        radiusTicks,
        verticalHalfSegmentTicks,
        edge,
        displacementXTicks,
        displacementYTicks,
        time,
        out,
        startedOverlapping: separation < -terrainContactEpsilonTicks,
      );
      return;
    }
    if (speedTicks == 0) return;

    var bracketLow = 0.0;
    var bracketHigh = 0.0;
    var bracketed = false;
    for (var iteration = 0; iteration < 8; iteration += 1) {
      final remaining = 1.0 - time;
      if (remaining <= 0) break;
      final distance = separation + radiusTicks;
      final closingSpeed = distance <= terrainGeometryEpsilonTicks
          ? speedTicks
          : -((_pair.firstXTicks - _pair.secondXTicks) * displacementXTicks +
                    (_pair.firstYTicks - _pair.secondYTicks) *
                        displacementYTicks) /
                distance;
      if (closingSpeed <= terrainParametricGuard) break;
      // The closest-distance function is convex for a translating capsule
      // against one segment. Advancing to its tangent-plane root remains
      // conservative and converges on endpoint grazing within the fixed cap.
      final advance = separation / closingSpeed;
      if (advance > remaining) break;
      final nextTime = math.min(
        1.0,
        time + math.max(advance, terrainParametricGuard),
      );
      final nextSeparation = _separationAt(
        centerXTicks,
        centerYTicks,
        radiusTicks,
        verticalHalfSegmentTicks,
        edge,
        displacementXTicks,
        displacementYTicks,
        nextTime,
      );
      if (nextSeparation <= terrainContactEpsilonTicks) {
        bracketLow = time;
        bracketHigh = nextTime;
        bracketed = true;
        break;
      }
      if (nextTime >= 1.0 || nextTime == time) break;
      time = nextTime;
      separation = nextSeparation;
    }

    if (!bracketed) return;
    for (var iteration = 0; iteration < 8; iteration += 1) {
      final middle = (bracketLow + bracketHigh) * 0.5;
      final middleSeparation = _separationAt(
        centerXTicks,
        centerYTicks,
        radiusTicks,
        verticalHalfSegmentTicks,
        edge,
        displacementXTicks,
        displacementYTicks,
        middle,
      );
      if (middleSeparation <= terrainContactEpsilonTicks) {
        bracketHigh = middle;
      } else {
        bracketLow = middle;
      }
    }
    _writeSweepHit(
      centerXTicks,
      centerYTicks,
      radiusTicks,
      verticalHalfSegmentTicks,
      edge,
      displacementXTicks,
      displacementYTicks,
      bracketHigh,
      out,
      startedOverlapping: false,
    );
  }

  /// Compares two successful hits using time tolerance then canonical edge ID.
  int compareHits(CapsuleSweepHit left, CapsuleSweepHit right) {
    final timeDelta = left.timeOfImpact - right.timeOfImpact;
    final timeTolerance =
        terrainContactEpsilonTicks / terrainPhysicsTicksPerWorldUnit;
    if (timeDelta.abs() > timeTolerance) {
      return timeDelta < 0 ? -1 : 1;
    }
    final leftId = left.edgeId;
    final rightId = right.edgeId;
    if (leftId == null || rightId == null) {
      throw StateError('Only successful sweep hits can be compared.');
    }
    return leftId.compareTo(rightId);
  }

  /// Whether two hit times fall inside the frozen equal-time tolerance.
  @pragma('vm:prefer-inline')
  bool hitsHaveEqualTime(CapsuleSweepHit left, CapsuleSweepHit right) =>
      (left._values[0] - right._values[0]).abs() <=
      terrainContactEpsilonTicks / terrainPhysicsTicksPerWorldUnit;

  /// SHA-256 digest of successful hits in canonical `contacts-v1` order.
  ///
  /// This allocates by design and is intended for golden evidence, never the
  /// collision hot path. Time and separation are quantized to integer physics
  /// ticks before serialization.
  String contactOrderSignature(Iterable<CapsuleSweepHit> hits) {
    final ordered = List<CapsuleSweepHit>.of(hits);
    for (final hit in ordered) {
      if (!hit.hit || hit.edgeId == null) {
        throw ArgumentError('Contact signatures require successful hits.');
      }
    }
    ordered.sort(compareHits);
    final records = <String>[
      for (final hit in ordered)
        <String>[
          'contacts-v1',
          hit.edgeId!.canonicalKey,
          terrainPhysicsTickValueToInt(
            hit.timeOfImpact * terrainPhysicsTicksPerWorldUnit,
            name: 'timeOfImpact',
          ).toString(),
          terrainPhysicsTickValueToInt(
            hit.signedSeparationTicks,
            name: 'signedSeparationTicks',
          ).toString(),
          hit.pointXTicks.toString(),
          hit.pointYTicks.toString(),
          hit.normalXTicks.toString(),
          hit.normalYTicks.toString(),
          hit.feature.name,
          hit.startedOverlapping ? '1' : '0',
        ].map((field) => '${utf8.encode(field).length}:$field').join('|'),
    ];
    return sha256.convert(utf8.encode(records.join('\n'))).toString();
  }

  @pragma('vm:prefer-inline')
  double _separationAt(
    int centerXTicks,
    int centerYTicks,
    int radiusTicks,
    int verticalHalfSegmentTicks,
    TerrainEdge edge,
    int displacementXTicks,
    int displacementYTicks,
    double time,
  ) {
    final centerX = centerXTicks + displacementXTicks.toDouble() * time;
    final centerY = centerYTicks + displacementYTicks.toDouble() * time;
    _closestSegmentPair(
      centerX,
      centerY - verticalHalfSegmentTicks,
      centerX,
      centerY + verticalHalfSegmentTicks,
      edge.start.xTicks.toDouble(),
      edge.start.yTicks.toDouble(),
      edge.end.xTicks.toDouble(),
      edge.end.yTicks.toDouble(),
      _pair,
    );
    return math.sqrt(_pair.squaredDistanceTicks) - radiusTicks;
  }

  @pragma('vm:prefer-inline')
  void _writeSweepHit(
    int centerXTicks,
    int centerYTicks,
    int radiusTicks,
    int verticalHalfSegmentTicks,
    TerrainEdge edge,
    int displacementXTicks,
    int displacementYTicks,
    double time,
    CapsuleSweepHit out, {
    required bool startedOverlapping,
  }) {
    final centerX = centerXTicks + displacementXTicks.toDouble() * time;
    final centerY = centerYTicks + displacementYTicks.toDouble() * time;
    _closestSegmentPair(
      centerX,
      centerY - verticalHalfSegmentTicks,
      centerX,
      centerY + verticalHalfSegmentTicks,
      edge.start.xTicks.toDouble(),
      edge.start.yTicks.toDouble(),
      edge.end.xTicks.toDouble(),
      edge.end.yTicks.toDouble(),
      _pair,
    );
    final distance = math.sqrt(_pair.squaredDistanceTicks);
    out
      ..hit = true
      ..startedOverlapping = startedOverlapping
      ..timeOfImpact = time
      ..signedSeparationTicks = distance - radiusTicks
      ..pointXTicks = terrainPhysicsTickValueToInt(
        _pair.secondXTicks,
        name: 'contactPointX',
      )
      ..pointYTicks = terrainPhysicsTickValueToInt(
        _pair.secondYTicks,
        name: 'contactPointY',
      )
      ..feature = _featureFor(_pair.secondT)
      ..edgeId = edge.id;
    _writeNormal(
      edge,
      _pair.firstXTicks - _pair.secondXTicks,
      _pair.firstYTicks - _pair.secondYTicks,
      distance,
      out,
    );
  }

  @pragma('vm:prefer-inline')
  void _evaluateAtCenter({
    required int centerXTicks,
    required int centerYTicks,
    required int radiusTicks,
    required int verticalHalfSegmentTicks,
    required TerrainEdge edge,
    required CapsuleSegmentContact out,
  }) {
    final centerX = centerXTicks.toDouble();
    final centerY = centerYTicks.toDouble();
    _closestSegmentPair(
      centerX,
      centerY - verticalHalfSegmentTicks,
      centerX,
      centerY + verticalHalfSegmentTicks,
      edge.start.xTicks.toDouble(),
      edge.start.yTicks.toDouble(),
      edge.end.xTicks.toDouble(),
      edge.end.yTicks.toDouble(),
      _pair,
    );
    final distance = math.sqrt(_pair.squaredDistanceTicks);
    final separation = distance - radiusTicks;
    out
      ..signedSeparationTicks = separation
      ..penetrationTicks = separation < 0 ? -separation : 0
      ..signedSeparationFloorTicks = separation.floor()
      ..collisionSkinCorrectionTicks = (terrainCollisionSkinTicks - separation)
          .ceil()
      ..pointXTicks = terrainPhysicsTickValueToInt(
        _pair.secondXTicks,
        name: 'contactPointX',
      )
      ..pointYTicks = terrainPhysicsTickValueToInt(
        _pair.secondYTicks,
        name: 'contactPointY',
      )
      ..feature = _featureFor(_pair.secondT)
      ..edgeId = edge.id;
    _writeContactNormal(
      edge,
      _pair.firstXTicks - _pair.secondXTicks,
      _pair.firstYTicks - _pair.secondYTicks,
      distance,
      out,
    );
  }
}

@pragma('vm:prefer-inline')
void _closestSegmentPair(
  double p0x,
  double p0y,
  double p1x,
  double p1y,
  double q0x,
  double q0y,
  double q1x,
  double q1y,
  TerrainSegmentPairResult out,
) {
  final ux = p1x - p0x;
  final uy = p1y - p0y;
  final vx = q1x - q0x;
  final vy = q1y - q0y;
  final wx = p0x - q0x;
  final wy = p0y - q0y;
  final a = ux * ux + uy * uy;
  final b = ux * vx + uy * vy;
  final c = vx * vx + vy * vy;
  final d = ux * wx + uy * wy;
  final e = vx * wx + vy * wy;
  final denominator = a * c - b * b;
  const tiny = terrainParametricGuard;

  var firstT = 0.0;
  var secondT = 0.0;
  if (a <= tiny && c <= tiny) {
    // Both closest points remain at their segment starts.
  } else if (a <= tiny) {
    secondT = e / c;
    if (secondT < 0) {
      secondT = 0;
    } else if (secondT > 1) {
      secondT = 1;
    }
  } else if (c <= tiny) {
    firstT = -d / a;
    if (firstT < 0) {
      firstT = 0;
    } else if (firstT > 1) {
      firstT = 1;
    }
  } else {
    var sNumerator = 0.0;
    var sDenominator = denominator;
    var tNumerator = 0.0;
    var tDenominator = denominator;

    if (denominator <= tiny) {
      sNumerator = 0;
      tNumerator = e;
      tDenominator = c;
      sDenominator = 1;
    } else {
      sNumerator = b * e - c * d;
      tNumerator = a * e - b * d;
      if (sNumerator < 0) {
        sNumerator = 0;
        tNumerator = e;
        tDenominator = c;
      } else if (sNumerator > sDenominator) {
        sNumerator = sDenominator;
        tNumerator = e + b;
        tDenominator = c;
      }
    }

    if (tNumerator < 0) {
      tNumerator = 0;
      if (-d < 0) {
        sNumerator = 0;
        sDenominator = 1;
      } else if (-d > a) {
        sNumerator = sDenominator;
      } else {
        sNumerator = -d;
        sDenominator = a;
      }
    } else if (tNumerator > tDenominator) {
      tNumerator = tDenominator;
      if (-d + b < 0) {
        sNumerator = 0;
        sDenominator = 1;
      } else if (-d + b > a) {
        sNumerator = sDenominator;
      } else {
        sNumerator = -d + b;
        sDenominator = a;
      }
    }

    firstT = sNumerator.abs() <= tiny ? 0.0 : sNumerator / sDenominator;
    secondT = tNumerator.abs() <= tiny ? 0.0 : tNumerator / tDenominator;
  }

  final firstX = p0x + firstT * ux;
  final firstY = p0y + firstT * uy;
  final secondX = q0x + secondT * vx;
  final secondY = q0y + secondT * vy;
  final deltaX = firstX - secondX;
  final deltaY = firstY - secondY;
  out
    ..firstXTicks = firstX
    ..firstYTicks = firstY
    ..secondXTicks = secondX
    ..secondYTicks = secondY
    ..firstT = firstT
    ..secondT = secondT
    ..squaredDistanceTicks = deltaX * deltaX + deltaY * deltaY;
}

int _roundedDivide(int numerator, int positiveDenominator) {
  final negative = numerator < 0;
  final quotient =
      (numerator.abs() + positiveDenominator ~/ 2) ~/ positiveDenominator;
  return negative ? -quotient : quotient;
}

TerrainSegmentFeature _featureFor(double segmentT) {
  const endpointTolerance = terrainEndpointParameterEpsilon;
  if (segmentT <= endpointTolerance) {
    return TerrainSegmentFeature.startEndpoint;
  }
  if (segmentT >= 1 - endpointTolerance) {
    return TerrainSegmentFeature.endEndpoint;
  }
  return TerrainSegmentFeature.face;
}

@pragma('vm:prefer-inline')
void _writeContactNormal(
  TerrainEdge edge,
  double radialX,
  double radialY,
  double distance,
  CapsuleSegmentContact out,
) {
  if (out.feature == TerrainSegmentFeature.face) {
    out
      ..normalXTicks = edge.outwardNormal.xTicks
      ..normalYTicks = edge.outwardNormal.yTicks;
    return;
  }
  if (distance <= terrainGeometryEpsilonTicks) {
    out
      ..normalXTicks = edge.outwardNormal.xTicks
      ..normalYTicks = edge.outwardNormal.yTicks;
    return;
  }
  out
    ..normalXTicks = terrainQuantizeDirectionComponent(radialX, distance)
    ..normalYTicks = terrainQuantizeDirectionComponent(radialY, distance);
}

@pragma('vm:prefer-inline')
void _writeNormal(
  TerrainEdge edge,
  double radialX,
  double radialY,
  double distance,
  CapsuleSweepHit out,
) {
  if (out.feature == TerrainSegmentFeature.face ||
      distance <= terrainGeometryEpsilonTicks) {
    out
      ..normalXTicks = edge.outwardNormal.xTicks
      ..normalYTicks = edge.outwardNormal.yTicks;
    return;
  }
  out
    ..normalXTicks = terrainQuantizeDirectionComponent(radialX, distance)
    ..normalYTicks = terrainQuantizeDirectionComponent(radialY, distance);
}
