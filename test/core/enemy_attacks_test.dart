import 'package:flutter_test/flutter_test.dart';

import 'package:walkscape_runner/core/combat/faction.dart';
import 'package:walkscape_runner/core/ecs/stores/body_store.dart';
import 'package:walkscape_runner/core/ecs/stores/collider_aabb_store.dart';
import 'package:walkscape_runner/core/ecs/stores/health_store.dart';
import 'package:walkscape_runner/core/ecs/stores/mana_store.dart';
import 'package:walkscape_runner/core/ecs/stores/stamina_store.dart';
import 'package:walkscape_runner/core/ecs/systems/damage_system.dart';
import 'package:walkscape_runner/core/ecs/systems/enemy_system.dart';
import 'package:walkscape_runner/core/ecs/systems/hitbox_follow_owner_system.dart';
import 'package:walkscape_runner/core/ecs/systems/hitbox_damage_system.dart';
import 'package:walkscape_runner/core/ecs/systems/melee_attack_system.dart';
import 'package:walkscape_runner/core/ecs/systems/projectile_hit_system.dart';
import 'package:walkscape_runner/core/ecs/world.dart';
import 'package:walkscape_runner/core/projectiles/projectile_catalog.dart';
import 'package:walkscape_runner/core/snapshots/enums.dart';
import 'package:walkscape_runner/core/spells/spawn_spell_projectile.dart';
import 'package:walkscape_runner/core/spells/spell_catalog.dart';
import 'package:walkscape_runner/core/spells/spell_id.dart';
import 'package:walkscape_runner/core/tuning/v0_enemy_tuning.dart';

import 'test_spawns.dart';

void main() {
  test('enemy projectile (lightning) damages player', () {
    final world = EcsWorld();

    final player = world.createPlayer(
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

    final demon = spawnDemon(
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
      spells: const SpellCatalog(),
      projectiles: ProjectileCatalogDerived.from(const ProjectileCatalog(), tickHz: 60),
      spellId: SpellId.lightning,
      faction: Faction.enemy,
      owner: demon,
      originX: 100,
      originY: 100,
      dirX: -1,
      dirY: 0,
    );
    expect(p, isNotNull);

    final damage = DamageSystem(invulnerabilityTicksOnHit: 0);
    final hit = ProjectileHitSystem();
    hit.step(world, damage.queue);
    damage.step(world);

    expect(world.health.hp[world.health.indexOf(player)], closeTo(90.0, 1e-9));
    expect(world.projectile.has(p!), isFalse);
  });

  test('FireWorm melee spawns enemy hitbox that damages player once', () {
    final world = EcsWorld();

    final player = world.createPlayer(
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

    final worm = spawnFireWorm(
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

    final enemyTuning = V0EnemyTuningDerived.from(
      const V0EnemyTuning(
        fireWormMeleeRangeX: 50.0,
        fireWormMeleeCooldownSeconds: 1.0,
        fireWormMeleeActiveSeconds: 0.10,
        fireWormMeleeDamage: 15.0,
        fireWormMeleeHitboxSizeX: 28.0,
        fireWormMeleeHitboxSizeY: 16.0,
      ),
      tickHz: 60,
    );

    final system = EnemySystem(
      tuning: enemyTuning,
    );

    final damage = DamageSystem(invulnerabilityTicksOnHit: 0);
    final follow = HitboxFollowOwnerSystem();
    final hitboxDamage = HitboxDamageSystem();
    final meleeAttack = MeleeAttackSystem();

    const currentTick = 1;
    system.stepAttacks(world, player: player, currentTick: currentTick);
    meleeAttack.step(world, currentTick: currentTick);
    follow.step(world);
    hitboxDamage.step(world, damage.queue);
    damage.step(world);

    expect(world.health.hp[world.health.indexOf(player)], closeTo(85.0, 1e-9));

    // Same tick again should be blocked by HitOnce (hitbox still alive).
    hitboxDamage.step(world, damage.queue);
    damage.step(world);
    expect(world.health.hp[world.health.indexOf(player)], closeTo(85.0, 1e-9));

    // And worm should have a melee cooldown set.
    expect(world.cooldown.meleeCooldownTicksLeft[world.cooldown.indexOf(worm)], greaterThan(0));
  });
}
