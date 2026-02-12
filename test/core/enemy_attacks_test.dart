import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_runner/core/combat/faction.dart';
import 'package:rpg_runner/core/ecs/stores/body_store.dart';
import 'package:rpg_runner/core/ecs/stores/collider_aabb_store.dart';
import 'package:rpg_runner/core/ecs/stores/health_store.dart';
import 'package:rpg_runner/core/ecs/stores/mana_store.dart';
import 'package:rpg_runner/core/ecs/stores/stamina_store.dart';
import 'package:rpg_runner/core/ecs/spatial/broadphase_grid.dart';
import 'package:rpg_runner/core/ecs/spatial/grid_index_2d.dart';
import 'package:rpg_runner/core/ecs/systems/damage_system.dart';
import 'package:rpg_runner/core/ecs/systems/enemy_engagement_system.dart';
import 'package:rpg_runner/core/ecs/systems/enemy_melee_system.dart';
import 'package:rpg_runner/core/ecs/systems/enemy_cast_system.dart';
import 'package:rpg_runner/core/ecs/systems/cooldown_system.dart';
import 'package:rpg_runner/core/ecs/systems/active_ability_phase_system.dart';
import 'package:rpg_runner/core/ecs/systems/hitbox_follow_owner_system.dart';
import 'package:rpg_runner/core/ecs/systems/hitbox_damage_system.dart';
import 'package:rpg_runner/core/ecs/systems/melee_strike_system.dart';
import 'package:rpg_runner/core/ecs/systems/projectile_hit_system.dart';
import 'package:rpg_runner/core/ecs/systems/projectile_launch_system.dart';
import 'package:rpg_runner/core/ecs/world.dart';
import 'package:rpg_runner/core/projectiles/projectile_catalog.dart';
import 'package:rpg_runner/core/projectiles/projectile_id.dart';
import 'package:rpg_runner/core/snapshots/enums.dart';
import 'package:rpg_runner/core/abilities/ability_catalog.dart';
import 'package:rpg_runner/core/abilities/ability_def.dart';
import 'package:rpg_runner/core/projectiles/spawn_projectile_item.dart';
import 'package:rpg_runner/core/enemies/enemy_catalog.dart';
import 'package:rpg_runner/core/tuning/ground_enemy_tuning.dart';
import 'package:rpg_runner/core/tuning/flying_enemy_tuning.dart';
import 'package:rpg_runner/core/tuning/spatial_grid_tuning.dart';

import 'test_spawns.dart';
import 'package:rpg_runner/core/ecs/entity_factory.dart';

void main() {
  test('enemy cast respects cooldown before recast', () {
    final world = EcsWorld();

    final player = EntityFactory(world).createPlayer(
      posX: 100,
      posY: 100,
      velX: 0,
      velY: 0,
      facing: Facing.right,
      grounded: true,
      body: const BodyDef(isKinematic: true, useGravity: false),
      collider: const ColliderAabbDef(halfX: 8, halfY: 8),
      health: const HealthDef(hp: 10000, hpMax: 10000, regenPerSecond100: 0),
      mana: const ManaDef(mana: 0, manaMax: 0, regenPerSecond100: 0),
      stamina: const StaminaDef(
        stamina: 0,
        staminaMax: 0,
        regenPerSecond100: 0,
      ),
    );

    final unocoDemon = spawnUnocoDemon(
      world,
      posX: 130,
      posY: 100,
      velX: 0,
      velY: 0,
      facing: Facing.left,
      body: const BodyDef(isKinematic: true, useGravity: false),
      collider: const ColliderAabbDef(halfX: 8, halfY: 8),
      health: const HealthDef(hp: 5000, hpMax: 5000, regenPerSecond100: 0),
      mana: const ManaDef(mana: 8000, manaMax: 8000, regenPerSecond100: 0),
      stamina: const StaminaDef(
        stamina: 0,
        staminaMax: 0,
        regenPerSecond100: 0,
      ),
    );

    world.cooldown.setTicksLeft(unocoDemon, CooldownGroup.projectile, 0);

    final castSystem = EnemyCastSystem(
      unocoDemonTuning: UnocoDemonTuningDerived.from(
        const UnocoDemonTuning(),
        tickHz: 60,
      ),
      enemyCatalog: const EnemyCatalog(),
      projectiles: const ProjectileCatalog(),
    );
    final launchSystem = ProjectileLaunchSystem(
      projectiles: const ProjectileCatalog(),
      tickHz: 60,
    );
    final cooldownSystem = CooldownSystem();
    final phaseSystem = ActiveAbilityPhaseSystem();

    for (var tick = 1; tick <= 80; tick += 1) {
      cooldownSystem.step(world);
      phaseSystem.step(world, currentTick: tick);
      castSystem.step(world, player: player, currentTick: tick);
      launchSystem.step(world, currentTick: tick);
    }

    // First cast should have launched exactly one projectile by now,
    // and cooldown should still block any recast.
    expect(world.projectile.denseEntities.length, equals(1));
    expect(
      world.cooldown.getTicksLeft(unocoDemon, CooldownGroup.projectile),
      greaterThan(0),
    );

    for (var tick = 81; tick <= 170; tick += 1) {
      cooldownSystem.step(world);
      phaseSystem.step(world, currentTick: tick);
      castSystem.step(world, player: player, currentTick: tick);
      launchSystem.step(world, currentTick: tick);
    }

    // After cooldown expiry, the demon should be able to cast again.
    expect(world.projectile.denseEntities.length, greaterThan(1));
  });

  test('enemy projectile (thunder) damages player', () {
    final world = EcsWorld();
    final thunderDamage = AbilityCatalog.tryGet(
      'common.enemy_cast',
    )!.baseDamage;
    final projectile = const ProjectileCatalog().get(
      ProjectileId.thunderBolt,
    );

    final player = EntityFactory(world).createPlayer(
      posX: 100,
      posY: 100,
      velX: 0,
      velY: 0,
      facing: Facing.right,
      grounded: true,
      body: const BodyDef(isKinematic: true, useGravity: false),
      collider: const ColliderAabbDef(halfX: 8, halfY: 8),
      health: const HealthDef(hp: 10000, hpMax: 10000, regenPerSecond100: 0),
      mana: const ManaDef(mana: 0, manaMax: 0, regenPerSecond100: 0),
      stamina: const StaminaDef(
        stamina: 0,
        staminaMax: 0,
        regenPerSecond100: 0,
      ),
    );

    final unocoDemon = spawnUnocoDemon(
      world,
      posX: 120,
      posY: 100,
      velX: 0,
      velY: 0,
      facing: Facing.left,
      body: const BodyDef(isKinematic: true, useGravity: false),
      collider: const ColliderAabbDef(halfX: 8, halfY: 8),
      health: const HealthDef(hp: 5000, hpMax: 5000, regenPerSecond100: 0),
      mana: const ManaDef(mana: 8000, manaMax: 8000, regenPerSecond100: 0),
      stamina: const StaminaDef(
        stamina: 0,
        staminaMax: 0,
        regenPerSecond100: 0,
      ),
    );

    final p = spawnProjectileFromCaster(
      world,
      tickHz: 60,
      projectileId: ProjectileId.thunderBolt,
      projectile: projectile,
      faction: Faction.enemy,
      owner: unocoDemon,
      casterX: 100,
      casterY: 100,
      originOffset: 0,
      dirX: -1,
      dirY: 0,
      fallbackDirX: -1,
      fallbackDirY: 0,
      damage100: thunderDamage,
      critChanceBp: 0,
      damageType: projectile.damageType,
      procs: projectile.procs,
      ballistic: projectile.ballistic,
      gravityScale: projectile.gravityScale,
    );
    expect(p, isNotNull);

    final damage = DamageSystem(invulnerabilityTicksOnHit: 0, rngSeed: 1);
    final broadphase = BroadphaseGrid(
      index: GridIndex2D(
        cellSize: const SpatialGridTuning().broadphaseCellSize,
      ),
    )..rebuild(world);
    final hit = ProjectileHitSystem();
    hit.step(world, broadphase, currentTick: 1);
    damage.step(world, currentTick: 1);

    expect(
      world.health.hp[world.health.indexOf(player)],
      equals(10000 - thunderDamage),
    );
    expect(world.projectile.has(p), isFalse);
  });

  test('GroundEnemy melee spawns enemy hitbox that damages player once', () {
    final world = EcsWorld();

    final player = EntityFactory(world).createPlayer(
      posX: 100,
      posY: 100,
      velX: 0,
      velY: 0,
      facing: Facing.right,
      grounded: true,
      body: const BodyDef(isKinematic: true, useGravity: false),
      collider: const ColliderAabbDef(halfX: 8, halfY: 8),
      health: const HealthDef(hp: 10000, hpMax: 10000, regenPerSecond100: 0),
      mana: const ManaDef(mana: 0, manaMax: 0, regenPerSecond100: 0),
      stamina: const StaminaDef(
        stamina: 0,
        staminaMax: 0,
        regenPerSecond100: 0,
      ),
    );

    final groundEnemy = spawnGroundEnemy(
      world,
      posX: 120,
      posY: 100,
      velX: 0,
      velY: 0,
      facing: Facing.left,
      body: const BodyDef(isKinematic: true, useGravity: false),
      collider: const ColliderAabbDef(halfX: 12, halfY: 12),
      health: const HealthDef(hp: 5000, hpMax: 5000, regenPerSecond100: 0),
      mana: const ManaDef(mana: 0, manaMax: 0, regenPerSecond100: 0),
      stamina: const StaminaDef(
        stamina: 0,
        staminaMax: 0,
        regenPerSecond100: 0,
      ),
    );

    final groundEnemyTuning = GroundEnemyTuningDerived.from(
      const GroundEnemyTuning(
        combat: GroundEnemyCombatTuning(
          meleeRangeX: 50.0,
          meleeCooldownSeconds: 1.0,
          meleeActiveSeconds: 0.10,
          meleeDamage: 15.0,
          meleeHitboxSizeX: 28.0,
          meleeHitboxSizeY: 16.0,
        ),
      ),
      tickHz: 60,
    );
    final expectedHp =
        10000 - (groundEnemyTuning.combat.meleeDamage * 100).round();

    final engagement = EnemyEngagementSystem(
      groundEnemyTuning: groundEnemyTuning,
    );
    final system = EnemyMeleeSystem(groundEnemyTuning: groundEnemyTuning);

    final damage = DamageSystem(invulnerabilityTicksOnHit: 0, rngSeed: 1);
    final broadphase = BroadphaseGrid(
      index: GridIndex2D(
        cellSize: const SpatialGridTuning().broadphaseCellSize,
      ),
    );
    final follow = HitboxFollowOwnerSystem();
    final hitboxDamage = HitboxDamageSystem();
    final meleeStrike = MeleeStrikeSystem();

    // Strike starts on engage->strike transition (2nd tick in range).
    const strikeStartTick = 2;
    final hitTick = strikeStartTick + groundEnemyTuning.combat.meleeWindupTicks;

    // Tick 1: approach -> engage; no hit scheduled yet.
    engagement.step(world, player: player, currentTick: 1);
    system.step(world, player: player, currentTick: 1);
    meleeStrike.step(world, currentTick: 1);
    follow.step(world);
    broadphase.rebuild(world);
    hitboxDamage.step(world, broadphase, currentTick: 1);
    damage.step(world, currentTick: 1);
    expect(world.health.hp[world.health.indexOf(player)], equals(10000));

    // Tick 2: engage -> strike; schedule the hit for a future tick.
    engagement.step(world, player: player, currentTick: strikeStartTick);
    system.step(world, player: player, currentTick: strikeStartTick);
    final intentIndex = world.meleeIntent.indexOf(groundEnemy);
    expect(world.meleeIntent.tick[intentIndex], equals(hitTick));
    meleeStrike.step(world, currentTick: strikeStartTick);
    follow.step(world);
    broadphase.rebuild(world);
    hitboxDamage.step(world, broadphase, currentTick: strikeStartTick);
    damage.step(world, currentTick: strikeStartTick);
    expect(world.health.hp[world.health.indexOf(player)], equals(10000));

    // No damage until the planned hit tick.
    for (var tick = strikeStartTick + 1; tick < hitTick; tick += 1) {
      engagement.step(world, player: player, currentTick: tick);
      system.step(world, player: player, currentTick: tick);
      expect(world.meleeIntent.tick[intentIndex], equals(hitTick));
      meleeStrike.step(world, currentTick: tick);
      follow.step(world);
      broadphase.rebuild(world);
      hitboxDamage.step(world, broadphase, currentTick: tick);
      damage.step(world, currentTick: tick);
      expect(world.health.hp[world.health.indexOf(player)], equals(10000));
    }

    // Hit tick: spawn hitbox and apply damage once.
    engagement.step(world, player: player, currentTick: hitTick);
    system.step(world, player: player, currentTick: hitTick);
    meleeStrike.step(world, currentTick: hitTick);
    follow.step(world);
    broadphase.rebuild(world);
    hitboxDamage.step(world, broadphase, currentTick: hitTick);
    damage.step(world, currentTick: hitTick);

    expect(world.health.hp[world.health.indexOf(player)], equals(expectedHp));

    // Same tick again should be blocked by HitOnce (hitbox still alive).
    hitboxDamage.step(world, broadphase, currentTick: hitTick);
    damage.step(world, currentTick: hitTick);
    expect(world.health.hp[world.health.indexOf(player)], equals(expectedHp));

    // And ground enemy should have a melee cooldown set.
    expect(
      world.cooldown.getTicksLeft(groundEnemy, CooldownGroup.primary),
      greaterThan(0),
    );
  });
}
