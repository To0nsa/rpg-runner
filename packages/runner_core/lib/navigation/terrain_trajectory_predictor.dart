import '../collision/terrain/capsule_segment_kernel.dart';
import '../collision/terrain/terrain_capsule_controller.dart';
import '../collision/terrain/terrain_contact_policy.dart';
import '../collision/terrain/terrain_edge.dart';
import '../collision/terrain/terrain_edge_id.dart';
import '../collision/terrain/terrain_motion_request.dart';
import '../collision/terrain/terrain_numeric.dart';
import '../collision/terrain/terrain_query_buffer.dart';
import '../collision/terrain/terrain_traversal_profile.dart';
import 'terrain_placement_query.dart';

/// Caller-owned result from [TerrainTrajectoryPredictor.predictLanding].
///
/// Every coordinate uses authoritative physics ticks. The object is reset and
/// reused on every query; callers must copy fields they need to retain.
final class TerrainLandingPrediction {
  /// Whether the latest query found a validated landing.
  bool hasLanding = false;

  /// Geometry version owning [supportEdgeId].
  int geometryVersion = -1;

  /// First fixed tick containing the landing contact.
  int ticksToLand = 0;

  /// Contact fraction inside [ticksToLand], where one million is one tick.
  int timeWithinTickUnits = 0;

  /// Exact validated body center on the destination support.
  int bodyCenterXTicks = 0;
  int bodyCenterYTicks = 0;

  /// Exact validated capsule center on the destination support.
  int capsuleCenterXTicks = 0;
  int capsuleCenterYTicks = 0;

  /// Exact point on the finite destination surface.
  int supportPointXTicks = 0;
  int supportPointYTicks = 0;

  /// Persistent identity of the destination support.
  TerrainEdgeId? supportEdgeId;

  /// Quantized destination tangent and outward normal.
  int supportTangentXTicks = 0;
  int supportTangentYTicks = 0;
  int supportNormalXTicks = 0;
  int supportNormalYTicks = 0;

  /// Restores the no-landing state without replacing this output object.
  void reset() {
    hasLanding = false;
    geometryVersion = -1;
    ticksToLand = 0;
    timeWithinTickUnits = 0;
    bodyCenterXTicks = 0;
    bodyCenterYTicks = 0;
    capsuleCenterXTicks = 0;
    capsuleCenterYTicks = 0;
    supportPointXTicks = 0;
    supportPointYTicks = 0;
    supportEdgeId = null;
    supportTangentXTicks = 0;
    supportTangentYTicks = 0;
    supportNormalXTicks = 0;
    supportNormalYTicks = 0;
  }
}

/// Fixed-tick full-capsule landing prediction over polygon terrain.
///
/// One instance is bound to a traversal/support policy and owns mutable query
/// scratch, so it must not be used concurrently. Ground-enemy navigation uses
/// this predictor against the currently published terrain bundle.
class TerrainTrajectoryPredictor {
  TerrainTrajectoryPredictor({
    required this.placementQuery,
    required this.traversalProfile,
    required this.supportRequirement,
    required this.dtSeconds,
    required this.maxTicks,
  }) : policy = TerrainContactPolicy(
         geometry: placementQuery.geometry,
         profile: traversalProfile,
       ),
       _controller = TerrainCapsuleController(
         geometry: placementQuery.geometry,
         index: placementQuery.terrainIndex,
         profile: traversalProfile,
       ),
       _queryBuffer = placementQuery.terrainIndex.createQueryBuffer() {
    if (!dtSeconds.isFinite || dtSeconds <= 0) {
      throw ArgumentError.value(
        dtSeconds,
        'dtSeconds',
        'Must be finite and positive.',
      );
    }
    if (maxTicks <= 0) {
      throw ArgumentError.value(maxTicks, 'maxTicks', 'Must be positive.');
    }
    if (supportRequirement.kind !=
        TerrainSupportRequirementKind.runtimeNavigation) {
      throw ArgumentError(
        'Runtime trajectory prediction requires a navigation foothold.',
      );
    }
  }

  /// Shared geometry, surface, and final-placement authority.
  final TerrainPlacementQuery placementQuery;

  /// Actor policy used for sidedness and support classification.
  final TerrainTraversalProfile traversalProfile;

  /// Actor foothold rule used to validate the first support contact.
  final TerrainSupportRequirement supportRequirement;

  /// Fixed Core timestep in seconds.
  final double dtSeconds;

  /// Bounded number of future ticks inspected per query.
  final int maxTicks;

  /// Reused contact policy for this actor profile.
  final TerrainContactPolicy policy;

  final CapsuleSegmentKernel _kernel = CapsuleSegmentKernel();
  final TerrainCapsuleController _controller;
  final TerrainQueryBuffer _queryBuffer;
  final CapsuleSweepHit _scratchHit = CapsuleSweepHit();
  final CapsuleSweepHit _bestHit = CapsuleSweepHit();
  final CapsuleSweepHit _bestSupportHit = CapsuleSweepHit();
  final TerrainContactDecision _scratchDecision = TerrainContactDecision();
  final TerrainCapsuleMotionResult _motionResult = TerrainCapsuleMotionResult();

  TerrainEdgeId? _bestSupportId;
  _TrajectoryContactOutcome _contactOutcome = _TrajectoryContactOutcome.none;

  /// Total canonical edge candidates inspected by the most recent query.
  int lastCandidateCount = 0;

  /// Total closed spatial-index cells visited by the most recent query.
  int lastQueryCellsVisited = 0;

  /// Fixed ticks simulated by the most recent query.
  int lastTicksSimulated = 0;

  /// Number of reusable terrain-buffer resizes since construction.
  int get queryBufferResizeCount =>
      _queryBuffer.resizeCount + _controller.queryBufferResizeCount;

  /// Predicts the first validated landing and writes it to [out].
  ///
  /// [velocityX] and [velocityY] are current world-unit velocities per second.
  /// [gravityY] is the already actor-resolved non-negative acceleration for
  /// the predicted ticks; pass zero when gravity is suppressed. Vertical
  /// velocity is clamped to [maximumFallSpeed] after gravity, matching Core's
  /// normal semi-implicit-Euler order. Horizontal velocity remains constant.
  bool predictLanding({
    required TerrainPoint startBodyCenter,
    required TerrainPlacementCapsule capsule,
    required double velocityX,
    required double velocityY,
    required double gravityY,
    required double maximumFallSpeed,
    required TerrainLandingPrediction out,
  }) {
    _validateMotionInputs(
      velocityX: velocityX,
      velocityY: velocityY,
      gravityY: gravityY,
      maximumFallSpeed: maximumFallSpeed,
    );
    out.reset();
    lastCandidateCount = 0;
    lastQueryCellsVisited = 0;
    lastTicksSimulated = 0;
    if (placementQuery.surfaceIndex.surfaces.isEmpty) return false;

    var bodyX = startBodyCenter.xTicks;
    var bodyY = startBodyCenter.yTicks;
    var verticalVelocity = velocityY;
    for (var tick = 1; tick <= maxTicks; tick += 1) {
      verticalVelocity = (verticalVelocity + gravityY * dtSeconds).clamp(
        -maximumFallSpeed,
        maximumFallSpeed,
      );
      final displacementX = physicsCoordinateToTicks(
        velocityX * dtSeconds,
        name: 'predictedDisplacementX',
      );
      final displacementY = physicsCoordinateToTicks(
        verticalVelocity * dtSeconds,
        name: 'predictedDisplacementY',
      );
      lastTicksSimulated = tick;

      if (displacementX == 0 && displacementY == 0) {
        bodyX += displacementX;
        bodyY += displacementY;
        continue;
      }

      final capsuleCenterX = bodyX + capsule.resolvedOffsetXTicks;
      final capsuleCenterY = bodyY + capsule.offsetYTicks;
      _findFirstBlockingContact(
        startCenterX: capsuleCenterX,
        startCenterY: capsuleCenterY,
        displacementX: displacementX,
        displacementY: displacementY,
        capsule: capsule,
      );
      if (_contactOutcome == _TrajectoryContactOutcome.blocked) return false;
      if (_contactOutcome == _TrajectoryContactOutcome.support) {
        // One-way backsides and separating support faces are filtered by the
        // contact policy. Any solid support reached before descent is still a
        // real obstruction, but cannot be reported as a landing because this
        // predictor does not model the controller response needed to continue
        // the arc from that contact.
        if (verticalVelocity <= 0) return false;
        return _validateAndWriteLanding(
          tick: tick,
          startCenterX: capsuleCenterX,
          startCenterY: capsuleCenterY,
          displacementX: displacementX,
          displacementY: displacementY,
          capsule: capsule,
          out: out,
        );
      }

      bodyX += displacementX;
      bodyY += displacementY;
    }
    return false;
  }

  void _findFirstBlockingContact({
    required int startCenterX,
    required int startCenterY,
    required int displacementX,
    required int displacementY,
    required TerrainPlacementCapsule capsule,
  }) {
    _contactOutcome = _TrajectoryContactOutcome.none;
    _bestSupportId = null;
    _bestHit.reset();
    _bestSupportHit.reset();
    final endCenterX = startCenterX + displacementX;
    final endCenterY = startCenterY + displacementY;
    final halfHeight = capsule.radiusTicks + capsule.verticalHalfSegmentTicks;
    final expansion = terrainCollisionSkinTicks + terrainContactEpsilonTicks;
    placementQuery.terrainIndex.queryBounds(
      minX: _min(startCenterX, endCenterX) - capsule.radiusTicks - expansion,
      minY: _min(startCenterY, endCenterY) - halfHeight - expansion,
      maxX: _max(startCenterX, endCenterX) + capsule.radiusTicks + expansion,
      maxY: _max(startCenterY, endCenterY) + halfHeight + expansion,
      buffer: _queryBuffer,
    );
    lastCandidateCount += _queryBuffer.candidateCount;
    lastQueryCellsVisited += _queryBuffer.stats.cellsVisited;

    var hasBlockingHit = false;
    for (
      var candidateIndex = 0;
      candidateIndex < _queryBuffer.candidateCount;
      candidateIndex += 1
    ) {
      final edge = _queryBuffer.edgeAt(
        candidateIndex,
        placementQuery.terrainIndex.edges,
      );
      _classifyCandidate(
        edge: edge,
        startCenterX: startCenterX,
        startCenterY: startCenterY,
        displacementX: displacementX,
        displacementY: displacementY,
        capsule: capsule,
      );
      if (!_scratchDecision.blocks) continue;
      if (!hasBlockingHit || _kernel.compareHits(_scratchHit, _bestHit) < 0) {
        hasBlockingHit = true;
        _bestHit.copyFrom(_scratchHit);
      }
    }
    if (!hasBlockingHit) return;

    var hasNonSupportConstraint = false;
    var supportPointY = 0;
    for (
      var candidateIndex = 0;
      candidateIndex < _queryBuffer.candidateCount;
      candidateIndex += 1
    ) {
      final edge = _queryBuffer.edgeAt(
        candidateIndex,
        placementQuery.terrainIndex.edges,
      );
      _classifyCandidate(
        edge: edge,
        startCenterX: startCenterX,
        startCenterY: startCenterY,
        displacementX: displacementX,
        displacementY: displacementY,
        capsule: capsule,
      );
      if (!_scratchDecision.blocks ||
          !_kernel.hitsHaveEqualTime(_scratchHit, _bestHit)) {
        continue;
      }
      if (_scratchDecision.kind != TerrainContactKind.support) {
        hasNonSupportConstraint = true;
        continue;
      }
      final supportId = _scratchDecision.constraintEdgeId ?? edge.id;
      final surface = placementQuery.surfaceIndex.surfaceSet.surfaceById(
        supportId,
      );
      if (surface == null || !surface.isEligibleFor(traversalProfile)) {
        hasNonSupportConstraint = true;
        continue;
      }
      if (_bestSupportId == null ||
          _scratchHit.pointYTicks < supportPointY ||
          (_scratchHit.pointYTicks == supportPointY &&
              supportId.compareTo(_bestSupportId!) < 0)) {
        _bestSupportId = supportId;
        supportPointY = _scratchHit.pointYTicks;
        _bestSupportHit.copyFrom(_scratchHit);
      }
    }
    _contactOutcome = hasNonSupportConstraint || _bestSupportId == null
        ? _TrajectoryContactOutcome.blocked
        : _TrajectoryContactOutcome.support;
  }

  void _classifyCandidate({
    required TerrainEdge edge,
    required int startCenterX,
    required int startCenterY,
    required int displacementX,
    required int displacementY,
    required TerrainPlacementCapsule capsule,
  }) {
    _kernel.sweepAtCenter(
      centerXTicks: startCenterX,
      centerYTicks: startCenterY,
      radiusTicks: capsule.radiusTicks,
      verticalHalfSegmentTicks: capsule.verticalHalfSegmentTicks,
      displacementXTicks: displacementX,
      displacementYTicks: displacementY,
      edge: edge,
      out: _scratchHit,
    );
    policy.classifySweepAtCenter(
      tickStartCenterXTicks: startCenterX,
      tickStartCenterYTicks: startCenterY,
      radiusTicks: capsule.radiusTicks,
      verticalHalfSegmentTicks: capsule.verticalHalfSegmentTicks,
      displacementXTicks: displacementX,
      displacementYTicks: displacementY,
      edge: edge,
      hit: _scratchHit,
      out: _scratchDecision,
    );
  }

  bool _validateAndWriteLanding({
    required int tick,
    required int startCenterX,
    required int startCenterY,
    required int displacementX,
    required int displacementY,
    required TerrainPlacementCapsule capsule,
    required TerrainLandingPrediction out,
  }) {
    if (!_firstSupportPlacementIsValid(
      startCenterX: startCenterX,
      displacementX: displacementX,
      capsule: capsule,
    )) {
      return false;
    }

    // Resolve the complete landing tick through the accepted controller. The
    // first-contact sweep above decides whether this tick is a landing at all;
    // the controller then consumes the post-impact remainder along a slope so
    // the published support point matches runtime rather than the raw TOI.
    _controller.moveAt(
      centerXTicks: startCenterX,
      centerYTicks: startCenterY,
      radiusTicks: capsule.radiusTicks,
      verticalHalfSegmentTicks: capsule.verticalHalfSegmentTicks,
      request: TerrainMotionRequest(
        displacementXTicks: displacementX,
        displacementYTicks: displacementY,
        mode: TerrainMotionMode.worldSpace,
      ),
      beganGrounded: false,
      out: _motionResult,
    );
    lastCandidateCount += _motionResult.candidateCount;
    lastQueryCellsVisited += _motionResult.queryCellsVisited;
    final supportId = _motionResult.supportEdgeId;
    if (!_motionResult.grounded || supportId == null) return false;
    final surface = placementQuery.surfaceIndex.surfaceSet.surfaceById(
      supportId,
    );
    if (surface == null || !surface.isEligibleFor(traversalProfile)) {
      return false;
    }
    final finalCenterX = _motionResult.finalCenterXTicks;
    if (finalCenterX < surface.xMinTicks || finalCenterX > surface.xMaxTicks) {
      return false;
    }
    final supportY = surface.yAtXTicks(finalCenterX);
    final placement = placementQuery.resolveGrounded(
      TerrainGroundPlacementRequest(
        desiredBodyCenterXTicks: finalCenterX - capsule.resolvedOffsetXTicks,
        minimumSupportYTicks: supportY,
        maximumSupportYTicks: supportY,
        capsule: capsule,
        traversalProfile: traversalProfile,
        supportRequirement: supportRequirement,
        intendedSupportEdgeId: supportId,
        expectedGeometryVersion: placementQuery.geometry.version,
      ),
    );
    if (!placement.isValid ||
        placement.bodyCenter == null ||
        placement.capsuleCenter == null ||
        placement.supportPoint == null ||
        placement.supportTangent == null ||
        placement.supportNormal == null) {
      return false;
    }

    out
      ..hasLanding = true
      ..geometryVersion = placement.geometryVersion
      ..ticksToLand = tick
      ..timeWithinTickUnits = terrainPhysicsTickValueToInt(
        _bestSupportHit.timeOfImpact * 1000000,
        name: 'predictedImpactTime',
      )
      ..bodyCenterXTicks = placement.bodyCenter!.xTicks
      ..bodyCenterYTicks = placement.bodyCenter!.yTicks
      ..capsuleCenterXTicks = placement.capsuleCenter!.xTicks
      ..capsuleCenterYTicks = placement.capsuleCenter!.yTicks
      // Contact point is the controller's exact normal projection on the
      // segment. Placement's support point instead uses vertical yAt(x), which
      // is useful for standing but is not the resolved collision contact on a
      // slope.
      ..supportPointXTicks = _motionResult.supportPointXTicks
      ..supportPointYTicks = _motionResult.supportPointYTicks
      ..supportEdgeId = supportId
      ..supportTangentXTicks = _motionResult.supportTangentXTicks
      ..supportTangentYTicks = _motionResult.supportTangentYTicks
      ..supportNormalXTicks = _motionResult.supportNormalXTicks
      ..supportNormalYTicks = _motionResult.supportNormalYTicks;
    return true;
  }

  bool _firstSupportPlacementIsValid({
    required int startCenterX,
    required int displacementX,
    required TerrainPlacementCapsule capsule,
  }) {
    final firstSupportId = _bestSupportId;
    if (firstSupportId == null) return false;
    final firstSurface = placementQuery.surfaceIndex.surfaceSet.surfaceById(
      firstSupportId,
    );
    if (firstSurface == null) return false;
    final impactCenterX = terrainPhysicsTickValueToInt(
      startCenterX + displacementX * _bestSupportHit.timeOfImpact,
      name: 'predictedImpactCenterX',
    );
    if (impactCenterX < firstSurface.xMinTicks ||
        impactCenterX > firstSurface.xMaxTicks) {
      return false;
    }
    final supportY = firstSurface.yAtXTicks(impactCenterX);
    final placement = placementQuery.resolveGrounded(
      TerrainGroundPlacementRequest(
        desiredBodyCenterXTicks: impactCenterX - capsule.resolvedOffsetXTicks,
        minimumSupportYTicks: supportY,
        maximumSupportYTicks: supportY,
        capsule: capsule,
        traversalProfile: traversalProfile,
        supportRequirement: supportRequirement,
        intendedSupportEdgeId: firstSupportId,
        expectedGeometryVersion: placementQuery.geometry.version,
      ),
    );
    return placement.isValid;
  }

  void _validateMotionInputs({
    required double velocityX,
    required double velocityY,
    required double gravityY,
    required double maximumFallSpeed,
  }) {
    if (!velocityX.isFinite || !velocityY.isFinite) {
      throw ArgumentError('Trajectory velocity must be finite.');
    }
    if (!gravityY.isFinite || gravityY < 0) {
      throw ArgumentError.value(
        gravityY,
        'gravityY',
        'Must be finite and non-negative.',
      );
    }
    if (!maximumFallSpeed.isFinite || maximumFallSpeed <= 0) {
      throw ArgumentError.value(
        maximumFallSpeed,
        'maximumFallSpeed',
        'Must be finite and positive.',
      );
    }
  }
}

enum _TrajectoryContactOutcome { none, support, blocked }

int _min(int left, int right) => left < right ? left : right;
int _max(int left, int right) => left > right ? left : right;
