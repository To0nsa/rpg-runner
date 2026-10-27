import '../collision/terrain/capsule_segment_kernel.dart';
import '../collision/terrain/terrain_capsule_controller.dart';
import '../collision/terrain/terrain_contact_policy.dart';
import '../collision/terrain/terrain_edge.dart';
import '../collision/terrain/terrain_edge_id.dart';
import '../collision/terrain/terrain_numeric.dart';
import '../util/cooperative_work_yield.dart';
import '../collision/terrain/terrain_motion_request.dart';
import '../collision/terrain/terrain_query_buffer.dart';
import 'terrain_placement_query.dart';
import 'terrain_surface_query_buffer.dart';
import 'types/terrain_navigation_surface.dart';
import 'types/terrain_surface_graph.dart';

/// Builds deterministic profile graph views over one shared surface set.
///
/// Walk edges use exact surface placement. Jump and drop edges reuse the
/// existing semi-implicit-Euler template, but validate every tick with a
/// continuous complete-capsule sweep against compiled terrain.
class TerrainSurfaceGraphBuilder {
  TerrainSurfaceGraphBuilder({required this.placementQuery});

  final TerrainPlacementQuery placementQuery;

  /// Uses the same ordered work as [build], yielding between bounded graph
  /// operations so a browser can service input and render during preparation.
  Future<TerrainSurfaceGraph> buildCooperatively(
    TerrainSurfaceGraphBuildProfile profile,
  ) => _ProfileGraphBuilder(
    placementQuery: placementQuery,
    profile: profile,
  ).buildCooperatively();

  /// Builds an immutable profile view with scratch data scoped to this call.
  TerrainSurfaceGraph build(TerrainSurfaceGraphBuildProfile profile) =>
      _ProfileGraphBuilder(
        placementQuery: placementQuery,
        profile: profile,
      ).build();
}

final class _ProfileGraphBuilder {
  _ProfileGraphBuilder({required this.placementQuery, required this.profile})
    : _surfaceBuffer = placementQuery.surfaceIndex.createQueryBuffer(),
      _terrainBuffer = placementQuery.terrainIndex.createQueryBuffer();

  final TerrainPlacementQuery placementQuery;
  final TerrainSurfaceGraphBuildProfile profile;
  // Bound retained placement evidence even for unusually dense authored chunks.
  // Geometry, capsule dimensions and traversal rules are fixed for this builder.
  static const _placementCacheCapacity = 4096;
  final _placements =
      <(TerrainEdgeId, int, int, bool), TerrainPlacementResult>{};
  late final _leftCapsule = profile.capsuleForDirection(-1);
  late final _rightCapsule = profile.capsuleForDirection(1);
  late final _contactPolicy = TerrainContactPolicy(
    geometry: placementQuery.geometry,
    profile: profile.traversalProfile,
  );
  late final _standableRanges = <TerrainStandableCenterRange?>[
    for (final surface in surfaceSet.surfaces)
      placementQuery.standableCenterRange(
        surface: surface,
        capsule: _rightCapsule,
        traversalProfile: profile.traversalProfile,
        supportRequirement: profile.supportRequirement,
      ),
  ];
  late final _jumpSamples = [
    for (final sample in profile.jumpTemplate.samples)
      (
        tick: sample.tick,
        falling: sample.velY >= 0,
        reach: terrainPhysicsTickValueToInt(
          sample.maxDx * terrainPhysicsTicksPerWorldUnit,
          name: 'jumpSample.maxDx',
        ),
        prevY: terrainPhysicsTickValueToInt(
          sample.prevY * terrainPhysicsTicksPerWorldUnit,
          name: 'jumpSample.prevY',
        ),
        y: terrainPhysicsTickValueToInt(
          sample.y * terrainPhysicsTicksPerWorldUnit,
          name: 'jumpSample.y',
        ),
      ),
  ];

  TerrainPlacementCapsule _capsuleForDirection(int direction) =>
      direction < 0 ? _leftCapsule : _rightCapsule;

  // Standable capsule-center ranges depend on radius/support and terrain, not
  // the facing-dependent body offset. No cache survives this profile build.
  TerrainStandableCenterRange? _standableRange(
    TerrainNavigationSurface surface,
  ) => _standableRanges[surfaceSet.indexOfId(surface.id)!];

  final TerrainSurfaceQueryBuffer _surfaceBuffer;
  final TerrainQueryBuffer _terrainBuffer;
  final CapsuleSegmentKernel _kernel = CapsuleSegmentKernel();
  final CapsuleSweepHit _scratchHit = CapsuleSweepHit();
  final CapsuleSweepHit _bestHit = CapsuleSweepHit();
  final CapsuleSweepHit _bestSupportHit = CapsuleSweepHit();
  final TerrainContactDecision _scratchDecision = TerrainContactDecision();
  late final _landingController = TerrainCapsuleController(
    geometry: placementQuery.geometry,
    index: placementQuery.terrainIndex,
    profile: profile.traversalProfile,
  );
  final TerrainCapsuleMotionResult _landingMotion =
      TerrainCapsuleMotionResult();

  TerrainSurfaceSet get surfaceSet => placementQuery.surfaceIndex.surfaceSet;

  late TerrainSurfaceGraph _result;

  TerrainSurfaceGraph build() {
    for (final _ in _buildSteps()) {}
    return _result;
  }

  Future<TerrainSurfaceGraph> buildCooperatively() async {
    final slice = Stopwatch()..start();
    for (final _ in _buildSteps()) {
      if (slice.elapsedMicroseconds < 2000) continue;
      // An event-queue yield, not a microtask, lets browser frames and input run.
      await yieldCooperativeWork();
      slice.reset();
    }
    return _result;
  }

  Iterable<void> _buildSteps() sync* {
    final eligibility = <bool>[
      for (final surface in surfaceSet.surfaces)
        surface.isEligibleFor(profile.traversalProfile),
    ];
    final edgeOffsets = List<int>.filled(surfaceSet.surfaces.length + 1, 0);
    final edges = <TerrainSurfaceGraphEdge>[];
    final row = <TerrainSurfaceGraphEdge>[];

    for (
      var sourceIndex = 0;
      sourceIndex < surfaceSet.surfaces.length;
      sourceIndex += 1
    ) {
      yield null;
      edgeOffsets[sourceIndex] = edges.length;
      if (!eligibility[sourceIndex]) continue;
      final source = surfaceSet.surfaces[sourceIndex];
      row.clear();
      _addConnectedWalk(
        source: source,
        directionX: -1,
        adjacentId: source.previousId,
        profile: profile,
        eligibility: eligibility,
        row: row,
      );
      _addConnectedWalk(
        source: source,
        directionX: 1,
        adjacentId: source.nextId,
        profile: profile,
        eligibility: eligibility,
        row: row,
      );
      if (source.startIsLedge) {
        _addSmallTransitions(
          sourceIndex: sourceIndex,
          source: source,
          directionX: -1,
          profile: profile,
          eligibility: eligibility,
          row: row,
        );
      }
      if (source.endIsLedge) {
        _addSmallTransitions(
          sourceIndex: sourceIndex,
          source: source,
          directionX: 1,
          profile: profile,
          eligibility: eligibility,
          row: row,
        );
      }
      if (profile.canJump) {
        yield* _addJumpEdges(
          sourceIndex: sourceIndex,
          source: source,
          profile: profile,
          eligibility: eligibility,
          row: row,
        );
      }
      if (source.startIsLedge) {
        _addDropEdge(
          sourceIndex: sourceIndex,
          source: source,
          directionX: -1,
          profile: profile,
          eligibility: eligibility,
          row: row,
        );
      }
      if (source.endIsLedge) {
        _addDropEdge(
          sourceIndex: sourceIndex,
          source: source,
          directionX: 1,
          profile: profile,
          eligibility: eligibility,
          row: row,
        );
      }
      row.sort(
        (left, right) =>
            compareTerrainSurfaceGraphEdges(left, right, surfaceSet),
      );
      for (final edge in row) {
        if (edges.length > edgeOffsets[sourceIndex] &&
            compareTerrainSurfaceGraphEdges(edges.last, edge, surfaceSet) ==
                0) {
          continue;
        }
        edges.add(edge);
      }
    }
    edgeOffsets[surfaceSet.surfaces.length] = edges.length;

    _result = TerrainSurfaceGraph(
      surfaceSet: surfaceSet,
      buildProfile: profile,
      eligibility: eligibility,
      edgeOffsets: edgeOffsets,
      edges: edges,
    );
  }

  void _addConnectedWalk({
    required TerrainNavigationSurface source,
    required int directionX,
    required TerrainEdgeId? adjacentId,
    required TerrainSurfaceGraphBuildProfile profile,
    required List<bool> eligibility,
    required List<TerrainSurfaceGraphEdge> row,
  }) {
    if (adjacentId == null) return;
    final targetIndex = surfaceSet.indexOfId(adjacentId);
    if (targetIndex == null || !eligibility[targetIndex]) return;
    final target = surfaceSet.surfaces[targetIndex];
    final sourceEndpoint = directionX > 0 ? source.end : source.start;
    final targetEndpoint = directionX > 0 ? target.start : target.end;
    if (sourceEndpoint != targetEndpoint) {
      throw StateError('Reciprocal surface adjacency must share one endpoint.');
    }
    final edge = _validatedWalkEdge(
      targetIndex: targetIndex,
      source: source,
      target: target,
      sourceEndpoint: sourceEndpoint,
      targetEndpoint: targetEndpoint,
      directionX: directionX,
      isSmallTransition: false,
      profile: profile,
    );
    if (edge != null) row.add(edge);
  }

  void _addSmallTransitions({
    required int sourceIndex,
    required TerrainNavigationSurface source,
    required int directionX,
    required TerrainSurfaceGraphBuildProfile profile,
    required List<bool> eligibility,
    required List<TerrainSurfaceGraphEdge> row,
  }) {
    final sourceEndpoint = directionX > 0 ? source.end : source.start;
    placementQuery.surfaceIndex.queryBounds(
      minX: sourceEndpoint.xTicks - terrainContactEpsilonTicks,
      minY: sourceEndpoint.yTicks - profile.traversalProfile.stepHeightTicks,
      maxX: sourceEndpoint.xTicks + terrainContactEpsilonTicks,
      maxY: sourceEndpoint.yTicks + profile.traversalProfile.snapDistanceTicks,
      buffer: _surfaceBuffer,
    );
    for (
      var candidateIndex = 0;
      candidateIndex < _surfaceBuffer.candidateCount;
      candidateIndex += 1
    ) {
      final target = _surfaceBuffer.surfaceAt(
        candidateIndex,
        surfaceSet.surfaces,
      );
      final targetIndex = surfaceSet.indexOfId(target.id)!;
      if (targetIndex == sourceIndex || !eligibility[targetIndex]) continue;
      if ((directionX > 0 && !target.startIsLedge) ||
          (directionX < 0 && !target.endIsLedge)) {
        continue;
      }
      final targetEndpoint = directionX > 0 ? target.start : target.end;
      if ((targetEndpoint.xTicks - sourceEndpoint.xTicks).abs() >
          terrainContactEpsilonTicks) {
        continue;
      }
      final deltaY = targetEndpoint.yTicks - sourceEndpoint.yTicks;
      if (deltaY == 0) continue;
      if (deltaY < 0 && -deltaY > profile.traversalProfile.stepHeightTicks) {
        continue;
      }
      if (deltaY > 0 && deltaY > profile.traversalProfile.snapDistanceTicks) {
        continue;
      }
      final edge = _validatedWalkEdge(
        targetIndex: targetIndex,
        source: source,
        target: target,
        sourceEndpoint: sourceEndpoint,
        targetEndpoint: targetEndpoint,
        directionX: directionX,
        isSmallTransition: true,
        profile: profile,
      );
      if (edge != null) row.add(edge);
    }
  }

  TerrainSurfaceGraphEdge? _validatedWalkEdge({
    required int targetIndex,
    required TerrainNavigationSurface source,
    required TerrainNavigationSurface target,
    required TerrainPoint sourceEndpoint,
    required TerrainPoint targetEndpoint,
    required int directionX,
    required bool isSmallTransition,
    required TerrainSurfaceGraphBuildProfile profile,
  }) {
    final capsule = _capsuleForDirection(directionX);
    final sourceSupportX =
        sourceEndpoint.xTicks - directionX * profile.radiusTicks;
    final targetSupportX =
        targetEndpoint.xTicks + directionX * profile.radiusTicks;
    final sourcePlacement = _placeOnSurface(
      surface: source,
      desiredCapsuleXTicks: sourceSupportX,
      capsule: capsule,
      profile: profile,
    );
    if (!sourcePlacement.isValid) return null;
    final targetPlacement = _placeOnSurface(
      surface: target,
      desiredCapsuleXTicks: targetSupportX,
      capsule: capsule,
      profile: profile,
    );
    if (!targetPlacement.isValid) return null;

    if (isSmallTransition) {
      final sourceBody = sourcePlacement.bodyCenter!;
      final targetBody = targetPlacement.bodyCenter!;
      final raisedBodyY = sourceBody.yTicks < targetBody.yTicks
          ? sourceBody.yTicks
          : targetBody.yTicks;
      final midpointBodyX = _divideRoundNearest(
        sourceBody.xTicks + targetBody.xTicks,
        2,
      );
      final midpoint = placementQuery.validateClearance(
        TerrainClearancePlacementRequest(
          bodyCenter: TerrainPoint(midpointBodyX, raisedBodyY),
          capsule: capsule,
          traversalProfile: profile.traversalProfile,
          expectedGeometryVersion: surfaceSet.geometryVersion,
        ),
      );
      if (!midpoint.isValid) return null;
    }

    return TerrainSurfaceGraphEdge.walk(
      to: targetIndex,
      takeoffPoint: sourcePlacement.bodyCenter!,
      landingPoint: targetPlacement.bodyCenter!,
      commitDirectionX: directionX,
      distanceTicks: source.lengthTicks,
      locomotionSpeedTicksPerSecond: profile.locomotionSpeedTicksPerSecond,
      simulationTicksPerSecond: profile.simulationTicksPerSecond,
    );
  }

  TerrainPlacementResult _placeOnSurface({
    required TerrainNavigationSurface surface,
    required int desiredCapsuleXTicks,
    required TerrainPlacementCapsule capsule,
    required TerrainSurfaceGraphBuildProfile profile,
    bool allowSameSupportClamp = true,
  }) {
    final key = (
      surface.id,
      desiredCapsuleXTicks,
      capsule.resolvedOffsetXTicks,
      allowSameSupportClamp,
    );
    final cached = _placements[key];
    if (cached != null) return cached;
    final minimumY = surface.start.yTicks < surface.end.yTicks
        ? surface.start.yTicks
        : surface.end.yTicks;
    final maximumY = surface.start.yTicks > surface.end.yTicks
        ? surface.start.yTicks
        : surface.end.yTicks;
    final result = placementQuery.resolveGrounded(
      TerrainGroundPlacementRequest(
        desiredBodyCenterXTicks:
            desiredCapsuleXTicks - capsule.resolvedOffsetXTicks,
        minimumSupportYTicks: minimumY,
        maximumSupportYTicks: maximumY,
        capsule: capsule,
        traversalProfile: profile.traversalProfile,
        supportRequirement: profile.supportRequirement,
        intendedSupportEdgeId: surface.id,
        allowSameSupportClamp: allowSameSupportClamp,
        expectedGeometryVersion: surfaceSet.geometryVersion,
      ),
    );
    if (_placements.length == _placementCacheCapacity) _placements.clear();
    _placements[key] = result;
    return result;
  }

  Iterable<void> _addJumpEdges({
    required int sourceIndex,
    required TerrainNavigationSurface source,
    required TerrainSurfaceGraphBuildProfile profile,
    required List<bool> eligibility,
    required List<TerrainSurfaceGraphEdge> row,
  }) sync* {
    final sourceRange = _standableRange(source);
    if (sourceRange == null) return;

    final maxDxTicks = physicsCoordinateToTicks(
      profile.jumpTemplate.maxDx,
      name: 'jumpTemplate.maxDx',
    );
    if (maxDxTicks <= 0) return;
    final takeoffSamples = _takeoffSamples(
      sourceRange.minimumXTicks,
      sourceRange.maximumXTicks,
      maxDxTicks,
    );

    for (final takeoffCapsuleX in takeoffSamples) {
      for (final directionX in const <int>[-1, 1]) {
        final capsule = _capsuleForDirection(directionX);
        final sourcePlacement = _placeOnSurface(
          surface: source,
          desiredCapsuleXTicks: takeoffCapsuleX,
          capsule: capsule,
          profile: profile,
          allowSameSupportClamp: false,
        );
        if (!sourcePlacement.isValid) continue;
        final takeoffCenter = sourcePlacement.capsuleCenter!;
        final supportOffsetMax =
            profile.verticalHalfSegmentTicks +
            _divideCeil(
              profile.radiusTicks * terrainDirectionScale,
              profile.traversalProfile.minimumSupportUpComponent,
            );
        final minArcY = terrainPhysicsTickValueToInt(
          profile.jumpTemplate.minDy * terrainPhysicsTicksPerWorldUnit,
          name: 'jumpTemplate.minDy',
        );
        final maxArcY = terrainPhysicsTickValueToInt(
          profile.jumpTemplate.maxDy * terrainPhysicsTicksPerWorldUnit,
          name: 'jumpTemplate.maxDy',
        );
        placementQuery.surfaceIndex.queryBounds(
          minX: takeoffCenter.xTicks - maxDxTicks,
          minY:
              takeoffCenter.yTicks +
              minArcY +
              profile.verticalHalfSegmentTicks +
              profile.radiusTicks -
              terrainContactEpsilonTicks,
          maxX: takeoffCenter.xTicks + maxDxTicks,
          maxY:
              takeoffCenter.yTicks +
              maxArcY +
              supportOffsetMax +
              terrainContactEpsilonTicks,
          buffer: _surfaceBuffer,
        );
        final candidates = <int>[];
        for (
          var candidateIndex = 0;
          candidateIndex < _surfaceBuffer.candidateCount;
          candidateIndex += 1
        ) {
          final target = _surfaceBuffer.surfaceAt(
            candidateIndex,
            surfaceSet.surfaces,
          );
          candidates.add(surfaceSet.indexOfId(target.id)!);
        }

        for (final targetIndex in candidates) {
          yield null;
          if (targetIndex == sourceIndex || !eligibility[targetIndex]) {
            continue;
          }
          final target = surfaceSet.surfaces[targetIndex];
          if (_isOrdinaryContinuation(source, target)) continue;
          final targetRange = _standableRange(target);
          if (targetRange == null) continue;
          if (directionX > 0
              ? targetRange.maximumXTicks <= takeoffCenter.xTicks
              : targetRange.minimumXTicks >= takeoffCenter.xTicks) {
            continue;
          }
          final landings = _jumpLandingCandidates(
            takeoffCenter: takeoffCenter,
            directionX: directionX,
            target: target,
            targetRange: targetRange,
            capsule: capsule,
            profile: profile,
          );
          for (final landing in landings) {
            yield null;
            final contact = _sweepJumpTrajectory(
              sourceId: source.id,
              targetId: target.id,
              takeoffCenter: takeoffCenter,
              landingCenterX: landing.placement.capsuleCenter!.xTicks,
              landingTick: landing.tick,
              capsule: capsule,
            );
            if (contact == null || contact.supportId != target.id) continue;
            // Execution derives cruise speed from the published contact point
            // and tick count. That shortened trajectory must itself land;
            // validating only the original candidate can change a face landing
            // into a corner graze when the edge is consumed by locomotion.
            final executingLanding = _sweepJumpTrajectory(
              sourceId: source.id,
              targetId: target.id,
              takeoffCenter: takeoffCenter,
              landingCenterX: contact.capsuleCenterXTicks,
              landingTick: contact.tick,
              capsule: capsule,
            );
            if (executingLanding == null) continue;
            final exactLanding = _placeOnSurface(
              surface: target,
              desiredCapsuleXTicks: contact.capsuleCenterXTicks,
              capsule: capsule,
              profile: profile,
              allowSameSupportClamp: false,
            );
            if (!exactLanding.isValid) continue;
            row.add(
              TerrainSurfaceGraphEdge.airborne(
                to: targetIndex,
                kind: TerrainSurfaceEdgeKind.jump,
                takeoffPoint: sourcePlacement.bodyCenter!,
                landingPoint: exactLanding.bodyCenter!,
                commitDirectionX: directionX,
                travelTicks: contact.tick,
                simulationTicksPerSecond: profile.simulationTicksPerSecond,
              ),
            );
            break;
          }
        }
      }
    }
  }

  Iterable<_JumpLandingCandidate> _jumpLandingCandidates({
    required TerrainPoint takeoffCenter,
    required int directionX,
    required TerrainNavigationSurface target,
    required TerrainStandableCenterRange targetRange,
    required TerrainPlacementCapsule capsule,
    required TerrainSurfaceGraphBuildProfile profile,
  }) sync* {
    final supportOffset =
        profile.verticalHalfSegmentTicks +
        _divideCeil(
          profile.radiusTicks * terrainDirectionScale,
          -target.outwardNormal.yTicks,
        );
    // Samples are tick ordered. Sort only this tick's at most three landings;
    // the consumer stops after its first valid trajectory without constructing
    // placements for later ticks. This preserves the original global ordering.
    for (final sample in _jumpSamples) {
      if (!sample.falling) continue;
      final candidates = <_JumpLandingCandidate>[];
      final reach = sample.reach;
      var minimumX = targetRange.minimumXTicks;
      var maximumX = targetRange.maximumXTicks;
      if (directionX > 0) {
        minimumX = _maxInt(minimumX, takeoffCenter.xTicks + 1);
        maximumX = _minInt(maximumX, takeoffCenter.xTicks + reach);
      } else {
        minimumX = _maxInt(minimumX, takeoffCenter.xTicks - reach);
        maximumX = _minInt(maximumX, takeoffCenter.xTicks - 1);
      }
      if (minimumX > maximumX) continue;

      final previousY = takeoffCenter.yTicks + sample.prevY;
      final currentY = takeoffCenter.yTicks + sample.y;
      final verticalRange = _surfaceCenterXRangeForY(
        surface: target,
        supportOffsetTicks: supportOffset,
        minimumX: minimumX,
        maximumX: maximumX,
        minimumY: previousY - terrainContactEpsilonTicks,
        maximumY: currentY + terrainContactEpsilonTicks,
      );
      if (verticalRange == null) continue;
      for (final landingCenterX in _endpointMidpointSamples(
        verticalRange.$1,
        verticalRange.$2,
      )) {
        final placement = _placeOnSurface(
          surface: target,
          desiredCapsuleXTicks: landingCenterX,
          capsule: capsule,
          profile: profile,
          allowSameSupportClamp: false,
        );
        if (!placement.isValid) continue;
        final landingY = placement.capsuleCenter!.yTicks;
        if (landingY < previousY - terrainContactEpsilonTicks ||
            landingY > currentY + terrainContactEpsilonTicks) {
          continue;
        }
        candidates.add(
          _JumpLandingCandidate(tick: sample.tick, placement: placement),
        );
      }
      candidates.sort((left, right) {
        final tickOrder = left.tick.compareTo(right.tick);
        if (tickOrder != 0) return tickOrder;
        final verticalOrder = left.placement.supportPoint!.yTicks.compareTo(
          right.placement.supportPoint!.yTicks,
        );
        if (verticalOrder != 0) return verticalOrder;
        return left.placement.capsuleCenter!.xTicks.compareTo(
          right.placement.capsuleCenter!.xTicks,
        );
      });
      yield* _dedupeLandingCandidates(candidates);
    }
  }

  _TrajectoryLanding? _sweepJumpTrajectory({
    required TerrainEdgeId sourceId,
    required TerrainEdgeId targetId,
    required TerrainPoint takeoffCenter,
    required int landingCenterX,
    required int landingTick,
    required TerrainPlacementCapsule capsule,
  }) {
    var previousX = takeoffCenter.xTicks;
    var previousY = takeoffCenter.yTicks;
    final contactPolicy = _contactPolicy;
    for (var tick = 1; tick <= landingTick; tick += 1) {
      final sample = _jumpSamples[tick - 1];
      final currentX =
          takeoffCenter.xTicks +
          _divideRoundNearest(
            (landingCenterX - takeoffCenter.xTicks) * tick,
            landingTick,
          );
      final currentY = takeoffCenter.yTicks + sample.y;
      final contact = _firstBlockingContact(
        startCenterX: previousX,
        startCenterY: previousY,
        displacementX: currentX - previousX,
        displacementY: currentY - previousY,
        capsule: capsule,
        contactPolicy: contactPolicy,
      );
      if (contact != null) {
        if (contact.kind != TerrainContactKind.support ||
            contact.edgeId == sourceId ||
            contact.edgeId != targetId) {
          return null;
        }
        // A support sweep can merely graze a rounded corner and slide back
        // into the air. Admit a landing only when the production controller
        // finishes this contact tick grounded on the intended finite surface.
        _landingController.moveAtValues(
          centerXTicks: previousX,
          centerYTicks: previousY,
          radiusTicks: capsule.radiusTicks,
          verticalHalfSegmentTicks: capsule.verticalHalfSegmentTicks,
          displacementXTicks: currentX - previousX,
          displacementYTicks: currentY - previousY,
          mode: TerrainMotionMode.worldSpace,
          beganGrounded: false,
          out: _landingMotion,
        );
        if (!_landingMotion.grounded ||
            _landingMotion.supportEdgeId != targetId) {
          return null;
        }
        final leavingCorner =
            (_bestSupportHit.feature == TerrainSegmentFeature.endEndpoint &&
                landingCenterX > takeoffCenter.xTicks) ||
            (_bestSupportHit.feature == TerrainSegmentFeature.startEndpoint &&
                landingCenterX < takeoffCenter.xTicks);
        if (leavingCorner &&
            !_cornerLandingSurvivesSupportSkin(
              sourceId: sourceId,
              targetId: targetId,
              previousX: previousX,
              previousY: previousY,
              displacementX: currentX - previousX,
              tick: tick,
              capsule: capsule,
            )) {
          return null;
        }
        return _TrajectoryLanding(
          supportId: contact.edgeId,
          tick: tick,
          capsuleCenterXTicks: contact.capsuleCenterXTicks,
        );
      }
      previousX = currentX;
      previousY = currentY;
    }
    return null;
  }

  bool _cornerLandingSurvivesSupportSkin({
    required TerrainEdgeId sourceId,
    required TerrainEdgeId targetId,
    required int previousX,
    required int previousY,
    required int displacementX,
    required int tick,
    required TerrainPlacementCapsule capsule,
  }) {
    // Placement describes a geometric tangent; grounded motion retains skin.
    // At a rounded tip that small height difference can delay contact until
    // the actor has passed the foothold. Probe the contact tick and its next
    // ballistic tick without snap or recovery, keeping the published cruise.
    final source = surfaceSet.surfaceById(sourceId)!;
    final target = surfaceSet.surfaceById(targetId)!;
    var x = previousX;
    var y =
        previousY -
        _divideCeil(
          terrainCollisionSkinTicks * terrainDirectionScale,
          -source.outwardNormal.yTicks,
        );
    for (
      var landingTick = tick;
      landingTick <= tick + 1 && landingTick <= _jumpSamples.length;
      landingTick += 1
    ) {
      final sample = _jumpSamples[landingTick - 1];
      _landingController.moveAtValues(
        centerXTicks: x,
        centerYTicks: y,
        radiusTicks: capsule.radiusTicks,
        verticalHalfSegmentTicks: capsule.verticalHalfSegmentTicks,
        displacementXTicks: displacementX,
        displacementYTicks: sample.y - sample.prevY,
        mode: TerrainMotionMode.worldSpace,
        beganGrounded: false,
        out: _landingMotion,
      );
      if (_landingMotion.usedRecovery) return false;
      if (_landingMotion.grounded) {
        final support = _landingMotion.supportEdgeId;
        // A shared vertex may resolve to either adjoining walkable face.
        return support == targetId ||
            support == target.previousId ||
            support == target.nextId;
      }
      if (_landingMotion.contactCount > 0) return false;
      x = _landingMotion.finalCenterXTicks;
      y = _landingMotion.finalCenterYTicks;
    }
    return false;
  }

  void _addDropEdge({
    required int sourceIndex,
    required TerrainNavigationSurface source,
    required int directionX,
    required TerrainSurfaceGraphBuildProfile profile,
    required List<bool> eligibility,
    required List<TerrainSurfaceGraphEdge> row,
  }) {
    final capsule = _capsuleForDirection(directionX);
    final range = _standableRange(source);
    if (range == null) return;
    final supportedX = directionX > 0
        ? range.maximumXTicks
        : range.minimumXTicks;
    final sourcePlacement = _placeOnSurface(
      surface: source,
      desiredCapsuleXTicks: supportedX,
      capsule: capsule,
      profile: profile,
      allowSameSupportClamp: false,
    );
    if (!sourcePlacement.isValid) return;

    final airborneCenter = sourcePlacement.capsuleCenter!.translated(
      directionX * terrainContactEpsilonTicks,
      0,
    );
    final landing = _sweepDropTrajectory(
      sourceId: source.id,
      takeoffCenter: airborneCenter,
      directionX: directionX,
      capsule: capsule,
      profile: profile,
    );
    if (landing == null) return;
    final targetIndex = surfaceSet.indexOfId(landing.supportId);
    if (targetIndex == null ||
        targetIndex == sourceIndex ||
        !eligibility[targetIndex]) {
      return;
    }
    final target = surfaceSet.surfaces[targetIndex];
    final targetPlacement = _placeOnSurface(
      surface: target,
      desiredCapsuleXTicks: landing.capsuleCenterXTicks,
      capsule: capsule,
      profile: profile,
      allowSameSupportClamp: false,
    );
    if (!targetPlacement.isValid) return;
    row.add(
      TerrainSurfaceGraphEdge.airborne(
        to: targetIndex,
        kind: TerrainSurfaceEdgeKind.drop,
        takeoffPoint: airborneCenter.translated(
          -capsule.resolvedOffsetXTicks,
          -capsule.offsetYTicks,
        ),
        landingPoint: targetPlacement.bodyCenter!,
        commitDirectionX: directionX,
        travelTicks: landing.tick,
        simulationTicksPerSecond: profile.simulationTicksPerSecond,
      ),
    );
  }

  _TrajectoryLanding? _sweepDropTrajectory({
    required TerrainEdgeId sourceId,
    required TerrainPoint takeoffCenter,
    required int directionX,
    required TerrainPlacementCapsule capsule,
    required TerrainSurfaceGraphBuildProfile profile,
  }) {
    final jumpProfile = profile.jumpTemplate.profile;
    var offsetY = 0.0;
    var velocityY = 0.0;
    var previousX = takeoffCenter.xTicks;
    var previousY = takeoffCenter.yTicks;
    final contactPolicy = _contactPolicy;
    for (var tick = 1; tick <= jumpProfile.maxAirTicks; tick += 1) {
      velocityY += jumpProfile.gravityY * jumpProfile.dtSeconds;
      offsetY += velocityY * jumpProfile.dtSeconds;
      final currentX =
          takeoffCenter.xTicks +
          directionX *
              terrainPhysicsTickValueToInt(
                jumpProfile.airSpeedX *
                    jumpProfile.dtSeconds *
                    tick *
                    terrainPhysicsTicksPerWorldUnit,
                name: 'dropOffsetX',
              );
      final currentY =
          takeoffCenter.yTicks +
          terrainPhysicsTickValueToInt(
            offsetY * terrainPhysicsTicksPerWorldUnit,
            name: 'dropOffsetY',
          );
      final contact = _firstBlockingContact(
        startCenterX: previousX,
        startCenterY: previousY,
        displacementX: currentX - previousX,
        displacementY: currentY - previousY,
        capsule: capsule,
        contactPolicy: contactPolicy,
        ignoredEdgeId: sourceId,
      );
      if (contact != null) {
        if (contact.kind != TerrainContactKind.support) return null;
        return _TrajectoryLanding(
          supportId: contact.edgeId,
          tick: tick,
          capsuleCenterXTicks: contact.capsuleCenterXTicks,
        );
      }
      previousX = currentX;
      previousY = currentY;
    }
    return null;
  }

  _TrajectoryContact? _firstBlockingContact({
    required int startCenterX,
    required int startCenterY,
    required int displacementX,
    required int displacementY,
    required TerrainPlacementCapsule capsule,
    required TerrainContactPolicy contactPolicy,
    TerrainEdgeId? ignoredEdgeId,
  }) {
    if (displacementX == 0 && displacementY == 0) return null;
    final endCenterX = startCenterX + displacementX;
    final endCenterY = startCenterY + displacementY;
    final halfHeight = capsule.radiusTicks + capsule.verticalHalfSegmentTicks;
    final expansion = terrainCollisionSkinTicks + terrainContactEpsilonTicks;
    placementQuery.terrainIndex.queryBounds(
      minX: _minInt(startCenterX, endCenterX) - capsule.radiusTicks - expansion,
      minY: _minInt(startCenterY, endCenterY) - halfHeight - expansion,
      maxX: _maxInt(startCenterX, endCenterX) + capsule.radiusTicks + expansion,
      maxY: _maxInt(startCenterY, endCenterY) + halfHeight + expansion,
      buffer: _terrainBuffer,
    );
    _bestHit.reset();
    TerrainEdge? bestEdge;
    for (
      var candidateIndex = 0;
      candidateIndex < _terrainBuffer.candidateCount;
      candidateIndex += 1
    ) {
      final edge = _terrainBuffer.edgeAt(
        candidateIndex,
        placementQuery.terrainIndex.edges,
      );
      if (edge.id == ignoredEdgeId) continue;
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
      contactPolicy.classifySweepAtCenter(
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
      if (!_scratchDecision.blocks ||
          _scratchDecision.constraintEdgeId == ignoredEdgeId) {
        continue;
      }
      if (bestEdge == null || _kernel.compareHits(_scratchHit, _bestHit) < 0) {
        bestEdge = edge;
        _bestHit.copyFrom(_scratchHit);
      }
    }
    if (bestEdge == null) return null;

    var hasNonSupportConstraint = false;
    TerrainEdgeId? supportId;
    var supportPointY = 0;
    _bestSupportHit.reset();
    for (
      var candidateIndex = 0;
      candidateIndex < _terrainBuffer.candidateCount;
      candidateIndex += 1
    ) {
      final edge = _terrainBuffer.edgeAt(
        candidateIndex,
        placementQuery.terrainIndex.edges,
      );
      if (edge.id == ignoredEdgeId) continue;
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
      if (!_scratchHit.hit ||
          !_kernel.hitsHaveEqualTime(_scratchHit, _bestHit)) {
        continue;
      }
      contactPolicy.classifySweepAtCenter(
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
      if (!_scratchDecision.blocks ||
          _scratchDecision.constraintEdgeId == ignoredEdgeId) {
        continue;
      }
      if (_scratchDecision.kind != TerrainContactKind.support) {
        hasNonSupportConstraint = true;
        continue;
      }
      final constraintId = _scratchDecision.constraintEdgeId ?? edge.id;
      if (supportId == null ||
          _scratchHit.pointYTicks < supportPointY ||
          (_scratchHit.pointYTicks == supportPointY &&
              constraintId.compareTo(supportId) < 0)) {
        supportId = constraintId;
        supportPointY = _scratchHit.pointYTicks;
        _bestSupportHit.copyFrom(_scratchHit);
      }
    }
    if (hasNonSupportConstraint || supportId == null) {
      return _TrajectoryContact(
        kind: TerrainContactKind.wall,
        edgeId: bestEdge.id,
        capsuleCenterXTicks: terrainPhysicsTickValueToInt(
          startCenterX + displacementX * _bestHit.timeOfImpact,
          name: 'impactCenterX',
        ),
      );
    }
    return _TrajectoryContact(
      kind: TerrainContactKind.support,
      edgeId: supportId,
      capsuleCenterXTicks: terrainPhysicsTickValueToInt(
        startCenterX + displacementX * _bestSupportHit.timeOfImpact,
        name: 'impactCenterX',
      ),
    );
  }

  bool _isOrdinaryContinuation(
    TerrainNavigationSurface source,
    TerrainNavigationSurface target,
  ) {
    if (source.previousId == target.id || source.nextId == target.id) {
      return true;
    }
    if (source.dyTicks != 0 || target.dyTicks != 0) return false;
    if (source.start.yTicks != target.start.yTicks) return false;
    return target.xMinTicks <= source.xMaxTicks + terrainContactEpsilonTicks &&
        target.xMaxTicks >= source.xMinTicks - terrainContactEpsilonTicks;
  }

  (int, int)? _surfaceCenterXRangeForY({
    required TerrainNavigationSurface surface,
    required int supportOffsetTicks,
    required int minimumX,
    required int maximumX,
    required int minimumY,
    required int maximumY,
  }) {
    int centerY(int x) => surface.yAtXTicks(x) - supportOffsetTicks;
    if (surface.dyTicks == 0) {
      final y = centerY(minimumX);
      return y >= minimumY && y <= maximumY ? (minimumX, maximumX) : null;
    }
    late final int low;
    late final int high;
    if (surface.dyTicks > 0) {
      final first = _firstTrue(
        minimumX,
        maximumX,
        (x) => centerY(x) >= minimumY,
      );
      final last = _lastTrue(minimumX, maximumX, (x) => centerY(x) <= maximumY);
      if (first == null || last == null) return null;
      low = first;
      high = last;
    } else {
      final first = _firstTrue(
        minimumX,
        maximumX,
        (x) => centerY(x) <= maximumY,
      );
      final last = _lastTrue(minimumX, maximumX, (x) => centerY(x) >= minimumY);
      if (first == null || last == null) return null;
      low = first;
      high = last;
    }
    return low <= high ? (low, high) : null;
  }
}

class _JumpLandingCandidate {
  const _JumpLandingCandidate({required this.tick, required this.placement});

  final int tick;
  final TerrainPlacementResult placement;
}

class _TrajectoryLanding {
  const _TrajectoryLanding({
    required this.supportId,
    required this.tick,
    required this.capsuleCenterXTicks,
  });

  final TerrainEdgeId supportId;
  final int tick;
  final int capsuleCenterXTicks;
}

class _TrajectoryContact {
  const _TrajectoryContact({
    required this.kind,
    required this.edgeId,
    required this.capsuleCenterXTicks,
  });

  final TerrainContactKind kind;
  final TerrainEdgeId edgeId;
  final int capsuleCenterXTicks;
}

List<int> _takeoffSamples(int minimumX, int maximumX, int maxDxTicks) {
  if (maximumX <= minimumX) return <int>[minimumX];
  // Authored props can leave only one tile of clearance for a takeoff.
  final maxStep = 16 * terrainPhysicsTicksPerWorldUnit;
  final step = _minInt(maxDxTicks, maxStep);
  if (step <= 0 || maximumX - minimumX <= step) {
    return _dedupeInts(<int>[
      minimumX,
      _divideRoundNearest(minimumX + maximumX, 2),
      maximumX,
    ]);
  }
  final samples = <int>[];
  for (var x = minimumX; x <= maximumX; x += step) {
    samples.add(x);
  }
  if (samples.last != maximumX) samples.add(maximumX);
  return _dedupeInts(samples);
}

List<int> _endpointMidpointSamples(int minimumX, int maximumX) => _dedupeInts(
  <int>[minimumX, _divideRoundNearest(minimumX + maximumX, 2), maximumX],
);

List<int> _dedupeInts(List<int> values) {
  values.sort();
  final result = <int>[];
  for (final value in values) {
    if (result.isEmpty || result.last != value) result.add(value);
  }
  return result;
}

List<_JumpLandingCandidate> _dedupeLandingCandidates(
  List<_JumpLandingCandidate> candidates,
) {
  final result = <_JumpLandingCandidate>[];
  for (final candidate in candidates) {
    if (result.isNotEmpty &&
        result.last.tick == candidate.tick &&
        result.last.placement.capsuleCenter ==
            candidate.placement.capsuleCenter) {
      continue;
    }
    result.add(candidate);
  }
  return result;
}

int? _firstTrue(int minimum, int maximum, bool Function(int) predicate) {
  if (!predicate(maximum)) return null;
  var low = minimum;
  var high = maximum;
  while (low < high) {
    final middle = low + ((high - low) >> 1);
    if (predicate(middle)) {
      high = middle;
    } else {
      low = middle + 1;
    }
  }
  return low;
}

int? _lastTrue(int minimum, int maximum, bool Function(int) predicate) {
  if (!predicate(minimum)) return null;
  var low = minimum;
  var high = maximum;
  while (low < high) {
    final middle = low + ((high - low + 1) >> 1);
    if (predicate(middle)) {
      low = middle;
    } else {
      high = middle - 1;
    }
  }
  return low;
}

int _minInt(int left, int right) => left < right ? left : right;

int _maxInt(int left, int right) => left > right ? left : right;

int _divideCeil(int numerator, int positiveDenominator) =>
    (numerator + positiveDenominator - 1) ~/ positiveDenominator;

int _divideRoundNearest(int numerator, int positiveDenominator) {
  if (numerator >= 0) {
    return (numerator + positiveDenominator ~/ 2) ~/ positiveDenominator;
  }
  return -((-numerator + positiveDenominator ~/ 2) ~/ positiveDenominator);
}
