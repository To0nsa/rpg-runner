import '../../combat/control_lock.dart';
import '../../collision/terrain/terrain_numeric.dart';
import '../../collision/terrain/terrain_traversal_profile.dart';
import '../../enemies/enemy_id.dart';
import '../../navigation/terrain_placement_query.dart';
import '../../navigation/terrain_runtime_bundle.dart';
import '../../navigation/terrain_surface_navigator.dart';
import '../../navigation/terrain_trajectory_predictor.dart';
import '../../navigation/types/terrain_surface_graph.dart';
import '../../tuning/physics_tuning.dart';
import '../../terrain/swimming_tuning.dart';
import '../../terrain/water_region.dart';
import '../entity_id.dart';
import '../collider_aabb_utils.dart';
import '../combat_target.dart';
import '../world.dart';

/// Routes polygon-terrain graphs into the existing ground-enemy intent store.
///
/// The current runtime bundle is read after the world-publication barrier. A
/// version change invalidates every entity's terrain navigator state through
/// [TerrainSurfaceNavigator] before any graph-local index can be consumed.
final class TerrainEnemyNavigationSystem {
  TerrainEnemyNavigationSystem({
    required TerrainRuntimeBundle Function() runtimeBundle,
    required TerrainSurfaceNavigator navigator,
    required PhysicsTuning physics,
    required double dtSeconds,
    this.predictionMaxTicks = 120,
  }) : _runtimeBundle = runtimeBundle,
       _navigator = navigator,
       _physics = physics,
       _dtSeconds = dtSeconds {
    if (!dtSeconds.isFinite || dtSeconds <= 0 || predictionMaxTicks <= 0) {
      throw ArgumentError(
        'Terrain navigation prediction needs positive finite timing.',
      );
    }
  }

  final TerrainRuntimeBundle Function() _runtimeBundle;
  final TerrainSurfaceNavigator _navigator;
  final PhysicsTuning _physics;
  final double _dtSeconds;
  final int predictionMaxTicks;
  final TerrainLandingPrediction _landingPrediction =
      TerrainLandingPrediction();

  int _boundBundleVersion = -1;
  TerrainPlacementQuery? _placementQuery;
  final Map<TerrainTraversalProfile, TerrainTrajectoryPredictor> _predictors =
      {};
  final Map<EntityId, TerrainSurfaceNavigationActorSnapshot> _tickTargets = {};

  /// Ground-enemy intents written by the latest tick.
  int lastNavigatedEnemyCount = 0;

  /// Whether the latest airborne player target produced a terrain landing.
  bool lastPredictedPlayerLanding = false;

  /// Writes land or water pursuit from the currently published terrain and
  /// [waterRegions]. Immersion must be refreshed before this call.
  void step(
    EcsWorld world, {
    required EntityId player,
    required int currentTick,
    Iterable<WaterRegion> waterRegions = const [],
  }) {
    lastNavigatedEnemyCount = 0;
    lastPredictedPlayerLanding = false;
    final bundle = _runtimeBundle();
    _bindBundle(bundle);
    final placementQuery = _placementQuery!;
    _tickTargets.clear();

    final navStore = world.surfaceNav;
    for (
      var navIndex = 0;
      navIndex < navStore.denseEntities.length;
      navIndex++
    ) {
      final enemy = navStore.denseEntities[navIndex];
      final enemyIndex = world.enemy.tryIndexOf(enemy);
      final intentIndex = world.navIntent.tryIndexOf(enemy);
      if (enemyIndex == null ||
          intentIndex == null ||
          world.deathState.has(enemy) ||
          !world.transform.has(enemy) ||
          !world.worldContactCapsule.has(enemy) ||
          !world.terrainTraversalProfile.has(enemy) ||
          !world.terrainContact.has(enemy)) {
        continue;
      }
      final enemyId = world.enemy.enemyId[enemyIndex];
      final graph = switch (enemyId) {
        EnemyId.grojib => bundle.grojibGraph,
        EnemyId.hashash => bundle.hashashGraph,
        EnemyId.unocoDemon || EnemyId.derf => null,
      };
      if (graph == null) continue;

      final targetId = combatTarget(world, enemy, player);
      if (targetId == null ||
          !world.worldContactCapsule.has(targetId) ||
          !world.terrainTraversalProfile.has(targetId) ||
          !world.terrainContact.has(targetId) ||
          !world.body.has(targetId)) {
        navStore.targetEntity[navIndex] = null;
        navStore.terrainState[navIndex].invalidateForBundle(bundle.version);
        final intents = world.navIntent;
        intents.hasPlan[intentIndex] = false;
        intents.jumpNow[intentIndex] = false;
        intents.commitMoveDirX[intentIndex] = 0;
        intents.desiredX[intentIndex] =
            world.transform.posX[world.transform.indexOf(enemy)];
        continue;
      }
      final selectionIndex = world.aiTarget.tryIndexOf(enemy);
      if (navStore.targetEntity[navIndex] != targetId) {
        navStore.terrainState[navIndex].invalidateForBundle(bundle.version);
        navStore.targetEntity[navIndex] = targetId;
      }
      final target = _tickTargets.putIfAbsent(
        targetId,
        () => _targetSnapshot(
          world,
          targetEntity: targetId,
          bundle: bundle,
          isPlayer: targetId == player,
        ),
      );

      final actor = _actorSnapshot(
        world,
        entity: enemy,
        graph: graph,
        bundleVersion: bundle.version,
      );
      if (world.swimState.isSwimming(enemy)) {
        // Surface paths assume dry ballistic motion. Discard them on immersion,
        // including retained bank bounds that would otherwise pull swimmers back.
        navStore.terrainState[navIndex].invalidateForBundle(bundle.version);
        _writeWaterIntent(
          world,
          intentIndex,
          world.transform.posX[world.transform.indexOf(targetId)],
        );
        lastNavigatedEnemyCount += 1;
        continue;
      }
      final intent = _navigator.update(
        state: navStore.terrainState[navIndex],
        graph: graph,
        placementQuery: placementQuery,
        bundleVersion: bundle.version,
        entity: actor,
        target: target,
        navigationLocked: world.controlLock.isLocked(
          enemy,
          LockFlag.nav,
          currentTick,
        ),
        movementLocked: world.controlLock.isLocked(
          enemy,
          LockFlag.move,
          currentTick,
        ),
        stunLocked: world.controlLock.isStunned(enemy, currentTick),
      );
      _writeIntent(
        world,
        intentIndex: intentIndex,
        navIndex: navIndex,
        graph: graph,
        target: target,
        intent: intent,
        grounded: actor.grounded,
      );
      if (!intent.hasPlan &&
          actor.grounded &&
          intent.hasSafeBodyRange &&
          !world.controlLock.isLocked(enemy, LockFlag.nav, currentTick) &&
          !world.controlLock.isLocked(enemy, LockFlag.move, currentTick) &&
          !world.controlLock.isStunned(enemy, currentTick) &&
          _canEnterWater(
            actor,
            intent,
            target.bodyCenter.xTicks,
            waterRegions,
          )) {
        navStore.terrainState[navIndex].invalidateForBundle(bundle.version);
        _writeWaterIntent(
          world,
          intentIndex,
          target.bodyCenter.xTicks / terrainPhysicsTicksPerWorldUnit,
        );
      } else if (selectionIndex != null &&
          targetId != player &&
          !intent.hasPlan &&
          actor.grounded &&
          target.grounded &&
          navStore.terrainState[navIndex].currentSurfaceIndex >= 0 &&
          navStore.terrainState[navIndex].targetSurfaceIndex >= 0 &&
          !world.controlLock.isLocked(enemy, LockFlag.nav, currentTick) &&
          !world.controlLock.isLocked(enemy, LockFlag.move, currentTick) &&
          !world.controlLock.isStunned(enemy, currentTick)) {
        world.aiTarget.unreachable[selectionIndex][targetId] =
            targetNavigationEvidence(world, enemy, targetId);
      }
      lastNavigatedEnemyCount += 1;
    }
  }

  void _writeWaterIntent(EcsWorld world, int index, double targetX) {
    final intents = world.navIntent;
    intents.navTargetX[index] = targetX;
    intents.desiredX[index] = targetX;
    intents.hasPlan[index] = false;
    intents.jumpNow[index] = false;
    intents.commitMoveDirX[index] = 0;
    intents.hasSafeSurface[index] = false;
    intents.clearActiveJumpTraversalAt(index);
  }

  bool _canEnterWater(
    TerrainSurfaceNavigationActorSnapshot actor,
    TerrainSurfaceNavIntent intent,
    int targetX,
    Iterable<WaterRegion> regions,
  ) {
    final direction = (targetX - actor.bodyCenter.xTicks).sign;
    if (direction == 0) return false;
    final safeEdge = direction > 0
        ? intent.safeMaximumBodyXTicks
        : intent.safeMinimumBodyXTicks;
    if ((targetX - safeEdge) * direction <= 0) return false;
    final footY =
        actor.bodyCenter.yTicks +
        actor.capsule.offsetYTicks +
        actor.capsule.radiusTicks +
        actor.capsule.verticalHalfSegmentTicks;
    // Probe immediately beyond the current capsule-width bank foothold. Never
    // release a ledge clamp for a distant pool or an ordinary dry gap.
    final probeX =
        safeEdge +
        actor.capsule.resolvedOffsetXTicks +
        direction *
            (actor.capsule.radiusTicks + 4 * terrainPhysicsTicksPerWorldUnit);
    for (final water in regions) {
      if (probeX >= water.leftTicks &&
          probeX < water.rightTicks &&
          water.bottomTicks > footY &&
          water.topTicks >= footY - 4 * terrainPhysicsTicksPerWorldUnit &&
          water.topTicks - footY <=
              SwimmingTuning.enemyEntryMaxDrop *
                  terrainPhysicsTicksPerWorldUnit) {
        return true;
      }
    }
    return false;
  }

  void _bindBundle(TerrainRuntimeBundle bundle) {
    if (_boundBundleVersion == bundle.version) return;
    final placementQuery = TerrainPlacementQuery(
      geometry: bundle.geometry,
      terrainIndex: bundle.edgeIndex,
      surfaceIndex: bundle.surfaceIndex,
    );
    _placementQuery = placementQuery;
    _predictors.clear();
    _boundBundleVersion = bundle.version;
  }

  TerrainSurfaceNavigationActorSnapshot _targetSnapshot(
    EcsWorld world, {
    required EntityId targetEntity,
    required TerrainRuntimeBundle bundle,
    required bool isPlayer,
  }) {
    final current = _worldActorSnapshot(
      world,
      entity: targetEntity,
      supportRequirement:
          const TerrainSupportRequirement.groundedEnemyRuntime(),
      bundleVersion: bundle.version,
    );
    if (current.grounded || !_canPredictTarget(world, targetEntity)) {
      return current;
    }

    final transformIndex = world.transform.indexOf(targetEntity);
    final bodyIndex = world.body.indexOf(targetEntity);
    final predictor = _predictors.putIfAbsent(
      current.traversalProfile,
      () => TerrainTrajectoryPredictor(
        placementQuery: _placementQuery!,
        traversalProfile: current.traversalProfile,
        supportRequirement:
            const TerrainSupportRequirement.groundedEnemyRuntime(),
        dtSeconds: _dtSeconds,
        maxTicks: predictionMaxTicks,
      ),
    );
    final predicted = predictor.predictLanding(
      startBodyCenter: current.bodyCenter,
      capsule: current.capsule,
      velocityX: world.transform.velX[transformIndex],
      velocityY: world.transform.velY[transformIndex],
      gravityY: world.body.useGravity[bodyIndex]
          ? _physics.gravityY * world.body.gravityScale[bodyIndex]
          : 0,
      maximumFallSpeed: world.body.maxVelY[bodyIndex],
      out: _landingPrediction,
    );
    if (isPlayer) lastPredictedPlayerLanding = predicted;
    if (!predicted || _landingPrediction.supportEdgeId == null) return current;
    return TerrainSurfaceNavigationActorSnapshot(
      bodyCenter: TerrainPoint(
        _landingPrediction.bodyCenterXTicks,
        _landingPrediction.bodyCenterYTicks,
      ),
      capsule: current.capsule,
      traversalProfile: current.traversalProfile,
      supportRequirement: current.supportRequirement,
      grounded: true,
      priorSupportEdgeId: _landingPrediction.supportEdgeId,
      priorSupportGeometryVersion: _landingPrediction.geometryVersion,
    );
  }

  bool _canPredictTarget(EcsWorld world, EntityId targetEntity) {
    if (world.swimState.isSwimming(targetEntity)) return false;
    final gravityIndex = world.gravityControl.tryIndexOf(targetEntity);
    return gravityIndex == null ||
        world.gravityControl.suppressGravityTicksLeft[gravityIndex] <= 0;
  }

  TerrainSurfaceNavigationActorSnapshot _actorSnapshot(
    EcsWorld world, {
    required EntityId entity,
    required TerrainSurfaceGraph graph,
    required int bundleVersion,
  }) => _worldActorSnapshot(
    world,
    entity: entity,
    supportRequirement: graph.buildProfile.supportRequirement,
    bundleVersion: bundleVersion,
  );

  TerrainSurfaceNavigationActorSnapshot _worldActorSnapshot(
    EcsWorld world, {
    required EntityId entity,
    required TerrainSupportRequirement supportRequirement,
    required int bundleVersion,
  }) {
    final transformIndex = world.transform.indexOf(entity);
    final capsuleIndex = world.worldContactCapsule.indexOf(entity);
    final profileIndex = world.terrainTraversalProfile.indexOf(entity);
    final contactIndex = world.terrainContact.indexOf(entity);
    final contactIsCurrent =
        world.terrainContact.grounded[contactIndex] &&
        world.terrainContact.supportEdgeId[contactIndex] != null &&
        world.terrainContact.supportGeometryVersion[contactIndex] ==
            bundleVersion;
    return TerrainSurfaceNavigationActorSnapshot(
      bodyCenter: TerrainPoint(
        physicsCoordinateToTicks(
          world.transform.posX[transformIndex],
          name: 'terrainNavigationBodyX',
        ),
        physicsCoordinateToTicks(
          world.transform.posY[transformIndex],
          name: 'terrainNavigationBodyY',
        ),
      ),
      capsule: TerrainPlacementCapsule(
        radiusTicks: world.worldContactCapsule.radiusTicks[capsuleIndex],
        verticalHalfSegmentTicks:
            world.worldContactCapsule.verticalHalfSegmentTicks[capsuleIndex],
        resolvedOffsetXTicks:
            world.worldContactCapsule.offsetXTicks[capsuleIndex] *
            colliderFacingSign(world, entity),
        offsetYTicks: world.worldContactCapsule.offsetYTicks[capsuleIndex],
      ),
      traversalProfile: world.terrainTraversalProfile.profile[profileIndex],
      supportRequirement: supportRequirement,
      grounded: contactIsCurrent,
      priorSupportEdgeId: contactIsCurrent
          ? world.terrainContact.supportEdgeId[contactIndex]
          : null,
      priorSupportGeometryVersion: contactIsCurrent
          ? world.terrainContact.supportGeometryVersion[contactIndex]
          : -1,
    );
  }

  void _writeIntent(
    EcsWorld world, {
    required int intentIndex,
    required int navIndex,
    required TerrainSurfaceGraph graph,
    required TerrainSurfaceNavigationActorSnapshot target,
    required TerrainSurfaceNavIntent intent,
    required bool grounded,
  }) {
    final intents = world.navIntent;
    intents.navTargetX[intentIndex] =
        target.bodyCenter.xTicks / terrainPhysicsTicksPerWorldUnit;
    intents.desiredX[intentIndex] =
        intent.desiredBodyXTicks / terrainPhysicsTicksPerWorldUnit;
    intents.jumpNow[intentIndex] = intent.jumpNow;
    intents.hasPlan[intentIndex] = intent.hasPlan;
    intents.commitMoveDirX[intentIndex] = intent.commitDirectionX;
    intents.hasSafeSurface[intentIndex] = intent.hasSafeBodyRange;
    intents.safeSurfaceMinX[intentIndex] =
        intent.safeMinimumBodyXTicks / terrainPhysicsTicksPerWorldUnit;
    intents.safeSurfaceMaxX[intentIndex] =
        intent.safeMaximumBodyXTicks / terrainPhysicsTicksPerWorldUnit;

    final edgeIndex = world.surfaceNav.terrainState[navIndex].activeEdgeIndex;
    if (edgeIndex < 0 || edgeIndex >= graph.edges.length) {
      // Terrain publication invalidates graph indices, not an already launched
      // body's ballistic commitment. Keep its scalar launch data until landing;
      // locomotion still resolves every tick through current terrain collision.
      if (grounded) intents.clearActiveJumpTraversalAt(intentIndex);
      return;
    }
    final edge = graph.edges[edgeIndex];
    if (edge.kind != TerrainSurfaceEdgeKind.jump) {
      intents.clearActiveJumpTraversalAt(intentIndex);
      return;
    }
    intents.setActiveJumpTraversalAt(
      intentIndex,
      takeoffX: edge.takeoffPoint.xTicks / terrainPhysicsTicksPerWorldUnit,
      landingX: edge.landingPoint.xTicks / terrainPhysicsTicksPerWorldUnit,
      commitDirectionX: edge.commitDirectionX,
      travelTicks: edge.travelTicks,
    );
  }
}
