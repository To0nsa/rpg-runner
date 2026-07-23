import 'dart:math' as math;

import '../../collision/static_world_geometry_index.dart';
import '../../collision/terrain/terrain_capsule_controller.dart';
import '../../collision/terrain/terrain_controller_diagnostic.dart';
import '../../collision/terrain/terrain_edge_index.dart';
import '../../collision/terrain/terrain_geometry.dart';
import '../../collision/terrain/terrain_motion_request.dart';
import '../../collision/terrain/terrain_numeric.dart';
import '../../collision/terrain/terrain_polygon.dart';
import '../../collision/terrain/terrain_traversal_profile.dart';
import '../../collision/terrain/terrain_traversal_cache.dart';
import '../../collision/terrain/upright_capsule.dart';
import '../../enemies/enemy_catalog.dart';
import '../../players/player_archetype.dart';
import '../../players/player_tuning.dart';
import '../../enemies/enemy_id.dart';
import '../../enemies/enemy_terrain_profile.dart';
import '../../navigation/terrain_placement_query.dart';
import '../../navigation/terrain_surface_extractor.dart';
import '../../navigation/terrain_surface_spatial_index.dart';
import '../../navigation/terrain_surface_query_buffer.dart';
import '../../navigation/types/surface_id.dart';
import '../../navigation/types/terrain_navigation_surface.dart';
import '../../snapshots/enums.dart';
import '../entity_id.dart';
import '../stores/world_contact_capsule_store.dart';
import '../world.dart';
import 'collision_system.dart';

/// One integration owner for dynamic-body movement during a Core tick.
///
/// Normal GameCore construction uses [LegacyWorldMotionAuthority]. The
/// narrowly scoped terrain harness uses [TerrainMultiBodyWorldMotionAuthority]
/// and rejects unsupported dynamic bodies rather than mixing authorities.
abstract interface class WorldMotionAuthority {
  bool get usesTerrainPlayer;

  int? get terrainGeometryVersion;

  bool get initialPlayerGrounded;

  void initializePlayer(
    EcsWorld world, {
    required EntityId player,
    required PlayerArchetype archetype,
  });

  /// Publishes tick-start ownership and prior-support state before consumers.
  ///
  /// This runs before jump, ordinary movement, mobility, and gravity so none
  /// of those systems can act on stale terrain support.
  void prepareTick(
    EcsWorld world, {
    required EntityId player,
    required int currentTick,
  });

  /// Integrates the selected world and returns this tick's distance delta.
  double step(
    EcsWorld world, {
    required EntityId player,
    required MovementTuningDerived movement,
    required StaticWorldGeometryIndex legacyStaticWorld,
    required bool fixedPointPilotEnabled,
    required int fixedPointSubpixelScale,
    required int currentTick,
  });

  bool playerGrounded(EcsWorld world, EntityId player);

  /// Clears transient support/path state and retains the last safe transform.
  WorldBodyPlacementOrigin beginBodyTeleport(EcsWorld world, EntityId entity);

  /// Validates and atomically commits one exact airborne teleport candidate.
  bool tryCommitBodyTeleport(
    EcsWorld world,
    EntityId entity, {
    required double bodyX,
    required double bodyY,
    required Facing facing,
  });

  /// Restores the safe transform retained by [beginBodyTeleport].
  void cancelBodyTeleport(
    EcsWorld world,
    EntityId entity,
    WorldBodyPlacementOrigin origin,
  );

  /// Resolves an exact-X/requested-support, fully supported enemy spawn.
  GroundedEnemySpawnPlacement? resolveGroundedEnemySpawn({
    required EnemyId enemyId,
    required double desiredBodyX,
    required double requestedSupportY,
  });

  /// Highest solid upward face below a flying capsule's current footprint.
  double? flyingTerrainReferenceY(EcsWorld world, EntityId entity);

  /// Previews and ranks the bounded solid-clearance steering candidates.
  void resolveFlyingClearanceSteering(
    EcsWorld world,
    EntityId entity, {
    required double directVelocityX,
    required double directVelocityY,
    required double targetBodyX,
    required double targetBodyY,
    required int blockerNormalXTicks,
    required int blockerNormalYTicks,
    required int previewTicks,
    required int tickHz,
    required FlyingClearanceSteeringOutput out,
  });

  void beforeExternalBodyVelocity(
    EcsWorld world,
    EntityId entity, {
    required double velocityY,
  });

  void beforeBodyMotionStops(EcsWorld world, EntityId entity);
}

/// Safe body transform retained while a teleport destination is evaluated.
final class WorldBodyPlacementOrigin {
  const WorldBodyPlacementOrigin({
    required this.bodyX,
    required this.bodyY,
    required this.facing,
  });

  final double bodyX;
  final double bodyY;
  final Facing facing;
}

/// Exact body transform approved for a grounded enemy spawn.
final class GroundedEnemySpawnPlacement {
  const GroundedEnemySpawnPlacement({required this.bodyX, required this.bodyY});

  final double bodyX;
  final double bodyY;
}

/// Caller-owned result for one bounded flying-clearance selection.
final class FlyingClearanceSteeringOutput {
  double velocityX = 0;
  double velocityY = 0;
  int candidateId = -1;

  void setDirect(double x, double y) {
    velocityX = x;
    velocityY = y;
    candidateId = 0;
  }
}

/// Explicit Phase 3 disposition for every body in the terrain harness.
enum TerrainBodyDisposition {
  terrainPlayer,
  terrainGroundedEnemy,
  terrainFlyingEnemy,
  kinematicPlacementEnemy,
  disabledIgnored,
  ballisticProjectileUnsupported,
  otherKinematicIgnored,
  unsupportedDynamicBody,
}

/// Typed failure used instead of silently falling back to rectangle motion.
final class TerrainUnsupportedBodyError extends StateError {
  TerrainUnsupportedBodyError({required this.entity, required this.disposition})
    : super(
        'Phase 3 terrain motion rejected body $entity '
        '(${disposition.name}); no legacy collision fallback is permitted.',
      );

  final EntityId entity;
  final TerrainBodyDisposition disposition;
}

/// A known actor has a missing, partial, or policy-incompatible terrain store.
final class TerrainBodyStoreError extends StateError {
  TerrainBodyStoreError({required this.entity, required String reason})
    : super('Phase 3 terrain body $entity is invalid: $reason');

  final EntityId entity;
}

/// Classifies a body under the Phase 3 terrain-harness policy.
TerrainBodyDisposition terrainBodyDisposition(
  EcsWorld world, {
  required EntityId entity,
  required EntityId terrainPlayer,
}) {
  final bodyIndex = world.body.indexOf(entity);
  if (!world.body.enabled[bodyIndex]) {
    return TerrainBodyDisposition.disabledIgnored;
  }
  if (entity == terrainPlayer) {
    return TerrainBodyDisposition.terrainPlayer;
  }
  final projectileIndex = world.projectile.tryIndexOf(entity);
  if (projectileIndex != null && world.projectile.usePhysics[projectileIndex]) {
    return TerrainBodyDisposition.ballisticProjectileUnsupported;
  }
  final enemyIndex = world.enemy.tryIndexOf(entity);
  if (enemyIndex != null) {
    switch (world.enemy.enemyId[enemyIndex]) {
      case EnemyId.grojib:
      case EnemyId.hashash:
        return TerrainBodyDisposition.terrainGroundedEnemy;
      case EnemyId.unocoDemon:
        return TerrainBodyDisposition.terrainFlyingEnemy;
      case EnemyId.derf:
        return TerrainBodyDisposition.kinematicPlacementEnemy;
    }
  }
  if (world.body.isKinematic[bodyIndex]) {
    return TerrainBodyDisposition.otherKinematicIgnored;
  }
  return TerrainBodyDisposition.unsupportedDynamicBody;
}

/// Adapter preserving the pre-slopes rectangle integration path exactly.
class LegacyWorldMotionAuthority implements WorldMotionAuthority {
  final CollisionSystem _collision = CollisionSystem();
  final EnemyCatalog _enemyCatalog = const EnemyCatalog();
  int _preparedTick = -1;
  int _integratedTick = -1;

  @override
  bool get usesTerrainPlayer => false;

  @override
  int? get terrainGeometryVersion => null;

  @override
  bool get initialPlayerGrounded => true;

  @override
  void initializePlayer(
    EcsWorld world, {
    required EntityId player,
    required PlayerArchetype archetype,
  }) {}

  @override
  void prepareTick(
    EcsWorld world, {
    required EntityId player,
    required int currentTick,
  }) {
    _auditPrepare(currentTick);
  }

  @override
  double step(
    EcsWorld world, {
    required EntityId player,
    required MovementTuningDerived movement,
    required StaticWorldGeometryIndex legacyStaticWorld,
    required bool fixedPointPilotEnabled,
    required int fixedPointSubpixelScale,
    required int currentTick,
  }) {
    _auditIntegrate(currentTick);
    _collision.step(
      world,
      movement,
      staticWorld: legacyStaticWorld,
      fixedPointPilotEnabled: fixedPointPilotEnabled,
      fixedPointSubpixelScale: fixedPointSubpixelScale,
    );
    final transformIndex = world.transform.indexOf(player);
    return math.max(0.0, world.transform.velX[transformIndex]) *
        movement.dtSeconds;
  }

  @override
  bool playerGrounded(EcsWorld world, EntityId player) {
    final collisionIndex = world.collision.indexOf(player);
    return world.collision.grounded[collisionIndex];
  }

  @override
  WorldBodyPlacementOrigin beginBodyTeleport(EcsWorld world, EntityId entity) =>
      _currentPlacementOrigin(world, entity);

  @override
  bool tryCommitBodyTeleport(
    EcsWorld world,
    EntityId entity, {
    required double bodyX,
    required double bodyY,
    required Facing facing,
  }) {
    _writeBodyPlacement(
      world,
      entity,
      bodyX: bodyX,
      bodyY: bodyY,
      facing: facing,
    );
    return true;
  }

  @override
  void cancelBodyTeleport(
    EcsWorld world,
    EntityId entity,
    WorldBodyPlacementOrigin origin,
  ) {
    _writeBodyPlacement(
      world,
      entity,
      bodyX: origin.bodyX,
      bodyY: origin.bodyY,
      facing: origin.facing,
    );
  }

  @override
  GroundedEnemySpawnPlacement? resolveGroundedEnemySpawn({
    required EnemyId enemyId,
    required double desiredBodyX,
    required double requestedSupportY,
  }) {
    final collider = _enemyCatalog.get(enemyId).collider;
    return GroundedEnemySpawnPlacement(
      bodyX: desiredBodyX,
      bodyY: requestedSupportY - (collider.offsetY + collider.halfY),
    );
  }

  @override
  double? flyingTerrainReferenceY(EcsWorld world, EntityId entity) => null;

  @override
  void resolveFlyingClearanceSteering(
    EcsWorld world,
    EntityId entity, {
    required double directVelocityX,
    required double directVelocityY,
    required double targetBodyX,
    required double targetBodyY,
    required int blockerNormalXTicks,
    required int blockerNormalYTicks,
    required int previewTicks,
    required int tickHz,
    required FlyingClearanceSteeringOutput out,
  }) {
    out.setDirect(directVelocityX, directVelocityY);
  }

  @override
  void beforeExternalBodyVelocity(
    EcsWorld world,
    EntityId entity, {
    required double velocityY,
  }) {}

  @override
  void beforeBodyMotionStops(EcsWorld world, EntityId entity) {}

  void _auditPrepare(int currentTick) {
    if (_preparedTick >= 0 && _integratedTick != _preparedTick) {
      throw StateError(
        'World motion prepared tick $_preparedTick but did not integrate it.',
      );
    }
    if (_preparedTick == currentTick) {
      throw StateError('World motion prepared tick $currentTick twice.');
    }
    _preparedTick = currentTick;
  }

  void _auditIntegrate(int currentTick) {
    if (_preparedTick != currentTick) {
      throw StateError(
        'World motion tick $currentTick was not prepared exactly once.',
      );
    }
    if (_integratedTick == currentTick) {
      throw StateError('World motion integrated tick $currentTick twice.');
    }
    _integratedTick = currentTick;
  }
}

/// Isolated Phase 3 terrain dispatcher for the player and migrated enemies.
///
/// The dispatcher preflights every body before mutating tick state, prepares
/// prior support before AI, and integrates enabled dynamic terrain actors once
/// in canonical entity order. Normal levels do not construct this authority.
class TerrainMultiBodyWorldMotionAuthority implements WorldMotionAuthority {
  factory TerrainMultiBodyWorldMotionAuthority({
    required TerrainGeometry geometry,
    required TerrainTraversalProfile playerProfile,
    EnemyCatalog enemyCatalog = const EnemyCatalog(),
  }) {
    final edgeIndex = TerrainEdgeIndex(edges: geometry.edges);
    final surfaceIndex = TerrainSurfaceSpatialIndex(
      surfaceSet: const TerrainSurfaceExtractor().extract(geometry),
    );
    final placementQuery = TerrainPlacementQuery(
      geometry: geometry,
      terrainIndex: edgeIndex,
      surfaceIndex: surfaceIndex,
    );
    _TerrainMotionScratch scratchFor(
      TerrainTraversalProfile profile,
      EnemyTerrainMotionKind motionKind,
    ) => _TerrainMotionScratch(
      profile: profile,
      motionKind: motionKind,
      geometry: geometry,
      edgeIndex: edgeIndex,
    );

    final grojib = enemyCatalog.terrainContactProfile(EnemyId.grojib);
    final hashash = enemyCatalog.terrainContactProfile(EnemyId.hashash);
    final unoco = enemyCatalog.terrainContactProfile(EnemyId.unocoDemon);
    final derf = enemyCatalog.terrainContactProfile(EnemyId.derf);
    return TerrainMultiBodyWorldMotionAuthority._(
      geometry: geometry,
      placementQuery: placementQuery,
      enemyCatalog: enemyCatalog,
      playerScratch: scratchFor(
        playerProfile,
        EnemyTerrainMotionKind.groundedDynamic,
      ),
      grojibProfile: grojib,
      grojibScratch: scratchFor(grojib.traversal, grojib.motionKind),
      hashashProfile: hashash,
      hashashScratch: scratchFor(hashash.traversal, hashash.motionKind),
      unocoProfile: unoco,
      unocoScratch: scratchFor(unoco.traversal, unoco.motionKind),
      derfProfile: derf,
    );
  }

  TerrainMultiBodyWorldMotionAuthority._({
    required TerrainGeometry geometry,
    required TerrainPlacementQuery placementQuery,
    required EnemyCatalog enemyCatalog,
    required _TerrainMotionScratch playerScratch,
    required EnemyTerrainContactProfile grojibProfile,
    required _TerrainMotionScratch grojibScratch,
    required EnemyTerrainContactProfile hashashProfile,
    required _TerrainMotionScratch hashashScratch,
    required EnemyTerrainContactProfile unocoProfile,
    required _TerrainMotionScratch unocoScratch,
    required EnemyTerrainContactProfile derfProfile,
  }) : _geometry = geometry,
       _placementQuery = placementQuery,
       _flightSurfaceBuffer = placementQuery.surfaceIndex.createQueryBuffer(),
       _enemyCatalog = enemyCatalog,
       _playerScratch = playerScratch,
       _grojibProfile = grojibProfile,
       _grojibScratch = grojibScratch,
       _hashashProfile = hashashProfile,
       _hashashScratch = hashashScratch,
       _unocoProfile = unocoProfile,
       _unocoScratch = unocoScratch,
       _derfProfile = derfProfile;

  final TerrainGeometry _geometry;
  final TerrainPlacementQuery _placementQuery;
  final TerrainSurfaceQueryBuffer _flightSurfaceBuffer;
  final TerrainCapsuleMotionResult _flyingPreviewResult =
      TerrainCapsuleMotionResult();
  final EnemyCatalog _enemyCatalog;
  final _TerrainMotionScratch _playerScratch;
  final EnemyTerrainContactProfile _grojibProfile;
  final _TerrainMotionScratch _grojibScratch;
  final EnemyTerrainContactProfile _hashashProfile;
  final _TerrainMotionScratch _hashashScratch;
  final EnemyTerrainContactProfile _unocoProfile;
  final _TerrainMotionScratch _unocoScratch;
  final EnemyTerrainContactProfile _derfProfile;
  final List<EntityId> _orderedBodies = <EntityId>[];
  int _preparedTick = -1;
  int _integratedTick = -1;

  /// Number of enabled dynamic terrain bodies solved by the latest [step].
  int lastIntegratedBodyCount = 0;

  @override
  bool get usesTerrainPlayer => true;

  @override
  int get terrainGeometryVersion => _geometry.version;

  @override
  bool get initialPlayerGrounded => false;

  @override
  void initializePlayer(
    EcsWorld world, {
    required EntityId player,
    required PlayerArchetype archetype,
  }) {
    if (_geometry.edges.isEmpty) {
      throw StateError('Terrain motion requires exposed terrain edges.');
    }
    if (!identical(archetype.terrainTraversalProfile, _playerScratch.profile)) {
      throw TerrainBodyStoreError(
        entity: player,
        reason: 'player archetype and authority traversal profiles differ',
      );
    }
    world.worldContactCapsule.add(player, archetype.worldContactCapsule);
    world.terrainContact.add(player);
    world.terrainTraversalProfile.add(
      player,
      archetype.terrainTraversalProfile,
    );
    world.resolvedMotion.add(player);

    final capsuleIndex = world.worldContactCapsule.indexOf(player);
    final transformIndex = world.transform.indexOf(player);
    final facingSign = _facingOffsetSign(world, player);
    final offsetX =
        world.worldContactCapsule.offsetXTicks[capsuleIndex] * facingSign;
    final offsetY = world.worldContactCapsule.offsetYTicks[capsuleIndex];
    final bodyX = physicsCoordinateToTicks(
      world.transform.posX[transformIndex],
      name: 'spawnBodyX',
    );
    var minimumY = _geometry.edges.first.bounds.minY;
    var maximumY = _geometry.edges.first.bounds.maxY;
    for (final edge in _geometry.edges.skip(1)) {
      minimumY = math.min(minimumY, edge.bounds.minY);
      maximumY = math.max(maximumY, edge.bounds.maxY);
    }
    final radius = world.worldContactCapsule.radiusTicks[capsuleIndex];
    final halfSegment =
        world.worldContactCapsule.verticalHalfSegmentTicks[capsuleIndex];
    final startCapsule = UprightCapsule(
      center: TerrainPoint(
        bodyX + offsetX,
        minimumY -
            radius -
            halfSegment -
            terrainCollisionSkinTicks -
            terrainPhysicsTicksPerWorldUnit,
      ),
      radiusTicks: radius,
      verticalHalfSegmentTicks: halfSegment,
    );
    final fallDistance =
        maximumY -
        startCapsule.center.yTicks +
        radius +
        halfSegment +
        terrainPhysicsTicksPerWorldUnit;
    _playerScratch.controller.placeOnFirstSupportBelow(
      capsule: startCapsule,
      maximumDistanceTicks: fallDistance,
      out: _playerScratch.result,
    );
    final result = _playerScratch.result;
    if (!result.grounded || result.supportEdgeId == null) {
      throw StateError(
        'Terrain player spawn X has no clear walkable support below it.',
      );
    }

    final finalBodyX = result.finalCenterXTicks - offsetX;
    final finalBodyY = result.finalCenterYTicks - offsetY;
    world.transform.posX[transformIndex] =
        finalBodyX / terrainPhysicsTicksPerWorldUnit;
    world.transform.posY[transformIndex] =
        finalBodyY / terrainPhysicsTicksPerWorldUnit;
    world.transform.velX[transformIndex] = 0;
    world.transform.velY[transformIndex] = 0;
    _writeContactState(
      world,
      entity: player,
      currentTick: 0,
      scratch: _playerScratch,
    );
    final contactIndex = world.terrainContact.indexOf(player);
    world.terrainContact.setLastValidBodyPosition(
      player,
      xTicks: finalBodyX,
      yTicks: finalBodyY,
    );
    world.terrainContact.setLastCapsuleState(
      player,
      centerXTicks: result.finalCenterXTicks,
      centerYTicks: result.finalCenterYTicks,
      facingSign: facingSign,
    );
    world.collision.grounded[world.collision.indexOf(player)] = true;
    world.resolvedMotion.setResolved(
      player,
      displacementXTicks: 0,
      displacementYTicks: 0,
      travelAlongSupportTicks: 0,
    );
    world.terrainContact.beganTickGrounded[contactIndex] = true;
  }

  @override
  void prepareTick(
    EcsWorld world, {
    required EntityId player,
    required int currentTick,
  }) {
    _refreshOrderedBodies(world);
    _preflightBodies(world, player: player, allowInitialization: true);
    _auditPrepare(currentTick);
    _initializePendingEnemyStores(world);

    for (final entity in _orderedBodies) {
      final scratch = _dynamicScratchFor(world, entity, player: player);
      if (scratch == null) {
        if (_isKinematicPlacementEnemy(world, entity)) {
          world.collision.resetTick(entity);
        }
        continue;
      }
      _invalidateStaleNavigation(world, entity);
      world.terrainContact.beginTick(
        entity,
        currentGeometryVersion: _geometry.version,
      );
      world.collision.resetTick(entity);
      world.resolvedMotion.setLocomotionReferenceSpeed(
        entity,
        ticksPerSecond: 0,
      );

      final bodyIndex = world.body.indexOf(entity);
      if (!world.body.enabled[bodyIndex] ||
          world.body.isKinematic[bodyIndex] ||
          !scratch.profile.enabled ||
          scratch.profile.isKinematic ||
          !scratch.canGround) {
        world.terrainContact.clearSupport(entity);
        world.terrainContact.beganTickGrounded[world.terrainContact.indexOf(
              entity,
            )] =
            false;
      }
    }
  }

  @override
  double step(
    EcsWorld world, {
    required EntityId player,
    required MovementTuningDerived movement,
    required StaticWorldGeometryIndex legacyStaticWorld,
    required bool fixedPointPilotEnabled,
    required int fixedPointSubpixelScale,
    required int currentTick,
  }) {
    _refreshOrderedBodies(world);
    _preflightBodies(world, player: player, allowInitialization: false);
    _auditIntegrate(currentTick);
    lastIntegratedBodyCount = 0;
    var playerDistanceDelta = 0.0;
    for (final entity in _orderedBodies) {
      final scratch = _dynamicScratchFor(world, entity, player: player);
      if (scratch == null) continue;
      final bodyIndex = world.body.indexOf(entity);
      if (!world.body.enabled[bodyIndex] ||
          world.body.isKinematic[bodyIndex] ||
          !scratch.profile.enabled ||
          scratch.profile.isKinematic) {
        world.terrainContact.clearSupport(entity);
        world.resolvedMotion.setResolved(
          entity,
          displacementXTicks: 0,
          displacementYTicks: 0,
          travelAlongSupportTicks: 0,
        );
        continue;
      }

      final progression = _integrateBody(
        world,
        entity: entity,
        player: player,
        scratch: scratch,
        movement: movement,
        currentTick: currentTick,
      );
      lastIntegratedBodyCount += 1;
      if (entity == player) playerDistanceDelta = progression;
    }
    return playerDistanceDelta;
  }

  @override
  bool playerGrounded(EcsWorld world, EntityId player) {
    final index = world.terrainContact.indexOf(player);
    return world.terrainContact.grounded[index] &&
        world.terrainContact.supportGeometryVersion[index] == _geometry.version;
  }

  @override
  WorldBodyPlacementOrigin beginBodyTeleport(EcsWorld world, EntityId entity) {
    var origin = _currentPlacementOrigin(world, entity);
    final contactIndex = world.terrainContact.tryIndexOf(entity);
    if (contactIndex != null &&
        world.terrainContact.hasLastValidBodyPosition[contactIndex]) {
      var safeFacing = origin.facing;
      if (world.terrainContact.hasLastCapsuleState[contactIndex]) {
        safeFacing = _facingForOffsetSign(
          world,
          entity,
          world.terrainContact.lastCapsuleFacingSign[contactIndex],
        );
      }
      origin = WorldBodyPlacementOrigin(
        bodyX:
            world.terrainContact.lastValidBodyXTicks[contactIndex] /
            terrainPhysicsTicksPerWorldUnit,
        bodyY:
            world.terrainContact.lastValidBodyYTicks[contactIndex] /
            terrainPhysicsTicksPerWorldUnit,
        facing: safeFacing,
      );
      world.terrainContact.clearForTeleport(entity);
    } else if (contactIndex != null) {
      world.terrainContact.clearForTeleport(entity);
    }
    _clearNavigation(world, entity);
    if (world.collision.has(entity)) world.collision.resetTick(entity);
    if (world.resolvedMotion.has(entity)) {
      world.resolvedMotion.setResolved(
        entity,
        displacementXTicks: 0,
        displacementYTicks: 0,
        travelAlongSupportTicks: 0,
      );
    }
    return origin;
  }

  @override
  bool tryCommitBodyTeleport(
    EcsWorld world,
    EntityId entity, {
    required double bodyX,
    required double bodyY,
    required Facing facing,
  }) {
    final capsuleIndex = world.worldContactCapsule.tryIndexOf(entity);
    final profileIndex = world.terrainTraversalProfile.tryIndexOf(entity);
    if (capsuleIndex == null || profileIndex == null) {
      throw TerrainBodyStoreError(
        entity: entity,
        reason: 'teleport placement requires capsule and traversal stores',
      );
    }
    final facingSign = _facingOffsetSignFor(world, entity, facing);
    final capsule = TerrainPlacementCapsule(
      radiusTicks: world.worldContactCapsule.radiusTicks[capsuleIndex],
      verticalHalfSegmentTicks:
          world.worldContactCapsule.verticalHalfSegmentTicks[capsuleIndex],
      resolvedOffsetXTicks:
          world.worldContactCapsule.offsetXTicks[capsuleIndex] * facingSign,
      offsetYTicks: world.worldContactCapsule.offsetYTicks[capsuleIndex],
    );
    final result = _placementQuery.validateClearance(
      TerrainClearancePlacementRequest(
        bodyCenter: TerrainPoint(
          physicsCoordinateToTicks(bodyX, name: 'teleportBodyX'),
          physicsCoordinateToTicks(bodyY, name: 'teleportBodyY'),
        ),
        capsule: capsule,
        traversalProfile: world.terrainTraversalProfile.profile[profileIndex],
        oneWayClearancePolicy: TerrainOneWayClearancePolicy.ignore,
        expectedGeometryVersion: _geometry.version,
      ),
    );
    if (!_placementQuery.canCommit(result)) return false;

    final committedBody = result.bodyCenter!;
    final committedCapsule = result.capsuleCenter!;
    _writeBodyPlacement(
      world,
      entity,
      bodyX: committedBody.xTicks / terrainPhysicsTicksPerWorldUnit,
      bodyY: committedBody.yTicks / terrainPhysicsTicksPerWorldUnit,
      facing: facing,
    );
    _reinitializePlacementHistory(
      world,
      entity,
      body: committedBody,
      capsuleCenter: committedCapsule,
      facingSign: facingSign,
    );
    return true;
  }

  @override
  void cancelBodyTeleport(
    EcsWorld world,
    EntityId entity,
    WorldBodyPlacementOrigin origin,
  ) {
    _writeBodyPlacement(
      world,
      entity,
      bodyX: origin.bodyX,
      bodyY: origin.bodyY,
      facing: origin.facing,
    );
    final capsuleIndex = world.worldContactCapsule.tryIndexOf(entity);
    if (capsuleIndex == null || !world.terrainContact.has(entity)) return;
    final facingSign = _facingOffsetSignFor(world, entity, origin.facing);
    final body = TerrainPoint(
      physicsCoordinateToTicks(origin.bodyX, name: 'safeBodyX'),
      physicsCoordinateToTicks(origin.bodyY, name: 'safeBodyY'),
    );
    _reinitializePlacementHistory(
      world,
      entity,
      body: body,
      capsuleCenter: body.translated(
        world.worldContactCapsule.offsetXTicks[capsuleIndex] * facingSign,
        world.worldContactCapsule.offsetYTicks[capsuleIndex],
      ),
      facingSign: facingSign,
    );
  }

  @override
  GroundedEnemySpawnPlacement? resolveGroundedEnemySpawn({
    required EnemyId enemyId,
    required double desiredBodyX,
    required double requestedSupportY,
  }) {
    final profile = _enemyProfile(enemyId);
    if (!profile.canGround || _geometry.edges.isEmpty) return null;
    final archetype = _enemyCatalog.get(enemyId);
    final facingSign = Facing.left == archetype.artFacingDir ? 1 : -1;
    final desiredBodyXTicks = physicsCoordinateToTicks(
      desiredBodyX,
      name: 'groundEnemySpawnBodyX',
    );
    final requestedSupportYTicks = physicsCoordinateToTicks(
      requestedSupportY,
      name: 'groundEnemySpawnSupportY',
    );
    TerrainNavigationSurface? intendedSupport;
    for (final surface in _placementQuery.surfaceIndex.surfaces) {
      if (desiredBodyXTicks < surface.xMinTicks ||
          desiredBodyXTicks > surface.xMaxTicks ||
          surface.yAtXTicks(desiredBodyXTicks) != requestedSupportYTicks) {
        continue;
      }
      if (intendedSupport == null ||
          surface.id.compareTo(intendedSupport.id) < 0) {
        intendedSupport = surface;
      }
    }
    if (intendedSupport == null) return null;
    final minimumSupportY = math.min(
      intendedSupport.start.yTicks,
      intendedSupport.end.yTicks,
    );
    final maximumSupportY = math.max(
      intendedSupport.start.yTicks,
      intendedSupport.end.yTicks,
    );
    final result = _placementQuery.resolveGrounded(
      TerrainGroundPlacementRequest(
        desiredBodyCenterXTicks: desiredBodyXTicks,
        minimumSupportYTicks: minimumSupportY,
        maximumSupportYTicks: maximumSupportY,
        capsule: TerrainPlacementCapsule(
          radiusTicks: profile.capsule.radiusTicks,
          verticalHalfSegmentTicks: profile.capsule.verticalHalfSegmentTicks,
          resolvedOffsetXTicks: profile.capsule.offsetXTicks * facingSign,
          offsetYTicks: profile.capsule.offsetYTicks,
        ),
        traversalProfile: profile.traversal,
        supportRequirement: const TerrainSupportRequirement.groundedSpawn(),
        intendedSupportEdgeId: intendedSupport.id,
        expectedGeometryVersion: _geometry.version,
      ),
    );
    if (!_placementQuery.canCommit(result)) return null;
    final body = result.bodyCenter!;
    return GroundedEnemySpawnPlacement(
      bodyX: body.xTicks / terrainPhysicsTicksPerWorldUnit,
      bodyY: body.yTicks / terrainPhysicsTicksPerWorldUnit,
    );
  }

  @override
  double? flyingTerrainReferenceY(EcsWorld world, EntityId entity) {
    final capsuleIndex = world.worldContactCapsule.tryIndexOf(entity);
    final transformIndex = world.transform.tryIndexOf(entity);
    final enemyIndex = world.enemy.tryIndexOf(entity);
    if (capsuleIndex == null || transformIndex == null || enemyIndex == null) {
      return null;
    }
    if (_enemyProfile(world.enemy.enemyId[enemyIndex]).motionKind !=
        EnemyTerrainMotionKind.flyingDynamic) {
      return null;
    }

    final facingSign = _facingOffsetSign(world, entity);
    final centerX =
        physicsCoordinateToTicks(
          world.transform.posX[transformIndex],
          name: 'flyingReferenceBodyX',
        ) +
        world.worldContactCapsule.offsetXTicks[capsuleIndex] * facingSign;
    final centerY =
        physicsCoordinateToTicks(
          world.transform.posY[transformIndex],
          name: 'flyingReferenceBodyY',
        ) +
        world.worldContactCapsule.offsetYTicks[capsuleIndex];
    final radius = world.worldContactCapsule.radiusTicks[capsuleIndex];
    final capsuleBottom =
        centerY +
        radius +
        world.worldContactCapsule.verticalHalfSegmentTicks[capsuleIndex];
    var maximumGeometryY = _geometry.edges.first.bounds.maxY;
    for (final edge in _geometry.edges.skip(1)) {
      maximumGeometryY = math.max(maximumGeometryY, edge.bounds.maxY);
    }
    if (capsuleBottom > maximumGeometryY) return null;

    final footprintMinX = centerX - radius;
    final footprintMaxX = centerX + radius;
    _placementQuery.surfaceIndex.queryBounds(
      minX: footprintMinX,
      minY: capsuleBottom,
      maxX: footprintMaxX,
      maxY: maximumGeometryY,
      buffer: _flightSurfaceBuffer,
    );
    int? bestY;
    TerrainEdgeId? bestId;
    for (
      var candidateIndex = 0;
      candidateIndex < _flightSurfaceBuffer.candidateCount;
      candidateIndex += 1
    ) {
      final surface = _flightSurfaceBuffer.surfaceAt(
        candidateIndex,
        _placementQuery.surfaceIndex.surfaces,
      );
      if (surface.collisionMode != TerrainCollisionMode.solid) continue;
      final overlapMinX = math.max(footprintMinX, surface.xMinTicks);
      final overlapMaxX = math.min(footprintMaxX, surface.xMaxTicks);
      if (overlapMinX > overlapMaxX) continue;
      final leftY = surface.yAtXTicks(overlapMinX);
      final rightY = surface.yAtXTicks(overlapMaxX);
      if (leftY < capsuleBottom && rightY < capsuleBottom) continue;
      final candidateY = leftY < capsuleBottom || rightY < capsuleBottom
          ? capsuleBottom
          : math.min(leftY, rightY);
      if (bestY == null ||
          candidateY < bestY ||
          (candidateY == bestY && surface.id.compareTo(bestId!) < 0)) {
        bestY = candidateY;
        bestId = surface.id;
      }
    }
    return bestY == null ? null : bestY / terrainPhysicsTicksPerWorldUnit;
  }

  @override
  void resolveFlyingClearanceSteering(
    EcsWorld world,
    EntityId entity, {
    required double directVelocityX,
    required double directVelocityY,
    required double targetBodyX,
    required double targetBodyY,
    required int blockerNormalXTicks,
    required int blockerNormalYTicks,
    required int previewTicks,
    required int tickHz,
    required FlyingClearanceSteeringOutput out,
  }) {
    out.setDirect(directVelocityX, directVelocityY);
    if (previewTicks <= 0 || tickHz <= 0) return;
    if (blockerNormalXTicks == 0 && blockerNormalYTicks == 0) return;
    final transformIndex = world.transform.tryIndexOf(entity);
    final capsuleIndex = world.worldContactCapsule.tryIndexOf(entity);
    if (transformIndex == null || capsuleIndex == null) return;

    final directVelocityXTicks = physicsCoordinateToTicks(
      directVelocityX,
      name: 'flyingDirectVelocityX',
    );
    final directVelocityYTicks = physicsCoordinateToTicks(
      directVelocityY,
      name: 'flyingDirectVelocityY',
    );
    final speedTicks = _integerSqrt(
      directVelocityXTicks * directVelocityXTicks +
          directVelocityYTicks * directVelocityYTicks,
    );
    if (speedTicks == 0) return;

    final facingSign = _facingOffsetSign(world, entity);
    final offsetX =
        world.worldContactCapsule.offsetXTicks[capsuleIndex] * facingSign;
    final offsetY = world.worldContactCapsule.offsetYTicks[capsuleIndex];
    final bodyX = physicsCoordinateToTicks(
      world.transform.posX[transformIndex],
      name: 'flyingClearanceBodyX',
    );
    final bodyY = physicsCoordinateToTicks(
      world.transform.posY[transformIndex],
      name: 'flyingClearanceBodyY',
    );
    final centerX = bodyX + offsetX;
    final centerY = bodyY + offsetY;
    final targetDeltaX =
        physicsCoordinateToTicks(
          targetBodyX,
          name: 'flyingClearanceTargetX',
        ) -
        bodyX;
    final targetDeltaY =
        physicsCoordinateToTicks(
          targetBodyY,
          name: 'flyingClearanceTargetY',
        ) -
        bodyY;

    int? bestProgress;
    int? bestClearTravelSquared;
    var bestId = 0;
    var bestVelocityXTicks = directVelocityXTicks;
    var bestVelocityYTicks = directVelocityYTicks;
    for (var candidateId = 0; candidateId < 4; candidateId += 1) {
      final (velocityXTicks, velocityYTicks) = switch (candidateId) {
        0 => (directVelocityXTicks, directVelocityYTicks),
        1 => (
          _roundedDivide(
            -speedTicks * blockerNormalYTicks,
            terrainDirectionScale,
          ),
          _roundedDivide(
            speedTicks * blockerNormalXTicks,
            terrainDirectionScale,
          ),
        ),
        2 => (
          _roundedDivide(
            speedTicks * blockerNormalYTicks,
            terrainDirectionScale,
          ),
          _roundedDivide(
            -speedTicks * blockerNormalXTicks,
            terrainDirectionScale,
          ),
        ),
        _ => (
          _roundedDivide(
            speedTicks * blockerNormalXTicks,
            terrainDirectionScale,
          ),
          _roundedDivide(
            speedTicks * blockerNormalYTicks,
            terrainDirectionScale,
          ),
        ),
      };
      final request = TerrainMotionRequest(
        displacementXTicks: _roundedDivide(
          velocityXTicks * previewTicks,
          tickHz,
        ),
        displacementYTicks: _roundedDivide(
          velocityYTicks * previewTicks,
          tickHz,
        ),
        gravityYTicks: 0,
        surfaceDirectionSign: velocityXTicks.sign == 0
            ? facingSign
            : velocityXTicks.sign,
        mode: TerrainMotionMode.worldSpace,
      );
      _unocoScratch.controller.moveAt(
        centerXTicks: centerX,
        centerYTicks: centerY,
        radiusTicks: world.worldContactCapsule.radiusTicks[capsuleIndex],
        verticalHalfSegmentTicks:
            world.worldContactCapsule.verticalHalfSegmentTicks[capsuleIndex],
        request: request,
        beganGrounded: false,
        priorSupportEdgeId: null,
        priorSupportGeometryVersion: -1,
        lastValidCapsuleCenterXTicks: centerX,
        lastValidCapsuleCenterYTicks: centerY,
        out: _flyingPreviewResult,
      );
      final acceptedX = _flyingPreviewResult.finalCenterXTicks - centerX;
      final acceptedY = _flyingPreviewResult.finalCenterYTicks - centerY;
      final progress = acceptedX * targetDeltaX + acceptedY * targetDeltaY;
      final clearTravelSquared =
          acceptedX * acceptedX + acceptedY * acceptedY;
      final better =
          bestProgress == null ||
          progress > bestProgress ||
          (progress == bestProgress &&
              (clearTravelSquared > bestClearTravelSquared! ||
                  (clearTravelSquared == bestClearTravelSquared &&
                      candidateId < bestId)));
      if (!better) continue;
      bestProgress = progress;
      bestClearTravelSquared = clearTravelSquared;
      bestId = candidateId;
      bestVelocityXTicks = velocityXTicks;
      bestVelocityYTicks = velocityYTicks;
    }

    out.velocityX = bestId == 0
        ? directVelocityX
        : bestVelocityXTicks / terrainPhysicsTicksPerWorldUnit;
    out.velocityY = bestId == 0
        ? directVelocityY
        : bestVelocityYTicks / terrainPhysicsTicksPerWorldUnit;
    out.candidateId = bestId;
  }

  @override
  void beforeExternalBodyVelocity(
    EcsWorld world,
    EntityId entity, {
    required double velocityY,
  }) {
    if (velocityY < 0 && world.terrainContact.has(entity)) {
      world.terrainContact.clearSupport(entity);
      if (world.collision.has(entity)) {
        world.collision.grounded[world.collision.indexOf(entity)] = false;
      }
    }
  }

  @override
  void beforeBodyMotionStops(EcsWorld world, EntityId entity) {
    if (world.terrainContact.has(entity)) {
      world.terrainContact.clearSupport(entity);
    }
    if (world.collision.has(entity)) {
      world.collision.grounded[world.collision.indexOf(entity)] = false;
    }
  }

  double _integrateBody(
    EcsWorld world, {
    required EntityId entity,
    required EntityId player,
    required _TerrainMotionScratch scratch,
    required MovementTuningDerived movement,
    required int currentTick,
  }) {
    final transformIndex = world.transform.indexOf(entity);
    final capsuleIndex = world.worldContactCapsule.indexOf(entity);
    final resolvedIndex = world.resolvedMotion.indexOf(entity);
    final contactIndex = world.terrainContact.indexOf(entity);
    final currentFacingSign = _facingOffsetSign(world, entity);
    final currentOffsetX =
        world.worldContactCapsule.offsetXTicks[capsuleIndex] *
        currentFacingSign;
    final offsetY = world.worldContactCapsule.offsetYTicks[capsuleIndex];
    final bodyStartX = physicsCoordinateToTicks(
      world.transform.posX[transformIndex],
      name: 'bodyStartX',
    );
    final bodyStartY = physicsCoordinateToTicks(
      world.transform.posY[transformIndex],
      name: 'bodyStartY',
    );
    final hasLastCapsule =
        world.terrainContact.hasLastCapsuleState[contactIndex];
    final previousFacingSign = hasLastCapsule
        ? world.terrainContact.lastCapsuleFacingSign[contactIndex]
        : currentFacingSign;
    final previousOffsetX =
        world.worldContactCapsule.offsetXTicks[capsuleIndex] *
        previousFacingSign;
    final startCapsuleCenterX = hasLastCapsule
        ? world.terrainContact.lastCapsuleCenterXTicks[contactIndex]
        : bodyStartX + previousOffsetX;
    final startCapsuleCenterY = hasLastCapsule
        ? world.terrainContact.lastCapsuleCenterYTicks[contactIndex]
        : bodyStartY + offsetY;

    final bodyDisplacementX = physicsCoordinateToTicks(
      world.transform.velX[transformIndex] * movement.dtSeconds,
      name: 'bodyDisplacementX',
    );
    final bodyDisplacementY = physicsCoordinateToTicks(
      world.transform.velY[transformIndex] * movement.dtSeconds,
      name: 'bodyDisplacementY',
    );
    final gravityDisplacementY = _roundedDivide(
      world.resolvedMotion.appliedGravityVelocityDeltaYTicks[resolvedIndex],
      movement.tickHz,
    );
    final beganGrounded =
        scratch.canGround &&
        world.terrainContact.beganTickGrounded[contactIndex] &&
        world.terrainContact.grounded[contactIndex] &&
        world.terrainContact.snapEligibleAtTickStart[contactIndex];
    final isPlayer = entity == player;
    final movementIndex = isPlayer ? world.movement.indexOf(entity) : -1;
    final dashing = isPlayer && world.movement.dashTicksLeft[movementIndex] > 0;
    final groundedEnemy =
        !isPlayer &&
        scratch.motionKind == EnemyTerrainMotionKind.groundedDynamic;
    final mode = scratch.canGround
        ? dashing && world.terrainContact.mobilityStartedGrounded[contactIndex]
              ? TerrainMotionMode.groundedSurface
              : beganGrounded
              ? groundedEnemy
                    ? TerrainMotionMode.groundedSurface
                    : TerrainMotionMode.groundedHorizontal
              : TerrainMotionMode.worldSpace
        : TerrainMotionMode.worldSpace;
    final surfaceDirectionSign = dashing
        ? world.terrainContact.mobilitySurfaceDirectionSign[contactIndex]
        : world.transform.velX[transformIndex].sign == 0
        ? currentFacingSign
        : world.transform.velX[transformIndex].sign.toInt();
    final request = TerrainMotionRequest(
      displacementXTicks: bodyDisplacementX + currentOffsetX - previousOffsetX,
      displacementYTicks: bodyDisplacementY - gravityDisplacementY,
      gravityYTicks: gravityDisplacementY,
      surfaceDirectionSign: surfaceDirectionSign,
      mode: mode,
    );
    world.resolvedMotion.beginTick(
      entity,
      capsuleCenterXTicks: startCapsuleCenterX,
      capsuleCenterYTicks: startCapsuleCenterY,
      request: request,
    );

    final hasLastValid =
        world.terrainContact.hasLastValidBodyPosition[contactIndex];
    final result = scratch.result;
    scratch.controller.moveAt(
      centerXTicks: startCapsuleCenterX,
      centerYTicks: startCapsuleCenterY,
      radiusTicks: world.worldContactCapsule.radiusTicks[capsuleIndex],
      verticalHalfSegmentTicks:
          world.worldContactCapsule.verticalHalfSegmentTicks[capsuleIndex],
      request: request,
      beganGrounded: beganGrounded,
      priorSupportEdgeId: scratch.canGround
          ? world.terrainContact.supportEdgeId[contactIndex]
          : null,
      priorSupportGeometryVersion: scratch.canGround
          ? world.terrainContact.supportGeometryVersion[contactIndex]
          : -1,
      lastValidCapsuleCenterXTicks: hasLastValid
          ? world.terrainContact.lastValidBodyXTicks[contactIndex] +
                currentOffsetX
          : null,
      lastValidCapsuleCenterYTicks: hasLastValid
          ? world.terrainContact.lastValidBodyYTicks[contactIndex] + offsetY
          : null,
      out: result,
    );

    final finalBodyX = result.finalCenterXTicks - currentOffsetX;
    final finalBodyY = result.finalCenterYTicks - offsetY;
    world.transform.posX[transformIndex] =
        finalBodyX / terrainPhysicsTicksPerWorldUnit;
    world.transform.posY[transformIndex] =
        finalBodyY / terrainPhysicsTicksPerWorldUnit;
    _writeResolvedVelocity(
      world,
      entity: entity,
      requestMode: mode,
      surfaceDirectionSign: surfaceDirectionSign,
      transformIndex: transformIndex,
      scratch: scratch,
    );
    _writeContactState(
      world,
      entity: entity,
      currentTick: currentTick,
      scratch: scratch,
    );
    world.resolvedMotion.setResolved(
      entity,
      displacementXTicks: finalBodyX - bodyStartX,
      displacementYTicks: finalBodyY - bodyStartY,
      travelAlongSupportTicks: scratch.canGround
          ? result.supportedTravelTicks
          : 0,
    );
    if (result.diagnostic != TerrainControllerDiagnostic.recoveryFailed) {
      world.terrainContact.setLastValidBodyPosition(
        entity,
        xTicks: finalBodyX,
        yTicks: finalBodyY,
      );
    }
    world.terrainContact.setLastCapsuleState(
      entity,
      centerXTicks: result.finalCenterXTicks,
      centerYTicks: result.finalCenterYTicks,
      facingSign: currentFacingSign,
    );
    final progressionBodyX =
        result.progressionXTicks - (currentOffsetX - previousOffsetX);
    return math
        .max(0, progressionBodyX / terrainPhysicsTicksPerWorldUnit)
        .toDouble();
  }

  void _writeContactState(
    EcsWorld world, {
    required EntityId entity,
    required int currentTick,
    required _TerrainMotionScratch scratch,
  }) {
    final terrain = world.terrainContact;
    final terrainIndex = terrain.indexOf(entity);
    final result = scratch.result;
    terrain.hitCeiling[terrainIndex] = result.hitCeiling;
    terrain.hitLeft[terrainIndex] = result.hitLeft;
    terrain.hitRight[terrainIndex] = result.hitRight;
    terrain.wallNormalXTicks[terrainIndex] = result.wallNormalXTicks;
    terrain.wallNormalYTicks[terrainIndex] = result.wallNormalYTicks;
    terrain.ceilingNormalXTicks[terrainIndex] = result.ceilingNormalXTicks;
    terrain.ceilingNormalYTicks[terrainIndex] = result.ceilingNormalYTicks;
    terrain.usedStep[terrainIndex] = result.usedStep;
    terrain.usedSnap[terrainIndex] = result.usedSnap;
    terrain.usedRecovery[terrainIndex] = result.usedRecovery;
    terrain.blockingContactCount[terrainIndex] = result.contactCount;
    for (
      var contactIndex = 0;
      contactIndex < terrainMaxBlockingContacts;
      contactIndex += 1
    ) {
      terrain.blockingContactEdgeIds[terrainIndex][contactIndex] =
          result.contactEdgeIds[contactIndex];
      terrain.blockingContactKinds[terrainIndex][contactIndex] =
          result.contactKinds[contactIndex];
      terrain.blockingContactFeatures[terrainIndex][contactIndex] =
          result.contactFeatures[contactIndex];
      terrain.blockingContactNormalXTicks[terrainIndex][contactIndex] =
          result.contactNormalXTicks[contactIndex];
      terrain.blockingContactNormalYTicks[terrainIndex][contactIndex] =
          result.contactNormalYTicks[contactIndex];
    }
    terrain.contactIterations[terrainIndex] = result.contactIterations;
    terrain.recoveryIterations[terrainIndex] = result.recoveryIterations;
    terrain.candidateCount[terrainIndex] = result.candidateCount;
    terrain.queryCellsVisited[terrainIndex] = result.queryCellsVisited;
    terrain.diagnostic[terrainIndex] = result.diagnostic;
    if (scratch.canGround && result.grounded && result.supportEdgeId != null) {
      final edge = _geometry.edgeById[result.supportEdgeId];
      if (edge == null) {
        throw StateError('Controller returned support outside its geometry.');
      }
      terrain.setSupport(
        entity,
        edge: edge,
        pointXTicks: result.supportPointXTicks,
        pointYTicks: result.supportPointYTicks,
        geometryVersion: _geometry.version,
        currentTick: currentTick,
        slopeAngleUnits:
            scratch.traversalCache[edge.id].absoluteSlopeAngleUnits,
      );
    } else {
      terrain.clearSupport(entity);
    }

    final collisionIndex = world.collision.indexOf(entity);
    world.collision.grounded[collisionIndex] =
        scratch.canGround && result.grounded;
    world.collision.hitCeiling[collisionIndex] = result.hitCeiling;
    world.collision.hitLeft[collisionIndex] = result.hitLeft;
    world.collision.hitRight[collisionIndex] = result.hitRight;

    if (scratch.motionKind == EnemyTerrainMotionKind.flyingDynamic) {
      final steeringIndex = world.flyingEnemySteering.tryIndexOf(entity);
      if (steeringIndex != null) {
        final blocked = result.contactCount > 0;
        world.flyingEnemySteering.terrainBlockedLastTick[steeringIndex] =
            blocked;
        world.flyingEnemySteering.blockingNormalXTicks[steeringIndex] =
            blocked ? result.contactNormalXTicks[0] : 0;
        world.flyingEnemySteering.blockingNormalYTicks[steeringIndex] =
            blocked ? result.contactNormalYTicks[0] : 0;
      }
    }
  }

  void _writeResolvedVelocity(
    EcsWorld world, {
    required EntityId entity,
    required TerrainMotionMode requestMode,
    required int surfaceDirectionSign,
    required int transformIndex,
    required _TerrainMotionScratch scratch,
  }) {
    final result = scratch.result;
    var velocityX = physicsCoordinateToTicks(
      world.transform.velX[transformIndex],
      name: 'velocityX',
    );
    var velocityY = physicsCoordinateToTicks(
      world.transform.velY[transformIndex],
      name: 'velocityY',
    );
    if (scratch.canGround &&
        result.grounded &&
        requestMode == TerrainMotionMode.groundedSurface) {
      final resolvedIndex = world.resolvedMotion.indexOf(entity);
      velocityY -=
          world.resolvedMotion.appliedGravityVelocityDeltaYTicks[resolvedIndex];
    }
    for (var index = 0; index < result.contactCount; index += 1) {
      final normalX = result.contactNormalXTicks[index];
      final normalY = result.contactNormalYTicks[index];
      final dot = velocityX * normalX + velocityY * normalY;
      if (dot >= 0) continue;
      velocityX -= _roundedDivide(
        dot * normalX,
        terrainDirectionScale * terrainDirectionScale,
      );
      velocityY -= _roundedDivide(
        dot * normalY,
        terrainDirectionScale * terrainDirectionScale,
      );
    }
    if (scratch.canGround &&
        result.grounded &&
        requestMode == TerrainMotionMode.groundedHorizontal &&
        result.supportTangentXTicks.abs() >=
            scratch.profile.minimumSupportUpComponent) {
      velocityY = _roundedDivide(
        velocityX * result.supportTangentYTicks,
        result.supportTangentXTicks,
      );
    } else if (scratch.canGround &&
        result.grounded &&
        requestMode == TerrainMotionMode.groundedSurface) {
      final speed = _integerSqrt(velocityX * velocityX + velocityY * velocityY);
      final tangentSign =
          result.supportTangentXTicks.sign == surfaceDirectionSign ? 1 : -1;
      velocityX = _roundedDivide(
        speed * result.supportTangentXTicks * tangentSign,
        terrainDirectionScale,
      );
      velocityY = _roundedDivide(
        speed * result.supportTangentYTicks * tangentSign,
        terrainDirectionScale,
      );
    }
    if ((result.hitRight && velocityX > 0) ||
        (result.hitLeft && velocityX < 0)) {
      velocityX = 0;
    }
    if (result.hitCeiling && velocityY < 0) velocityY = 0;
    if (result.grounded && requestMode == TerrainMotionMode.worldSpace) {
      final supportDot =
          velocityX * result.supportNormalXTicks +
          velocityY * result.supportNormalYTicks;
      if (supportDot < 0) {
        velocityX -= _roundedDivide(
          supportDot * result.supportNormalXTicks,
          terrainDirectionScale * terrainDirectionScale,
        );
        velocityY -= _roundedDivide(
          supportDot * result.supportNormalYTicks,
          terrainDirectionScale * terrainDirectionScale,
        );
      }
    }
    world.transform.velX[transformIndex] =
        velocityX / terrainPhysicsTicksPerWorldUnit;
    world.transform.velY[transformIndex] =
        velocityY / terrainPhysicsTicksPerWorldUnit;
  }

  void _refreshOrderedBodies(EcsWorld world) {
    _orderedBodies.clear();
    for (final entity in world.body.denseEntities) {
      var insertAt = _orderedBodies.length;
      _orderedBodies.add(entity);
      while (insertAt > 0 && _orderedBodies[insertAt - 1] > entity) {
        _orderedBodies[insertAt] = _orderedBodies[insertAt - 1];
        insertAt -= 1;
      }
      _orderedBodies[insertAt] = entity;
    }
  }

  void _preflightBodies(
    EcsWorld world, {
    required EntityId player,
    required bool allowInitialization,
  }) {
    for (final entity in _orderedBodies) {
      if (entity == player) {
        _requireActorBaseStores(world, entity, requireMovement: true);
        _requireDynamicTerrainStores(
          world,
          entity: entity,
          expectedProfile: _playerScratch.profile,
          allowAbsent: false,
        );
        continue;
      }

      final enemyIndex = world.enemy.tryIndexOf(entity);
      if (enemyIndex != null) {
        _requireActorBaseStores(world, entity);
        final profile = _enemyProfile(world.enemy.enemyId[enemyIndex]);
        final bodyIndex = world.body.indexOf(entity);
        if (profile.motionKind == EnemyTerrainMotionKind.kinematicPlacement) {
          if (!world.body.isKinematic[bodyIndex]) {
            throw TerrainBodyStoreError(
              entity: entity,
              reason: 'kinematic-placement policy has a dynamic body',
            );
          }
          _requireKinematicTerrainStores(
            world,
            entity: entity,
            expected: profile,
            allowAbsent: allowInitialization,
          );
        } else {
          _requireDynamicTerrainStores(
            world,
            entity: entity,
            expectedProfile: profile.traversal,
            expectedCapsule: profile.capsule,
            allowAbsent: allowInitialization,
          );
        }
        continue;
      }

      final bodyIndex = world.body.indexOf(entity);
      if (!world.body.enabled[bodyIndex] || world.body.isKinematic[bodyIndex]) {
        continue;
      }
      throw TerrainUnsupportedBodyError(
        entity: entity,
        disposition: terrainBodyDisposition(
          world,
          entity: entity,
          terrainPlayer: player,
        ),
      );
    }
  }

  void _requireActorBaseStores(
    EcsWorld world,
    EntityId entity, {
    bool requireMovement = false,
  }) {
    final complete =
        world.transform.has(entity) &&
        world.colliderAabb.has(entity) &&
        world.collision.has(entity) &&
        (!requireMovement || world.movement.has(entity));
    if (!complete) {
      throw TerrainBodyStoreError(
        entity: entity,
        reason: 'required transform/collider/collision stores are missing',
      );
    }
  }

  void _requireDynamicTerrainStores(
    EcsWorld world, {
    required EntityId entity,
    required TerrainTraversalProfile expectedProfile,
    WorldContactCapsuleDef? expectedCapsule,
    required bool allowAbsent,
  }) {
    final hasCapsule = world.worldContactCapsule.has(entity);
    final hasProfile = world.terrainTraversalProfile.has(entity);
    final hasContact = world.terrainContact.has(entity);
    final hasResolved = world.resolvedMotion.has(entity);
    final count =
        (hasCapsule ? 1 : 0) +
        (hasProfile ? 1 : 0) +
        (hasContact ? 1 : 0) +
        (hasResolved ? 1 : 0);
    if (count == 0 && allowAbsent) return;
    if (count != 4) {
      throw TerrainBodyStoreError(
        entity: entity,
        reason: count == 0
            ? 'terrain stores were not initialized during prepareTick'
            : 'terrain stores are partial ($count of 4)',
      );
    }
    _validateAttachedPolicy(
      world,
      entity: entity,
      expectedProfile: expectedProfile,
      expectedCapsule: expectedCapsule,
    );
  }

  void _requireKinematicTerrainStores(
    EcsWorld world, {
    required EntityId entity,
    required EnemyTerrainContactProfile expected,
    required bool allowAbsent,
  }) {
    final hasCapsule = world.worldContactCapsule.has(entity);
    final hasProfile = world.terrainTraversalProfile.has(entity);
    final hasContact = world.terrainContact.has(entity);
    final hasResolved = world.resolvedMotion.has(entity);
    final count =
        (hasCapsule ? 1 : 0) +
        (hasProfile ? 1 : 0) +
        (hasContact ? 1 : 0) +
        (hasResolved ? 1 : 0);
    if (count == 0 && allowAbsent) return;
    if (!hasCapsule || !hasProfile || hasContact || hasResolved) {
      throw TerrainBodyStoreError(
        entity: entity,
        reason: count == 0
            ? 'kinematic placement stores were not initialized during prepareTick'
            : 'kinematic placement requires capsule/profile stores only',
      );
    }
    _validateAttachedPolicy(
      world,
      entity: entity,
      expectedProfile: expected.traversal,
      expectedCapsule: expected.capsule,
    );
  }

  void _validateAttachedPolicy(
    EcsWorld world, {
    required EntityId entity,
    required TerrainTraversalProfile expectedProfile,
    WorldContactCapsuleDef? expectedCapsule,
  }) {
    final profileIndex = world.terrainTraversalProfile.indexOf(entity);
    if (!identical(
      world.terrainTraversalProfile.profile[profileIndex],
      expectedProfile,
    )) {
      throw TerrainBodyStoreError(
        entity: entity,
        reason: 'attached traversal profile differs from catalog policy',
      );
    }
    if (expectedCapsule == null) return;
    final capsuleIndex = world.worldContactCapsule.indexOf(entity);
    if (world.worldContactCapsule.radiusTicks[capsuleIndex] !=
            expectedCapsule.radiusTicks ||
        world.worldContactCapsule.verticalHalfSegmentTicks[capsuleIndex] !=
            expectedCapsule.verticalHalfSegmentTicks ||
        world.worldContactCapsule.offsetXTicks[capsuleIndex] !=
            expectedCapsule.offsetXTicks ||
        world.worldContactCapsule.offsetYTicks[capsuleIndex] !=
            expectedCapsule.offsetYTicks) {
      throw TerrainBodyStoreError(
        entity: entity,
        reason: 'attached capsule differs from catalog policy',
      );
    }
  }

  void _initializePendingEnemyStores(EcsWorld world) {
    for (final entity in _orderedBodies) {
      final enemyIndex = world.enemy.tryIndexOf(entity);
      if (enemyIndex == null || world.worldContactCapsule.has(entity)) continue;
      final profile = _enemyProfile(world.enemy.enemyId[enemyIndex]);
      world.worldContactCapsule.add(entity, profile.capsule);
      world.terrainTraversalProfile.add(entity, profile.traversal);
      if (profile.motionKind != EnemyTerrainMotionKind.kinematicPlacement) {
        world.terrainContact.add(entity);
        world.resolvedMotion.add(entity);
      }
    }
  }

  EnemyTerrainContactProfile _enemyProfile(EnemyId id) => switch (id) {
    EnemyId.grojib => _grojibProfile,
    EnemyId.hashash => _hashashProfile,
    EnemyId.unocoDemon => _unocoProfile,
    EnemyId.derf => _derfProfile,
  };

  _TerrainMotionScratch? _dynamicScratchFor(
    EcsWorld world,
    EntityId entity, {
    required EntityId player,
  }) {
    if (entity == player) return _playerScratch;
    final enemyIndex = world.enemy.tryIndexOf(entity);
    if (enemyIndex == null) return null;
    return switch (world.enemy.enemyId[enemyIndex]) {
      EnemyId.grojib => _grojibScratch,
      EnemyId.hashash => _hashashScratch,
      EnemyId.unocoDemon => _unocoScratch,
      EnemyId.derf => null,
    };
  }

  bool _isKinematicPlacementEnemy(EcsWorld world, EntityId entity) {
    final enemyIndex = world.enemy.tryIndexOf(entity);
    return enemyIndex != null &&
        world.enemy.enemyId[enemyIndex] == EnemyId.derf;
  }

  void _reinitializePlacementHistory(
    EcsWorld world,
    EntityId entity, {
    required TerrainPoint body,
    required TerrainPoint capsuleCenter,
    required int facingSign,
  }) {
    if (world.terrainContact.has(entity)) {
      world.terrainContact.clearSupport(entity);
      world.terrainContact.setLastValidBodyPosition(
        entity,
        xTicks: body.xTicks,
        yTicks: body.yTicks,
      );
      world.terrainContact.setLastCapsuleState(
        entity,
        centerXTicks: capsuleCenter.xTicks,
        centerYTicks: capsuleCenter.yTicks,
        facingSign: facingSign,
      );
    }
    final collisionIndex = world.collision.tryIndexOf(entity);
    if (collisionIndex != null) {
      world.collision.grounded[collisionIndex] = false;
    }
  }

  void _clearNavigation(EcsWorld world, EntityId entity) {
    final navIndex = world.surfaceNav.tryIndexOf(entity);
    if (navIndex == null) return;
    world.surfaceNav.graphVersion[navIndex] = -1;
    world.surfaceNav.repathTicksLeft[navIndex] = 0;
    world.surfaceNav.currentSurfaceId[navIndex] = surfaceIdUnknown;
    world.surfaceNav.lastGroundSurfaceId[navIndex] = surfaceIdUnknown;
    world.surfaceNav.targetSurfaceId[navIndex] = surfaceIdUnknown;
    world.surfaceNav.activeEdgeIndex[navIndex] = -1;
    world.surfaceNav.pathCursor[navIndex] = 0;
    world.surfaceNav.pathEdges[navIndex].clear();
  }

  void _invalidateStaleNavigation(EcsWorld world, EntityId entity) {
    final navIndex = world.surfaceNav.tryIndexOf(entity);
    if (navIndex == null) return;
    final contactIndex = world.terrainContact.indexOf(entity);
    final staleSupport =
        world.terrainContact.supportGeometryVersion[contactIndex] >= 0 &&
        world.terrainContact.supportGeometryVersion[contactIndex] !=
            _geometry.version;
    final stalePath =
        world.surfaceNav.graphVersion[navIndex] >= 0 &&
        world.surfaceNav.graphVersion[navIndex] != _geometry.version;
    if (!staleSupport && !stalePath) return;
    _clearNavigation(world, entity);
  }

  void _auditPrepare(int currentTick) {
    if (_preparedTick >= 0 && _integratedTick != _preparedTick) {
      throw StateError(
        'Terrain motion prepared tick $_preparedTick but did not integrate it.',
      );
    }
    if (_preparedTick == currentTick) {
      throw StateError('Terrain motion prepared tick $currentTick twice.');
    }
    _preparedTick = currentTick;
  }

  void _auditIntegrate(int currentTick) {
    if (_preparedTick != currentTick) {
      throw StateError(
        'Terrain motion tick $currentTick was not prepared exactly once.',
      );
    }
    if (_integratedTick == currentTick) {
      throw StateError('Terrain motion integrated tick $currentTick twice.');
    }
    _integratedTick = currentTick;
  }
}

final class _TerrainMotionScratch {
  _TerrainMotionScratch({
    required this.profile,
    required this.motionKind,
    required TerrainGeometry geometry,
    required TerrainEdgeIndex edgeIndex,
  }) : traversalCache = TerrainTraversalCache.fromGeometry(geometry),
       controller = TerrainCapsuleController(
         geometry: geometry,
         index: edgeIndex,
         profile: profile,
       );

  final TerrainTraversalProfile profile;
  final EnemyTerrainMotionKind motionKind;
  final TerrainTraversalCache traversalCache;
  final TerrainCapsuleController controller;
  final TerrainCapsuleMotionResult result = TerrainCapsuleMotionResult();

  bool get canGround => motionKind == EnemyTerrainMotionKind.groundedDynamic;
}

WorldBodyPlacementOrigin _currentPlacementOrigin(
  EcsWorld world,
  EntityId entity,
) {
  final transformIndex = world.transform.indexOf(entity);
  final movementIndex = world.movement.tryIndexOf(entity);
  final enemyIndex = world.enemy.tryIndexOf(entity);
  return WorldBodyPlacementOrigin(
    bodyX: world.transform.posX[transformIndex],
    bodyY: world.transform.posY[transformIndex],
    facing: movementIndex != null
        ? world.movement.facing[movementIndex]
        : enemyIndex != null
        ? world.enemy.facing[enemyIndex]
        : Facing.right,
  );
}

void _writeBodyPlacement(
  EcsWorld world,
  EntityId entity, {
  required double bodyX,
  required double bodyY,
  required Facing facing,
}) {
  final transformIndex = world.transform.indexOf(entity);
  world.transform.posX[transformIndex] = bodyX;
  world.transform.posY[transformIndex] = bodyY;
  final movementIndex = world.movement.tryIndexOf(entity);
  if (movementIndex != null) world.movement.facing[movementIndex] = facing;
  final enemyIndex = world.enemy.tryIndexOf(entity);
  if (enemyIndex != null) world.enemy.facing[enemyIndex] = facing;
}

int _facingOffsetSignFor(EcsWorld world, EntityId entity, Facing facing) {
  final movementIndex = world.movement.tryIndexOf(entity);
  if (movementIndex != null) {
    return facing == world.movement.artFacing[movementIndex] ? 1 : -1;
  }
  final enemyIndex = world.enemy.tryIndexOf(entity);
  if (enemyIndex != null) {
    return facing == world.enemy.artFacing[enemyIndex] ? 1 : -1;
  }
  return 1;
}

Facing _facingForOffsetSign(EcsWorld world, EntityId entity, int sign) {
  final movementIndex = world.movement.tryIndexOf(entity);
  if (movementIndex != null) {
    final artFacing = world.movement.artFacing[movementIndex];
    return sign == 1 ? artFacing : _oppositeFacing(artFacing);
  }
  final enemyIndex = world.enemy.tryIndexOf(entity);
  if (enemyIndex != null) {
    final artFacing = world.enemy.artFacing[enemyIndex];
    return sign == 1 ? artFacing : _oppositeFacing(artFacing);
  }
  return Facing.right;
}

Facing _oppositeFacing(Facing facing) =>
    facing == Facing.right ? Facing.left : Facing.right;

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
