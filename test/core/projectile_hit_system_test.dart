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
import 'package:rpg_runner/core/projectiles/projectile_catalog.dart';
import 'package:rpg_runner/core/projectiles/projectile_id.dart';
import 'package:rpg_runner/core/snapshots/enums.dart';
import 'package:rpg_runner/core/spells/spawn_spell_projectile.dart';
import 'package:rpg_runner/core/spells/spell_catalog.dart';
import 'package:rpg_runner/core/spells/spell_id.dart';
import 'package:rpg_runner/core/tuning/spatial_grid_tuning.dart';

import 'test_spawns.dart';
import 'package:rpg_runner/core/ecs/entity_factory.dart';

void main() {
  test('ProjectileHitSystem damages target and despawns projectile', () {
    final world = EcsWorld();
    const spellCatalog = SpellCatalog();
    final iceBoltDamage = spellCatalog.get(SpellId.iceBolt).stats.damage;

    final player = EntityFactory(world).createPlayer(
      posX: 100,
      posY: 100,
      velX: 0,
      velY: 0,
      facing: Facing.right,
      grounded: true,
      body: const BodyDef(isKinematic: true, useGravity: false),
      collider: const ColliderAabbDef(halfX: 8, halfY: 8),
      health: const HealthDef(hp: 100, hpMax: 100, regenPerSecond: 0),
      mana: const ManaDef(mana: 100, manaMax: 100, regenPerSecond: 0),
      stamina: const StaminaDef(stamina: 0, staminaMax: 0, regenPerSecond: 0),
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
      health: const HealthDef(hp: 100, hpMax: 100, regenPerSecond: 0),
      mana: const ManaDef(mana: 0, manaMax: 0, regenPerSecond: 0),
      stamina: const StaminaDef(stamina: 0, staminaMax: 0, regenPerSecond: 0),
    );

    // Spawn a projectile overlapping the enemy.
    final projectile = spawnSpellProjectile(
      world,
      spells: spellCatalog,
      projectiles: ProjectileCatalogDerived.from(const ProjectileCatalog(), tickHz: 60),
      spellId: SpellId.iceBolt,
      faction: Faction.player,
      owner: player,
      originX: 140,
      originY: 100,
      dirX: 1,
      dirY: 0,
    );
    expect(projectile, isNotNull);

    final damage = DamageSystem(invulnerabilityTicksOnHit: 0);
    final broadphase = BroadphaseGrid(
      index: GridIndex2D(cellSize: const SpatialGridTuning().broadphaseCellSize),
    )..rebuild(world);
    final hits = ProjectileHitSystem();
    final hitEvents = <ProjectileHitEvent>[];
    hits.step(
      world,
      damage.queue,
      broadphase,
      currentTick: 1,
      queueHitEvent: hitEvents.add,
    );
    damage.step(world, currentTick: 1);

    expect(
      world.health.hp[world.health.indexOf(enemy)],
      closeTo(100.0 - iceBoltDamage, 1e-9),
    );
    expect(world.projectile.has(projectile!), isFalse);
    expect(hitEvents.length, 1);
    expect(hitEvents.single.projectileId, ProjectileId.iceBolt);
    expect(hitEvents.single.spellId, SpellId.iceBolt);
  });
}
