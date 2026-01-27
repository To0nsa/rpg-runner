import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_runner/core/combat/damage_type.dart';
import 'package:rpg_runner/core/combat/faction.dart';
import 'package:rpg_runner/core/abilities/ability_def.dart';
import 'package:rpg_runner/core/ecs/stores/body_store.dart';
import 'package:rpg_runner/core/ecs/stores/projectile_intent_store.dart';
import 'package:rpg_runner/core/ecs/stores/collider_aabb_store.dart';
import 'package:rpg_runner/core/ecs/stores/health_store.dart';
import 'package:rpg_runner/core/ecs/stores/hitbox_store.dart';
import 'package:rpg_runner/core/ecs/stores/mana_store.dart';
import 'package:rpg_runner/core/ecs/stores/melee_intent_store.dart';
import 'package:rpg_runner/core/ecs/stores/stamina_store.dart';
import 'package:rpg_runner/core/ecs/systems/hitbox_follow_owner_system.dart';
import 'package:rpg_runner/core/ecs/systems/melee_strike_system.dart';
import 'package:rpg_runner/core/ecs/systems/projectile_launch_system.dart';
import 'package:rpg_runner/core/ecs/world.dart';
import 'package:rpg_runner/core/projectiles/projectile_catalog.dart';
import 'package:rpg_runner/core/snapshots/enums.dart';
import 'package:rpg_runner/core/projectiles/projectile_id.dart';
import 'package:rpg_runner/core/projectiles/projectile_item_id.dart';
import 'package:rpg_runner/core/ecs/entity_factory.dart';

void main() {
  test('executors: intent is executed at most once per tick', () {
    final world = EcsWorld();

    final caster = EntityFactory(world).createPlayer(
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
        stamina: 10000,
        staminaMax: 10000,
        regenPerSecond100: 0,
      ),
    );

    // Projectile intent.
    world.projectileIntent.set(
      caster,
      const ProjectileIntentDef(
        projectileItemId: ProjectileItemId.iceBolt,
        abilityId: 'eloise.ice_bolt',
        slot: AbilitySlot.projectile,
        damage100: 100,
        staminaCost100: 0,
        manaCost100: 0,
        projectileId: ProjectileId.iceBolt,
        damageType: DamageType.ice,
        ballistic: false,
        gravityScale: 1.0,
        dirX: 1,
        dirY: 0,
        fallbackDirX: 1,
        fallbackDirY: 0,
        originOffset: 4,
        commitTick: 1,
        windupTicks: 0,
        activeTicks: 1,
        recoveryTicks: 0,
        cooldownTicks: 10,
        tick: 1,
      ),
    );

    final projectileLaunch = ProjectileLaunchSystem(
      projectiles: ProjectileCatalogDerived.from(
        const ProjectileCatalog(),
        tickHz: 60,
      ),
    );

    projectileLaunch.step(world, currentTick: 1);
    projectileLaunch.step(world, currentTick: 1);

    expect(world.projectile.denseEntities.length, 1);

    // Melee intent.
    world.meleeIntent.set(
      caster,
      const MeleeIntentDef(
        abilityId: 'common.unarmed_strike',
        slot: AbilitySlot.primary,
        damage100: 100,
        damageType: DamageType.physical,
        halfX: 4,
        halfY: 4,
        offsetX: 10,
        offsetY: 0,
        dirX: 1,
        dirY: 0,
        commitTick: 2,
        windupTicks: 0,
        activeTicks: 2,
        recoveryTicks: 0,
        cooldownTicks: 10,
        staminaCost100: 1000,
        tick: 2,
      ),
    );

    final meleeStrike = MeleeStrikeSystem();
    meleeStrike.step(world, currentTick: 2);
    meleeStrike.step(world, currentTick: 2);

    expect(world.hitbox.denseEntities.length, 1);
    expect(
      world.stamina.stamina[world.stamina.indexOf(caster)],
      equals(9000),
    );
  });

  test('HitboxFollowOwnerSystem positions hitbox at owner + offset', () {
    final world = EcsWorld();

    final owner = world.createEntity();
    world.transform.add(owner, posX: 100, posY: 50, velX: 0, velY: 0);

    final hitbox = world.createEntity();
    world.transform.add(hitbox, posX: 0, posY: 0, velX: 0, velY: 0);
    world.hitbox.add(
      hitbox,
      HitboxDef(
        owner: owner,
        faction: Faction.player,
        damage100: 100,
        damageType: DamageType.physical,
        halfX: 4,
        halfY: 4,
        offsetX: 10,
        offsetY: -5,
        dirX: 1,
        dirY: 0,
      ),
    );

    final follow = HitboxFollowOwnerSystem();
    follow.step(world);

    final ti = world.transform.indexOf(hitbox);
    expect(world.transform.posX[ti], closeTo(110.0, 1e-9));
    expect(world.transform.posY[ti], closeTo(45.0, 1e-9));
  });

  test('HitOnceStore saturates safely (no crash, deterministic block)', () {
    final world = EcsWorld();

    final hb = world.createEntity();
    world.hitOnce.add(hb);

    world.hitOnce.markHit(hb, 10);
    world.hitOnce.markHit(hb, 11);
    world.hitOnce.markHit(hb, 12);
    world.hitOnce.markHit(hb, 13);

    expect(world.hitOnce.hasHit(hb, 10), isTrue);
    expect(world.hitOnce.hasHit(hb, 11), isTrue);
    expect(world.hitOnce.hasHit(hb, 12), isTrue);
    expect(world.hitOnce.hasHit(hb, 13), isTrue);
    expect(world.hitOnce.hasHit(hb, 99), isFalse);

    // 5th unique hit saturates; after saturation, all targets are treated as hit.
    world.hitOnce.markHit(hb, 99);
    expect(world.hitOnce.hasHit(hb, 99), isTrue);
    expect(world.hitOnce.hasHit(hb, 12345), isTrue);
  });
}
