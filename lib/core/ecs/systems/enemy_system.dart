import 'dart:math';

import '../../enemies/enemy_id.dart';
import '../../snapshots/enums.dart';
import '../../projectiles/projectile_catalog.dart';
import '../../spells/spell_catalog.dart';
import '../../spells/spell_id.dart';
import '../../tuning/v0_flying_enemy_tuning.dart';
import '../../tuning/v0_ground_enemy_tuning.dart';
import '../../util/deterministic_rng.dart';
import '../../util/double_math.dart';
import '../../util/velocity_math.dart';
import '../../navigation/surface_graph.dart';
import '../../navigation/surface_id.dart';
import '../../navigation/surface_navigator.dart';
import '../../navigation/surface_spatial_index.dart';
import '../entity_id.dart';
import '../stores/cast_intent_store.dart';
import '../stores/melee_intent_store.dart';
import '../world.dart';

class EnemySystem {
  EnemySystem({
    required this.flyingEnemyTuning,
    required this.groundEnemyTuning,
    required this.surfaceNavigator,
    required this.spells,
    required this.projectiles,
  });

  final V0FlyingEnemyTuningDerived flyingEnemyTuning;
  final V0GroundEnemyTuningDerived groundEnemyTuning;
  final SurfaceNavigator surfaceNavigator;
  final SpellCatalog spells;
  final ProjectileCatalogDerived projectiles;

  SurfaceGraph? _surfaceGraph;
  SurfaceSpatialIndex? _surfaceIndex;
  int _surfaceGraphVersion = 0;

  void setSurfaceGraph({
    required SurfaceGraph graph,
    required SurfaceSpatialIndex spatialIndex,
    required int graphVersion,
  }) {
    _surfaceGraph = graph;
    _surfaceIndex = spatialIndex;
    _surfaceGraphVersion = graphVersion;
  }

  void stepSteering(
    EcsWorld world, {
    required EntityId player,
    required double groundTopY,
    required double dtSeconds,
  }) {
    if (!world.transform.has(player)) return;

    final playerTi = world.transform.indexOf(player);
    final playerX = world.transform.posX[playerTi];
    final playerY = world.transform.posY[playerTi];
    final playerGrounded = world.collision.has(player)
        ? world.collision.grounded[world.collision.indexOf(player)]
        : false;
    var playerHalfX = 0.0;
    var playerBottomY = playerY;
    if (world.colliderAabb.has(player)) {
      final ai = world.colliderAabb.indexOf(player);
      playerHalfX = world.colliderAabb.halfX[ai];
      final offsetY = world.colliderAabb.offsetY[ai];
      playerBottomY = playerY + offsetY + world.colliderAabb.halfY[ai];
    }

    final enemies = world.enemy;
    for (var ei = 0; ei < enemies.denseEntities.length; ei += 1) {
      final e = enemies.denseEntities[ei];
      if (!world.transform.has(e)) continue;

      final ti = world.transform.indexOf(e);
      final ex = world.transform.posX[ti];
      final ey = world.transform.posY[ti];

      switch (enemies.enemyId[ei]) {
        case EnemyId.flyingEnemy:
          _steerFlyingEnemy(
            world,
            enemyIndex: ei,
            enemy: e,
            enemyTi: ti,
            playerX: playerX,
            playerY: playerY,
            ex: ex,
            ey: ey,
            groundTopY: groundTopY,
            dtSeconds: dtSeconds,
          );
        case EnemyId.groundEnemy:
          _steerGroundEnemy(
            world,
            enemyIndex: ei,
            enemy: e,
            enemyTi: ti,
            playerX: playerX,
            playerBottomY: playerBottomY,
            playerHalfX: playerHalfX,
            playerGrounded: playerGrounded,
            ex: ex,
            dtSeconds: dtSeconds,
          );
      }
    }
  }

  void stepAttacks(
    EcsWorld world, {
    required EntityId player,
    required int currentTick,
  }) {
    if (!world.transform.has(player)) return;
    final playerTi = world.transform.indexOf(player);
    final playerX = world.transform.posX[playerTi];
    final playerY = world.transform.posY[playerTi];
    final playerVelX = world.transform.velX[playerTi];
    final playerVelY = world.transform.velY[playerTi];
    var playerCenterX = playerX;
    var playerCenterY = playerY;
    if (world.colliderAabb.has(player)) {
      final ai = world.colliderAabb.indexOf(player);
      playerCenterX += world.colliderAabb.offsetX[ai];
      playerCenterY += world.colliderAabb.offsetY[ai];
    }

    final enemies = world.enemy;
    for (var ei = 0; ei < enemies.denseEntities.length; ei += 1) {
      final e = enemies.denseEntities[ei];
      if (!world.transform.has(e)) continue;
      if (!world.cooldown.has(e)) continue;

      final ti = world.transform.indexOf(e);
      final ex = world.transform.posX[ti];
      final ey = world.transform.posY[ti];

      switch (enemies.enemyId[ei]) {
        case EnemyId.flyingEnemy:
          var enemyCenterX = ex;
          var enemyCenterY = ey;
          if (world.colliderAabb.has(e)) {
            final ai = world.colliderAabb.indexOf(e);
            enemyCenterX += world.colliderAabb.offsetX[ai];
            enemyCenterY += world.colliderAabb.offsetY[ai];
          }
          _writeFlyingEnemyCastIntent(
            world,
            enemy: e,
            enemyCenterX: enemyCenterX,
            enemyCenterY: enemyCenterY,
            playerCenterX: playerCenterX,
            playerCenterY: playerCenterY,
            playerVelX: playerVelX,
            playerVelY: playerVelY,
            currentTick: currentTick,
          );
        case EnemyId.groundEnemy:
          _writeGroundEnemyMeleeIntent(
            world,
            enemy: e,
            enemyIndex: ei,
            ex: ex,
            ey: ey,
            playerX: playerX,
            currentTick: currentTick,
          );
      }
    }
  }

  void _steerFlyingEnemy(
    EcsWorld world, {
    required int enemyIndex,
    required EntityId enemy,
    required int enemyTi,
    required double playerX,
    required double playerY,
    required double ex,
    required double ey,
    required double groundTopY,
    required double dtSeconds,
  }) {
    if (dtSeconds <= 0.0) return;
    final tuning = flyingEnemyTuning;
    if (!world.flyingEnemySteering.has(enemy)) {
      assert(
        false,
        'EnemySystem requires FlyingEnemySteeringStore on flying enemies; add it at spawn time.',
      );
      return;
    }

    final steering = world.flyingEnemySteering;
    final si = steering.indexOf(enemy);

    var rngState = steering.rngState[si];
    double nextRange(double min, double max) {
      rngState = nextUint32(rngState);
      return rangeDouble(rngState, min, max);
    }

    if (!steering.initialized[si]) {
      steering.initialized[si] = true;
      steering.desiredRangeHoldLeftS[si] = nextRange(
        tuning.base.flyingEnemyDesiredRangeHoldMinSeconds,
        tuning.base.flyingEnemyDesiredRangeHoldMaxSeconds,
      );
      steering.desiredRange[si] = nextRange(
        tuning.base.flyingEnemyDesiredRangeMin,
        tuning.base.flyingEnemyDesiredRangeMax,
      );
      steering.flightTargetHoldLeftS[si] = 0.0;
      steering.flightTargetAboveGround[si] = nextRange(
        tuning.base.flyingEnemyMinHeightAboveGround,
        tuning.base.flyingEnemyMaxHeightAboveGround,
      );
    }

    var desiredRangeHoldLeftS = steering.desiredRangeHoldLeftS[si];
    var desiredRange = steering.desiredRange[si];

    // Hold desired range target.
    if (desiredRangeHoldLeftS > 0.0) {
      desiredRangeHoldLeftS -= dtSeconds;
    } else {
      desiredRangeHoldLeftS = nextRange(
        tuning.base.flyingEnemyDesiredRangeHoldMinSeconds,
        tuning.base.flyingEnemyDesiredRangeHoldMaxSeconds,
      );
      desiredRange = nextRange(
        tuning.base.flyingEnemyDesiredRangeMin,
        tuning.base.flyingEnemyDesiredRangeMax,
      );
    }

    final dx = playerX - ex;
    final distX = dx.abs();
    if (distX > 1e-6) {
      world.enemy.facing[enemyIndex] = dx >= 0 ? Facing.right : Facing.left;
    }

    final slack = tuning.base.flyingEnemyHoldSlack;
    double desiredVelX = 0.0;
    if (distX > 1e-6) {
      final dirToPlayerX = dx >= 0 ? 1.0 : -1.0;
      final error = distX - desiredRange;

      if (error.abs() > slack) {
        final slowRadiusX = tuning.base.flyingEnemySlowRadiusX;
        final t = slowRadiusX > 0.0
            ? clampDouble((error.abs() - slack) / slowRadiusX, 0.0, 1.0)
            : 1.0;
        final speed = t * tuning.base.flyingEnemyMaxSpeedX;
        desiredVelX = (error > 0.0 ? dirToPlayerX : -dirToPlayerX) * speed;
      }
    }

    var flightTargetHoldLeftS = steering.flightTargetHoldLeftS[si];
    var flightTargetAboveGround = steering.flightTargetAboveGround[si];
    if (flightTargetHoldLeftS > 0.0) {
      flightTargetHoldLeftS -= dtSeconds;
    } else {
      flightTargetHoldLeftS = nextRange(
        tuning.base.flyingEnemyFlightTargetHoldMinSeconds,
        tuning.base.flyingEnemyFlightTargetHoldMaxSeconds,
      );
      flightTargetAboveGround = nextRange(
        tuning.base.flyingEnemyMinHeightAboveGround,
        tuning.base.flyingEnemyMaxHeightAboveGround,
      );
    }

    final targetY = groundTopY - flightTargetAboveGround;
    final deltaY = targetY - ey;
    double desiredVelY = clampDouble(
      deltaY * tuning.base.flyingEnemyVerticalKp,
      -tuning.base.flyingEnemyMaxSpeedY,
      tuning.base.flyingEnemyMaxSpeedY,
    );
    if (deltaY.abs() <= tuning.base.flyingEnemyVerticalDeadzone) {
      desiredVelY = 0.0;
    }

    final currentVelX = world.transform.velX[enemyTi];
    world.transform.velX[enemyTi] = applyAccelDecel(
      current: currentVelX,
      desired: desiredVelX,
      dtSeconds: dtSeconds,
      accelPerSecond: tuning.base.flyingEnemyAccelX,
      decelPerSecond: tuning.base.flyingEnemyDecelX,
    );
    world.transform.velY[enemyTi] = desiredVelY;

    steering.desiredRangeHoldLeftS[si] = desiredRangeHoldLeftS;
    steering.desiredRange[si] = desiredRange;
    steering.flightTargetHoldLeftS[si] = flightTargetHoldLeftS;
    steering.flightTargetAboveGround[si] = flightTargetAboveGround;
    steering.rngState[si] = rngState;
  }

  void _steerGroundEnemy(
    EcsWorld world, {
    required int enemyIndex,
    required EntityId enemy,
    required int enemyTi,
    required double playerX,
    required double playerBottomY,
    required double playerHalfX,
    required bool playerGrounded,
    required double ex,
    required double dtSeconds,
  }) {
    if (dtSeconds <= 0.0) return;
    final tuning = groundEnemyTuning;

    final navIndex = world.surfaceNav.tryIndexOf(enemy);
    if (navIndex == null) return;

    _ensureChaseOffsetInitialized(world, enemy);

    if (!world.groundEnemyChaseOffset.has(enemy)) return;

    final chaseOffset = world.groundEnemyChaseOffset;
    final chaseIndex = chaseOffset.indexOf(enemy);
    final chaseOffsetX = chaseOffset.chaseOffsetX[chaseIndex];
    final chaseSpeedScale = chaseOffset.chaseSpeedScale[chaseIndex];
    final collapseDistX = tuning.base.groundEnemyMeleeRangeX +
        tuning.base.groundEnemyStopDistanceX;
    final distToPlayerX = (playerX - ex).abs();
    final meleeOffsetMaxX = tuning.base.groundEnemyChaseOffsetMeleeX.abs();
    final meleeOffsetAbs = min(meleeOffsetMaxX, chaseOffsetX.abs());
    final meleeOffsetX = meleeOffsetAbs == 0.0
        ? 0.0
        : (chaseOffsetX >= 0.0 ? meleeOffsetAbs : -meleeOffsetAbs);
    final effectiveTargetX = distToPlayerX <= collapseDistX
        ? playerX + meleeOffsetX
        : playerX + chaseOffsetX;
    final navTargetX = playerX;

    final graph = _surfaceGraph;
    final spatialIndex = _surfaceIndex;
    double? noPlanSurfaceMinX;
    double? noPlanSurfaceMaxX;
    SurfaceNavIntent intent;
    if (graph == null ||
        spatialIndex == null ||
        !world.colliderAabb.has(enemy)) {
      intent = SurfaceNavIntent(
        desiredX: effectiveTargetX,
        jumpNow: false,
        hasPlan: false,
      );
    } else {
      final ai = world.colliderAabb.indexOf(enemy);
      final enemyHalfX = world.colliderAabb.halfX[ai];
      final enemyHalfY = world.colliderAabb.halfY[ai];
      final offsetY = world.colliderAabb.offsetY[ai];
      final enemyBottomY = world.transform.posY[enemyTi] + offsetY + enemyHalfY;
      final grounded =
          world.collision.has(enemy) &&
          world.collision.grounded[world.collision.indexOf(enemy)];

      intent = surfaceNavigator.update(
        navStore: world.surfaceNav,
        navIndex: navIndex,
        graph: graph,
        spatialIndex: spatialIndex,
        graphVersion: _surfaceGraphVersion,
        entityX: ex,
        entityBottomY: enemyBottomY,
        entityHalfWidth: enemyHalfX,
        entityGrounded: grounded,
        targetX: navTargetX,
        targetBottomY: playerBottomY,
        targetHalfWidth: playerHalfX,
        targetGrounded: playerGrounded,
      );

      // Preserve chase offset behavior when no plan is active, but keep it safe:
      // if grounded, clamp desired X to the current surface span so we never
      // walk off into a gap due to an offset pointing into empty space.
      if (!intent.hasPlan) {
        var desiredX = effectiveTargetX;
        final currentSurfaceId = world.surfaceNav.currentSurfaceId[navIndex];
        if (currentSurfaceId != surfaceIdUnknown) {
          final currentIndex = graph.indexOfSurfaceId(currentSurfaceId);
          if (currentIndex != null) {
            final surface = graph.surfaces[currentIndex];
            final minX = surface.xMin + enemyHalfX;
            final maxX = surface.xMax - enemyHalfX;
            if (minX <= maxX) {
              desiredX = clampDouble(desiredX, minX, maxX);
              noPlanSurfaceMinX = minX;
              noPlanSurfaceMaxX = maxX;
            }
          }
        }

        intent = SurfaceNavIntent(
          desiredX: desiredX,
          jumpNow: false,
          hasPlan: false,
        );
      }
    }

    // Speed scale is intended to break symmetric chasing overlaps, but keep
    // navigation edge execution stable (jump/drop takeoffs) by using base speed
    // while following a plan.
    final effectiveSpeedScale = intent.hasPlan ? 1.0 : chaseSpeedScale;

    _applyGroundEnemyPhysics(
      world,
      enemyIndex: enemyIndex,
      enemyTi: enemyTi,
      ex: ex,
      intent: intent,
      effectiveSpeedScale: effectiveSpeedScale,
      dtSeconds: dtSeconds,
      safeSurfaceMinX: noPlanSurfaceMinX,
      safeSurfaceMaxX: noPlanSurfaceMaxX,
      navIndex: navIndex,
      graph: graph,
    );
  }

  void _writeFlyingEnemyCastIntent(
    EcsWorld world, {
    required EntityId enemy,
    required double enemyCenterX,
    required double enemyCenterY,
    required double playerCenterX,
    required double playerCenterY,
    required double playerVelX,
    required double playerVelY,
    required int currentTick,
  }) {
    final tuning = flyingEnemyTuning;
    if (!world.castIntent.has(enemy)) {
      assert(
        false,
        'EnemySystem requires CastIntentStore on enemies; add it at spawn time.',
      );
      return;
    }

    const spellId = SpellId.lightning;
    final projectileId = spells.get(spellId).projectileId;
    final projectileSpeed = projectileId == null
        ? null
        : projectiles.base.get(projectileId).speedUnitsPerSecond;
    var targetX = playerCenterX;
    var targetY = playerCenterY;
    if (projectileSpeed != null && projectileSpeed > 0.0) {
      final dx = playerCenterX - enemyCenterX;
      final dy = playerCenterY - enemyCenterY;
      final distance = sqrt(dx * dx + dy * dy);
      final leadSeconds = clampDouble(
        distance / projectileSpeed,
        tuning.base.flyingEnemyAimLeadMinSeconds,
        tuning.base.flyingEnemyAimLeadMaxSeconds,
      );
      targetX = playerCenterX + playerVelX * leadSeconds;
      targetY = playerCenterY + playerVelY * leadSeconds;
    }

    // IMPORTANT: EnemySystem writes intent only; execution happens in
    // `SpellCastSystem` which owns mana/cooldown rules and projectile spawning.
    world.castIntent.set(
      enemy,
      CastIntentDef(
        spellId: spellId,
        dirX: targetX - enemyCenterX,
        dirY: targetY - enemyCenterY,
        fallbackDirX: 1.0,
        fallbackDirY: 0.0,
        originOffset: tuning.base.flyingEnemyCastOriginOffset,
        cooldownTicks: tuning.flyingEnemyCastCooldownTicks,
        tick: currentTick,
      ),
    );
  }

  void _writeGroundEnemyMeleeIntent(
    EcsWorld world, {
    required EntityId enemy,
    required int enemyIndex,
    required double ex,
    required double ey,
    required double playerX,
    required int currentTick,
  }) {
    final tuning = groundEnemyTuning;
    if (!world.meleeIntent.has(enemy)) {
      assert(
        false,
        'EnemySystem requires MeleeIntentStore on enemies; add it at spawn time.',
      );
      return;
    }
    if (!world.colliderAabb.has(enemy)) {
      assert(
        false,
        'GroundEnemy melee requires ColliderAabbStore on the enemy to compute hitbox offset.',
      );
      return;
    }
    final dx = (playerX - ex).abs();
    if (dx > tuning.base.groundEnemyMeleeRangeX) return;

    final facing = world.enemy.facing[enemyIndex];
    final dirX = facing == Facing.right ? 1.0 : -1.0;

    final halfX = tuning.base.groundEnemyMeleeHitboxSizeX * 0.5;
    final halfY = tuning.base.groundEnemyMeleeHitboxSizeY * 0.5;

    final ownerHalfX =
        world.colliderAabb.halfX[world.colliderAabb.indexOf(enemy)];
    final offsetX = dirX * (ownerHalfX * 0.5 + halfX);
    const offsetY = 0.0;

    world.meleeIntent.set(
      enemy,
      MeleeIntentDef(
        damage: tuning.base.groundEnemyMeleeDamage,
        halfX: halfX,
        halfY: halfY,
        offsetX: offsetX,
        offsetY: offsetY,
        dirX: dirX,
        dirY: 0.0,
        activeTicks: tuning.groundEnemyMeleeActiveTicks,
        cooldownTicks: tuning.groundEnemyMeleeCooldownTicks,
        staminaCost: 0.0,
        tick: currentTick,
      ),
    );
  }

  void _ensureChaseOffsetInitialized(
    EcsWorld world,
    EntityId enemy,
  ) {
    if (!world.groundEnemyChaseOffset.has(enemy)) return;

    final chaseOffset = world.groundEnemyChaseOffset;
    final chaseIndex = chaseOffset.indexOf(enemy);
    if (chaseOffset.initialized[chaseIndex]) return;

    final tuning = groundEnemyTuning;
    var rngState = chaseOffset.rngState[chaseIndex];
    if (rngState == 0) {
      rngState = enemy;
    }
    final maxAbs = tuning.base.groundEnemyChaseOffsetMaxX.abs();
    var offsetX = 0.0;
    if (maxAbs > 0.0) {
      rngState = nextUint32(rngState);
      offsetX = rangeDouble(rngState, -maxAbs, maxAbs);
      final minAbs = clampDouble(
        tuning.base.groundEnemyChaseOffsetMinAbsX,
        0.0,
        maxAbs,
      );
      final absOffset = offsetX.abs();
      if (absOffset < minAbs) {
        offsetX = offsetX >= 0.0 ? minAbs : -minAbs;
        if (absOffset == 0.0) {
          offsetX = minAbs;
        }
      }
    }

    rngState = nextUint32(rngState);
    final speedScale = rangeDouble(
      rngState,
      tuning.base.groundEnemyChaseSpeedScaleMin,
      tuning.base.groundEnemyChaseSpeedScaleMax,
    );
    chaseOffset.initialized[chaseIndex] = true;
    chaseOffset.chaseOffsetX[chaseIndex] = offsetX;
    chaseOffset.chaseSpeedScale[chaseIndex] = speedScale;
    chaseOffset.rngState[chaseIndex] = rngState;
  }

  void _applyGroundEnemyPhysics(
    EcsWorld world, {
    required int enemyIndex,
    required int enemyTi,
    required double ex,
    required SurfaceNavIntent intent,
    required double effectiveSpeedScale,
    required double dtSeconds,
    required double? safeSurfaceMinX,
    required double? safeSurfaceMaxX,
    required int navIndex,
    required SurfaceGraph? graph,
  }) {
    final tuning = groundEnemyTuning;
    final dx = intent.desiredX - ex;
    double desiredVelX = 0.0;
    if (intent.commitMoveDirX != 0) {
      final dirX = intent.commitMoveDirX.toDouble();
      world.enemy.facing[enemyIndex] = dirX > 0 ? Facing.right : Facing.left;
      desiredVelX = dirX * tuning.base.groundEnemySpeedX * effectiveSpeedScale;
    } else if (dx.abs() > tuning.base.groundEnemyStopDistanceX) {
      final dirX = dx >= 0 ? 1.0 : -1.0;
      world.enemy.facing[enemyIndex] = dirX > 0 ? Facing.right : Facing.left;
      desiredVelX = dirX * tuning.base.groundEnemySpeedX * effectiveSpeedScale;
    }

    if (intent.jumpNow) {
      world.transform.velY[enemyTi] = -tuning.base.groundEnemyJumpSpeed;
    }

    final currentVelX = world.transform.velX[enemyTi];
    final nextVelX = applyAccelDecel(
      current: currentVelX,
      desired: desiredVelX,
      dtSeconds: dtSeconds,
      accelPerSecond: tuning.base.groundEnemyAccelX,
      decelPerSecond: tuning.base.groundEnemyDecelX,
    );

    double? jumpSnapVelX;
    if (intent.hasPlan && intent.jumpNow && graph != null) {
      final activeEdgeIndex = world.surfaceNav.activeEdgeIndex[navIndex];
      if (activeEdgeIndex >= 0 && activeEdgeIndex < graph.edges.length) {
        final edge = graph.edges[activeEdgeIndex];
        if (edge.kind == SurfaceEdgeKind.jump && edge.travelTicks > 0) {
          final travelSeconds = edge.travelTicks * dtSeconds;
          if (travelSeconds > 0.0) {
            final dxAbs = (edge.landingX - ex).abs();
            final requiredAbs = dxAbs / travelSeconds;
            final desiredAbs = desiredVelX.abs();
            final currentAbs = currentVelX.abs();
            final snapAbs = min(desiredAbs, max(currentAbs, requiredAbs));
            if (snapAbs > nextVelX.abs()) {
              final sign = desiredVelX >= 0.0 ? 1.0 : -1.0;
              jumpSnapVelX = sign * snapAbs;
            }
          }
        }
      }
    }

    world.transform.velX[enemyTi] = jumpSnapVelX ?? nextVelX;

    if (!intent.hasPlan && safeSurfaceMinX != null && safeSurfaceMaxX != null) {
      final stopDist = tuning.base.groundEnemyStopDistanceX;
      final nextVelX = world.transform.velX[enemyTi];
      if (nextVelX > 0.0 && ex >= safeSurfaceMaxX! - stopDist) {
        world.transform.velX[enemyTi] = 0.0;
      } else if (nextVelX < 0.0 && ex <= safeSurfaceMinX! + stopDist) {
        world.transform.velX[enemyTi] = 0.0;
      }
    }
  }
}
