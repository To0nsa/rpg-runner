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
import 'package:rpg_runner/core/ecs/systems/hitbox_follow_owner_system.dart';
import 'package:rpg_runner/core/ecs/systems/hitbox_damage_system.dart';
import 'package:rpg_runner/core/ecs/systems/melee_attack_system.dart';
import 'package:rpg_runner/core/ecs/systems/projectile_hit_system.dart';
import 'package:rpg_runner/core/ecs/world.dart';
import 'package:rpg_runner/core/projectiles/projectile_catalog.dart';
import 'package:rpg_runner/core/snapshots/enums.dart';
import 'package:rpg_runner/core/spells/spawn_spell_projectile.dart';
import 'package:rpg_runner/core/spells/spell_catalog.dart';
import 'package:rpg_runner/core/spells/spell_id.dart';
import 'package:rpg_runner/core/tuning/ground_enemy_tuning.dart';
import 'package:rpg_runner/core/tuning/spatial_grid_tuning.dart';

import 'test_spawns.dart';
import 'package:rpg_runner/core/ecs/entity_factory.dart';

void main() {
  test('enemy projectile (thunder) damages player', () {
    final world = EcsWorld();
    const spellCatalog = SpellCatalog();
    final thunderDamage = spellCatalog.get(SpellId.thunderBolt).stats.damage;

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
      mana: const ManaDef(mana: 0, manaMax: 0, regenPerSecond: 0),
      stamina: const StaminaDef(stamina: 0, staminaMax: 0, regenPerSecond: 0),
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
      health: const HealthDef(hp: 50, hpMax: 50, regenPerSecond: 0),
      mana: const ManaDef(mana: 80, manaMax: 80, regenPerSecond: 0),
      stamina: const StaminaDef(stamina: 0, staminaMax: 0, regenPerSecond: 0),
    );

    final p = spawnSpellProjectile(
      world,
      spells: spellCatalog,
      projectiles: ProjectileCatalogDerived.from(const ProjectileCatalog(), tickHz: 60),
      spellId: SpellId.thunderBolt,
      faction: Faction.enemy,
      owner: unocoDemon,
      originX: 100,
      originY: 100,
      dirX: -1,
      dirY: 0,
    );
    expect(p, isNotNull);

    final damage = DamageSystem(invulnerabilityTicksOnHit: 0);
    final broadphase = BroadphaseGrid(
      index: GridIndex2D(cellSize: const SpatialGridTuning().broadphaseCellSize),
    )..rebuild(world);
    final hit = ProjectileHitSystem();
    hit.step(
      world,
      damage.queue,
      broadphase,
      currentTick: 1,
    );
    damage.step(world, currentTick: 1);

    expect(
      world.health.hp[world.health.indexOf(player)],
      closeTo(100.0 - thunderDamage, 1e-9),
    );
    expect(world.projectile.has(p!), isFalse);
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
      health: const HealthDef(hp: 100, hpMax: 100, regenPerSecond: 0),
      mana: const ManaDef(mana: 0, manaMax: 0, regenPerSecond: 0),
      stamina: const StaminaDef(stamina: 0, staminaMax: 0, regenPerSecond: 0),
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
      health: const HealthDef(hp: 50, hpMax: 50, regenPerSecond: 0),
      mana: const ManaDef(mana: 0, manaMax: 0, regenPerSecond: 0),
      stamina: const StaminaDef(stamina: 0, staminaMax: 0, regenPerSecond: 0),
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
    final expectedHp = 100.0 - groundEnemyTuning.combat.meleeDamage;

    final engagement = EnemyEngagementSystem(
      groundEnemyTuning: groundEnemyTuning,
    );
    final system = EnemyMeleeSystem(
      groundEnemyTuning: groundEnemyTuning,
    );

    final damage = DamageSystem(invulnerabilityTicksOnHit: 0);
    final broadphase = BroadphaseGrid(
      index: GridIndex2D(cellSize: const SpatialGridTuning().broadphaseCellSize),
    );
    final follow = HitboxFollowOwnerSystem();
    final hitboxDamage = HitboxDamageSystem();
    final meleeAttack = MeleeAttackSystem();

    // Attack starts on engage->attack transition (2nd tick in range).
    const attackStartTick = 2;
    final hitTick = attackStartTick + groundEnemyTuning.combat.meleeWindupTicks;

    // Tick 1: approach -> engage; no hit scheduled yet.
    engagement.step(world, player: player, currentTick: 1);
    system.step(world, player: player, currentTick: 1);
    meleeAttack.step(world, currentTick: 1);
    follow.step(world);
    broadphase.rebuild(world);
    hitboxDamage.step(world, damage.queue, broadphase);
    damage.step(world, currentTick: 1);
    expect(
      world.health.hp[world.health.indexOf(player)],
      closeTo(100.0, 1e-9),
    );

    // Tick 2: engage -> attack; schedule the hit for a future tick.
    engagement.step(world, player: player, currentTick: attackStartTick);
    system.step(world, player: player, currentTick: attackStartTick);
    final intentIndex = world.meleeIntent.indexOf(groundEnemy);
    expect(world.meleeIntent.tick[intentIndex], equals(hitTick));
    meleeAttack.step(world, currentTick: attackStartTick);
    follow.step(world);
    broadphase.rebuild(world);
    hitboxDamage.step(world, damage.queue, broadphase);
    damage.step(world, currentTick: attackStartTick);
    expect(
      world.health.hp[world.health.indexOf(player)],
      closeTo(100.0, 1e-9),
    );

    // No damage until the planned hit tick.
    for (var tick = attackStartTick + 1; tick < hitTick; tick += 1) {
      engagement.step(world, player: player, currentTick: tick);
      system.step(world, player: player, currentTick: tick);
      expect(world.meleeIntent.tick[intentIndex], equals(hitTick));
      meleeAttack.step(world, currentTick: tick);
      follow.step(world);
      broadphase.rebuild(world);
      hitboxDamage.step(world, damage.queue, broadphase);
      damage.step(world, currentTick: tick);
      expect(
        world.health.hp[world.health.indexOf(player)],
        closeTo(100.0, 1e-9),
      );
    }

    // Hit tick: spawn hitbox and apply damage once.
    engagement.step(world, player: player, currentTick: hitTick);
    system.step(world, player: player, currentTick: hitTick);
    meleeAttack.step(world, currentTick: hitTick);
    follow.step(world);
    broadphase.rebuild(world);
    hitboxDamage.step(world, damage.queue, broadphase);
    damage.step(world, currentTick: hitTick);

    expect(
      world.health.hp[world.health.indexOf(player)],
      closeTo(expectedHp, 1e-9),
    );

    // Same tick again should be blocked by HitOnce (hitbox still alive).
    hitboxDamage.step(world, damage.queue, broadphase);
    damage.step(world, currentTick: hitTick);
    expect(
      world.health.hp[world.health.indexOf(player)],
      closeTo(expectedHp, 1e-9),
    );

    // And ground enemy should have a melee cooldown set.
    expect(
      world.cooldown.meleeCooldownTicksLeft[world.cooldown.indexOf(groundEnemy)],
      greaterThan(0),
    );
  });
}
