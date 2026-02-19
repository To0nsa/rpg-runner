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
import 'package:rpg_runner/core/ecs/systems/projectile_hit_system.dart';
import 'package:rpg_runner/core/ecs/world.dart';
import 'package:rpg_runner/core/events/game_event.dart';
import 'package:rpg_runner/core/projectiles/projectile_id.dart';
import 'package:rpg_runner/core/projectiles/projectile_catalog.dart';
import 'package:rpg_runner/core/snapshots/enums.dart';
import 'package:rpg_runner/core/abilities/ability_catalog.dart';
import 'package:rpg_runner/core/projectiles/spawn_projectile_item.dart';
import 'package:rpg_runner/core/tuning/spatial_grid_tuning.dart';
import 'package:rpg_runner/core/enemies/death_behavior.dart';
import 'package:rpg_runner/core/ecs/stores/death_state_store.dart';

import 'test_spawns.dart';
import 'package:rpg_runner/core/ecs/entity_factory.dart';

void main() {
  test(
    'ProjectileHitSystem keeps projectile alive when owner is in death state',
    () {
      final world = EcsWorld();
      final projectileDef = const ProjectileCatalog().get(
        ProjectileId.fireBolt,
      );
      final iceBoltDamage = AbilityCatalog.shared
          .resolve('eloise.charged_shot')!
          .baseDamage;

      final owner = spawnUnocoDemon(
        world,
        posX: 100,
        posY: 100,
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
      world.deathState.add(
        owner,
        const DeathStateDef(
          phase: DeathPhase.deathAnim,
          deathStartTick: 1,
          despawnTick: 10,
        ),
      );

      // Keep a valid target in broadphase so hit system runs, but far away to
      // avoid overlap-based despawn.
      EntityFactory(world).createPlayer(
        posX: 500,
        posY: 100,
        velX: 0,
        velY: 0,
        facing: Facing.left,
        grounded: true,
        body: const BodyDef(isKinematic: true, useGravity: false),
        collider: const ColliderAabbDef(halfX: 8, halfY: 8),
        health: const HealthDef(hp: 10000, hpMax: 10000, regenPerSecond100: 0),
        mana: const ManaDef(mana: 10000, manaMax: 10000, regenPerSecond100: 0),
        stamina: const StaminaDef(
          stamina: 0,
          staminaMax: 0,
          regenPerSecond100: 0,
        ),
      );

      final projectileEntity = spawnProjectileFromCaster(
        world,
        tickHz: 60,
        projectileId: ProjectileId.fireBolt,
        projectile: projectileDef,
        faction: Faction.enemy,
        owner: owner,
        casterX: 100,
        casterY: 100,
        originOffset: 0,
        dirX: 1,
        dirY: 0,
        fallbackDirX: 1,
        fallbackDirY: 0,
        damage100: iceBoltDamage,
        critChanceBp: 0,
        damageType: projectileDef.damageType,
        procs: projectileDef.procs,
        ballistic: projectileDef.ballistic,
        gravityScale: projectileDef.gravityScale,
      );

      final broadphase = BroadphaseGrid(
        index: GridIndex2D(
          cellSize: const SpatialGridTuning().broadphaseCellSize,
        ),
      )..rebuild(world);
      final hits = ProjectileHitSystem();
      hits.step(world, broadphase, currentTick: 1);

      expect(world.projectile.has(projectileEntity), isTrue);
    },
  );

  test('ProjectileHitSystem damages target and despawns projectile', () {
    final world = EcsWorld();
    final iceBoltDamage = AbilityCatalog.shared
        .resolve('eloise.charged_shot')!
        .baseDamage;
    final projectile = const ProjectileCatalog().get(ProjectileId.iceBolt);

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
      mana: const ManaDef(mana: 10000, manaMax: 10000, regenPerSecond100: 0),
      stamina: const StaminaDef(
        stamina: 0,
        staminaMax: 0,
        regenPerSecond100: 0,
      ),
    );

    final enemy = spawnUnocoDemon(
      world,
      posX: 140,
      posY: 100,
      velX: 0,
      velY: 0,
      facing: Facing.left,
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

    // Spawn a projectile overlapping the enemy.
    final projectileItem = spawnProjectileFromCaster(
      world,
      tickHz: 60,
      projectileId: ProjectileId.iceBolt,
      projectile: projectile,
      faction: Faction.player,
      owner: player,
      casterX: 140,
      casterY: 100,
      originOffset: 0,
      dirX: 1,
      dirY: 0,
      fallbackDirX: 1,
      fallbackDirY: 0,
      damage100: iceBoltDamage,
      critChanceBp: 0,
      damageType: projectile.damageType,
      procs: projectile.procs,
      ballistic: projectile.ballistic,
      gravityScale: projectile.gravityScale,
    );
    expect(projectile, isNotNull);

    final damage = DamageSystem(invulnerabilityTicksOnHit: 0, rngSeed: 1);
    final broadphase = BroadphaseGrid(
      index: GridIndex2D(
        cellSize: const SpatialGridTuning().broadphaseCellSize,
      ),
    )..rebuild(world);
    final hits = ProjectileHitSystem();
    final hitEvents = <ProjectileHitEvent>[];
    hits.step(world, broadphase, currentTick: 1, queueHitEvent: hitEvents.add);
    damage.step(world, currentTick: 1);

    expect(
      world.health.hp[world.health.indexOf(enemy)],
      equals(10000 - iceBoltDamage),
    );
    expect(world.projectile.has(projectileItem), isFalse);
    expect(hitEvents.length, 1);
    expect(hitEvents.single.projectileId, ProjectileId.iceBolt);
    expect(hitEvents.single.projectileId, ProjectileId.iceBolt);
  });
}
