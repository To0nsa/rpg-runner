import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';

import 'terrain_edge.dart';
import 'terrain_edge_id.dart';
import 'terrain_numeric.dart';
import 'upright_capsule.dart';

/// Terrain feature selected by a closest-point or sweep query.
enum TerrainSegmentFeature { startEndpoint, face, endEndpoint }

/// Caller-owned closest-point output; coordinates are physics ticks.
class TerrainClosestPointResult {
  double pointXTicks = 0;
  double pointYTicks = 0;
  double segmentT = 0;
  double squaredDistanceTicks = 0;
}

/// Caller-owned closest-points output for two finite segments.
class TerrainSegmentPairResult {
  double firstXTicks = 0;
  double firstYTicks = 0;
  double secondXTicks = 0;
  double secondYTicks = 0;
  double firstT = 0;
  double secondT = 0;
  double squaredDistanceTicks = 0;
}

/// Caller-owned capsule/edge separation and overlap diagnostic.
class CapsuleSegmentContact {
  double signedSeparationTicks = double.infinity;
  double penetrationTicks = 0;
  int pointXTicks = 0;
  int pointYTicks = 0;
  int normalXTicks = 0;
  int normalYTicks = 0;
  TerrainSegmentFeature feature = TerrainSegmentFeature.face;
  TerrainEdgeId? edgeId;

  bool get overlaps => signedSeparationTicks <= terrainContactEpsilonTicks;

  double get signedSeparationWorld =>
      signedSeparationTicks / terrainPhysicsTicksPerWorldUnit;
}

/// Caller-owned result for a moving upright capsule against one terrain edge.
class CapsuleSweepHit {
  bool hit = false;
  bool startedOverlapping = false;
  double timeOfImpact = 1;
  double signedSeparationTicks = double.infinity;
  int pointXTicks = 0;
  int pointYTicks = 0;
  int normalXTicks = 0;
  int normalYTicks = 0;
  TerrainSegmentFeature feature = TerrainSegmentFeature.face;
  TerrainEdgeId? edgeId;

  void reset() {
    hit = false;
    startedOverlapping = false;
    timeOfImpact = 1;
    signedSeparationTicks = double.infinity;
    pointXTicks = 0;
    pointYTicks = 0;
    normalXTicks = 0;
    normalYTicks = 0;
    feature = TerrainSegmentFeature.face;
    edgeId = null;
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
    _evaluateAt(
      capsule: capsule,
      edge: edge,
      offsetXTicks: 0,
      offsetYTicks: 0,
      out: out,
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
    out.reset();
    final speedTicks = math.sqrt(
      displacementXTicks.toDouble() * displacementXTicks +
          displacementYTicks.toDouble() * displacementYTicks,
    );

    var time = 0.0;
    var separation = _separationAt(
      capsule,
      edge,
      displacementXTicks,
      displacementYTicks,
      time,
    );
    if (separation <= terrainContactEpsilonTicks) {
      _writeSweepHit(
        capsule,
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
      final advance = separation / speedTicks;
      if (advance > remaining) break;
      final nextTime = math.min(1.0, time + math.max(advance, 1e-12));
      final nextSeparation = _separationAt(
        capsule,
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
        capsule,
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
      capsule,
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
          (hit.timeOfImpact * terrainPhysicsTicksPerWorldUnit)
              .round()
              .toString(),
          hit.signedSeparationTicks.round().toString(),
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

  double _separationAt(
    UprightCapsule capsule,
    TerrainEdge edge,
    int displacementXTicks,
    int displacementYTicks,
    double time,
  ) {
    final centerX =
        capsule.center.xTicks + displacementXTicks.toDouble() * time;
    final centerY =
        capsule.center.yTicks + displacementYTicks.toDouble() * time;
    _closestSegmentPair(
      centerX,
      centerY - capsule.verticalHalfSegmentTicks,
      centerX,
      centerY + capsule.verticalHalfSegmentTicks,
      edge.start.xTicks.toDouble(),
      edge.start.yTicks.toDouble(),
      edge.end.xTicks.toDouble(),
      edge.end.yTicks.toDouble(),
      _pair,
    );
    return math.sqrt(_pair.squaredDistanceTicks) - capsule.radiusTicks;
  }

  void _writeSweepHit(
    UprightCapsule capsule,
    TerrainEdge edge,
    int displacementXTicks,
    int displacementYTicks,
    double time,
    CapsuleSweepHit out, {
    required bool startedOverlapping,
  }) {
    final centerX =
        capsule.center.xTicks + displacementXTicks.toDouble() * time;
    final centerY =
        capsule.center.yTicks + displacementYTicks.toDouble() * time;
    _closestSegmentPair(
      centerX,
      centerY - capsule.verticalHalfSegmentTicks,
      centerX,
      centerY + capsule.verticalHalfSegmentTicks,
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
      ..signedSeparationTicks = distance - capsule.radiusTicks
      ..pointXTicks = _pair.secondXTicks.round()
      ..pointYTicks = _pair.secondYTicks.round()
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

  void _evaluateAt({
    required UprightCapsule capsule,
    required TerrainEdge edge,
    required double offsetXTicks,
    required double offsetYTicks,
    required CapsuleSegmentContact out,
  }) {
    final centerX = capsule.center.xTicks + offsetXTicks;
    final centerY = capsule.center.yTicks + offsetYTicks;
    _closestSegmentPair(
      centerX,
      centerY - capsule.verticalHalfSegmentTicks,
      centerX,
      centerY + capsule.verticalHalfSegmentTicks,
      edge.start.xTicks.toDouble(),
      edge.start.yTicks.toDouble(),
      edge.end.xTicks.toDouble(),
      edge.end.yTicks.toDouble(),
      _pair,
    );
    final distance = math.sqrt(_pair.squaredDistanceTicks);
    final separation = distance - capsule.radiusTicks;
    out
      ..signedSeparationTicks = separation
      ..penetrationTicks = math.max(0, -separation)
      ..pointXTicks = _pair.secondXTicks.round()
      ..pointYTicks = _pair.secondYTicks.round()
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
  const tiny = 1e-12;

  if (a <= tiny && c <= tiny) {
    _writeSegmentPairResult(
      p0x: p0x,
      p0y: p0y,
      q0x: q0x,
      q0y: q0y,
      firstT: 0,
      secondT: 0,
      out: out,
    );
    return;
  }
  if (a <= tiny) {
    final secondT = (e / c).clamp(0.0, 1.0);
    _writeSegmentPairResult(
      p0x: p0x,
      p0y: p0y,
      q0x: q0x,
      q0y: q0y,
      vx: vx,
      vy: vy,
      firstT: 0,
      secondT: secondT,
      out: out,
    );
    return;
  }
  if (c <= tiny) {
    final firstT = (-d / a).clamp(0.0, 1.0);
    _writeSegmentPairResult(
      p0x: p0x,
      p0y: p0y,
      q0x: q0x,
      q0y: q0y,
      ux: ux,
      uy: uy,
      firstT: firstT,
      secondT: 0,
      out: out,
    );
    return;
  }

  var sNumerator = 0.0;
  var sDenominator = denominator;
  var tNumerator = 0.0;
  var tDenominator = denominator;

  if (denominator <= tiny) {
    sNumerator = 0;
    sDenominator = 1;
    tNumerator = e;
    tDenominator = c;
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

  final firstT = sNumerator.abs() <= tiny ? 0.0 : sNumerator / sDenominator;
  final secondT = tNumerator.abs() <= tiny ? 0.0 : tNumerator / tDenominator;
  _writeSegmentPairResult(
    p0x: p0x,
    p0y: p0y,
    q0x: q0x,
    q0y: q0y,
    ux: ux,
    uy: uy,
    vx: vx,
    vy: vy,
    firstT: firstT,
    secondT: secondT,
    out: out,
  );
}

void _writeSegmentPairResult({
  required double p0x,
  required double p0y,
  required double q0x,
  required double q0y,
  double ux = 0,
  double uy = 0,
  double vx = 0,
  double vy = 0,
  required double firstT,
  required double secondT,
  required TerrainSegmentPairResult out,
}) {
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

TerrainSegmentFeature _featureFor(double segmentT) {
  const endpointTolerance = 1e-9;
  if (segmentT <= endpointTolerance) {
    return TerrainSegmentFeature.startEndpoint;
  }
  if (segmentT >= 1 - endpointTolerance) {
    return TerrainSegmentFeature.endEndpoint;
  }
  return TerrainSegmentFeature.face;
}

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
    ..normalXTicks = (radialX * terrainDirectionScale / distance).round()
    ..normalYTicks = (radialY * terrainDirectionScale / distance).round();
}

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
    ..normalXTicks = (radialX * terrainDirectionScale / distance).round()
    ..normalYTicks = (radialY * terrainDirectionScale / distance).round();
}
