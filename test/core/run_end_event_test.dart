import 'package:flutter_test/flutter_test.dart';

import 'package:runner_core/combat/damage_type.dart';
import 'package:runner_core/combat/faction.dart';
import 'package:runner_core/ecs/spatial/broadphase_grid.dart';
import 'package:runner_core/ecs/spatial/grid_index_2d.dart';
import 'package:runner_core/ecs/stores/body_store.dart';
import 'package:runner_core/ecs/stores/collider_aabb_store.dart';
import 'package:runner_core/ecs/stores/hitbox_store.dart';
import 'package:runner_core/ecs/stores/health_store.dart';
import 'package:runner_core/ecs/stores/mana_store.dart';
import 'package:runner_core/ecs/stores/stamina_store.dart';
import 'package:runner_core/ecs/systems/damage_system.dart';
import 'package:runner_core/ecs/systems/hitbox_damage_system.dart';
import 'package:runner_core/ecs/systems/projectile_hit_system.dart';
import 'package:runner_core/ecs/world.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/events/game_event.dart';
import 'package:runner_core/game_core.dart';
import '../support/test_level.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/levels/level_registry.dart';
import 'package:runner_core/projectiles/projectile_id.dart';
import 'package:runner_core/projectiles/projectile_catalog.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/abilities/ability_catalog.dart';
import 'package:runner_core/projectiles/spawn_projectile_item.dart';
import 'package:runner_core/tuning/spatial_grid_tuning.dart';

import 'test_spawns.dart';
import 'package:runner_core/ecs/entity_factory.dart';

void main() {
  test('projectile kill records death metadata', () {
    final world = EcsWorld();
    final projectile = const ProjectileCatalog().get(ProjectileId.thunderBolt);
    final thunderDamage = AbilityCatalog.shared
        .resolve('unoco.enemy_cast')!
        .baseDamage;

    final player = EntityFactory(world).createPlayer(
      posX: 100,
      posY: 100,
      velX: 0,
      velY: 0,
      facing: Facing.right,
      grounded: true,
      body: const BodyDef(isKinematic: true, useGravity: false),
      collider: const ColliderAabbDef(halfX: 8, halfY: 8),
      health: const HealthDef(hp: 500, hpMax: 500, regenPerSecond100: 0),
      mana: const ManaDef(mana: 0, manaMax: 0, regenPerSecond100: 0),
      stamina: const StaminaDef(
        stamina: 0,
        staminaMax: 0,
        regenPerSecond100: 0,
      ),
    );

    final enemy = spawnUnocoDemon(world, posX: 120, posY: 100);

    final projectileItem = spawnProjectileFromCaster(
      world,
      tickHz: 60,
      projectileId: ProjectileId.thunderBolt,
      projectile: projectile,
      faction: Faction.enemy,
      owner: enemy,
      casterX: 100,
      casterY: 100,
      originOffset: 0,
      dirX: 1,
      dirY: 0,
      fallbackDirX: 1,
      fallbackDirY: 0,
      damage100: thunderDamage,
      critChanceBp: 0,
      damageType: projectile.damageType,
      procs: projectile.procs,
      ballistic: projectile.ballistic,
      gravityScale: projectile.gravityScale,
    );
    expect(projectileItem, isNotNull);

    final broadphase = BroadphaseGrid(
      index: GridIndex2D(
        cellSize: const SpatialGridTuning().broadphaseCellSize,
      ),
    )..rebuild(world);
    final hits = ProjectileHitSystem();
    final damage = DamageSystem(invulnerabilityTicksOnHit: 0, rngSeed: 1);
    hits.step(world, broadphase, currentTick: 3);
    damage.step(world, currentTick: 3);

    final li = world.lastDamage.indexOf(player);
    expect(world.lastDamage.kind[li], DeathSourceKind.projectile);
    expect(world.lastDamage.hasEnemyId[li], isTrue);
    expect(world.lastDamage.enemyId[li], EnemyId.unocoDemon);
    expect(world.lastDamage.hasProjectileId[li], isTrue);
    expect(world.lastDamage.projectileId[li], ProjectileId.thunderBolt);
    expect(world.lastDamage.hasSourceProjectileId[li], isTrue);
    expect(world.lastDamage.projectileId[li], ProjectileId.thunderBolt);
  });

  test('melee kill records death metadata', () {
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
      health: const HealthDef(hp: 400, hpMax: 400, regenPerSecond100: 0),
      mana: const ManaDef(mana: 0, manaMax: 0, regenPerSecond100: 0),
      stamina: const StaminaDef(
        stamina: 0,
        staminaMax: 0,
        regenPerSecond100: 0,
      ),
    );

    final enemy = spawnGroundEnemy(world, posX: 120, posY: 100);

    final hitbox = world.createEntity();
    world.transform.add(hitbox, posX: 100, posY: 100, velX: 0, velY: 0);
    world.hitbox.add(
      hitbox,
      HitboxDef(
        owner: enemy,
        faction: Faction.enemy,
        damage100: 1000,
        damageType: DamageType.physical,
        halfX: 8,
        halfY: 8,
        offsetX: 0,
        offsetY: 0,
        dirX: 1,
        dirY: 0,
      ),
    );
    world.hitOnce.add(hitbox);

    final broadphase = BroadphaseGrid(
      index: GridIndex2D(
        cellSize: const SpatialGridTuning().broadphaseCellSize,
      ),
    )..rebuild(world);
    final hitboxDamage = HitboxDamageSystem();
    final damage = DamageSystem(invulnerabilityTicksOnHit: 0, rngSeed: 1);
    hitboxDamage.step(world, broadphase, currentTick: 5);
    damage.step(world, currentTick: 5);

    final li = world.lastDamage.indexOf(player);
    expect(world.lastDamage.kind[li], DeathSourceKind.meleeHitbox);
    expect(world.lastDamage.hasEnemyId[li], isTrue);
    expect(world.lastDamage.enemyId[li], EnemyId.grojib);
    expect(world.lastDamage.hasProjectileId[li], isFalse);
    expect(world.lastDamage.hasSourceProjectileId[li], isFalse);
  });

  test('give up emits RunEndReason.gaveUp', () {
    final core = GameCore(
      levelDefinition: LevelRegistry.byId(LevelId.field),
      playerCharacter: testPlayerCharacter,
      seed: 1,
    );
    core.giveUp();

    final ended = core.drainEvents().whereType<RunEndedEvent>().single;
    expect(ended.reason, RunEndReason.gaveUp);
  });
}
