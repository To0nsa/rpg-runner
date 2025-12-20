import '../../enemies/enemy_id.dart';
import '../../snapshots/enums.dart';
import '../../spells/spell_id.dart';
import '../../tuning/v0_flying_enemy_tuning.dart';
import '../../tuning/v0_ground_enemy_tuning.dart';
import '../../util/deterministic_rng.dart';
import '../../util/double_math.dart';
import '../entity_id.dart';
import '../stores/cast_intent_store.dart';
import '../stores/melee_intent_store.dart';
import '../world.dart';

class EnemySystem {
  EnemySystem({
    required this.flyingEnemyTuning,
    required this.groundEnemyTuning,
  });

  final V0FlyingEnemyTuningDerived flyingEnemyTuning;
  final V0GroundEnemyTuningDerived groundEnemyTuning;

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
            ex: ex,
          );
      }
    }
  }

  void stepAttacks(EcsWorld world, {required EntityId player, required int currentTick}) {
    if (!world.transform.has(player)) return;
    final playerTi = world.transform.indexOf(player);
    final playerX = world.transform.posX[playerTi];
    final playerY = world.transform.posY[playerTi];

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
          _writeFlyingEnemyCastIntent(
            world,
            enemy: e,
            ex: ex,
            ey: ey,
            playerX: playerX,
            playerY: playerY,
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
    final accel = desiredVelX == 0.0 ? tuning.base.flyingEnemyDecelX : tuning.base.flyingEnemyAccelX;
    final maxDeltaX = accel * dtSeconds;
    final deltaVelX = desiredVelX - currentVelX;
    final nextVelX = deltaVelX.abs() > maxDeltaX
        ? currentVelX + (deltaVelX > 0.0 ? maxDeltaX : -maxDeltaX)
        : desiredVelX;

    world.transform.velX[enemyTi] = nextVelX;
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
    required double ex,
  }) {
    final dx = playerX - ex;
    final tuning = groundEnemyTuning;
    if (dx.abs() <= tuning.base.groundEnemyStopDistanceX) {
      world.transform.velX[enemyTi] = 0.0;
      return;
    }

    final dirX = dx >= 0 ? 1.0 : -1.0;
    world.enemy.facing[enemyIndex] = dirX > 0 ? Facing.right : Facing.left;
    world.transform.velX[enemyTi] = dirX * tuning.base.groundEnemySpeedX;
  }

  void _writeFlyingEnemyCastIntent(
    EcsWorld world, {
      required EntityId enemy,
      required double ex,
      required double ey,
      required double playerX,
      required double playerY,
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

    // IMPORTANT: EnemySystem writes intent only; execution happens in
    // `SpellCastSystem` which owns mana/cooldown rules and projectile spawning.
    world.castIntent.set(
      enemy,
      CastIntentDef(
        spellId: spellId,
        dirX: playerX - ex,
        dirY: playerY - ey,
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

    final ownerHalfX = world.colliderAabb.halfX[world.colliderAabb.indexOf(enemy)];
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
        activeTicks: tuning.groundEnemyMeleeActiveTicks,
        cooldownTicks: tuning.groundEnemyMeleeCooldownTicks,
        staminaCost: 0.0,
        tick: currentTick,
      ),
    );
  }
}
