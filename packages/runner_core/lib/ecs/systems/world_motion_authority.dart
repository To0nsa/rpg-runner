import 'dart:math' as math;

import '../../collision/static_world_geometry_index.dart';
import '../../collision/terrain/terrain_capsule_controller.dart';
import '../../collision/terrain/terrain_controller_diagnostic.dart';
import '../../collision/terrain/terrain_edge_index.dart';
import '../../collision/terrain/terrain_geometry.dart';
import '../../collision/terrain/terrain_motion_request.dart';
import '../../collision/terrain/terrain_numeric.dart';
import '../../collision/terrain/terrain_traversal_profile.dart';
import '../../collision/terrain/terrain_traversal_cache.dart';
import '../../collision/terrain/upright_capsule.dart';
import '../../players/player_archetype.dart';
import '../../players/player_tuning.dart';
import '../../enemies/enemy_id.dart';
import '../entity_id.dart';
import '../world.dart';
import 'collision_system.dart';

/// One integration owner for dynamic-body movement during a Core tick.
///
/// Normal GameCore construction uses [LegacyWorldMotionAuthority]. The
/// narrowly scoped terrain harness uses [TerrainPlayerWorldMotionAuthority]
/// and rejects unsupported dynamic non-player bodies.
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

  void beforePlayerTeleport(EcsWorld world, EntityId player);

  void beforeExternalPlayerVelocity(
    EcsWorld world,
    EntityId player, {
    required double velocityY,
  });

  void beforePlayerMotionStops(EcsWorld world, EntityId player);
}

/// Explicit Phase 2 disposition for bodies that are not the terrain player.
enum TerrainPhase2BodyDisposition {
  terrainPlayer,
  disabledIgnored,
  groundedEnemyAwaitingProfile,
  flyingEnemyAwaitingContact,
  derfKinematicClearanceDeferred,
  hashashTeleportClearanceDeferred,
  ballisticProjectileAwaitingSweptCircle,
  otherKinematicIgnored,
  unsupportedDynamicBody,
}

/// Typed failure used instead of silently falling back to rectangle motion.
class TerrainUnsupportedBodyError extends StateError {
  TerrainUnsupportedBodyError({required this.entity, required this.disposition})
    : super(
        'Phase 2 terrain motion rejected body $entity '
        '(${disposition.name}); it requires its later-phase migration.',
      );

  final EntityId entity;
  final TerrainPhase2BodyDisposition disposition;
}

/// Classifies a body without granting it Phase 2 terrain authority.
TerrainPhase2BodyDisposition terrainPhase2BodyDisposition(
  EcsWorld world, {
  required EntityId entity,
  required EntityId terrainPlayer,
}) {
  final bodyIndex = world.body.indexOf(entity);
  if (!world.body.enabled[bodyIndex]) {
    return TerrainPhase2BodyDisposition.disabledIgnored;
  }
  final hasCompleteTerrainCapsule =
      world.worldContactCapsule.has(entity) &&
      world.terrainTraversalProfile.has(entity) &&
      world.terrainContact.has(entity) &&
      world.resolvedMotion.has(entity);
  if (hasCompleteTerrainCapsule) {
    return entity == terrainPlayer
        ? TerrainPhase2BodyDisposition.terrainPlayer
        : TerrainPhase2BodyDisposition.unsupportedDynamicBody;
  }
  if (entity == terrainPlayer) {
    return TerrainPhase2BodyDisposition.unsupportedDynamicBody;
  }
  final projectileIndex = world.projectile.tryIndexOf(entity);
  if (projectileIndex != null && world.projectile.usePhysics[projectileIndex]) {
    return TerrainPhase2BodyDisposition.ballisticProjectileAwaitingSweptCircle;
  }
  final enemyIndex = world.enemy.tryIndexOf(entity);
  if (enemyIndex != null) {
    switch (world.enemy.enemyId[enemyIndex]) {
      case EnemyId.grojib:
        return TerrainPhase2BodyDisposition.groundedEnemyAwaitingProfile;
      case EnemyId.unocoDemon:
        return TerrainPhase2BodyDisposition.flyingEnemyAwaitingContact;
      case EnemyId.derf:
        return TerrainPhase2BodyDisposition.derfKinematicClearanceDeferred;
      case EnemyId.hashash:
        return TerrainPhase2BodyDisposition.hashashTeleportClearanceDeferred;
    }
  }
  if (world.body.isKinematic[bodyIndex]) {
    return TerrainPhase2BodyDisposition.otherKinematicIgnored;
  }
  return TerrainPhase2BodyDisposition.unsupportedDynamicBody;
}

/// Adapter preserving the pre-slopes rectangle integration path exactly.
class LegacyWorldMotionAuthority implements WorldMotionAuthority {
  final CollisionSystem _collision = CollisionSystem();
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
  void beforePlayerTeleport(EcsWorld world, EntityId player) {}

  @override
  void beforeExternalPlayerVelocity(
    EcsWorld world,
    EntityId player, {
    required double velocityY,
  }) {}

  @override
  void beforePlayerMotionStops(EcsWorld world, EntityId player) {}

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

/// Isolated Phase 2 player-only terrain integration authority.
///
/// This owner is intentionally unsuitable for normal levels until Phase 3
/// migrates enemies and other dynamic bodies.
class TerrainPlayerWorldMotionAuthority implements WorldMotionAuthority {
  factory TerrainPlayerWorldMotionAuthority({
    required TerrainGeometry geometry,
    required TerrainTraversalProfile profile,
  }) {
    final edgeIndex = TerrainEdgeIndex(edges: geometry.edges);
    return TerrainPlayerWorldMotionAuthority._(
      geometry: geometry,
      profile: profile,
      controller: TerrainCapsuleController(
        geometry: geometry,
        index: edgeIndex,
        profile: profile,
      ),
    );
  }

  TerrainPlayerWorldMotionAuthority._({
    required TerrainGeometry geometry,
    required TerrainTraversalProfile profile,
    required TerrainCapsuleController controller,
  }) : _geometry = geometry,
       _profile = profile,
       _traversalCache = TerrainTraversalCache.fromGeometry(geometry),
       _controller = controller;

  final TerrainGeometry _geometry;
  final TerrainTraversalProfile _profile;
  final TerrainTraversalCache _traversalCache;
  final TerrainCapsuleController _controller;
  final TerrainCapsuleMotionResult _result = TerrainCapsuleMotionResult();
  int _preparedTick = -1;
  int _integratedTick = -1;

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
      throw StateError('Terrain player motion requires exposed terrain edges.');
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
    _controller.placeOnFirstSupportBelow(
      capsule: startCapsule,
      maximumDistanceTicks: fallDistance,
      out: _result,
    );
    if (!_result.grounded || _result.supportEdgeId == null) {
      throw StateError(
        'Terrain player spawn X has no clear walkable support below it.',
      );
    }

    final finalBodyX = _result.finalCenterXTicks - offsetX;
    final finalBodyY = _result.finalCenterYTicks - offsetY;
    world.transform.posX[transformIndex] =
        finalBodyX / terrainPhysicsTicksPerWorldUnit;
    world.transform.posY[transformIndex] =
        finalBodyY / terrainPhysicsTicksPerWorldUnit;
    world.transform.velX[transformIndex] = 0;
    world.transform.velY[transformIndex] = 0;
    _writeContactState(world, player: player, currentTick: 0);
    final contactIndex = world.terrainContact.indexOf(player);
    world.terrainContact.setLastValidBodyPosition(
      player,
      xTicks: finalBodyX,
      yTicks: finalBodyY,
    );
    world.terrainContact.setLastCapsuleState(
      player,
      centerXTicks: _result.finalCenterXTicks,
      centerYTicks: _result.finalCenterYTicks,
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
    _auditPrepare(currentTick);
    _rejectUnsupportedDynamicBodies(world, player);
    world.terrainContact.beginTick(
      player,
      currentGeometryVersion: _geometry.version,
    );
    world.collision.resetTick(player);
    world.resolvedMotion.locomotionReferenceSpeedTicksPerSecond[world
            .resolvedMotion
            .indexOf(player)] =
        0;

    final bodyIndex = world.body.indexOf(player);
    if (!world.body.enabled[bodyIndex] ||
        world.body.isKinematic[bodyIndex] ||
        !_profile.enabled ||
        _profile.isKinematic) {
      world.terrainContact.clearSupport(player);
      world.terrainContact.beganTickGrounded[world.terrainContact.indexOf(
            player,
          )] =
          false;
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
    _auditIntegrate(currentTick);
    _rejectUnsupportedDynamicBodies(world, player);
    final bodyIndex = world.body.indexOf(player);
    final contactIndex = world.terrainContact.indexOf(player);

    if (!world.body.enabled[bodyIndex] ||
        world.body.isKinematic[bodyIndex] ||
        !_profile.enabled ||
        _profile.isKinematic) {
      world.terrainContact.clearSupport(player);
      world.resolvedMotion.setResolved(
        player,
        displacementXTicks: 0,
        displacementYTicks: 0,
        travelAlongSupportTicks: 0,
      );
      return 0;
    }

    final transformIndex = world.transform.indexOf(player);
    final capsuleIndex = world.worldContactCapsule.indexOf(player);
    final resolvedIndex = world.resolvedMotion.indexOf(player);
    final movementIndex = world.movement.indexOf(player);
    final currentFacingSign = _facingOffsetSign(world, player);
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
        world.terrainContact.beganTickGrounded[contactIndex] &&
        world.terrainContact.grounded[contactIndex] &&
        world.terrainContact.snapEligibleAtTickStart[contactIndex];
    final dashing = world.movement.dashTicksLeft[movementIndex] > 0;
    final mode =
        dashing && world.terrainContact.mobilityStartedGrounded[contactIndex]
        ? TerrainMotionMode.groundedSurface
        : beganGrounded
        ? TerrainMotionMode.groundedHorizontal
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
      player,
      capsuleCenterXTicks: startCapsuleCenterX,
      capsuleCenterYTicks: startCapsuleCenterY,
      request: request,
    );

    final hasLastValid =
        world.terrainContact.hasLastValidBodyPosition[contactIndex];
    _controller.moveAt(
      centerXTicks: startCapsuleCenterX,
      centerYTicks: startCapsuleCenterY,
      radiusTicks: world.worldContactCapsule.radiusTicks[capsuleIndex],
      verticalHalfSegmentTicks:
          world.worldContactCapsule.verticalHalfSegmentTicks[capsuleIndex],
      request: request,
      beganGrounded: beganGrounded,
      priorSupportEdgeId: world.terrainContact.supportEdgeId[contactIndex],
      priorSupportGeometryVersion:
          world.terrainContact.supportGeometryVersion[contactIndex],
      lastValidCapsuleCenterXTicks: hasLastValid
          ? world.terrainContact.lastValidBodyXTicks[contactIndex] +
                currentOffsetX
          : null,
      lastValidCapsuleCenterYTicks: hasLastValid
          ? world.terrainContact.lastValidBodyYTicks[contactIndex] + offsetY
          : null,
      out: _result,
    );

    final finalBodyX = _result.finalCenterXTicks - currentOffsetX;
    final finalBodyY = _result.finalCenterYTicks - offsetY;
    world.transform.posX[transformIndex] =
        finalBodyX / terrainPhysicsTicksPerWorldUnit;
    world.transform.posY[transformIndex] =
        finalBodyY / terrainPhysicsTicksPerWorldUnit;
    _writeResolvedVelocity(
      world,
      player: player,
      requestMode: mode,
      transformIndex: transformIndex,
    );
    _writeContactState(world, player: player, currentTick: currentTick);
    world.resolvedMotion.setResolved(
      player,
      displacementXTicks: finalBodyX - bodyStartX,
      displacementYTicks: finalBodyY - bodyStartY,
      travelAlongSupportTicks: _result.supportedTravelTicks,
    );
    if (_result.diagnostic != TerrainControllerDiagnostic.recoveryFailed) {
      world.terrainContact.setLastValidBodyPosition(
        player,
        xTicks: finalBodyX,
        yTicks: finalBodyY,
      );
    }
    world.terrainContact.setLastCapsuleState(
      player,
      centerXTicks: _result.finalCenterXTicks,
      centerYTicks: _result.finalCenterYTicks,
      facingSign: currentFacingSign,
    );
    final progressionBodyX =
        _result.progressionXTicks - (currentOffsetX - previousOffsetX);
    return math
        .max(0, progressionBodyX / terrainPhysicsTicksPerWorldUnit)
        .toDouble();
  }

  @override
  bool playerGrounded(EcsWorld world, EntityId player) {
    final index = world.terrainContact.indexOf(player);
    return world.terrainContact.grounded[index] &&
        world.terrainContact.supportGeometryVersion[index] == _geometry.version;
  }

  @override
  void beforePlayerTeleport(EcsWorld world, EntityId player) {
    world.terrainContact.clearForTeleport(player);
    world.collision.resetTick(player);
  }

  @override
  void beforeExternalPlayerVelocity(
    EcsWorld world,
    EntityId player, {
    required double velocityY,
  }) {
    if (velocityY < 0) {
      world.terrainContact.clearSupport(player);
      world.collision.grounded[world.collision.indexOf(player)] = false;
    }
  }

  @override
  void beforePlayerMotionStops(EcsWorld world, EntityId player) {
    world.terrainContact.clearSupport(player);
    world.collision.grounded[world.collision.indexOf(player)] = false;
  }

  void _writeContactState(
    EcsWorld world, {
    required EntityId player,
    required int currentTick,
  }) {
    final terrain = world.terrainContact;
    final terrainIndex = terrain.indexOf(player);
    terrain.hitCeiling[terrainIndex] = _result.hitCeiling;
    terrain.hitLeft[terrainIndex] = _result.hitLeft;
    terrain.hitRight[terrainIndex] = _result.hitRight;
    terrain.wallNormalXTicks[terrainIndex] = _result.wallNormalXTicks;
    terrain.wallNormalYTicks[terrainIndex] = _result.wallNormalYTicks;
    terrain.ceilingNormalXTicks[terrainIndex] = _result.ceilingNormalXTicks;
    terrain.ceilingNormalYTicks[terrainIndex] = _result.ceilingNormalYTicks;
    terrain.usedStep[terrainIndex] = _result.usedStep;
    terrain.usedSnap[terrainIndex] = _result.usedSnap;
    terrain.usedRecovery[terrainIndex] = _result.usedRecovery;
    terrain.blockingContactCount[terrainIndex] = _result.contactCount;
    for (
      var contactIndex = 0;
      contactIndex < terrainMaxBlockingContacts;
      contactIndex += 1
    ) {
      terrain.blockingContactEdgeIds[terrainIndex][contactIndex] =
          _result.contactEdgeIds[contactIndex];
      terrain.blockingContactKinds[terrainIndex][contactIndex] =
          _result.contactKinds[contactIndex];
      terrain.blockingContactFeatures[terrainIndex][contactIndex] =
          _result.contactFeatures[contactIndex];
      terrain.blockingContactNormalXTicks[terrainIndex][contactIndex] =
          _result.contactNormalXTicks[contactIndex];
      terrain.blockingContactNormalYTicks[terrainIndex][contactIndex] =
          _result.contactNormalYTicks[contactIndex];
    }
    terrain.contactIterations[terrainIndex] = _result.contactIterations;
    terrain.recoveryIterations[terrainIndex] = _result.recoveryIterations;
    terrain.candidateCount[terrainIndex] = _result.candidateCount;
    terrain.queryCellsVisited[terrainIndex] = _result.queryCellsVisited;
    terrain.diagnostic[terrainIndex] = _result.diagnostic;
    if (_result.grounded && _result.supportEdgeId != null) {
      final edge = _geometry.edgeById[_result.supportEdgeId];
      if (edge == null) {
        throw StateError('Controller returned support outside its geometry.');
      }
      terrain.setSupport(
        player,
        edge: edge,
        pointXTicks: _result.supportPointXTicks,
        pointYTicks: _result.supportPointYTicks,
        geometryVersion: _geometry.version,
        currentTick: currentTick,
        slopeAngleUnits: _traversalCache[edge.id].absoluteSlopeAngleUnits,
      );
    } else {
      terrain.clearSupport(player);
    }

    final collisionIndex = world.collision.indexOf(player);
    world.collision.grounded[collisionIndex] = _result.grounded;
    world.collision.hitCeiling[collisionIndex] = _result.hitCeiling;
    world.collision.hitLeft[collisionIndex] = _result.hitLeft;
    world.collision.hitRight[collisionIndex] = _result.hitRight;
  }

  void _writeResolvedVelocity(
    EcsWorld world, {
    required EntityId player,
    required TerrainMotionMode requestMode,
    required int transformIndex,
  }) {
    var velocityX = physicsCoordinateToTicks(
      world.transform.velX[transformIndex],
      name: 'velocityX',
    );
    var velocityY = physicsCoordinateToTicks(
      world.transform.velY[transformIndex],
      name: 'velocityY',
    );
    for (var index = 0; index < _result.contactCount; index += 1) {
      final normalX = _result.contactNormalXTicks[index];
      final normalY = _result.contactNormalYTicks[index];
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
    if (_result.grounded &&
        requestMode == TerrainMotionMode.groundedHorizontal &&
        _result.supportTangentXTicks.abs() >=
            _profile.minimumSupportUpComponent) {
      velocityY = _roundedDivide(
        velocityX * _result.supportTangentYTicks,
        _result.supportTangentXTicks,
      );
    } else if (_result.grounded &&
        requestMode == TerrainMotionMode.groundedSurface) {
      final speed = _integerSqrt(velocityX * velocityX + velocityY * velocityY);
      final contactIndex = world.terrainContact.indexOf(player);
      final direction =
          world.terrainContact.mobilitySurfaceDirectionSign[contactIndex];
      final tangentSign = _result.supportTangentXTicks.sign == direction
          ? 1
          : -1;
      velocityX = _roundedDivide(
        speed * _result.supportTangentXTicks * tangentSign,
        terrainDirectionScale,
      );
      velocityY = _roundedDivide(
        speed * _result.supportTangentYTicks * tangentSign,
        terrainDirectionScale,
      );
    }
    if ((_result.hitRight && velocityX > 0) ||
        (_result.hitLeft && velocityX < 0)) {
      velocityX = 0;
    }
    if (_result.hitCeiling && velocityY < 0) velocityY = 0;
    if (_result.grounded && requestMode == TerrainMotionMode.worldSpace) {
      final supportDot =
          velocityX * _result.supportNormalXTicks +
          velocityY * _result.supportNormalYTicks;
      if (supportDot < 0) {
        velocityX -= _roundedDivide(
          supportDot * _result.supportNormalXTicks,
          terrainDirectionScale * terrainDirectionScale,
        );
        velocityY -= _roundedDivide(
          supportDot * _result.supportNormalYTicks,
          terrainDirectionScale * terrainDirectionScale,
        );
      }
    }
    world.transform.velX[transformIndex] =
        velocityX / terrainPhysicsTicksPerWorldUnit;
    world.transform.velY[transformIndex] =
        velocityY / terrainPhysicsTicksPerWorldUnit;
  }

  void _rejectUnsupportedDynamicBodies(EcsWorld world, EntityId player) {
    final bodies = world.body;
    for (var index = 0; index < bodies.denseEntities.length; index += 1) {
      final entity = bodies.denseEntities[index];
      final disposition = terrainPhase2BodyDisposition(
        world,
        entity: entity,
        terrainPlayer: player,
      );
      if (disposition == TerrainPhase2BodyDisposition.terrainPlayer ||
          disposition == TerrainPhase2BodyDisposition.disabledIgnored ||
          bodies.isKinematic[index]) {
        continue;
      }
      throw TerrainUnsupportedBodyError(
        entity: entity,
        disposition: disposition,
      );
    }
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

int _facingOffsetSign(EcsWorld world, EntityId player) {
  final movementIndex = world.movement.indexOf(player);
  return world.movement.facing[movementIndex] ==
          world.movement.artFacing[movementIndex]
      ? 1
      : -1;
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
