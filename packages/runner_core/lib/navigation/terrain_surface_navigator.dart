import '../collision/terrain/terrain_edge_id.dart';
import '../collision/terrain/terrain_numeric.dart';
import '../collision/terrain/terrain_traversal_profile.dart';
import 'terrain_placement_query.dart';
import 'terrain_surface_pathfinder.dart';
import 'types/terrain_surface_graph.dart';

/// Prior-tick actor evidence consumed by [TerrainSurfaceNavigator].
///
/// The snapshot is actor-neutral so enemies and their player target use the
/// same exact support-validation path. Body and capsule values are expressed
/// in authoritative physics ticks.
class TerrainSurfaceNavigationActorSnapshot {
  const TerrainSurfaceNavigationActorSnapshot({
    required this.bodyCenter,
    required this.capsule,
    required this.traversalProfile,
    required this.supportRequirement,
    required this.grounded,
    this.priorSupportEdgeId,
    this.priorSupportGeometryVersion = -1,
  });

  /// Authoritative body center in physics ticks.
  final TerrainPoint bodyCenter;

  /// Direction-resolved upright capsule used for support and fallback bounds.
  final TerrainPlacementCapsule capsule;

  /// Actor-owned contact policy used when retained support needs validation.
  final TerrainTraversalProfile traversalProfile;

  /// Actor-owned foothold rule used by support lookup and safe fallback.
  final TerrainSupportRequirement supportRequirement;

  /// Whether the preceding tick ended on validated support.
  final bool grounded;

  /// Support validated at the end of the preceding simulation tick.
  final TerrainEdgeId? priorSupportEdgeId;

  /// Geometry version that owns [priorSupportEdgeId].
  final int priorSupportGeometryVersion;
}

/// Version-local runtime state for one terrain-graph navigation agent.
///
/// Surface IDs are persistent geometry identities. Cached indices and global
/// edge indices are valid only while [bundleVersion] matches the published
/// runtime bundle and are cleared together on every version change.
class TerrainSurfaceNavigatorState {
  /// Published runtime-bundle version owning every cached index below.
  int bundleVersion = -1;

  /// Prior-tick entity support identity, or `null` while airborne/unresolved.
  TerrainEdgeId? currentSurfaceId;

  /// Version-local index matching [currentSurfaceId].
  int currentSurfaceIndex = -1;

  /// Most recent validated eligible support used by safe fallback.
  TerrainEdgeId? lastGroundSurfaceId;

  /// Version-local index matching [lastGroundSurfaceId].
  int lastGroundSurfaceIndex = -1;

  /// Retained grounded target support identity.
  TerrainEdgeId? targetSurfaceId;

  /// Version-local index matching [targetSurfaceId].
  int targetSurfaceIndex = -1;

  /// Remaining fixed ticks before a periodic path refresh is eligible.
  int repathTicksLeft = 0;

  /// Reused global graph-edge indices in traversal order.
  final List<int> pathEdges = <int>[];

  /// Next entry in [pathEdges] to approach or execute.
  int pathCursor = 0;

  /// Committed global edge index, or `-1` before takeoff/after landing.
  int activeEdgeIndex = -1;

  /// Clears every support and graph-index cache before a new bundle is read.
  void invalidateForBundle(int nextBundleVersion) {
    if (nextBundleVersion < 0) {
      throw ArgumentError.value(
        nextBundleVersion,
        'nextBundleVersion',
        'Must be non-negative.',
      );
    }
    bundleVersion = nextBundleVersion;
    currentSurfaceId = null;
    currentSurfaceIndex = -1;
    lastGroundSurfaceId = null;
    lastGroundSurfaceIndex = -1;
    targetSurfaceId = null;
    targetSurfaceIndex = -1;
    repathTicksLeft = 0;
    pathEdges.clear();
    pathCursor = 0;
    activeEdgeIndex = -1;
  }
}

/// Integer movement request emitted by [TerrainSurfaceNavigator].
class TerrainSurfaceNavIntent {
  const TerrainSurfaceNavIntent({
    required this.desiredBodyXTicks,
    required this.jumpNow,
    required this.hasPlan,
    this.commitDirectionX = 0,
    this.hasSafeBodyRange = false,
    this.safeMinimumBodyXTicks = 0,
    this.safeMaximumBodyXTicks = 0,
  }) : assert(
         !hasSafeBodyRange || safeMinimumBodyXTicks <= safeMaximumBodyXTicks,
       );

  /// World-X body target in authoritative physics ticks.
  final int desiredBodyXTicks;

  /// One-tick request to start the graph edge's jump.
  final bool jumpNow;

  /// Whether a direct walk chain or graph path currently exists.
  final bool hasPlan;

  /// Stable horizontal commitment while approaching or traversing an edge.
  final int commitDirectionX;

  /// Whether no-plan fallback resolved a finite standable body-center range.
  final bool hasSafeBodyRange;

  /// Inclusive safe body-center bounds for no-plan locomotion.
  final int safeMinimumBodyXTicks;
  final int safeMaximumBodyXTicks;
}

/// Deterministic runtime controller for polygon-terrain surface graphs.
///
/// Terrain world-motion authority selects this controller through the ECS
/// navigation adapter. Normal streamed production levels use it with the
/// graph views published in their current runtime bundle.
class TerrainSurfaceNavigator {
  TerrainSurfaceNavigator({
    required this.pathfinder,
    this.repathCooldownTicks = 12,
    this.takeoffToleranceTicks = 4 * terrainPhysicsTicksPerWorldUnit,
  }) {
    if (repathCooldownTicks < 0 || takeoffToleranceTicks < 0) {
      throw ArgumentError(
        'Navigation cooldown and takeoff tolerance must be non-negative.',
      );
    }
  }

  /// Reusable deterministic A* authority.
  final TerrainSurfacePathfinder pathfinder;

  /// Fixed-tick delay between unchanged-surface path refreshes.
  final int repathCooldownTicks;

  /// Inclusive world-X takeoff tolerance in physics ticks.
  final int takeoffToleranceTicks;

  /// Shared placement lookups made by this navigator, exposed for diagnostics.
  int placementQueryCount = 0;

  /// A* requests made by this navigator, including preferred-direction retry.
  int pathQueryCount = 0;

  /// Updates one agent from prior-tick support evidence.
  ///
  /// [bundleVersion] owns all indices in [state]. A mismatch clears the state
  /// before lock handling. Navigation/stun locks then hold it unchanged; a
  /// movement lock permits support/path observation but suppresses motion and
  /// cannot activate a pending edge.
  TerrainSurfaceNavIntent update({
    required TerrainSurfaceNavigatorState state,
    required TerrainSurfaceGraph graph,
    required TerrainPlacementQuery placementQuery,
    required int bundleVersion,
    required TerrainSurfaceNavigationActorSnapshot entity,
    required TerrainSurfaceNavigationActorSnapshot target,
    bool navigationLocked = false,
    bool movementLocked = false,
    bool stunLocked = false,
  }) {
    if (bundleVersion < 0) {
      throw ArgumentError.value(
        bundleVersion,
        'bundleVersion',
        'Must be non-negative.',
      );
    }
    if (placementQuery.geometry.version != graph.geometryVersion ||
        !identical(placementQuery.surfaceIndex.surfaceSet, graph.surfaceSet)) {
      throw ArgumentError(
        'Navigator graph and placement query must share one terrain bundle.',
      );
    }

    // Bundle invalidation is deliberately first: AI locks may not preserve
    // stale version-local indices, paths, or support identities.
    if (state.bundleVersion != bundleVersion) {
      state.invalidateForBundle(bundleVersion);
    }

    if (navigationLocked || stunLocked) {
      return _applyMovementLock(
        TerrainSurfaceNavIntent(
          desiredBodyXTicks: entity.bodyCenter.xTicks,
          jumpNow: false,
          hasPlan: false,
        ),
        entity.bodyCenter.xTicks,
        movementLocked,
      );
    }

    final previousCurrentId = state.currentSurfaceId;
    final previousTargetId = state.targetSurfaceId;

    final current = entity.grounded
        ? _resolveSupport(graph, placementQuery, entity)
        : null;
    _setCurrentSurface(state, current);
    if (current != null) {
      state.lastGroundSurfaceId = current.id;
      state.lastGroundSurfaceIndex = current.index;
    }

    final resolvedTarget = target.grounded
        ? _resolveSupport(graph, placementQuery, target)
        : null;
    if (target.grounded) {
      _setTargetSurface(state, resolvedTarget);
    } else {
      _validateRetainedTarget(state, graph);
    }

    if (state.repathTicksLeft > 0) state.repathTicksLeft -= 1;
    final surfaceChanged =
        previousCurrentId != state.currentSurfaceId ||
        previousTargetId != state.targetSurfaceId;
    if (surfaceChanged && state.activeEdgeIndex < 0) {
      state.repathTicksLeft = 0;
      state.pathEdges.clear();
      state.pathCursor = 0;
    }

    final navigableTargetBodyX = state.targetSurfaceIndex >= 0
        ? _clampBodyXToSurface(
            graph: graph,
            placementQuery: placementQuery,
            surfaceIndex: state.targetSurfaceIndex,
            actor: entity,
            desiredBodyXTicks: target.bodyCenter.xTicks,
          )
        : null;

    final executing = _executeActiveEdge(
      state: state,
      graph: graph,
      entity: entity,
      targetBodyXTicks: navigableTargetBodyX ?? entity.bodyCenter.xTicks,
    );
    if (executing != null) {
      return _applyMovementLock(
        executing,
        entity.bodyCenter.xTicks,
        movementLocked,
      );
    }

    if (entity.grounded &&
        state.currentSurfaceIndex >= 0 &&
        state.targetSurfaceIndex >= 0 &&
        navigableTargetBodyX != null &&
        _hasDirectWalkChain(
          graph,
          state.currentSurfaceIndex,
          state.targetSurfaceIndex,
        )) {
      state.pathEdges.clear();
      state.pathCursor = 0;
      state.activeEdgeIndex = -1;
      return _applyMovementLock(
        TerrainSurfaceNavIntent(
          desiredBodyXTicks: navigableTargetBodyX,
          jumpNow: false,
          hasPlan: true,
        ),
        entity.bodyCenter.xTicks,
        movementLocked,
      );
    }

    if (entity.grounded &&
        state.currentSurfaceIndex >= 0 &&
        state.targetSurfaceIndex >= 0 &&
        navigableTargetBodyX != null &&
        state.repathTicksLeft == 0) {
      _repath(
        state: state,
        graph: graph,
        entityBodyXTicks: entity.bodyCenter.xTicks,
        targetBodyXTicks: navigableTargetBodyX,
      );
    }

    if (state.pathCursor >= state.pathEdges.length) {
      state.activeEdgeIndex = -1;
      return _applyMovementLock(
        _safeFallback(
          state: state,
          graph: graph,
          placementQuery: placementQuery,
          entity: entity,
          targetBodyXTicks: target.bodyCenter.xTicks,
        ),
        entity.bodyCenter.xTicks,
        movementLocked,
      );
    }

    final edgeIndex = state.pathEdges[state.pathCursor];
    if (!_edgeIndexIsValidForSource(state, graph, edgeIndex)) {
      _clearPath(state);
      return _applyMovementLock(
        _safeFallback(
          state: state,
          graph: graph,
          placementQuery: placementQuery,
          entity: entity,
          targetBodyXTicks: target.bodyCenter.xTicks,
        ),
        entity.bodyCenter.xTicks,
        movementLocked,
      );
    }
    final edge = graph.edges[edgeIndex];
    // A move lock may observe support and refresh a plan, but it cannot
    // consume a takeoff. A suppressed one-shot jump must remain available
    // when the lock expires.
    if (movementLocked) {
      return TerrainSurfaceNavIntent(
        desiredBodyXTicks: entity.bodyCenter.xTicks,
        jumpNow: false,
        hasPlan: true,
      );
    }
    if (entity.grounded && _reachedTakeoff(entity.bodyCenter.xTicks, edge)) {
      state.activeEdgeIndex = edgeIndex;
      return _applyMovementLock(
        TerrainSurfaceNavIntent(
          desiredBodyXTicks: edge.kind == TerrainSurfaceEdgeKind.drop
              ? edge.takeoffPoint.xTicks
              : edge.landingPoint.xTicks,
          jumpNow: edge.kind == TerrainSurfaceEdgeKind.jump,
          hasPlan: true,
          commitDirectionX: edge.commitDirectionX,
        ),
        entity.bodyCenter.xTicks,
        movementLocked,
      );
    }

    return _applyMovementLock(
      TerrainSurfaceNavIntent(
        desiredBodyXTicks: edge.takeoffPoint.xTicks,
        jumpNow: false,
        hasPlan: true,
        commitDirectionX: edge.commitDirectionX,
      ),
      entity.bodyCenter.xTicks,
      movementLocked,
    );
  }

  _ResolvedSurface? _resolveSupport(
    TerrainSurfaceGraph graph,
    TerrainPlacementQuery placementQuery,
    TerrainSurfaceNavigationActorSnapshot actor,
  ) {
    final retainedId = actor.priorSupportEdgeId;
    if (retainedId != null &&
        actor.priorSupportGeometryVersion == graph.geometryVersion) {
      final retainedIndex = graph.indexOfSurfaceId(retainedId);
      if (retainedIndex != null && graph.eligibility[retainedIndex]) {
        return _ResolvedSurface(retainedId, retainedIndex);
      }
    }

    placementQueryCount += 1;
    final capsuleCenterY = actor.bodyCenter.yTicks + actor.capsule.offsetYTicks;
    final minimumSupportY =
        capsuleCenterY +
        actor.capsule.verticalHalfSegmentTicks +
        actor.capsule.radiusTicks -
        terrainContactEpsilonTicks;
    final maximumRadiusOffset = _divideCeil(
      actor.capsule.radiusTicks * terrainDirectionScale,
      actor.traversalProfile.minimumSupportUpComponent,
    );
    final result = placementQuery.resolveGrounded(
      TerrainGroundPlacementRequest(
        desiredBodyCenterXTicks: actor.bodyCenter.xTicks,
        minimumSupportYTicks: minimumSupportY,
        maximumSupportYTicks:
            capsuleCenterY +
            actor.capsule.verticalHalfSegmentTicks +
            maximumRadiusOffset +
            terrainContactEpsilonTicks,
        capsule: actor.capsule,
        traversalProfile: actor.traversalProfile,
        supportRequirement: actor.supportRequirement,
        expectedGeometryVersion: graph.geometryVersion,
      ),
    );
    final resolvedId = result.isValid ? result.supportEdgeId : null;
    if (resolvedId == null) return null;
    final resolvedIndex = graph.indexOfSurfaceId(resolvedId);
    if (resolvedIndex == null || !graph.eligibility[resolvedIndex]) return null;
    return _ResolvedSurface(resolvedId, resolvedIndex);
  }

  void _setCurrentSurface(
    TerrainSurfaceNavigatorState state,
    _ResolvedSurface? resolved,
  ) {
    state.currentSurfaceId = resolved?.id;
    state.currentSurfaceIndex = resolved?.index ?? -1;
  }

  void _setTargetSurface(
    TerrainSurfaceNavigatorState state,
    _ResolvedSurface? resolved,
  ) {
    state.targetSurfaceId = resolved?.id;
    state.targetSurfaceIndex = resolved?.index ?? -1;
  }

  void _validateRetainedTarget(
    TerrainSurfaceNavigatorState state,
    TerrainSurfaceGraph graph,
  ) {
    final id = state.targetSurfaceId;
    if (id == null) {
      state.targetSurfaceIndex = -1;
      return;
    }
    final index = graph.indexOfSurfaceId(id);
    if (index == null || !graph.eligibility[index]) {
      state.targetSurfaceId = null;
      state.targetSurfaceIndex = -1;
      return;
    }
    state.targetSurfaceIndex = index;
  }

  TerrainSurfaceNavIntent? _executeActiveEdge({
    required TerrainSurfaceNavigatorState state,
    required TerrainSurfaceGraph graph,
    required TerrainSurfaceNavigationActorSnapshot entity,
    required int targetBodyXTicks,
  }) {
    final activeEdgeIndex = state.activeEdgeIndex;
    if (activeEdgeIndex < 0) return null;
    if (state.pathCursor >= state.pathEdges.length ||
        state.pathEdges[state.pathCursor] != activeEdgeIndex ||
        activeEdgeIndex >= graph.edges.length) {
      _clearPath(state);
      return null;
    }
    final edge = graph.edges[activeEdgeIndex];
    final destinationId = graph.surfaces[edge.to].id;
    if (entity.grounded && state.currentSurfaceId == destinationId) {
      state.activeEdgeIndex = -1;
      state.pathCursor += 1;
      return TerrainSurfaceNavIntent(
        desiredBodyXTicks: targetBodyXTicks,
        jumpNow: false,
        hasPlan: true,
      );
    }

    return TerrainSurfaceNavIntent(
      desiredBodyXTicks:
          edge.kind == TerrainSurfaceEdgeKind.drop && entity.grounded
          ? edge.takeoffPoint.xTicks
          : edge.landingPoint.xTicks,
      jumpNow: false,
      hasPlan: true,
      commitDirectionX: edge.commitDirectionX,
    );
  }

  bool _hasDirectWalkChain(
    TerrainSurfaceGraph graph,
    int startIndex,
    int goalIndex,
  ) {
    if (startIndex == goalIndex) return true;
    final start = graph.surfaces[startIndex];
    final goal = graph.surfaces[goalIndex];
    if (start.chainId != goal.chainId) return false;

    final direction = goal.xMinTicks >= start.xMinTicks ? 1 : -1;
    var currentIndex = startIndex;
    for (var traversed = 0; traversed < graph.surfaces.length; traversed += 1) {
      final current = graph.surfaces[currentIndex];
      final nextId = direction > 0 ? current.nextId : current.previousId;
      if (nextId == null) return false;
      final nextIndex = graph.indexOfSurfaceId(nextId);
      if (nextIndex == null || !graph.eligibility[nextIndex]) return false;
      if (!_hasWalkEdge(graph, currentIndex, nextIndex)) return false;
      if (nextIndex == goalIndex) return true;
      currentIndex = nextIndex;
    }
    return false;
  }

  bool _hasWalkEdge(TerrainSurfaceGraph graph, int fromIndex, int toIndex) {
    for (
      var edgeIndex = graph.edgeOffsets[fromIndex];
      edgeIndex < graph.edgeOffsets[fromIndex + 1];
      edgeIndex += 1
    ) {
      final edge = graph.edges[edgeIndex];
      if (edge.to == toIndex && edge.kind == TerrainSurfaceEdgeKind.walk) {
        return true;
      }
    }
    return false;
  }

  void _repath({
    required TerrainSurfaceNavigatorState state,
    required TerrainSurfaceGraph graph,
    required int entityBodyXTicks,
    required int targetBodyXTicks,
  }) {
    final preferredDirection = _sign(targetBodyXTicks - entityBodyXTicks);
    var found = false;
    if (preferredDirection != 0) {
      pathQueryCount += 1;
      found = pathfinder.findPath(
        graph,
        startIndex: state.currentSurfaceIndex,
        goalIndex: state.targetSurfaceIndex,
        outEdges: state.pathEdges,
        startBodyXTicks: entityBodyXTicks,
        goalBodyXTicks: targetBodyXTicks,
        preferredDirectionX: preferredDirection,
        restrictToPreferredDirection: true,
      );
    }
    if (!found) {
      pathQueryCount += 1;
      found = pathfinder.findPath(
        graph,
        startIndex: state.currentSurfaceIndex,
        goalIndex: state.targetSurfaceIndex,
        outEdges: state.pathEdges,
        startBodyXTicks: entityBodyXTicks,
        goalBodyXTicks: targetBodyXTicks,
      );
    }
    if (!found) state.pathEdges.clear();
    state.pathCursor = 0;
    state.activeEdgeIndex = -1;
    state.repathTicksLeft = repathCooldownTicks;
  }

  TerrainSurfaceNavIntent _safeFallback({
    required TerrainSurfaceNavigatorState state,
    required TerrainSurfaceGraph graph,
    required TerrainPlacementQuery placementQuery,
    required TerrainSurfaceNavigationActorSnapshot entity,
    required int targetBodyXTicks,
  }) {
    final safeIndex = state.currentSurfaceIndex >= 0
        ? state.currentSurfaceIndex
        : state.lastGroundSurfaceIndex;
    if (safeIndex < 0 ||
        safeIndex >= graph.surfaces.length ||
        !graph.eligibility[safeIndex]) {
      return TerrainSurfaceNavIntent(
        desiredBodyXTicks: entity.bodyCenter.xTicks,
        jumpNow: false,
        hasPlan: false,
      );
    }
    final standable = placementQuery.standableCenterRange(
      surface: graph.surfaces[safeIndex],
      capsule: entity.capsule,
      traversalProfile: entity.traversalProfile,
      supportRequirement: entity.supportRequirement,
    );
    if (standable == null) {
      return TerrainSurfaceNavIntent(
        desiredBodyXTicks: entity.bodyCenter.xTicks,
        jumpNow: false,
        hasPlan: false,
      );
    }
    final minimumBodyX =
        standable.minimumXTicks - entity.capsule.resolvedOffsetXTicks;
    final maximumBodyX =
        standable.maximumXTicks - entity.capsule.resolvedOffsetXTicks;
    return TerrainSurfaceNavIntent(
      desiredBodyXTicks: targetBodyXTicks.clamp(minimumBodyX, maximumBodyX),
      jumpNow: false,
      hasPlan: false,
      hasSafeBodyRange: true,
      safeMinimumBodyXTicks: minimumBodyX,
      safeMaximumBodyXTicks: maximumBodyX,
    );
  }

  int? _clampBodyXToSurface({
    required TerrainSurfaceGraph graph,
    required TerrainPlacementQuery placementQuery,
    required int surfaceIndex,
    required TerrainSurfaceNavigationActorSnapshot actor,
    required int desiredBodyXTicks,
  }) {
    final standable = placementQuery.standableCenterRange(
      surface: graph.surfaces[surfaceIndex],
      capsule: actor.capsule,
      traversalProfile: actor.traversalProfile,
      supportRequirement: actor.supportRequirement,
    );
    if (standable == null) return null;
    final minimumBodyX =
        standable.minimumXTicks - actor.capsule.resolvedOffsetXTicks;
    final maximumBodyX =
        standable.maximumXTicks - actor.capsule.resolvedOffsetXTicks;
    return desiredBodyXTicks.clamp(minimumBodyX, maximumBodyX);
  }

  bool _edgeIndexIsValidForSource(
    TerrainSurfaceNavigatorState state,
    TerrainSurfaceGraph graph,
    int edgeIndex,
  ) {
    final sourceIndex = state.currentSurfaceIndex >= 0
        ? state.currentSurfaceIndex
        : state.lastGroundSurfaceIndex;
    return sourceIndex >= 0 &&
        edgeIndex >= graph.edgeOffsets[sourceIndex] &&
        edgeIndex < graph.edgeOffsets[sourceIndex + 1];
  }

  bool _reachedTakeoff(int bodyXTicks, TerrainSurfaceGraphEdge edge) =>
      edge.commitDirectionX > 0
      ? bodyXTicks >= edge.takeoffPoint.xTicks - takeoffToleranceTicks
      : bodyXTicks <= edge.takeoffPoint.xTicks + takeoffToleranceTicks;

  void _clearPath(TerrainSurfaceNavigatorState state) {
    state.pathEdges.clear();
    state.pathCursor = 0;
    state.activeEdgeIndex = -1;
    state.repathTicksLeft = 0;
  }

  TerrainSurfaceNavIntent _applyMovementLock(
    TerrainSurfaceNavIntent intent,
    int currentBodyXTicks,
    bool movementLocked,
  ) => movementLocked
      ? TerrainSurfaceNavIntent(
          desiredBodyXTicks: currentBodyXTicks,
          jumpNow: false,
          hasPlan: intent.hasPlan,
        )
      : intent;
}

class _ResolvedSurface {
  const _ResolvedSurface(this.id, this.index);

  final TerrainEdgeId id;
  final int index;
}

int _sign(int value) => value == 0 ? 0 : (value > 0 ? 1 : -1);

int _divideCeil(int numerator, int positiveDenominator) =>
    (numerator + positiveDenominator - 1) ~/ positiveDenominator;
