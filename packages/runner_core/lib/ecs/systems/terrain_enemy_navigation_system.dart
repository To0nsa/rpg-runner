import '../../combat/control_lock.dart';
import '../../collision/terrain/terrain_numeric.dart';
import '../../enemies/enemy_id.dart';
import '../../navigation/terrain_placement_query.dart';
import '../../navigation/terrain_runtime_bundle.dart';
import '../../navigation/terrain_surface_navigator.dart';
import '../../navigation/terrain_trajectory_predictor.dart';
import '../../navigation/types/terrain_surface_graph.dart';
import '../../tuning/physics_tuning.dart';
import '../entity_id.dart';
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
  TerrainTrajectoryPredictor? _playerTrajectoryPredictor;

  /// Ground-enemy intents written by the latest tick.
  int lastNavigatedEnemyCount = 0;

  /// Whether the latest airborne player target produced a terrain landing.
  bool lastPredictedPlayerLanding = false;

  void step(
    EcsWorld world, {
    required EntityId player,
    required int currentTick,
  }) {
    lastNavigatedEnemyCount = 0;
    lastPredictedPlayerLanding = false;
    if (!world.transform.has(player) ||
        !world.worldContactCapsule.has(player) ||
        !world.terrainTraversalProfile.has(player) ||
        !world.terrainContact.has(player) ||
        !world.body.has(player)) {
      return;
    }

    final bundle = _runtimeBundle();
    _bindBundle(bundle, world, player);
    final placementQuery = _placementQuery!;
    final target = _targetSnapshot(world, player: player, bundle: bundle);

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

      final actor = _actorSnapshot(
        world,
        entity: enemy,
        graph: graph,
        bundleVersion: bundle.version,
      );
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
      );
      lastNavigatedEnemyCount += 1;
    }
  }

  void _bindBundle(
    TerrainRuntimeBundle bundle,
    EcsWorld world,
    EntityId player,
  ) {
    if (_boundBundleVersion == bundle.version) return;
    final placementQuery = TerrainPlacementQuery(
      geometry: bundle.geometry,
      terrainIndex: bundle.edgeIndex,
      surfaceIndex: bundle.surfaceIndex,
    );
    final profileIndex = world.terrainTraversalProfile.indexOf(player);
    _placementQuery = placementQuery;
    _playerTrajectoryPredictor = TerrainTrajectoryPredictor(
      placementQuery: placementQuery,
      traversalProfile: world.terrainTraversalProfile.profile[profileIndex],
      supportRequirement:
          const TerrainSupportRequirement.groundedEnemyRuntime(),
      dtSeconds: _dtSeconds,
      maxTicks: predictionMaxTicks,
    );
    _boundBundleVersion = bundle.version;
  }

  TerrainSurfaceNavigationActorSnapshot _targetSnapshot(
    EcsWorld world, {
    required EntityId player,
    required TerrainRuntimeBundle bundle,
  }) {
    final current = _worldActorSnapshot(
      world,
      entity: player,
      supportRequirement:
          const TerrainSupportRequirement.groundedEnemyRuntime(),
      bundleVersion: bundle.version,
    );
    if (current.grounded || !_canPredictPlayer(world, player)) return current;

    final transformIndex = world.transform.indexOf(player);
    final bodyIndex = world.body.indexOf(player);
    final predicted = _playerTrajectoryPredictor!.predictLanding(
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
    lastPredictedPlayerLanding = predicted;
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

  bool _canPredictPlayer(EcsWorld world, EntityId player) {
    final gravityIndex = world.gravityControl.tryIndexOf(player);
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
            _facingOffsetSign(world, entity),
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
      intents.clearActiveJumpTraversalAt(intentIndex);
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

int _facingOffsetSign(EcsWorld world, EntityId entity) {
  final movementIndex = world.movement.tryIndexOf(entity);
  if (movementIndex != null) {
    return world.movement.facing[movementIndex] ==
            world.movement.artFacing[movementIndex]
        ? 1
        : -1;
  }
  final enemyIndex = world.enemy.tryIndexOf(entity);
  if (enemyIndex != null) {
    return world.enemy.facing[enemyIndex] == world.enemy.artFacing[enemyIndex]
        ? 1
        : -1;
  }
  return 1;
}
