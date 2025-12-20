import '../../enemies/enemy_id.dart';
import '../../snapshots/enums.dart';
import '../../spells/spell_id.dart';
import '../../tuning/v0_enemy_tuning.dart';
import '../../util/deterministic_rng.dart';
import '../../util/double_math.dart';
import '../entity_id.dart';
import '../stores/cast_intent_store.dart';
import '../stores/melee_intent_store.dart';
import '../world.dart';

class EnemySystem {
  EnemySystem({
    required this.tuning,
  });

  final V0EnemyTuningDerived tuning;

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
        case EnemyId.demon:
          _steerDemon(
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
        case EnemyId.fireWorm:
          _steerFireWorm(
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
        case EnemyId.demon:
          _writeDemonCastIntent(
            world,
            enemy: e,
            ex: ex,
            ey: ey,
            playerX: playerX,
            playerY: playerY,
            currentTick: currentTick,
          );
        case EnemyId.fireWorm:
          _writeFireWormMeleeIntent(
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

  void _steerDemon(
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
    if (!world.demonSteering.has(enemy)) {
      assert(
        false,
        'EnemySystem requires DemonSteeringStore on demons; add it at spawn time.',
      );
      return;
    }

    final steering = world.demonSteering;
    final si = steering.indexOf(enemy);

    var rngState = steering.rngState[si];
    double nextRange(double min, double max) {
      rngState = nextUint32(rngState);
      return rangeDouble(rngState, min, max);
    }

    if (!steering.initialized[si]) {
      steering.initialized[si] = true;
      steering.desiredRangeHoldLeftS[si] = nextRange(
        tuning.base.demonDesiredRangeHoldMinSeconds,
        tuning.base.demonDesiredRangeHoldMaxSeconds,
      );
      steering.desiredRange[si] = nextRange(
        tuning.base.demonDesiredRangeMin,
        tuning.base.demonDesiredRangeMax,
      );
      steering.flightTargetHoldLeftS[si] = 0.0;
      steering.flightTargetAboveGround[si] = nextRange(
        tuning.base.demonMinHeightAboveGround,
        tuning.base.demonMaxHeightAboveGround,
      );
    }

    var desiredRangeHoldLeftS = steering.desiredRangeHoldLeftS[si];
    var desiredRange = steering.desiredRange[si];

    // Hold desired range target.
    if (desiredRangeHoldLeftS > 0.0) {
      desiredRangeHoldLeftS -= dtSeconds;
    } else {
      desiredRangeHoldLeftS = nextRange(
        tuning.base.demonDesiredRangeHoldMinSeconds,
        tuning.base.demonDesiredRangeHoldMaxSeconds,
      );
      desiredRange = nextRange(
        tuning.base.demonDesiredRangeMin,
        tuning.base.demonDesiredRangeMax,
      );
    }

    final dx = playerX - ex;
    final distX = dx.abs();
    if (distX > 1e-6) {
      world.enemy.facing[enemyIndex] = dx >= 0 ? Facing.right : Facing.left;
    }

    final slack = tuning.base.demonHoldSlack;
    double desiredVelX = 0.0;
    if (distX > 1e-6) {
      final dirToPlayerX = dx >= 0 ? 1.0 : -1.0;
      final error = distX - desiredRange;

      if (error.abs() > slack) {
        final slowRadiusX = tuning.base.demonSlowRadiusX;
        final t = slowRadiusX > 0.0
            ? clampDouble((error.abs() - slack) / slowRadiusX, 0.0, 1.0)
            : 1.0;
        final speed = t * tuning.base.demonMaxSpeedX;
        desiredVelX = (error > 0.0 ? dirToPlayerX : -dirToPlayerX) * speed;
      }
    }

    var flightTargetHoldLeftS = steering.flightTargetHoldLeftS[si];
    var flightTargetAboveGround = steering.flightTargetAboveGround[si];
    if (flightTargetHoldLeftS > 0.0) {
      flightTargetHoldLeftS -= dtSeconds;
    } else {
      flightTargetHoldLeftS = nextRange(
        tuning.base.demonFlightTargetHoldMinSeconds,
        tuning.base.demonFlightTargetHoldMaxSeconds,
      );
      flightTargetAboveGround = nextRange(
        tuning.base.demonMinHeightAboveGround,
        tuning.base.demonMaxHeightAboveGround,
      );
    }

    final targetY = groundTopY - flightTargetAboveGround;
    final deltaY = targetY - ey;
    double desiredVelY = clampDouble(
      deltaY * tuning.base.demonVerticalKp,
      -tuning.base.demonMaxSpeedY,
      tuning.base.demonMaxSpeedY,
    );
    if (deltaY.abs() <= tuning.base.demonVerticalDeadzone) {
      desiredVelY = 0.0;
    }

    final currentVelX = world.transform.velX[enemyTi];
    final accel = desiredVelX == 0.0 ? tuning.base.demonDecelX : tuning.base.demonAccelX;
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

  void _steerFireWorm(
    EcsWorld world, {
    required int enemyIndex,
    required EntityId enemy,
    required int enemyTi,
    required double playerX,
    required double ex,
  }) {
    final dx = playerX - ex;
    if (dx.abs() <= tuning.base.fireWormStopDistanceX) {
      world.transform.velX[enemyTi] = 0.0;
      return;
    }

    final dirX = dx >= 0 ? 1.0 : -1.0;
    world.enemy.facing[enemyIndex] = dirX > 0 ? Facing.right : Facing.left;
    world.transform.velX[enemyTi] = dirX * tuning.base.fireWormSpeedX;
  }

  void _writeDemonCastIntent(
    EcsWorld world, {
      required EntityId enemy,
      required double ex,
      required double ey,
      required double playerX,
      required double playerY,
      required int currentTick,
    }) {
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
        originOffset: tuning.base.demonCastOriginOffset,
        cooldownTicks: tuning.demonCastCooldownTicks,
        tick: currentTick,
      ),
    );
  }

  void _writeFireWormMeleeIntent(
    EcsWorld world, {
      required EntityId enemy,
      required int enemyIndex,
      required double ex,
      required double ey,
      required double playerX,
      required int currentTick,
    }) {
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
        'FireWorm melee requires ColliderAabbStore on the enemy to compute hitbox offset.',
      );
      return;
    }
    final dx = (playerX - ex).abs();
    if (dx > tuning.base.fireWormMeleeRangeX) return;

    final facing = world.enemy.facing[enemyIndex];
    final dirX = facing == Facing.right ? 1.0 : -1.0;

    final halfX = tuning.base.fireWormMeleeHitboxSizeX * 0.5;
    final halfY = tuning.base.fireWormMeleeHitboxSizeY * 0.5;

    final ownerHalfX = world.colliderAabb.halfX[world.colliderAabb.indexOf(enemy)];
    final offsetX = dirX * (ownerHalfX * 0.5 + halfX);
    const offsetY = 0.0;

    world.meleeIntent.set(
      enemy,
      MeleeIntentDef(
        damage: tuning.base.fireWormMeleeDamage,
        halfX: halfX,
        halfY: halfY,
        offsetX: offsetX,
        offsetY: offsetY,
        activeTicks: tuning.fireWormMeleeActiveTicks,
        cooldownTicks: tuning.fireWormMeleeCooldownTicks,
        staminaCost: 0.0,
        tick: currentTick,
      ),
    );
  }
}
