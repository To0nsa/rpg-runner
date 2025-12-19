import '../../combat/faction.dart';
import '../../enemies/enemy_id.dart';
import '../../snapshots/enums.dart';
import '../../spells/spawn_spell_projectile.dart';
import '../../spells/spell_catalog.dart';
import '../../spells/spell_id.dart';
import '../../tuning/v0_enemy_tuning.dart';
import '../../util/double_math.dart';
import '../entity_id.dart';
import '../stores/hitbox_store.dart';
import '../stores/lifetime_store.dart';
import '../world.dart';
import '../../projectiles/projectile_catalog.dart';

class EnemySystem {
  EnemySystem({
    required this.tuning,
    required this.spells,
    required this.projectiles,
  });

  final V0EnemyTuningDerived tuning;
  final SpellCatalog spells;
  final ProjectileCatalogDerived projectiles;

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

  void stepAttacks(EcsWorld world, {required EntityId player}) {
    if (!world.transform.has(player)) return;
    final playerTi = world.transform.indexOf(player);
    final playerX = world.transform.posX[playerTi];
    final playerY = world.transform.posY[playerTi];

    final enemies = world.enemy;
    for (var ei = 0; ei < enemies.denseEntities.length; ei += 1) {
      final e = enemies.denseEntities[ei];
      if (!world.transform.has(e)) continue;
      if (!world.cooldown.has(e)) continue;
      final enemyCooldownIndex = world.cooldown.indexOf(e);

      final ti = world.transform.indexOf(e);
      final ex = world.transform.posX[ti];
      final ey = world.transform.posY[ti];

      switch (enemies.enemyId[ei]) {
        case EnemyId.demon:
          _tryDemonCast(
            world,
            enemy: e,
            enemyCooldownIndex: enemyCooldownIndex,
            ex: ex,
            ey: ey,
            playerX: playerX,
            playerY: playerY,
          );
        case EnemyId.fireWorm:
          _tryFireWormMelee(
            world,
            enemy: e,
            enemyCooldownIndex: enemyCooldownIndex,
            enemyIndex: ei,
            ex: ex,
            ey: ey,
            playerX: playerX,
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

  void _tryDemonCast(
    EcsWorld world, {
    required EntityId enemy,
    required int enemyCooldownIndex,
    required double ex,
    required double ey,
    required double playerX,
    required double playerY,
  }) {
    if (!world.mana.has(enemy)) return;
    final ci = enemyCooldownIndex;
    if (world.cooldown.castCooldownTicksLeft[ci] > 0) return;

    const spellId = SpellId.lightning;
    final def = spells.get(spellId);

    final mi = world.mana.indexOf(enemy);
    final mana = world.mana.mana[mi];
    if (mana < def.stats.manaCost) return;

    // IMPORTANT: `spawnSpellProjectileFromCaster` owns:
    // - "is this spell a projectile?" checks
    // - direction normalization (with fallback)
    // Only spend mana / start cooldown if a projectile was actually spawned.
    final spawned = spawnSpellProjectileFromCaster(
      world,
      spells: spells,
      projectiles: projectiles,
      spellId: spellId,
      faction: Faction.enemy,
      owner: enemy,
      casterX: ex,
      casterY: ey,
      originOffset: tuning.base.demonCastOriginOffset,
      dirX: playerX - ex,
      dirY: playerY - ey,
      fallbackDirX: 1.0,
      fallbackDirY: 0.0,
    );
    if (spawned == null) return;

    world.mana.mana[mi] = clampDouble(
      mana - def.stats.manaCost,
      0.0,
      world.mana.manaMax[mi],
    );
    world.cooldown.castCooldownTicksLeft[ci] = tuning.demonCastCooldownTicks;
  }

  void _tryFireWormMelee(
    EcsWorld world, {
    required EntityId enemy,
    required int enemyCooldownIndex,
    required int enemyIndex,
    required double ex,
    required double ey,
    required double playerX,
  }) {
    final dx = (playerX - ex).abs();
    if (dx > tuning.base.fireWormMeleeRangeX) return;

    final ci = enemyCooldownIndex;
    if (world.cooldown.meleeCooldownTicksLeft[ci] > 0) return;

    final facing = world.enemy.facing[enemyIndex];
    final dirX = facing == Facing.right ? 1.0 : -1.0;

    final halfX = tuning.base.fireWormMeleeHitboxSizeX * 0.5;
    final halfY = tuning.base.fireWormMeleeHitboxSizeY * 0.5;

    double ownerHalfX = 12.0;
    if (world.colliderAabb.has(enemy)) {
      ownerHalfX = world.colliderAabb.halfX[world.colliderAabb.indexOf(enemy)];
    }
    final offsetX = dirX * (ownerHalfX * 0.5 + halfX);
    const offsetY = 0.0;

    final hitbox = world.createEntity();
    world.transform.add(hitbox, posX: ex, posY: ey, velX: 0.0, velY: 0.0);
    world.hitbox.add(
      hitbox,
      HitboxDef(
        owner: enemy,
        faction: Faction.enemy,
        damage: tuning.base.fireWormMeleeDamage,
        halfX: halfX,
        halfY: halfY,
        offsetX: offsetX,
        offsetY: offsetY,
      ),
    );
    world.hitOnce.add(hitbox);
    world.lifetime.add(
      hitbox,
      LifetimeDef(ticksLeft: tuning.fireWormMeleeActiveTicks),
    );

    world.cooldown.meleeCooldownTicksLeft[ci] = tuning.fireWormMeleeCooldownTicks;
  }
}
