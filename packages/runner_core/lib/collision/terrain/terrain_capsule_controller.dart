import 'dart:math' as math;

import 'capsule_segment_kernel.dart';
import 'terrain_contact_policy.dart';
import 'terrain_controller_diagnostic.dart';
import 'terrain_edge.dart';
import 'terrain_edge_id.dart';
import 'terrain_edge_index.dart';
import 'terrain_geometry.dart';
import 'terrain_motion_request.dart';
import 'terrain_numeric.dart';
import 'terrain_polygon.dart';
import 'terrain_query_buffer.dart';
import 'terrain_traversal_profile.dart';
import 'upright_capsule.dart';

/// Caller-owned deterministic output from one capsule motion solve.
///
/// Contact arrays have fixed [terrainMaxBlockingContacts] capacity and are
/// reused across ticks. All positions and displacements use physics ticks.
class TerrainCapsuleMotionResult {
  TerrainCapsuleMotionResult()
    : contactEdgeIds = List<TerrainEdgeId?>.filled(
        terrainMaxBlockingContacts,
        null,
      ),
      contactKinds = List<TerrainContactKind>.filled(
        terrainMaxBlockingContacts,
        TerrainContactKind.ignored,
      ),
      contactFeatures = List<TerrainSegmentFeature>.filled(
        terrainMaxBlockingContacts,
        TerrainSegmentFeature.face,
      ),
      contactNormalXTicks = List<int>.filled(terrainMaxBlockingContacts, 0),
      contactNormalYTicks = List<int>.filled(terrainMaxBlockingContacts, 0);

  int startCenterXTicks = 0;
  int startCenterYTicks = 0;
  int finalCenterXTicks = 0;
  int finalCenterYTicks = 0;
  int resolvedXTicks = 0;
  int resolvedYTicks = 0;
  int progressionXTicks = 0;
  int supportedTravelTicks = 0;
  int recoveryCorrectionXTicks = 0;
  int recoveryCorrectionYTicks = 0;
  int stepVerticalCorrectionYTicks = 0;
  int snapCorrectionYTicks = 0;

  bool grounded = false;
  TerrainEdgeId? supportEdgeId;
  int supportPointXTicks = 0;
  int supportPointYTicks = 0;
  int supportNormalXTicks = 0;
  int supportNormalYTicks = 0;
  int supportTangentXTicks = 0;
  int supportTangentYTicks = 0;

  bool hitCeiling = false;
  bool hitLeft = false;
  bool hitRight = false;
  int wallNormalXTicks = 0;
  int wallNormalYTicks = 0;
  int ceilingNormalXTicks = 0;
  int ceilingNormalYTicks = 0;

  bool usedStep = false;
  bool usedSnap = false;
  bool usedRecovery = false;
  int contactCount = 0;
  int contactIterations = 0;
  int recoveryIterations = 0;
  int candidateCount = 0;
  int queryCellsVisited = 0;
  TerrainControllerDiagnostic diagnostic = TerrainControllerDiagnostic.none;

  final List<TerrainEdgeId?> contactEdgeIds;
  final List<TerrainContactKind> contactKinds;
  final List<TerrainSegmentFeature> contactFeatures;
  final List<int> contactNormalXTicks;
  final List<int> contactNormalYTicks;

  void reset(UprightCapsule capsule) {
    resetAt(
      centerXTicks: capsule.center.xTicks,
      centerYTicks: capsule.center.yTicks,
    );
  }

  /// Resets from primitive center fields without allocating a capsule wrapper.
  void resetAt({required int centerXTicks, required int centerYTicks}) {
    startCenterXTicks = centerXTicks;
    startCenterYTicks = centerYTicks;
    finalCenterXTicks = startCenterXTicks;
    finalCenterYTicks = startCenterYTicks;
    resolvedXTicks = 0;
    resolvedYTicks = 0;
    progressionXTicks = 0;
    supportedTravelTicks = 0;
    recoveryCorrectionXTicks = 0;
    recoveryCorrectionYTicks = 0;
    stepVerticalCorrectionYTicks = 0;
    snapCorrectionYTicks = 0;
    _clearSupport();

    hitCeiling = false;
    hitLeft = false;
    hitRight = false;
    wallNormalXTicks = 0;
    wallNormalYTicks = 0;
    ceilingNormalXTicks = 0;
    ceilingNormalYTicks = 0;

    usedStep = false;
    usedSnap = false;
    usedRecovery = false;
    contactCount = 0;
    contactIterations = 0;
    recoveryIterations = 0;
    candidateCount = 0;
    queryCellsVisited = 0;
    diagnostic = TerrainControllerDiagnostic.none;
    for (var index = 0; index < terrainMaxBlockingContacts; index += 1) {
      contactEdgeIds[index] = null;
      contactKinds[index] = TerrainContactKind.ignored;
      contactFeatures[index] = TerrainSegmentFeature.face;
      contactNormalXTicks[index] = 0;
      contactNormalYTicks[index] = 0;
    }
  }

  void _clearSupport() {
    grounded = false;
    supportEdgeId = null;
    supportPointXTicks = 0;
    supportPointYTicks = 0;
    supportNormalXTicks = 0;
    supportNormalYTicks = 0;
    supportTangentXTicks = 0;
    supportTangentYTicks = 0;
  }
}

/// Deterministic upright-capsule recovery, sweep, slide, and support solver.
///
/// One instance owns reusable scratch state and must not be used concurrently.
/// It mutates only the caller-owned [TerrainCapsuleMotionResult].
class TerrainCapsuleController {
  TerrainCapsuleController({
    required this.geometry,
    required this.index,
    required this.profile,
  }) : policy = TerrainContactPolicy(geometry: geometry, profile: profile),
       _queryBuffer = index.createQueryBuffer() {
    if (index.edges.length != geometry.edges.length) {
      throw ArgumentError('Terrain geometry and index edge counts must match.');
    }
    for (var edgeIndex = 0; edgeIndex < index.edges.length; edgeIndex += 1) {
      if (index.edges[edgeIndex].id != geometry.edges[edgeIndex].id) {
        throw ArgumentError(
          'Terrain geometry and index must use identical canonical edges.',
        );
      }
    }
  }

  final TerrainGeometry geometry;
  final TerrainEdgeIndex index;
  final TerrainTraversalProfile profile;
  final TerrainContactPolicy policy;

  /// Number of times the reusable broad-phase candidate buffer has grown.
  ///
  /// Benchmarks sample this after warmup to prove steady-state capacity.
  int get queryBufferResizeCount => _queryBuffer.resizeCount;

  final CapsuleSegmentKernel _kernel = CapsuleSegmentKernel();
  final TerrainQueryBuffer _queryBuffer;
  final CapsuleSweepHit _scratchHit = CapsuleSweepHit();
  final CapsuleSweepHit _bestHit = CapsuleSweepHit();
  final TerrainContactDecision _scratchDecision = TerrainContactDecision();
  final CapsuleSegmentContact _scratchContact = CapsuleSegmentContact();
  final _SupportTransition _supportTransitionScratch = _SupportTransition();
  final List<int> _constraintNormalX = List<int>.filled(
    terrainMaxBlockingContacts,
    0,
  );
  final List<int> _constraintNormalY = List<int>.filled(
    terrainMaxBlockingContacts,
    0,
  );
  final List<TerrainContactKind> _constraintKind =
      List<TerrainContactKind>.filled(
        terrainMaxBlockingContacts,
        TerrainContactKind.ignored,
      );
  final List<TerrainEdge?> _constraintEdge = List<TerrainEdge?>.filled(
    terrainMaxBlockingContacts,
    null,
  );
  final List<TerrainSegmentFeature> _constraintFeature =
      List<TerrainSegmentFeature>.filled(
        terrainMaxBlockingContacts,
        TerrainSegmentFeature.face,
      );

  late TerrainCapsuleMotionResult _out;
  var _tickStartCenterX = 0;
  var _tickStartCenterY = 0;
  var _radiusTicks = 0;
  var _verticalHalfSegmentTicks = 0;
  var _centerX = 0;
  var _centerY = 0;
  var _beganGrounded = false;
  var _supportedPathTravelTicks = 0;
  var _supportedPathDirectionSign = 1;
  TerrainEdge? _tickStartSupport;
  TerrainEdge? _provisionalSupport;
  TerrainEdge? _recoveryEdge;
  TerrainEdge? _cachedTransitionSource;
  var _cachedTransitionDirection = 0;
  var _cachedTransitionRadiusTicks = -1;
  var _cachedTransitionHalfSegmentTicks = -1;
  var _cachedTransitionExists = false;
  var _recoveryCorrectionTicks = 0;
  var _recoveryNormalXTicks = 0;
  var _recoveryNormalYTicks = 0;

  /// Places a clear capsule on the first eligible support directly below.
  ///
  /// This spawn/test query performs no move-and-slide continuation, so a large
  /// search distance cannot turn unused fall distance into slope travel.
  void placeOnFirstSupportBelow({
    required UprightCapsule capsule,
    required int maximumDistanceTicks,
    required TerrainCapsuleMotionResult out,
  }) {
    if (maximumDistanceTicks < 0) {
      throw ArgumentError.value(
        maximumDistanceTicks,
        'maximumDistanceTicks',
        'Must be non-negative.',
      );
    }
    _out = out;
    _tickStartCenterX = capsule.center.xTicks;
    _tickStartCenterY = capsule.center.yTicks;
    _radiusTicks = capsule.radiusTicks;
    _verticalHalfSegmentTicks = capsule.verticalHalfSegmentTicks;
    _centerX = capsule.center.xTicks;
    _centerY = capsule.center.yTicks;
    _beganGrounded = false;
    _supportedPathTravelTicks = 0;
    _supportedPathDirectionSign = 1;
    _provisionalSupport = null;
    out.reset(capsule);

    final support = _findFirstSupportSweep(
      centerX: capsule.center.xTicks,
      centerY: capsule.center.yTicks,
      displacementYTicks: maximumDistanceTicks,
    );
    if (support == null) {
      _finalize();
      return;
    }
    final supportCenterY = _supportCenterYAtX(support, _centerX);
    final advance = supportCenterY - _centerY;
    if (advance < 0 || advance > maximumDistanceTicks) {
      _finalize();
      return;
    }
    _centerY = supportCenterY;
    _writeSupport(support, _bestHit.pointXTicks, _bestHit.pointYTicks);
    _provisionalSupport = support;
    if (_findRecoveryCandidate()) {
      out
        .._clearSupport()
        ..diagnostic = TerrainControllerDiagnostic.recoveryFailed;
      _centerX = capsule.center.xTicks;
      _centerY = capsule.center.yTicks;
    }
    _finalize();
  }

  /// Resolves one fixed-tick request against the immutable terrain version.
  ///
  /// [priorSupportGeometryVersion] must match [TerrainGeometry.version] before
  /// supported motion or snap can be retained. Recovery failure restores the
  /// optional last-valid capsule center.
  void move({
    required UprightCapsule capsule,
    required TerrainMotionRequest request,
    required bool beganGrounded,
    TerrainEdgeId? priorSupportEdgeId,
    int priorSupportGeometryVersion = -1,
    int? lastValidCapsuleCenterXTicks,
    int? lastValidCapsuleCenterYTicks,
    required TerrainCapsuleMotionResult out,
  }) {
    moveAt(
      centerXTicks: capsule.center.xTicks,
      centerYTicks: capsule.center.yTicks,
      radiusTicks: capsule.radiusTicks,
      verticalHalfSegmentTicks: capsule.verticalHalfSegmentTicks,
      request: request,
      beganGrounded: beganGrounded,
      priorSupportEdgeId: priorSupportEdgeId,
      priorSupportGeometryVersion: priorSupportGeometryVersion,
      lastValidCapsuleCenterXTicks: lastValidCapsuleCenterXTicks,
      lastValidCapsuleCenterYTicks: lastValidCapsuleCenterYTicks,
      out: out,
    );
  }

  /// Primitive-center equivalent of [move] for allocation-sensitive owners.
  void moveAt({
    required int centerXTicks,
    required int centerYTicks,
    required int radiusTicks,
    required int verticalHalfSegmentTicks,
    required TerrainMotionRequest request,
    required bool beganGrounded,
    TerrainEdgeId? priorSupportEdgeId,
    int priorSupportGeometryVersion = -1,
    int? lastValidCapsuleCenterXTicks,
    int? lastValidCapsuleCenterYTicks,
    required TerrainCapsuleMotionResult out,
  }) {
    moveAtValues(
      centerXTicks: centerXTicks,
      centerYTicks: centerYTicks,
      radiusTicks: radiusTicks,
      verticalHalfSegmentTicks: verticalHalfSegmentTicks,
      displacementXTicks: request.displacementXTicks,
      displacementYTicks: request.displacementYTicks,
      gravityXTicks: request.gravityXTicks,
      gravityYTicks: request.gravityYTicks,
      surfaceDirectionSign: request.surfaceDirectionSign,
      mode: request.mode,
      beganGrounded: beganGrounded,
      priorSupportEdgeId: priorSupportEdgeId,
      priorSupportGeometryVersion: priorSupportGeometryVersion,
      lastValidCapsuleCenterXTicks: lastValidCapsuleCenterXTicks,
      lastValidCapsuleCenterYTicks: lastValidCapsuleCenterYTicks,
      out: out,
    );
  }

  /// Allocation-free primitive request equivalent of [moveAt].
  void moveAtValues({
    required int centerXTicks,
    required int centerYTicks,
    required int radiusTicks,
    required int verticalHalfSegmentTicks,
    required int displacementXTicks,
    required int displacementYTicks,
    int gravityXTicks = 0,
    int gravityYTicks = 0,
    int surfaceDirectionSign = 1,
    required TerrainMotionMode mode,
    required bool beganGrounded,
    TerrainEdgeId? priorSupportEdgeId,
    int priorSupportGeometryVersion = -1,
    int? lastValidCapsuleCenterXTicks,
    int? lastValidCapsuleCenterYTicks,
    required TerrainCapsuleMotionResult out,
  }) {
    if ((lastValidCapsuleCenterXTicks == null) !=
        (lastValidCapsuleCenterYTicks == null)) {
      throw ArgumentError(
        'Both last-valid capsule-center coordinates must be supplied together.',
      );
    }
    if (radiusTicks < 0 || verticalHalfSegmentTicks < 0) {
      throw ArgumentError('Capsule dimensions must be non-negative.');
    }
    if (displacementXTicks.abs() > terrainMaxAbsPhysicsTicks ||
        displacementYTicks.abs() > terrainMaxAbsPhysicsTicks ||
        gravityXTicks.abs() > terrainMaxAbsPhysicsTicks ||
        gravityYTicks.abs() > terrainMaxAbsPhysicsTicks) {
      throw RangeError('Terrain request values exceed the physics range.');
    }
    if (surfaceDirectionSign != -1 && surfaceDirectionSign != 1) {
      throw ArgumentError.value(
        surfaceDirectionSign,
        'surfaceDirectionSign',
        'Must be -1 or 1.',
      );
    }
    _out = out;
    _tickStartCenterX = centerXTicks;
    _tickStartCenterY = centerYTicks;
    _radiusTicks = radiusTicks;
    _verticalHalfSegmentTicks = verticalHalfSegmentTicks;
    _centerX = centerXTicks;
    _centerY = centerYTicks;
    _beganGrounded = beganGrounded;
    _supportedPathTravelTicks = 0;
    _supportedPathDirectionSign = surfaceDirectionSign;
    _tickStartSupport = null;
    _provisionalSupport = null;
    out.resetAt(centerXTicks: centerXTicks, centerYTicks: centerYTicks);

    final priorSupportIsCurrent =
        beganGrounded &&
        priorSupportGeometryVersion == geometry.version &&
        priorSupportEdgeId != null &&
        geometry.edgeById.containsKey(priorSupportEdgeId);
    final priorSupport = priorSupportIsCurrent
        ? geometry.edgeById[priorSupportEdgeId]
        : null;
    _tickStartSupport = priorSupport;
    if (beganGrounded && !priorSupportIsCurrent) {
      out.diagnostic = priorSupportGeometryVersion != geometry.version
          ? TerrainControllerDiagnostic.invalidGeometryVersion
          : TerrainControllerDiagnostic.invalidSupport;
    }

    if (!_recoverInitialOverlap(
      lastValidCenterX: lastValidCapsuleCenterXTicks,
      lastValidCenterY: lastValidCapsuleCenterYTicks,
    )) {
      _finalize();
      return;
    }

    if (!profile.enabled || profile.isKinematic) {
      _finalize();
      return;
    }

    if (priorSupport != null &&
        (mode == TerrainMotionMode.groundedHorizontal ||
            mode == TerrainMotionMode.groundedSurface) &&
        profile.isWalkableSupport(priorSupport)) {
      _provisionalSupport = priorSupport;
      if (mode == TerrainMotionMode.groundedHorizontal) {
        _solveGroundedHorizontal(
          displacementXTicks,
          support: priorSupport,
          surfaceDirectionSign: surfaceDirectionSign,
        );
      } else {
        final distance = _integerSqrt(
          displacementXTicks * displacementXTicks +
              displacementYTicks * displacementYTicks,
        );
        _solveGroundedSurface(
          distance,
          support: priorSupport,
          surfaceDirectionSign: surfaceDirectionSign,
        );
      }
      _resolveFinalSupport(beganGrounded: true, allowSnap: true);
      if (!out.grounded) {
        _solveDisplacement(
          gravityXTicks,
          gravityYTicks,
          mode: TerrainMotionMode.worldSpace,
          surfaceDirectionSign: surfaceDirectionSign,
          allowStep: false,
        );
        _resolveFinalSupport(beganGrounded: false, allowSnap: false);
      }
    } else {
      _solveDisplacement(
        displacementXTicks + gravityXTicks,
        displacementYTicks + gravityYTicks,
        mode: TerrainMotionMode.worldSpace,
        surfaceDirectionSign: surfaceDirectionSign,
        allowStep: false,
      );
      _resolveFinalSupport(beganGrounded: false, allowSnap: false);
    }
    _finalize();
  }

  void _solveGroundedHorizontal(
    int requestedXTicks, {
    required TerrainEdge support,
    required int surfaceDirectionSign,
  }) {
    if (requestedXTicks == 0) return;
    _supportedPathDirectionSign = requestedXTicks.sign;
    final targetX = _centerX + requestedXTicks;
    final direction = requestedXTicks.sign;
    var currentSupport = support;
    var transitions = 0;

    while (transitions <= geometry.edges.length) {
      final transition = _supportTransition(currentSupport, direction);
      if (transition == null ||
          !_crossesInDirection(_centerX, targetX, transition.thresholdX)) {
        final targetY = _supportCenterYAtX(currentSupport, targetX);
        _solveSupportedSegment(
          targetX - _centerX,
          targetY - _centerY,
          mode: TerrainMotionMode.groundedHorizontal,
          surfaceDirectionSign: surfaceDirectionSign,
          allowStep: true,
        );
        _provisionalSupport ??= currentSupport;
        return;
      }

      _solveSupportedSegment(
        transition.thresholdX - _centerX,
        transition.thresholdY - _centerY,
        mode: TerrainMotionMode.groundedHorizontal,
        surfaceDirectionSign: surfaceDirectionSign,
        allowStep: true,
      );
      if (_centerX != transition.thresholdX ||
          _centerY != transition.thresholdY) {
        return;
      }

      if (transition.convex) {
        final completed = _followConvexVertex(
          vertex: transition.vertex,
          currentSupport: currentSupport,
          nextSupport: transition.nextSupport,
          targetX: targetX,
          direction: direction,
          surfaceDirectionSign: surfaceDirectionSign,
        );
        if (!completed) return;
      }
      currentSupport = transition.nextSupport;
      _provisionalSupport = currentSupport;
      transitions += 1;
    }
    _out.diagnostic = TerrainControllerDiagnostic.contactIterationLimit;
  }

  void _solveGroundedSurface(
    int requestedDistanceTicks, {
    required TerrainEdge support,
    required int surfaceDirectionSign,
  }) {
    if (requestedDistanceTicks <= 0) return;
    var remaining = requestedDistanceTicks;
    var currentSupport = support;
    var transitions = 0;

    while (transitions <= geometry.edges.length) {
      final tangentSign =
          currentSupport.tangent.xTicks.sign == surfaceDirectionSign ? 1 : -1;
      final transition = _supportTransition(
        currentSupport,
        surfaceDirectionSign,
      );
      if (transition == null) {
        _solveSupportedSegment(
          _roundedDivide(
            remaining * currentSupport.tangent.xTicks * tangentSign,
            terrainDirectionScale,
          ),
          _roundedDivide(
            remaining * currentSupport.tangent.yTicks * tangentSign,
            terrainDirectionScale,
          ),
          mode: TerrainMotionMode.groundedSurface,
          surfaceDirectionSign: surfaceDirectionSign,
          allowStep: true,
        );
        _provisionalSupport ??= currentSupport;
        return;
      }

      final toTransitionX = transition.thresholdX - _centerX;
      final toTransitionY = transition.thresholdY - _centerY;
      final transitionIsAhead =
          toTransitionX == 0 || toTransitionX.sign == surfaceDirectionSign;
      final distanceToTransition = _integerSqrt(
        toTransitionX * toTransitionX + toTransitionY * toTransitionY,
      );
      if (!transitionIsAhead || distanceToTransition > remaining) {
        _solveSupportedSegment(
          _roundedDivide(
            remaining * currentSupport.tangent.xTicks * tangentSign,
            terrainDirectionScale,
          ),
          _roundedDivide(
            remaining * currentSupport.tangent.yTicks * tangentSign,
            terrainDirectionScale,
          ),
          mode: TerrainMotionMode.groundedSurface,
          surfaceDirectionSign: surfaceDirectionSign,
          allowStep: true,
        );
        _provisionalSupport ??= currentSupport;
        return;
      }

      _solveSupportedSegment(
        toTransitionX,
        toTransitionY,
        mode: TerrainMotionMode.groundedSurface,
        surfaceDirectionSign: surfaceDirectionSign,
        allowStep: true,
      );
      if (_centerX != transition.thresholdX ||
          _centerY != transition.thresholdY) {
        return;
      }
      remaining -= distanceToTransition;
      if (remaining <= 0) {
        _provisionalSupport = currentSupport;
        return;
      }

      if (transition.convex) {
        final arc = _followConvexVertexDistance(
          vertex: transition.vertex,
          currentSupport: currentSupport,
          nextSupport: transition.nextSupport,
          remainingDistanceTicks: remaining,
          surfaceDirectionSign: surfaceDirectionSign,
        );
        remaining = arc.remainingDistanceTicks;
        if (!arc.crossedVertex) return;
      }
      currentSupport = transition.nextSupport;
      _provisionalSupport = currentSupport;
      if (remaining <= 0) return;
      transitions += 1;
    }
    _out.diagnostic = TerrainControllerDiagnostic.contactIterationLimit;
  }

  _SupportTransition? _supportTransition(TerrainEdge edge, int direction) {
    if (identical(edge, _cachedTransitionSource) &&
        direction == _cachedTransitionDirection &&
        _radiusTicks == _cachedTransitionRadiusTicks &&
        _verticalHalfSegmentTicks == _cachedTransitionHalfSegmentTicks) {
      return _cachedTransitionExists ? _supportTransitionScratch : null;
    }
    final useEnd = direction > 0
        ? edge.end.xTicks >= edge.start.xTicks
        : edge.end.xTicks <= edge.start.xTicks;
    final vertex = useEnd ? edge.end : edge.start;
    final adjacentId = useEnd ? edge.nextId : edge.previousId;
    final join = useEnd ? edge.endJoin : edge.startJoin;
    if (adjacentId == null || join == TerrainVertexJoin.exposed) {
      _cacheSupportTransition(edge, direction, exists: false);
      return null;
    }
    final adjacent = geometry.edgeById[adjacentId];
    if (adjacent == null || !profile.isWalkableSupport(adjacent)) {
      _cacheSupportTransition(edge, direction, exists: false);
      return null;
    }

    final incoming = useEnd ? edge : adjacent;
    final outgoing = useEnd ? adjacent : edge;
    final cross =
        incoming.dxTicks * outgoing.dyTicks -
        incoming.dyTicks * outgoing.dxTicks;
    final convex = cross > 0;
    if (convex) {
      final radiusWithSkin = _radiusTicks + terrainCollisionSkinTicks;
      final edgeLength = _edgeLengthTicks(edge);
      final thresholdX =
          vertex.xTicks +
          _roundedDivide(radiusWithSkin * _rawNormalX(edge), edgeLength);
      final transition = _supportTransitionScratch..set(
        nextSupport: adjacent,
        vertex: vertex,
        thresholdX: thresholdX,
        thresholdY: _supportCenterYAtX(edge, thresholdX),
        convex: true,
      );
      _cacheSupportTransition(edge, direction, exists: true);
      return transition;
    }

    final intersection = _supportLineIntersection(edge, adjacent);
    if (intersection == null) {
      _cacheSupportTransition(edge, direction, exists: false);
      return null;
    }
    final transition = _supportTransitionScratch..set(
      nextSupport: adjacent,
      vertex: vertex,
      thresholdX: intersection.xTicks,
      thresholdY: intersection.yTicks,
      convex: false,
    );
    _cacheSupportTransition(edge, direction, exists: true);
    return transition;
  }

  void _cacheSupportTransition(
    TerrainEdge edge,
    int direction, {
    required bool exists,
  }) {
    _cachedTransitionSource = edge;
    _cachedTransitionDirection = direction;
    _cachedTransitionRadiusTicks = _radiusTicks;
    _cachedTransitionHalfSegmentTicks = _verticalHalfSegmentTicks;
    _cachedTransitionExists = exists;
  }

  bool _followConvexVertex({
    required TerrainPoint vertex,
    required TerrainEdge currentSupport,
    required TerrainEdge nextSupport,
    required int targetX,
    required int direction,
    required int surfaceDirectionSign,
  }) {
    final pathRadius =
        _radiusTicks + terrainCollisionSkinTicks + terrainContactEpsilonTicks;
    final nextLength = _edgeLengthTicks(nextSupport);
    final nextBoundaryX =
        vertex.xTicks +
        _roundedDivide(pathRadius * _rawNormalX(nextSupport), nextLength);
    final targetFallsOnArc = direction > 0
        ? targetX <= nextBoundaryX
        : targetX >= nextBoundaryX;
    final arcTargetX = targetFallsOnArc ? targetX : nextBoundaryX;
    final deltaX = arcTargetX - _centerX;
    final maxChordX = math.max(
      1,
      _integerSqrt(8 * pathRadius * terrainContactEpsilonTicks),
    );
    final segmentCount = math.max(
      1,
      (deltaX.abs() + maxChordX - 1) ~/ maxChordX,
    );
    final arcStartX = _centerX;
    for (var segment = 1; segment <= segmentCount; segment += 1) {
      final nextX = arcStartX + deltaX * segment ~/ segmentCount;
      final radialX = nextX - vertex.xTicks;
      final radialSquared = pathRadius * pathRadius - radialX * radialX;
      if (radialSquared < 0) return false;
      final nextY =
          vertex.yTicks -
          _verticalHalfSegmentTicks -
          _integerSqrt(radialSquared);
      _solveSupportedSegment(
        nextX - _centerX,
        nextY - _centerY,
        mode: TerrainMotionMode.worldSpace,
        surfaceDirectionSign: surfaceDirectionSign,
        allowStep: false,
      );
      if (_centerX != nextX || _centerY != nextY) return false;
    }
    if (targetFallsOnArc) {
      _provisionalSupport = currentSupport;
      return false;
    }
    return true;
  }

  ({bool crossedVertex, int remainingDistanceTicks})
  _followConvexVertexDistance({
    required TerrainPoint vertex,
    required TerrainEdge currentSupport,
    required TerrainEdge nextSupport,
    required int remainingDistanceTicks,
    required int surfaceDirectionSign,
  }) {
    final pathRadius =
        _radiusTicks + terrainCollisionSkinTicks + terrainContactEpsilonTicks;
    final nextLength = _edgeLengthTicks(nextSupport);
    final nextBoundaryX =
        vertex.xTicks +
        _roundedDivide(pathRadius * _rawNormalX(nextSupport), nextLength);
    final deltaX = nextBoundaryX - _centerX;
    final maxChordX = math.max(
      1,
      _integerSqrt(8 * pathRadius * terrainContactEpsilonTicks),
    );
    final segmentCount = math.max(
      1,
      (deltaX.abs() + maxChordX - 1) ~/ maxChordX,
    );
    final arcStartX = _centerX;
    var remaining = remainingDistanceTicks;
    for (var segment = 1; segment <= segmentCount; segment += 1) {
      final nextX = arcStartX + deltaX * segment ~/ segmentCount;
      final radialX = nextX - vertex.xTicks;
      final radialSquared = pathRadius * pathRadius - radialX * radialX;
      if (radialSquared < 0) {
        return (crossedVertex: false, remainingDistanceTicks: remaining);
      }
      final nextY =
          vertex.yTicks -
          _verticalHalfSegmentTicks -
          _integerSqrt(radialSquared);
      final chordX = nextX - _centerX;
      final chordY = nextY - _centerY;
      final chordLength = _integerSqrt(chordX * chordX + chordY * chordY);
      if (chordLength > remaining) {
        _solveSupportedSegment(
          _roundedDivide(chordX * remaining, chordLength),
          _roundedDivide(chordY * remaining, chordLength),
          mode: TerrainMotionMode.groundedSurface,
          surfaceDirectionSign: surfaceDirectionSign,
          allowStep: false,
        );
        _provisionalSupport = currentSupport;
        return (crossedVertex: false, remainingDistanceTicks: 0);
      }
      _solveSupportedSegment(
        chordX,
        chordY,
        mode: TerrainMotionMode.groundedSurface,
        surfaceDirectionSign: surfaceDirectionSign,
        allowStep: false,
      );
      if (_centerX != nextX || _centerY != nextY) {
        return (crossedVertex: false, remainingDistanceTicks: remaining);
      }
      remaining -= chordLength;
      if (remaining <= 0) {
        _provisionalSupport = currentSupport;
        return (crossedVertex: false, remainingDistanceTicks: 0);
      }
    }
    return (crossedVertex: true, remainingDistanceTicks: remaining);
  }

  void _solveSupportedSegment(
    int requestedX,
    int requestedY, {
    required TerrainMotionMode mode,
    required int surfaceDirectionSign,
    required bool allowStep,
  }) {
    final beforeX = _centerX;
    final beforeY = _centerY;
    final stepBefore = _out.stepVerticalCorrectionYTicks;
    _solveDisplacement(
      requestedX,
      requestedY,
      mode: mode,
      surfaceDirectionSign: surfaceDirectionSign,
      allowStep: allowStep,
    );
    final acceptedX = _centerX - beforeX;
    final acceptedY =
        _centerY - beforeY - (_out.stepVerticalCorrectionYTicks - stepBefore);
    _supportedPathTravelTicks += _integerSqrt(
      acceptedX * acceptedX + acceptedY * acceptedY,
    );
  }

  TerrainPoint? _supportLineIntersection(
    TerrainEdge first,
    TerrainEdge second,
  ) {
    final firstX = _rawNormalX(first);
    final firstY = _rawNormalY(first);
    final secondX = _rawNormalX(second);
    final secondY = _rawNormalY(second);
    final determinant = firstX * secondY - secondX * firstY;
    if (determinant == 0) return null;
    final firstConstant = _supportLineConstant(first);
    final secondConstant = _supportLineConstant(second);
    return TerrainPoint(
      _roundedDivide(
        firstConstant * secondY - secondConstant * firstY,
        determinant,
      ),
      _roundedDivide(
        firstX * secondConstant - secondX * firstConstant,
        determinant,
      ),
    );
  }

  int _supportCenterYAtX(
    TerrainEdge edge,
    int centerX, {
    int extraClearanceTicks = 0,
  }) {
    final normalX = _rawNormalX(edge);
    final normalY = _rawNormalY(edge);
    if (normalY == 0) return _centerY;
    final constant = _supportLineConstant(
      edge,
      extraClearanceTicks: extraClearanceTicks,
    );
    return _roundedDivide(constant - normalX * centerX, normalY);
  }

  int _supportLineConstant(TerrainEdge edge, {int extraClearanceTicks = 0}) {
    final normalX = _rawNormalX(edge);
    final normalY = _rawNormalY(edge);
    final edgeLength = _edgeLengthTicks(edge);
    final extent =
        _radiusTicks * edgeLength +
        _verticalHalfSegmentTicks * normalY.abs() +
        (terrainCollisionSkinTicks + extraClearanceTicks) * edgeLength;
    return normalX * edge.start.xTicks + normalY * edge.start.yTicks + extent;
  }

  int _rawNormalX(TerrainEdge edge) => edge.dyTicks;

  int _rawNormalY(TerrainEdge edge) => -edge.dxTicks;

  int _edgeLengthTicks(TerrainEdge edge) => edge.lengthFloorTicks;

  void _solveDisplacement(
    int requestedX,
    int requestedY, {
    required TerrainMotionMode mode,
    required int surfaceDirectionSign,
    required bool allowStep,
  }) {
    var remainingX = requestedX;
    var remainingY = requestedY;
    while (_out.contactIterations < terrainMaxBlockingContacts) {
      if (remainingX == 0 && remainingY == 0) return;
      outContactIteration:
      {
        final sweepStartX = _centerX;
        final sweepStartY = _centerY;
        _querySweptCapsule(
          centerX: sweepStartX,
          centerY: sweepStartY,
          displacementX: remainingX,
          displacementY: remainingY,
        );

        var bestEdgeIndex = -1;
        _bestHit.reset();
        for (
          var candidateIndex = 0;
          candidateIndex < _queryBuffer.candidateCount;
          candidateIndex += 1
        ) {
          final edge = _queryBuffer.edgeAt(candidateIndex, index.edges);
          final retainedSupport = _provisionalSupport;
          if ((mode == TerrainMotionMode.groundedHorizontal ||
                  mode == TerrainMotionMode.groundedSurface) &&
              retainedSupport != null &&
              edge.id == retainedSupport.id) {
            // Grounded traversal already constrains motion to its current
            // eligible support face. That same face cannot block as a wall;
            // neighboring walkable faces must still sweep so canonical
            // support transitions and contacts remain observable.
            continue;
          }
          _kernel.sweepAtCenter(
            centerXTicks: sweepStartX,
            centerYTicks: sweepStartY,
            radiusTicks: _radiusTicks,
            verticalHalfSegmentTicks: _verticalHalfSegmentTicks,
            displacementXTicks: remainingX,
            displacementYTicks: remainingY,
            edge: edge,
            out: _scratchHit,
          );
          policy.classifySweepAtCenter(
            tickStartCenterXTicks: _tickStartCenterX,
            tickStartCenterYTicks: _tickStartCenterY,
            radiusTicks: _radiusTicks,
            verticalHalfSegmentTicks: _verticalHalfSegmentTicks,
            displacementXTicks: remainingX,
            displacementYTicks: remainingY,
            edge: edge,
            hit: _scratchHit,
            out: _scratchDecision,
          );
          if (!_scratchDecision.blocks) continue;
          if (bestEdgeIndex < 0 ||
              _kernel.compareHits(_scratchHit, _bestHit) < 0) {
            bestEdgeIndex = candidateIndex;
            _bestHit.copyFrom(_scratchHit);
          }
        }
        if (bestEdgeIndex < 0) {
          _centerX += remainingX;
          _centerY += remainingY;
          return;
        }

        final bestEdge = _queryBuffer.edgeAt(bestEdgeIndex, index.edges);
        policy.classifySweepAtCenter(
          tickStartCenterXTicks: _tickStartCenterX,
          tickStartCenterYTicks: _tickStartCenterY,
          radiusTicks: _radiusTicks,
          verticalHalfSegmentTicks: _verticalHalfSegmentTicks,
          displacementXTicks: remainingX,
          displacementYTicks: remainingY,
          edge: bestEdge,
          hit: _bestHit,
          out: _scratchDecision,
        );
        final retainedSkin =
            terrainCollisionSkinTicks - terrainContactEpsilonTicks;
        final closingProjection =
            -(remainingX * _scratchDecision.normalXTicks +
                remainingY * _scratchDecision.normalYTicks);
        final advanceX = _bestHit.displacementBeforeImpactTicks(
          displacementTicks: remainingX,
          closingProjection: closingProjection,
          skinTicks: retainedSkin,
        );
        final advanceY = _bestHit.displacementBeforeImpactTicks(
          displacementTicks: remainingY,
          closingProjection: closingProjection,
          skinTicks: retainedSkin,
        );
        _centerX += advanceX;
        _centerY += advanceY;

        var constraintCount = 0;
        for (
          var candidateIndex = 0;
          candidateIndex < _queryBuffer.candidateCount;
          candidateIndex += 1
        ) {
          final edge = _queryBuffer.edgeAt(candidateIndex, index.edges);
          _kernel.sweepAtCenter(
            centerXTicks: sweepStartX,
            centerYTicks: sweepStartY,
            radiusTicks: _radiusTicks,
            verticalHalfSegmentTicks: _verticalHalfSegmentTicks,
            displacementXTicks: remainingX,
            displacementYTicks: remainingY,
            edge: edge,
            out: _scratchHit,
          );
          if (!_scratchHit.hit ||
              !_kernel.hitsHaveEqualTime(_scratchHit, _bestHit)) {
            continue;
          }
          policy.classifySweepAtCenter(
            tickStartCenterXTicks: _tickStartCenterX,
            tickStartCenterYTicks: _tickStartCenterY,
            radiusTicks: _radiusTicks,
            verticalHalfSegmentTicks: _verticalHalfSegmentTicks,
            displacementXTicks: remainingX,
            displacementYTicks: remainingY,
            edge: edge,
            hit: _scratchHit,
            out: _scratchDecision,
          );
          if (!_scratchDecision.blocks) continue;
          if (constraintCount < terrainMaxBlockingContacts) {
            _constraintNormalX[constraintCount] = _scratchDecision.normalXTicks;
            _constraintNormalY[constraintCount] = _scratchDecision.normalYTicks;
            _constraintKind[constraintCount] = _scratchDecision.kind;
            _constraintEdge[constraintCount] =
                geometry.edgeById[_scratchDecision.constraintEdgeId] ?? edge;
            _constraintFeature[constraintCount] = _scratchHit.feature;
            constraintCount += 1;
          }
          _recordBlockingContact(edge, _scratchHit, _scratchDecision);
        }
        _out.contactIterations += 1;

        var unresolvedX = _bestHit.displacementAfterImpactTicks(remainingX);
        var unresolvedY = _bestHit.displacementAfterImpactTicks(remainingY);

        TerrainEdge? transitionSupport;
        var hasNonSupportConstraint = false;
        var hasWallConstraint = false;
        for (var index = 0; index < constraintCount; index += 1) {
          if (_constraintKind[index] == TerrainContactKind.support &&
              _constraintFeature[index] == TerrainSegmentFeature.face) {
            transitionSupport ??= _constraintEdge[index];
          } else if (_constraintKind[index] != TerrainContactKind.support) {
            hasNonSupportConstraint = true;
            if (_constraintKind[index] == TerrainContactKind.wall) {
              hasWallConstraint = true;
            }
          }
        }

        if (allowStep &&
            !_out.usedStep &&
            hasWallConstraint &&
            unresolvedX != 0 &&
            _tryStep(forwardXTicks: unresolvedX)) {
          return;
        }

        if (!hasNonSupportConstraint &&
            transitionSupport != null &&
            mode == TerrainMotionMode.groundedHorizontal &&
            transitionSupport.tangent.xTicks.abs() >=
                profile.minimumSupportUpComponent) {
          unresolvedY = _roundedDivide(
            unresolvedX * transitionSupport.tangent.yTicks,
            transitionSupport.tangent.xTicks,
          );
        } else if (!hasNonSupportConstraint &&
            transitionSupport != null &&
            mode == TerrainMotionMode.groundedSurface) {
          final distance = _integerSqrt(
            unresolvedX * unresolvedX + unresolvedY * unresolvedY,
          );
          final tangentSign =
              transitionSupport.tangent.xTicks.sign == surfaceDirectionSign
              ? 1
              : -1;
          unresolvedX = _roundedDivide(
            distance * transitionSupport.tangent.xTicks * tangentSign,
            terrainDirectionScale,
          );
          unresolvedY = _roundedDivide(
            distance * transitionSupport.tangent.yTicks * tangentSign,
            terrainDirectionScale,
          );
        } else {
          final constrained = _applyConstraints(
            unresolvedX,
            unresolvedY,
            constraintCount,
          );
          unresolvedX = constrained.$1;
          unresolvedY = constrained.$2;
        }

        if (advanceX == 0 &&
            advanceY == 0 &&
            unresolvedX == remainingX &&
            unresolvedY == remainingY) {
          _out.diagnostic = TerrainControllerDiagnostic.contactIterationLimit;
          return;
        }
        remainingX = unresolvedX;
        remainingY = unresolvedY;
        break outContactIteration;
      }
    }
    if (remainingX != 0 || remainingY != 0) {
      _out.diagnostic = TerrainControllerDiagnostic.contactIterationLimit;
    }
  }

  bool _tryStep({required int forwardXTicks}) {
    final startX = _centerX;
    final startY = _centerY;
    final stepOriginSupport = _provisionalSupport;
    // Lift and advance one skin beyond the authored request so an
    // exactly-max-height ledge is not rejected as endpoint tangency during
    // preview. Final support below remains bounded by authored geometry.
    final previewLiftTicks =
        profile.stepHeightTicks +
        terrainCollisionSkinTicks +
        terrainContactEpsilonTicks;
    final raisedY = startY - previewLiftTicks;
    if (_pathBlocked(0, -previewLiftTicks)) return false;
    _centerY = raisedY;
    final previewForwardXTicks =
        forwardXTicks +
        forwardXTicks.sign *
            (terrainCollisionSkinTicks + terrainContactEpsilonTicks);
    if (_pathBlocked(previewForwardXTicks, 0)) {
      _centerX = startX;
      _centerY = startY;
      return false;
    }
    _centerX += previewForwardXTicks;

    final probeDistance =
        previewLiftTicks +
        terrainCollisionSkinTicks +
        terrainContactEpsilonTicks;
    final supportHit = _findFirstSupportSweep(
      centerX: _centerX,
      centerY: _centerY,
      displacementYTicks: probeDistance,
    );
    if (supportHit == null) {
      _centerX = startX;
      _centerY = startY;
      return false;
    }
    if (stepOriginSupport == null) {
      _centerX = startX;
      _centerY = startY;
      return false;
    }
    final supportX = _bestHit.pointXTicks;
    final geometricRise =
        _edgeYAtXClamped(stepOriginSupport, supportX) -
        _edgeYAtXClamped(supportHit, supportX);
    if (geometricRise < 0 ||
        geometricRise > profile.stepHeightTicks + terrainContactEpsilonTicks) {
      _centerX = startX;
      _centerY = startY;
      return false;
    }
    final downDistance = math.max(
      0,
      _bestHit.displacementBeforeImpactTicks(
        displacementTicks: probeDistance,
        closingProjection: probeDistance * terrainDirectionScale,
        skinTicks: terrainCollisionSkinTicks - terrainContactEpsilonTicks,
      ),
    );
    final finalY = raisedY + downDistance;
    final rise = startY - finalY;
    if (finalY > startY ||
        rise < 0 ||
        rise > profile.stepHeightTicks + terrainContactEpsilonTicks) {
      _centerX = startX;
      _centerY = startY;
      return false;
    }

    _centerY = finalY;
    _out
      ..usedStep = true
      ..stepVerticalCorrectionYTicks += finalY - startY
      ..hitLeft = false
      ..hitRight = false
      ..wallNormalXTicks = 0
      ..wallNormalYTicks = 0;
    _provisionalSupport = supportHit;
    _writeSupport(supportHit, _bestHit.pointXTicks, _bestHit.pointYTicks);
    return true;
  }

  int _edgeYAtXClamped(TerrainEdge edge, int xTicks) {
    if (edge.dxTicks == 0) return edge.start.yTicks;
    final minX = math.min(edge.start.xTicks, edge.end.xTicks);
    final maxX = math.max(edge.start.xTicks, edge.end.xTicks);
    final clampedX = xTicks.clamp(minX, maxX);
    return edge.start.yTicks +
        _roundedDivide(
          (clampedX - edge.start.xTicks) * edge.dyTicks,
          edge.dxTicks,
        );
  }

  bool _pathBlocked(int displacementX, int displacementY) {
    if (displacementX == 0 && displacementY == 0) return false;
    _querySweptCapsule(
      centerX: _centerX,
      centerY: _centerY,
      displacementX: displacementX,
      displacementY: displacementY,
    );
    for (
      var candidateIndex = 0;
      candidateIndex < _queryBuffer.candidateCount;
      candidateIndex += 1
    ) {
      final edge = _queryBuffer.edgeAt(candidateIndex, index.edges);
      _kernel.sweepAtCenter(
        centerXTicks: _centerX,
        centerYTicks: _centerY,
        radiusTicks: _radiusTicks,
        verticalHalfSegmentTicks: _verticalHalfSegmentTicks,
        displacementXTicks: displacementX,
        displacementYTicks: displacementY,
        edge: edge,
        out: _scratchHit,
      );
      policy.classifySweepAtCenter(
        tickStartCenterXTicks: _tickStartCenterX,
        tickStartCenterYTicks: _tickStartCenterY,
        radiusTicks: _radiusTicks,
        verticalHalfSegmentTicks: _verticalHalfSegmentTicks,
        displacementXTicks: displacementX,
        displacementYTicks: displacementY,
        edge: edge,
        hit: _scratchHit,
        out: _scratchDecision,
      );
      if (_scratchDecision.blocks) return true;
    }
    final endCenterX = _centerX + displacementX;
    final endCenterY = _centerY + displacementY;
    _queryCapsule(centerX: endCenterX, centerY: endCenterY);
    for (
      var candidateIndex = 0;
      candidateIndex < _queryBuffer.candidateCount;
      candidateIndex += 1
    ) {
      final edge = _queryBuffer.edgeAt(candidateIndex, index.edges);
      if (edge.collisionMode != TerrainCollisionMode.solid) continue;
      if (policy.capsuleCenterPlaneDistanceNumeratorAtCenter(
            centerXTicks: endCenterX,
            centerYTicks: endCenterY,
            edge: edge,
          ) <
          -terrainContactEpsilonTicks * terrainDirectionScale) {
        continue;
      }
      _kernel.evaluateAtCenter(
        centerXTicks: endCenterX,
        centerYTicks: endCenterY,
        radiusTicks: _radiusTicks,
        verticalHalfSegmentTicks: _verticalHalfSegmentTicks,
        edge: edge,
        out: _scratchContact,
      );
      if (_scratchContact.separationLessThanTicks(
        terrainCollisionSkinTicks - terrainContactEpsilonTicks,
      )) {
        return true;
      }
    }
    return false;
  }

  TerrainEdge? _findFirstSupportSweep({
    required int centerX,
    required int centerY,
    required int displacementYTicks,
  }) {
    _querySweptCapsule(
      centerX: centerX,
      centerY: centerY,
      displacementX: 0,
      displacementY: displacementYTicks,
    );
    TerrainEdge? support;
    _bestHit.reset();
    for (
      var candidateIndex = 0;
      candidateIndex < _queryBuffer.candidateCount;
      candidateIndex += 1
    ) {
      final edge = _queryBuffer.edgeAt(candidateIndex, index.edges);
      if (!profile.isWalkableSupport(edge)) continue;
      _kernel.sweepAtCenter(
        centerXTicks: centerX,
        centerYTicks: centerY,
        radiusTicks: _radiusTicks,
        verticalHalfSegmentTicks: _verticalHalfSegmentTicks,
        displacementXTicks: 0,
        displacementYTicks: displacementYTicks,
        edge: edge,
        out: _scratchHit,
      );
      policy.classifySweepAtCenter(
        tickStartCenterXTicks: _tickStartCenterX,
        tickStartCenterYTicks: _tickStartCenterY,
        radiusTicks: _radiusTicks,
        verticalHalfSegmentTicks: _verticalHalfSegmentTicks,
        displacementXTicks: 0,
        displacementYTicks: displacementYTicks,
        edge: edge,
        hit: _scratchHit,
        out: _scratchDecision,
      );
      if (_scratchDecision.kind != TerrainContactKind.support) continue;
      if (support == null || _kernel.compareHits(_scratchHit, _bestHit) < 0) {
        support = edge;
        _bestHit.copyFrom(_scratchHit);
      }
    }
    return support;
  }

  void _queryCapsule({required int centerX, required int centerY}) {
    final expansion = terrainCollisionSkinTicks + terrainContactEpsilonTicks;
    final halfHeight = _radiusTicks + _verticalHalfSegmentTicks;
    index.queryBounds(
      minX: centerX - _radiusTicks - expansion,
      minY: centerY - halfHeight - expansion,
      maxX: centerX + _radiusTicks + expansion,
      maxY: centerY + halfHeight + expansion,
      buffer: _queryBuffer,
    );
    _out.candidateCount += _queryBuffer.candidateCount;
    _out.queryCellsVisited += _queryBuffer.stats.cellsVisited;
  }

  void _querySweptCapsule({
    required int centerX,
    required int centerY,
    required int displacementX,
    required int displacementY,
  }) {
    final expansion = terrainCollisionSkinTicks + terrainContactEpsilonTicks;
    final halfHeight = _radiusTicks + _verticalHalfSegmentTicks;
    final endX = centerX + displacementX;
    final endY = centerY + displacementY;
    index.queryBounds(
      minX: math.min(centerX, endX) - _radiusTicks - expansion,
      minY: math.min(centerY, endY) - halfHeight - expansion,
      maxX: math.max(centerX, endX) + _radiusTicks + expansion,
      maxY: math.max(centerY, endY) + halfHeight + expansion,
      buffer: _queryBuffer,
    );
    _out.candidateCount += _queryBuffer.candidateCount;
    _out.queryCellsVisited += _queryBuffer.stats.cellsVisited;
  }

  (int, int) _applyConstraints(int x, int y, int constraintCount) {
    if (_satisfiesConstraints(x, y, constraintCount)) return (x, y);

    // In 2D the closest point in the intersection of origin-based contact
    // half-spaces is the original vector, one constraint boundary, or the
    // shared origin. Testing those finite candidates avoids alternating
    // sequential projection between two non-parallel corner normals.
    var constrainedX = 0;
    var constrainedY = 0;
    var bestDistanceSquared = x * x + y * y;
    for (var index = 0; index < constraintCount; index += 1) {
      final normalX = _constraintNormalX[index];
      final normalY = _constraintNormalY[index];
      final dot = x * normalX + y * normalY;
      if (dot >= 0) continue;
      final normalLengthSquared = normalX * normalX + normalY * normalY;
      final candidateX = x - _roundedDivide(dot * normalX, normalLengthSquared);
      final candidateY = y - _roundedDivide(dot * normalY, normalLengthSquared);
      if (!_satisfiesConstraints(candidateX, candidateY, constraintCount)) {
        continue;
      }
      final deltaX = candidateX - x;
      final deltaY = candidateY - y;
      final distanceSquared = deltaX * deltaX + deltaY * deltaY;
      if (distanceSquared < bestDistanceSquared) {
        constrainedX = candidateX;
        constrainedY = candidateY;
        bestDistanceSquared = distanceSquared;
      }
    }
    if (constrainedX.abs() <= terrainGeometryEpsilonTicks) constrainedX = 0;
    if (constrainedY.abs() <= terrainGeometryEpsilonTicks) constrainedY = 0;
    return (constrainedX, constrainedY);
  }

  bool _satisfiesConstraints(int x, int y, int constraintCount) {
    final tolerance = terrainGeometryEpsilonTicks * terrainDirectionScale;
    for (var index = 0; index < constraintCount; index += 1) {
      if (x * _constraintNormalX[index] + y * _constraintNormalY[index] <
          -tolerance) {
        return false;
      }
    }
    return true;
  }

  void _recordBlockingContact(
    TerrainEdge edge,
    CapsuleSweepHit hit,
    TerrainContactDecision decision,
  ) {
    if (_out.contactCount < terrainMaxBlockingContacts) {
      final index = _out.contactCount;
      _out.contactEdgeIds[index] = edge.id;
      _out.contactKinds[index] = decision.kind;
      _out.contactFeatures[index] = hit.feature;
      _out.contactNormalXTicks[index] = decision.normalXTicks;
      _out.contactNormalYTicks[index] = decision.normalYTicks;
      _out.contactCount += 1;
    }

    switch (decision.kind) {
      case TerrainContactKind.support:
        if (_provisionalSupport == null ||
            edge.id.compareTo(_provisionalSupport!.id) < 0) {
          _provisionalSupport = edge;
        }
      case TerrainContactKind.wall:
        _out.wallNormalXTicks = decision.normalXTicks;
        _out.wallNormalYTicks = decision.normalYTicks;
        if (decision.normalXTicks < 0) _out.hitRight = true;
        if (decision.normalXTicks > 0) _out.hitLeft = true;
      case TerrainContactKind.ceiling:
        _out.hitCeiling = true;
        _out.ceilingNormalXTicks = decision.normalXTicks;
        _out.ceilingNormalYTicks = decision.normalYTicks;
      case TerrainContactKind.ignored:
        break;
    }
  }

  @pragma('vm:prefer-inline')
  void _resolveFinalSupport({
    required bool beganGrounded,
    required bool allowSnap,
  }) {
    _out._clearSupport();
    final provisional = _provisionalSupport;
    if (provisional != null) {
      final withinSupportTolerance = _kernel.evaluateSupportAtCenterWithin(
        centerXTicks: _centerX,
        centerYTicks: _centerY,
        radiusTicks: _radiusTicks,
        verticalHalfSegmentTicks: _verticalHalfSegmentTicks,
        edge: provisional,
        maximumSeparationTicks:
            terrainCollisionSkinTicks + terrainContactEpsilonTicks,
        out: _scratchContact,
      );
      if (withinSupportTolerance &&
          policy.acceptsSupportContactAtCenter(
            tickStartCenterXTicks: _tickStartCenterX,
            tickStartCenterYTicks: _tickStartCenterY,
            radiusTicks: _radiusTicks,
            verticalHalfSegmentTicks: _verticalHalfSegmentTicks,
            edge: provisional,
            contact: _scratchContact,
          )) {
        _writeSupport(
          provisional,
          _scratchContact.pointXTicks,
          _scratchContact.pointYTicks,
        );
        return;
      }
    }
    if (!beganGrounded || !allowSnap) return;

    final probeDistance =
        profile.snapDistanceTicks +
        terrainCollisionSkinTicks +
        terrainContactEpsilonTicks;
    _querySweptCapsule(
      centerX: _centerX,
      centerY: _centerY,
      displacementX: 0,
      displacementY: probeDistance,
    );

    TerrainEdge? support;
    _bestHit.reset();
    for (
      var candidateIndex = 0;
      candidateIndex < _queryBuffer.candidateCount;
      candidateIndex += 1
    ) {
      final edge = _queryBuffer.edgeAt(candidateIndex, index.edges);
      if (!profile.isWalkableSupport(edge)) continue;
      _kernel.sweepAtCenter(
        centerXTicks: _centerX,
        centerYTicks: _centerY,
        radiusTicks: _radiusTicks,
        verticalHalfSegmentTicks: _verticalHalfSegmentTicks,
        displacementXTicks: 0,
        displacementYTicks: probeDistance,
        edge: edge,
        out: _scratchHit,
      );
      policy.classifySweepAtCenter(
        tickStartCenterXTicks: _tickStartCenterX,
        tickStartCenterYTicks: _tickStartCenterY,
        radiusTicks: _radiusTicks,
        verticalHalfSegmentTicks: _verticalHalfSegmentTicks,
        displacementXTicks: 0,
        displacementYTicks: probeDistance,
        edge: edge,
        hit: _scratchHit,
        out: _scratchDecision,
      );
      if (_scratchDecision.kind != TerrainContactKind.support) continue;
      if (support == null || _kernel.compareHits(_scratchHit, _bestHit) < 0) {
        support = edge;
        _bestHit.copyFrom(_scratchHit);
      }
    }
    if (support == null) return;

    final tickStartSupport = _tickStartSupport;
    if (tickStartSupport != null && tickStartSupport.id != support.id) {
      final supportX = _bestHit.pointXTicks;
      final geometricDrop =
          _edgeYAtXClamped(support, supportX) -
          _edgeYAtXClamped(tickStartSupport, supportX);
      if (geometricDrop >
          profile.snapDistanceTicks + terrainContactEpsilonTicks) {
        return;
      }
    }

    final snapDistance = math.max(
      0,
      _bestHit.displacementBeforeImpactTicks(
        displacementTicks: probeDistance,
        closingProjection: probeDistance * terrainDirectionScale,
        skinTicks: terrainCollisionSkinTicks - terrainContactEpsilonTicks,
      ),
    );
    if (snapDistance > profile.snapDistanceTicks) return;
    if (snapDistance > 0) {
      _centerY += snapDistance;
      _out.usedSnap = true;
      _out.snapCorrectionYTicks += snapDistance;
    }
    _writeSupport(support, _bestHit.pointXTicks, _bestHit.pointYTicks);
  }

  void _writeSupport(TerrainEdge edge, int pointX, int pointY) {
    _out
      ..grounded = true
      ..supportEdgeId = edge.id
      ..supportPointXTicks = pointX
      ..supportPointYTicks = pointY
      ..supportNormalXTicks = edge.outwardNormal.xTicks
      ..supportNormalYTicks = edge.outwardNormal.yTicks
      ..supportTangentXTicks = edge.tangent.xTicks
      ..supportTangentYTicks = edge.tangent.yTicks;
  }

  bool _recoverInitialOverlap({
    required int? lastValidCenterX,
    required int? lastValidCenterY,
  }) {
    var totalCorrection = 0;
    for (
      var iteration = 0;
      iteration < terrainMaxRecoveryIterations;
      iteration += 1
    ) {
      if (!_findRecoveryCandidate()) return true;
      if (_recoveryCorrectionTicks <= 0 ||
          totalCorrection + _recoveryCorrectionTicks > _radiusTicks) {
        _restoreAfterRecoveryFailure(lastValidCenterX, lastValidCenterY);
        return false;
      }
      final correctionX = _roundedDivide(
        _recoveryCorrectionTicks * _recoveryNormalXTicks,
        terrainDirectionScale,
      );
      final correctionY = _roundedDivide(
        _recoveryCorrectionTicks * _recoveryNormalYTicks,
        terrainDirectionScale,
      );
      if (correctionX == 0 && correctionY == 0) {
        _restoreAfterRecoveryFailure(lastValidCenterX, lastValidCenterY);
        return false;
      }
      _centerX += correctionX;
      _centerY += correctionY;
      _out.recoveryCorrectionXTicks += correctionX;
      _out.recoveryCorrectionYTicks += correctionY;
      _out.recoveryIterations += 1;
      _out.usedRecovery = true;
      totalCorrection += _recoveryCorrectionTicks;
    }
    if (_findRecoveryCandidate()) {
      _restoreAfterRecoveryFailure(lastValidCenterX, lastValidCenterY);
      return false;
    }
    return true;
  }

  @pragma('vm:prefer-inline')
  bool _findRecoveryCandidate() {
    _recoveryEdge = null;
    _recoveryCorrectionTicks = 0;
    _recoveryNormalXTicks = 0;
    _recoveryNormalYTicks = 0;
    for (
      var polygonIndex = 0;
      polygonIndex < geometry.polygons.length;
      polygonIndex += 1
    ) {
      final polygon = geometry.polygons[polygonIndex];
      if (polygon.collisionMode != TerrainCollisionMode.solid ||
          (!_pointInsidePolygon(_centerX, _centerY, polygon.vertices) &&
              !_pointInsidePolygon(
                _centerX,
                _centerY - _verticalHalfSegmentTicks,
                polygon.vertices,
              ) &&
              !_pointInsidePolygon(
                _centerX,
                _centerY + _verticalHalfSegmentTicks,
                polygon.vertices,
              ))) {
        continue;
      }
      for (
        var edgeIndex = 0;
        edgeIndex < geometry.edges.length;
        edgeIndex += 1
      ) {
        final edge = geometry.edges[edgeIndex];
        if (!_edgeBelongsToPolygon(edge, polygon)) continue;
        final clearanceNumerator = policy
            .capsulePlaneClearanceNumeratorAtCenter(
              centerXTicks: _centerX,
              centerYTicks: _centerY,
              radiusTicks: _radiusTicks,
              verticalHalfSegmentTicks: _verticalHalfSegmentTicks,
              edge: edge,
            );
        final correction = _ceilingDivide(
          terrainCollisionSkinTicks * terrainDirectionScale -
              clearanceNumerator,
          terrainDirectionScale,
        );
        if (correction <= 0) continue;
        _considerRecoveryCandidate(
          edge: edge,
          correctionTicks: correction,
          normalXTicks: edge.outwardNormal.xTicks,
          normalYTicks: edge.outwardNormal.yTicks,
        );
      }
    }

    _queryCapsule(centerX: _centerX, centerY: _centerY);
    for (
      var candidateIndex = 0;
      candidateIndex < _queryBuffer.candidateCount;
      candidateIndex += 1
    ) {
      final edge = _queryBuffer.edgeAt(candidateIndex, index.edges);
      if (edge.collisionMode != TerrainCollisionMode.solid) continue;
      if (policy.capsuleCenterPlaneDistanceNumeratorAtCenter(
            centerXTicks: _centerX,
            centerYTicks: _centerY,
            edge: edge,
          ) <
          -terrainContactEpsilonTicks * terrainDirectionScale) {
        continue;
      }
      _kernel.evaluateRecoveryAtCenter(
        centerXTicks: _centerX,
        centerYTicks: _centerY,
        radiusTicks: _radiusTicks,
        verticalHalfSegmentTicks: _verticalHalfSegmentTicks,
        edge: edge,
        out: _scratchContact,
      );
      if (_scratchContact.signedSeparationFloorTicks >=
          terrainCollisionSkinTicks - terrainContactEpsilonTicks) {
        continue;
      }
      _considerRecoveryCandidate(
        edge: edge,
        correctionTicks: _scratchContact.collisionSkinCorrectionTicks,
        normalXTicks: _scratchContact.normalXTicks,
        normalYTicks: _scratchContact.normalYTicks,
      );
    }
    return _recoveryEdge != null;
  }

  void _considerRecoveryCandidate({
    required TerrainEdge edge,
    required int correctionTicks,
    required int normalXTicks,
    required int normalYTicks,
  }) {
    final current = _recoveryEdge;
    if (current != null &&
        (correctionTicks > _recoveryCorrectionTicks ||
            (correctionTicks == _recoveryCorrectionTicks &&
                edge.id.compareTo(current.id) >= 0))) {
      return;
    }
    _recoveryEdge = edge;
    _recoveryCorrectionTicks = correctionTicks;
    _recoveryNormalXTicks = normalXTicks;
    _recoveryNormalYTicks = normalYTicks;
  }

  void _restoreAfterRecoveryFailure(int? lastValidX, int? lastValidY) {
    if (lastValidX != null && lastValidY != null) {
      _centerX = lastValidX;
      _centerY = lastValidY;
    } else {
      _centerX = _tickStartCenterX;
      _centerY = _tickStartCenterY;
    }
    _out
      ..grounded = false
      ..recoveryCorrectionXTicks = 0
      ..recoveryCorrectionYTicks = 0
      ..diagnostic = TerrainControllerDiagnostic.recoveryFailed;
  }

  void _finalize() {
    _out
      ..finalCenterXTicks = _centerX
      ..finalCenterYTicks = _centerY
      ..resolvedXTicks = _centerX - _out.startCenterXTicks
      ..resolvedYTicks = _centerY - _out.startCenterYTicks;
    if (_out.diagnostic == TerrainControllerDiagnostic.recoveryFailed) {
      _out.progressionXTicks = 0;
      _out.supportedTravelTicks = 0;
      return;
    }
    _out.progressionXTicks =
        _centerX - _out.startCenterXTicks - _out.recoveryCorrectionXTicks;
    _out.supportedTravelTicks =
        _supportedPathDirectionSign * _supportedPathTravelTicks;
    if (_out.diagnostic == TerrainControllerDiagnostic.none) {
      if (_out.hitCeiling) {
        _out.diagnostic = TerrainControllerDiagnostic.blockedCeiling;
      } else if (_out.hitLeft || _out.hitRight) {
        _out.diagnostic = TerrainControllerDiagnostic.blockedWall;
      } else if (_beganGrounded && !_out.grounded) {
        _out.diagnostic = TerrainControllerDiagnostic.unsupported;
      }
    }
  }
}

class _SupportTransition {
  late TerrainEdge nextSupport;
  late TerrainPoint vertex;
  int thresholdX = 0;
  int thresholdY = 0;
  bool convex = false;

  void set({
    required TerrainEdge nextSupport,
    required TerrainPoint vertex,
    required int thresholdX,
    required int thresholdY,
    required bool convex,
  }) {
    this.nextSupport = nextSupport;
    this.vertex = vertex;
    this.thresholdX = thresholdX;
    this.thresholdY = thresholdY;
    this.convex = convex;
  }
}

bool _crossesInDirection(int start, int end, int threshold) {
  if (end > start) return end > threshold && start <= threshold;
  if (end < start) return end < threshold && start >= threshold;
  return false;
}

int _roundedDivide(int numerator, int denominator) {
  if (denominator == 0) {
    throw ArgumentError.value(denominator, 'denominator', 'Must not be zero.');
  }
  final negative = (numerator < 0) != (denominator < 0);
  final absoluteNumerator = numerator.abs();
  final absoluteDenominator = denominator.abs();
  final quotient =
      (absoluteNumerator + absoluteDenominator ~/ 2) ~/ absoluteDenominator;
  return negative ? -quotient : quotient;
}

int _ceilingDivide(int numerator, int positiveDenominator) {
  if (positiveDenominator <= 0) {
    throw ArgumentError.value(
      positiveDenominator,
      'positiveDenominator',
      'Must be positive.',
    );
  }
  if (numerator >= 0) {
    return (numerator + positiveDenominator - 1) ~/ positiveDenominator;
  }
  return -((-numerator) ~/ positiveDenominator);
}

int _integerSqrt(int value) {
  if (value < 0) {
    throw ArgumentError.value(value, 'value', 'Must be non-negative.');
  }
  if (value < 2) return value;
  var estimate = 1 << ((value.bitLength + 1) >> 1);
  while (true) {
    final next = (estimate + value ~/ estimate) >> 1;
    if (next >= estimate) return estimate;
    estimate = next;
  }
}

bool _edgeBelongsToPolygon(TerrainEdge edge, TerrainPolygon polygon) {
  final identity = polygon.identity;
  final id = edge.id;
  return id.chunkIndex == identity.chunkIndex &&
      id.chunkKey == identity.chunkKey &&
      id.placementKey == identity.placementKey &&
      id.shapeId == identity.shapeId;
}

bool _pointInsidePolygon(int pointX, int pointY, List<TerrainPoint> vertices) {
  var inside = false;
  for (
    var currentIndex = 0, previousIndex = vertices.length - 1;
    currentIndex < vertices.length;
    previousIndex = currentIndex, currentIndex += 1
  ) {
    final current = vertices[currentIndex];
    final previous = vertices[previousIndex];
    final edgeX = current.xTicks - previous.xTicks;
    final edgeY = current.yTicks - previous.yTicks;
    final relativePointX = pointX - previous.xTicks;
    final relativePointY = pointY - previous.yTicks;
    final cross = edgeX * relativePointY - edgeY * relativePointX;
    if (cross == 0 &&
        pointX >= math.min(previous.xTicks, current.xTicks) &&
        pointX <= math.max(previous.xTicks, current.xTicks) &&
        pointY >= math.min(previous.yTicks, current.yTicks) &&
        pointY <= math.max(previous.yTicks, current.yTicks)) {
      return true;
    }

    final crossesY = (current.yTicks > pointY) != (previous.yTicks > pointY);
    if (!crossesY) continue;
    final left = (pointX - current.xTicks) * (previous.yTicks - current.yTicks);
    final right =
        (previous.xTicks - current.xTicks) * (pointY - current.yTicks);
    final crossesRight = previous.yTicks > current.yTicks
        ? left < right
        : left > right;
    if (crossesRight) inside = !inside;
  }
  return inside;
}
