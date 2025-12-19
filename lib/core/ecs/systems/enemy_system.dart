import '../../enemies/enemy_id.dart';
import '../../snapshots/enums.dart';
import '../../spells/spell_id.dart';
import '../../tuning/v0_enemy_tuning.dart';
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
  }) {
    final dx = playerX - ex;
    final distX = dx.abs();
    if (distX > 1e-6) {
      world.enemy.facing[enemyIndex] = dx >= 0 ? Facing.right : Facing.left;
    }

    final desiredRange = tuning.base.demonDesiredRangeX;
    final slack = tuning.base.demonRangeSlack;
    final maxSpeedX = tuning.base.demonMaxSpeedX;

    double desiredVelX = 0.0;
    if (distX > desiredRange + slack) {
      desiredVelX = (dx >= 0 ? 1.0 : -1.0) * maxSpeedX;
    } else if (distX < desiredRange - slack) {
      desiredVelX = (dx >= 0 ? -1.0 : 1.0) * maxSpeedX;
    }

    final targetY = groundTopY - tuning.base.demonHoverOffsetY;
    final deltaY = targetY - ey;
    double desiredVelY = clampDouble(
      deltaY * tuning.base.demonVerticalKp,
      -tuning.base.demonMaxSpeedY,
      tuning.base.demonMaxSpeedY,
    );
    if (deltaY.abs() <= tuning.base.demonVerticalDeadzone) {
      desiredVelY = 0.0;
    }

    world.transform.velX[enemyTi] = desiredVelX;
    world.transform.velY[enemyTi] = desiredVelY;
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
