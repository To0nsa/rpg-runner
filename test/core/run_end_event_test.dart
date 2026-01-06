import 'package:flutter_test/flutter_test.dart';

import 'package:walkscape_runner/core/combat/faction.dart';
import 'package:walkscape_runner/core/ecs/spatial/broadphase_grid.dart';
import 'package:walkscape_runner/core/ecs/spatial/grid_index_2d.dart';
import 'package:walkscape_runner/core/ecs/stores/body_store.dart';
import 'package:walkscape_runner/core/ecs/stores/collider_aabb_store.dart';
import 'package:walkscape_runner/core/ecs/stores/hitbox_store.dart';
import 'package:walkscape_runner/core/ecs/stores/health_store.dart';
import 'package:walkscape_runner/core/ecs/stores/mana_store.dart';
import 'package:walkscape_runner/core/ecs/stores/stamina_store.dart';
import 'package:walkscape_runner/core/ecs/systems/damage_system.dart';
import 'package:walkscape_runner/core/ecs/systems/hitbox_damage_system.dart';
import 'package:walkscape_runner/core/ecs/systems/projectile_hit_system.dart';
import 'package:walkscape_runner/core/ecs/world.dart';
import 'package:walkscape_runner/core/enemies/enemy_id.dart';
import 'package:walkscape_runner/core/events/game_event.dart';
import 'package:walkscape_runner/core/game_core.dart';
import 'package:walkscape_runner/core/projectiles/projectile_catalog.dart';
import 'package:walkscape_runner/core/projectiles/projectile_id.dart';
import 'package:walkscape_runner/core/snapshots/enums.dart';
import 'package:walkscape_runner/core/spells/spawn_spell_projectile.dart';
import 'package:walkscape_runner/core/spells/spell_catalog.dart';
import 'package:walkscape_runner/core/spells/spell_id.dart';
import 'package:walkscape_runner/core/tuning/spatial_grid_tuning.dart';

import 'test_spawns.dart';
import 'package:walkscape_runner/core/ecs/entity_factory.dart';

void main() {
  test('projectile kill records death metadata', () {
    final world = EcsWorld();
    const spellCatalog = SpellCatalog();
    final projectiles = ProjectileCatalogDerived.from(
      const ProjectileCatalog(),
      tickHz: 60,
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
      health: const HealthDef(hp: 5, hpMax: 5, regenPerSecond: 0),
      mana: const ManaDef(mana: 0, manaMax: 0, regenPerSecond: 0),
      stamina: const StaminaDef(stamina: 0, staminaMax: 0, regenPerSecond: 0),
    );

    final enemy = spawnFlyingEnemy(world, posX: 120, posY: 100);

    final projectile = spawnSpellProjectile(
      world,
      spells: spellCatalog,
      projectiles: projectiles,
      spellId: SpellId.lightning,
      faction: Faction.enemy,
      owner: enemy,
      originX: 100,
      originY: 100,
      dirX: 1,
      dirY: 0,
    );
    expect(projectile, isNotNull);

    final broadphase = BroadphaseGrid(
      index: GridIndex2D(cellSize: SpatialGridTuning.v0BroadphaseCellSize),
    )..rebuild(world);
    final hits = ProjectileHitSystem();
    final damage = DamageSystem(invulnerabilityTicksOnHit: 0);
    hits.step(world, damage.queue, broadphase);
    damage.step(world, currentTick: 3);

    final li = world.lastDamage.indexOf(player);
    expect(world.lastDamage.kind[li], DeathSourceKind.projectile);
    expect(world.lastDamage.hasEnemyId[li], isTrue);
    expect(world.lastDamage.enemyId[li], EnemyId.flyingEnemy);
    expect(world.lastDamage.hasProjectileId[li], isTrue);
    expect(world.lastDamage.projectileId[li], ProjectileId.lightningBolt);
    expect(world.lastDamage.hasSpellId[li], isTrue);
    expect(world.lastDamage.spellId[li], SpellId.lightning);
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
      health: const HealthDef(hp: 4, hpMax: 4, regenPerSecond: 0),
      mana: const ManaDef(mana: 0, manaMax: 0, regenPerSecond: 0),
      stamina: const StaminaDef(stamina: 0, staminaMax: 0, regenPerSecond: 0),
    );

    final enemy = spawnGroundEnemy(world, posX: 120, posY: 100);

    final hitbox = world.createEntity();
    world.transform.add(hitbox, posX: 100, posY: 100, velX: 0, velY: 0);
    world.hitbox.add(
      hitbox,
      HitboxDef(
        owner: enemy,
        faction: Faction.enemy,
        damage: 10,
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
      index: GridIndex2D(cellSize: SpatialGridTuning.v0BroadphaseCellSize),
    )..rebuild(world);
    final hitboxDamage = HitboxDamageSystem();
    final damage = DamageSystem(invulnerabilityTicksOnHit: 0);
    hitboxDamage.step(world, damage.queue, broadphase);
    damage.step(world, currentTick: 5);

    final li = world.lastDamage.indexOf(player);
    expect(world.lastDamage.kind[li], DeathSourceKind.meleeHitbox);
    expect(world.lastDamage.hasEnemyId[li], isTrue);
    expect(world.lastDamage.enemyId[li], EnemyId.groundEnemy);
    expect(world.lastDamage.hasProjectileId[li], isFalse);
    expect(world.lastDamage.hasSpellId[li], isFalse);
  });

  test('give up emits RunEndReason.gaveUp', () {
    final core = GameCore(seed: 1);
    core.giveUp();

    final ended = core
        .drainEvents()
        .whereType<RunEndedEvent>()
        .single;
    expect(ended.reason, RunEndReason.gaveUp);
  });
}
