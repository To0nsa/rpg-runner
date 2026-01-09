import 'dart:math';

import 'package:walkscape_runner/core/ecs/entity_id.dart';

import '../../enemies/enemy_catalog.dart';
import '../../enemies/enemy_id.dart';
import '../../combat/damage_type.dart';
import '../../combat/status/status.dart';
import '../../snapshots/enums.dart';
import '../../projectiles/projectile_catalog.dart';
import '../../spells/spell_catalog.dart';
import '../../tuning/flying_enemy_tuning.dart';
import '../../tuning/ground_enemy_tuning.dart';
import '../../util/deterministic_rng.dart';
import '../../util/double_math.dart';
import '../../util/velocity_math.dart';
import '../../navigation/types/surface_graph.dart';
import '../../navigation/types/surface_id.dart';
import '../../navigation/surface_navigator.dart';
import '../../navigation/utils/surface_spatial_index.dart';
import '../../navigation/utils/trajectory_predictor.dart';
import '../stores/cast_intent_store.dart';
import '../stores/melee_intent_store.dart';
import '../world.dart';

/// Handles AI logic for enemies (steering and attacks).
///
/// Responsibilities:
/// 1.  **Steering**: Computes velocities to move enemies toward their targets
///     (Player) or patrol points. Supports both flying (direct/boid-like) and
///     ground (pathfinding over surface graph) locomotion.
/// 2.  **Attacks**: Decisions on when to attack. Writes intent to [CastIntentStore]
///     (ranged) or [MeleeIntentStore] (melee), which are executed by downstream
///     systems like `SpellCastSystem` or `MeleeSystem`.
class EnemySystem {
  EnemySystem({
    required this.flyingEnemyTuning,
    required this.groundEnemyTuning,
    required this.surfaceNavigator,
    required this.enemyCatalog,
    required this.spells,
    required this.projectiles,
    this.trajectoryPredictor,
  });

  final FlyingEnemyTuningDerived flyingEnemyTuning;
  final GroundEnemyTuningDerived groundEnemyTuning;
  final SurfaceNavigator surfaceNavigator;
  final EnemyCatalog enemyCatalog;
  final SpellCatalog spells;
  final ProjectileCatalogDerived projectiles;

  /// Optional predictor for anticipating where an airborne player will land.
  ///
  /// When provided, ground enemies will pathfind toward the predicted landing
  /// spot instead of the player's current (airborne) position.
  final TrajectoryPredictor? trajectoryPredictor;

  /// The navigation graph for ground enemies. Can be null if the level has no surface data.
  SurfaceGraph? _surfaceGraph;
  /// Spatial index for quick lookup of surfaces/edges near an entity.
  SurfaceSpatialIndex? _surfaceIndex;
  /// Version tracker to detect graph updates and invalidate cached paths if necessary.
  int _surfaceGraphVersion = 0;

  /// Updates the navigation graph used by ground enemies.
  ///
  /// This should be called whenever the level geometry changes or is loaded.
  void setSurfaceGraph({
    required SurfaceGraph graph,
    required SurfaceSpatialIndex spatialIndex,
    required int graphVersion,
  }) {
    _surfaceGraph = graph;
    _surfaceIndex = spatialIndex;
    _surfaceGraphVersion = graphVersion;
  }

  /// Calculates and applies steering velocities for all active enemies.
  ///
  /// This traverses the enemy list, determines the player's position, and delegates
  /// to specific steering implementations ([_steerFlyingEnemy] or [_steerGroundEnemy]).
  void stepSteering(
    EcsWorld world, {
    required EntityId player,
    required double groundTopY,
    required double dtSeconds,
  }) {
    // If the player doesn't exist (e.g. dead or not spawned), enemies have no target.
    if (!world.transform.has(player)) return;

    // Cache player position/physics data once to avoid repeated lookups inside the loop.
    final playerTi = world.transform.indexOf(player);
    final playerX = world.transform.posX[playerTi];
    final playerY = world.transform.posY[playerTi];

    // Determine if player is grounded (relevant for ground enemies tracking).
    final playerGrounded = world.collision.has(player)
        ? world.collision.grounded[world.collision.indexOf(player)]
        : false;
    
    // Calculate player bounds for accurate targeting (e.g., aiming at center/bottom).
    var playerHalfX = 0.0;
    var playerBottomY = playerY;
    if (world.colliderAabb.has(player)) {
      final ai = world.colliderAabb.indexOf(player);
      playerHalfX = world.colliderAabb.halfX[ai];
      final offsetY = world.colliderAabb.offsetY[ai];
      playerBottomY = playerY + offsetY + world.colliderAabb.halfY[ai];
    }

    // Cache player velocity for trajectory prediction (ground enemies).
    final playerVelX = world.transform.velX[playerTi];
    final playerVelY = world.transform.velY[playerTi];

    final enemies = world.enemy;
    // Iterate over all entities tagged as enemies.
    for (var ei = 0; ei < enemies.denseEntities.length; ei += 1) {
      final e = enemies.denseEntities[ei];
      final ti = world.transform.tryIndexOf(e);
      if (ti == null) continue; // Should not happen if data integrity is maintained.

      final ex = world.transform.posX[ti];
      final ey = world.transform.posY[ti];
      
      /// TODO(Optimization): If enemy types grow significantly, consider separating
      /// entities into specialized systems queries or sorting component arrays by
      /// EnemyId to minimize branch mispredictions and improve cache locality.
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
            playerVelX: playerVelX,
            playerVelY: playerVelY,
            playerGrounded: playerGrounded,
            ex: ex,
            dtSeconds: dtSeconds,
          );
      }
    }
  }

  /// Evaluates attack opportunities for all enemies.
  ///
  /// This checks distance/line-of-sight (implicitly or explicitly) and cooldowns.
  /// If an attack is viable, it writes an intent to the respective intent store.
  void stepAttacks(
    EcsWorld world, {
    required EntityId player,
    required int currentTick,
  }) {
    if (!world.transform.has(player)) return;
    
    // Pre-calculate player center for aiming.
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
      final ti = world.transform.tryIndexOf(e);
      if (ti == null) continue;
      
      // Cooldown check is cheap, but requires the store.
      // Assuming all enemies have cooldowns, but safer to check.
      if (!world.cooldown.has(e)) continue;

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
            enemyIndex: ei,
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

  /// Implements "Boids-like" or direct steering for flying enemies.
  ///
  /// Behavior:
  /// - Maintains a specific horizontal distance heavily (hovering left/right of player).
  /// - Maintains a specific height above ground (bobbing).
  /// - Randomizes target parameters periodically to add organic noise.
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
    
    // Ensure steering state exists. Contains RNG state and current target timers.
    if (!world.flyingEnemySteering.has(enemy)) {
      assert(
        false,
        'EnemySystem requires FlyingEnemySteeringStore on flying enemies; add it at spawn time.',
      );
      return;
    }

    final steering = world.flyingEnemySteering;
    final si = steering.indexOf(enemy);
    final modIndex = world.statModifier.tryIndexOf(enemy);
    final moveSpeedMul =
        modIndex == null ? 1.0 : world.statModifier.moveSpeedMul[modIndex];

    var rngState = steering.rngState[si];
    // Helper to advance RNG and get a range.
    double nextRange(double min, double max) {
      rngState = nextUint32(rngState);
      return rangeDouble(rngState, min, max);
    }

    // -- Initialization --
    // If first frame, randomize initial targets (range to hold, height to fly at).
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

    // -- Horizontal Logic --
    // Decay timer for holding the current desired range.
    var desiredRangeHoldLeftS = steering.desiredRangeHoldLeftS[si];
    var desiredRange = steering.desiredRange[si];

    if (desiredRangeHoldLeftS > 0.0) {
      desiredRangeHoldLeftS -= dtSeconds;
    } else {
      // Pick new range target when timer expires.
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
    // Face the player.
    if (distX > 1e-6) {
      world.enemy.facing[enemyIndex] = dx >= 0 ? Facing.right : Facing.left;
    }

    // Calculate desired horizontal velocity to maintain `desiredRange`.
    final slack = tuning.base.flyingEnemyHoldSlack;
    double desiredVelX = 0.0;
    if (distX > 1e-6) {
      final dirToPlayerX = dx >= 0 ? 1.0 : -1.0;
      final error = distX - desiredRange;

      // Only move if outside the slack (hysteresis) zone to prevent jitter.
      if (error.abs() > slack) {
        final slowRadiusX = tuning.base.flyingEnemySlowRadiusX;
        // Dampen speed as we approach the target range (arrival behavior).
        final t = slowRadiusX > 0.0
            ? clampDouble((error.abs() - slack) / slowRadiusX, 0.0, 1.0)
            : 1.0;
        final speed = t * tuning.base.flyingEnemyMaxSpeedX;
        // If error > 0, we are too far -> move towards player.
        // If error < 0, we are too close -> move away from player.
        desiredVelX = (error > 0.0 ? dirToPlayerX : -dirToPlayerX) * speed;
      }
    }

    // -- Vertical Logic --
    // Decay timer for vertical target hold.
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

    // Simple P-controller for height.
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

    // -- Physics Integration --
    desiredVelX *= moveSpeedMul;
    desiredVelY *= moveSpeedMul;
    final currentVelX = world.transform.velX[enemyTi];
    world.transform.velX[enemyTi] = applyAccelDecel(
      current: currentVelX,
      desired: desiredVelX,
      dtSeconds: dtSeconds,
      accelPerSecond: tuning.base.flyingEnemyAccelX,
      decelPerSecond: tuning.base.flyingEnemyDecelX,
    );
    world.transform.velY[enemyTi] = desiredVelY;

    // Write back state.
    steering.desiredRangeHoldLeftS[si] = desiredRangeHoldLeftS;
    steering.desiredRange[si] = desiredRange;
    steering.flightTargetHoldLeftS[si] = flightTargetHoldLeftS;
    steering.flightTargetAboveGround[si] = flightTargetAboveGround;
    steering.rngState[si] = rngState;
  }

  /// Implements pathfinding and steering for ground enemies.
  ///
  /// This uses [SurfaceNavigator] to compute the next immediate move (jump/walk)
  /// towards the player. It also handles "chase offsets" to prevent enemies from
  /// stacking perfectly on top of each other.
  void _steerGroundEnemy(
    EcsWorld world, {
    required int enemyIndex,
    required EntityId enemy,
    required int enemyTi,
    required double playerX,
    required double playerBottomY,
    required double playerHalfX,
    required double playerVelX,
    required double playerVelY,
    required bool playerGrounded,
    required double ex,
    required double dtSeconds,
  }) {
    if (dtSeconds <= 0.0) return;
    final tuning = groundEnemyTuning;

    final navIndex = world.surfaceNav.tryIndexOf(enemy);
    if (navIndex == null) return;

    // Optimized: Resolve chase offset store once and pass index to avoid re-lookup.
    final chaseIndex = world.groundEnemyChaseOffset.tryIndexOf(enemy);
    if (chaseIndex == null) return;

    // Lazy initialization of random chase parameters.
    _ensureChaseOffsetInitialized(world, chaseIndex, enemy);

    final chaseOffset = world.groundEnemyChaseOffset;
    final chaseOffsetX = chaseOffset.chaseOffsetX[chaseIndex];
    final chaseSpeedScale = chaseOffset.chaseSpeedScale[chaseIndex];

    // -- Target Selection --
    // "Collapse" behavior: when very close to player, ignore chase offset and
    // move directly to player (to attack). Otherwise, maintain offset.
    final collapseDistX = tuning.base.groundEnemyMeleeRangeX +
        tuning.base.groundEnemyStopDistanceX;
    final distToPlayerX = (playerX - ex).abs();
    
    // Calculate melee offset (which side of the player to stand on).
    final meleeOffsetMaxX = tuning.base.groundEnemyChaseOffsetMeleeX.abs();
    final meleeOffsetAbs = min(meleeOffsetMaxX, chaseOffsetX.abs());
    final meleeOffsetX = meleeOffsetAbs == 0.0
        ? 0.0
        : (chaseOffsetX >= 0.0 ? meleeOffsetAbs : -meleeOffsetAbs);
    
    final effectiveTargetX = distToPlayerX <= collapseDistX
        ? playerX + meleeOffsetX
        : playerX + chaseOffsetX;

    // -- Pathfinding Query --
    final graph = _surfaceGraph;
    final spatialIndex = _surfaceIndex;

    // -- Landing Prediction --
    // When player is airborne, predict where they'll land and navigate there.
    var navTargetX = playerX;
    var navTargetBottomY = playerBottomY;
    var navTargetGrounded = playerGrounded;

    if (!playerGrounded &&
        trajectoryPredictor != null &&
        graph != null &&
        spatialIndex != null) {
      final prediction = trajectoryPredictor!.predictLanding(
        startX: playerX,
        startBottomY: playerBottomY,
        velX: playerVelX,
        velY: playerVelY,
        graph: graph,
        spatialIndex: spatialIndex,
        entityHalfWidth: playerHalfX,
      );

      if (prediction != null) {
        navTargetX = prediction.x;
        navTargetBottomY = prediction.bottomY;
        navTargetGrounded = true; // Treat predicted landing as grounded.
      }
    }

    double? noPlanSurfaceMinX;
    double? noPlanSurfaceMaxX;
    SurfaceNavIntent intent;
    
    // If graph is missing or navigation not possible, fallback to no-op/dumb chase.
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

      // Query the navigator for what to do this frame.
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
        targetBottomY: navTargetBottomY,
        targetHalfWidth: playerHalfX,
        targetGrounded: navTargetGrounded,
      );

      // -- Fallback Logic --
      // If the navigator defines no plan (e.g. lost track or arrived), we still
      // want to move towards `desiredX` (chase behavior), BUT we must be careful
      // not to walk off a ledge blindly.
      if (!intent.hasPlan) {
        var desiredX = effectiveTargetX;
        // Clamp desiredX to the current surface's bounds to stop at edges.
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

    // Speed scale is intended to break symmetric chasing overlaps.
    // However, when executing a precise plan (like a Jump edge), we used standard
    // speed to ensure the physics align with the pre-calculated jump arc.
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

  /// Calculates aim and registers a spell cast intent for flying enemies.
  void _writeFlyingEnemyCastIntent(
    EcsWorld world, {
    required EntityId enemy,
    required int enemyIndex,
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

    // Determine projectile properties for aiming.
    final enemyId = world.enemy.enemyId[enemyIndex];
    final spellId = enemyCatalog.get(enemyId).primarySpellId;
    if (spellId == null) return;
    final projectileId = spells.get(spellId).projectileId;
    final projectileSpeed = projectileId == null
        ? null
        : projectiles.base.get(projectileId).speedUnitsPerSecond;
    
    // -- Aim Leading --
    var targetX = playerCenterX;
    var targetY = playerCenterY;
    if (projectileSpeed != null && projectileSpeed > 0.0) {
      final dx = playerCenterX - enemyCenterX;
      final dy = playerCenterY - enemyCenterY;
      final distance = sqrt(dx * dx + dy * dy);
      // Rough estimation of time-to-impact to predict player position.
      final leadSeconds = clampDouble(
        distance / projectileSpeed,
        tuning.base.flyingEnemyAimLeadMinSeconds,
        tuning.base.flyingEnemyAimLeadMaxSeconds,
      );
      targetX = playerCenterX + playerVelX * leadSeconds;
      targetY = playerCenterY + playerVelY * leadSeconds;
    }

    // Write intent. Actual spawning handles cooldown/mana checks.
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

  /// Checks range and registers a melee attack intent for ground enemies.
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
    
    // Simple range check.
    final dx = (playerX - ex).abs();
    if (dx > tuning.base.groundEnemyMeleeRangeX) return;

    // Determine hitbox position based on facing direction.
    final facing = world.enemy.facing[enemyIndex];
    final dirX = facing == Facing.right ? 1.0 : -1.0;

    final halfX = tuning.base.groundEnemyMeleeHitboxSizeX * 0.5;
    final halfY = tuning.base.groundEnemyMeleeHitboxSizeY * 0.5;

    final ownerHalfX =
        world.colliderAabb.halfX[world.colliderAabb.indexOf(enemy)];
    final offsetX = dirX * (ownerHalfX * 0.5 + halfX);
    const offsetY = 0.0;

    // Write intent.
    world.meleeIntent.set(
      enemy,
      MeleeIntentDef(
        damage: tuning.base.groundEnemyMeleeDamage,
        damageType: DamageType.physical,
        statusProfileId: StatusProfileId.none,
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

  /// Ensures that the ground enemy has valid initialized chase offsets.
  ///
  /// Adds randomness to tracking so multiple enemies don't overlap perfectly.
  void _ensureChaseOffsetInitialized(
    EcsWorld world,
    int chaseIndex,
    EntityId enemy,
  ) {
    // world.groundEnemyChaseOffset.has(enemy) is guaranteed primarily by caller.
    final chaseOffset = world.groundEnemyChaseOffset;
    if (chaseOffset.initialized[chaseIndex]) return;

    final tuning = groundEnemyTuning;
    var rngState = chaseOffset.rngState[chaseIndex];
    if (rngState == 0) {
      rngState = enemy; // Seed with entity ID for determinism.
    }
    
    // Choose a random horizontal offset relative to the player.
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
      // Ensure the offset isn't too small (which would defeat the purpose).
      if (absOffset < minAbs) {
        offsetX = offsetX >= 0.0 ? minAbs : -minAbs;
        if (absOffset == 0.0) {
          offsetX = minAbs;
        }
      }
    }

    // Choose a slight variation in speed.
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

  /// Low-level physics application for ground enemies based on [SurfaceNavIntent].
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
    final enemy = world.enemy.denseEntities[enemyIndex];
    final modIndex = world.statModifier.tryIndexOf(enemy);
    final moveSpeedMul =
        modIndex == null ? 1.0 : world.statModifier.moveSpeedMul[modIndex];
    final dx = intent.desiredX - ex;
    double desiredVelX = 0.0;

    // -- Horizontal Movement --
    if (intent.commitMoveDirX != 0) {
      // If navigation explicitly requests a direction (e.g., preparing for jump).
      final dirX = intent.commitMoveDirX.toDouble();
      world.enemy.facing[enemyIndex] = dirX > 0 ? Facing.right : Facing.left;
      desiredVelX = dirX * tuning.base.groundEnemySpeedX * effectiveSpeedScale;
    } else if (dx.abs() > tuning.base.groundEnemyStopDistanceX) {
      // Standard seek behavior logic.
      final dirX = dx >= 0 ? 1.0 : -1.0;
      world.enemy.facing[enemyIndex] = dirX > 0 ? Facing.right : Facing.left;
      desiredVelX = dirX * tuning.base.groundEnemySpeedX * effectiveSpeedScale;
    }

    desiredVelX *= moveSpeedMul;

    // -- Jumping --
    if (intent.jumpNow) {
      world.transform.velY[enemyTi] = -tuning.base.groundEnemyJumpSpeed;
    }

    // -- Physics Update --
    final currentVelX = world.transform.velX[enemyTi];
    final nextVelX = applyAccelDecel(
      current: currentVelX,
      desired: desiredVelX,
      dtSeconds: dtSeconds,
      accelPerSecond: tuning.base.groundEnemyAccelX,
      decelPerSecond: tuning.base.groundEnemyDecelX,
    );

    // -- Jump Velocity Snapping --
    // If we are executing a jump edge, we might need to "snap" velocity to exactly
    // what is required to make the gap, overriding acceleration/deceleration.
    // This fixes issues where enemies undershoot/overshoot jumps due to frame variances.
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
            // Only snap if it's reasonable (bounded by current/desired speeds).
            final desiredAbs = desiredVelX.abs();
            final currentAbs = currentVelX.abs();
            final snapAbs = min(desiredAbs, max(currentAbs, requiredAbs));
            // Apply if the snap velocity is actually faster (avoid getting stuck).
            if (snapAbs > nextVelX.abs()) {
              final sign = desiredVelX >= 0.0 ? 1.0 : -1.0;
              jumpSnapVelX = sign * snapAbs;
            }
          }
        }
      }
    }

    world.transform.velX[enemyTi] = jumpSnapVelX ?? nextVelX;

    // -- Ledge Safety --
    // If we have no plan (wandering/chasing blindly), hard stop at surface edges.
    if (!intent.hasPlan && safeSurfaceMinX != null && safeSurfaceMaxX != null) {
      final stopDist = tuning.base.groundEnemyStopDistanceX;
      final nextVelX = world.transform.velX[enemyTi];
      if (nextVelX > 0.0 && ex >= safeSurfaceMaxX - stopDist) {
        world.transform.velX[enemyTi] = 0.0;
      } else if (nextVelX < 0.0 && ex <= safeSurfaceMinX + stopDist) {
        world.transform.velX[enemyTi] = 0.0;
      }
    }
  }
}
