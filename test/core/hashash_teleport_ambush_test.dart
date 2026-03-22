import 'package:flutter_test/flutter_test.dart';

import 'package:runner_core/abilities/ability_catalog.dart';
import 'package:runner_core/combat/control_lock.dart';
import 'package:runner_core/combat/damage.dart';
import 'package:runner_core/combat/middleware/hashash_teleport_evade_middleware.dart';
import 'package:runner_core/ecs/entity_factory.dart';
import 'package:runner_core/ecs/stores/body_store.dart';
import 'package:runner_core/ecs/stores/collider_aabb_store.dart';
import 'package:runner_core/ecs/stores/damage_queue_store.dart';
import 'package:runner_core/ecs/stores/health_store.dart';
import 'package:runner_core/ecs/stores/mana_store.dart';
import 'package:runner_core/ecs/stores/stamina_store.dart';
import 'package:runner_core/ecs/stores/enemies/hashash_teleport_state_store.dart';
import 'package:runner_core/ecs/systems/damage_middleware_system.dart';
import 'package:runner_core/ecs/systems/hashash_teleport_ambush_system.dart';
import 'package:runner_core/ecs/world.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/events/game_event.dart';
import 'package:runner_core/snapshots/enums.dart';

void main() {
  test(
    'Hashash evade middleware cancels direct hit and enters teleport-out',
    () {
      final world = EcsWorld(seed: 7);
      final factory = EntityFactory(world);

      final player = factory.createPlayer(
        posX: 100.0,
        posY: 10.0,
        velX: 0.0,
        velY: 0.0,
        facing: Facing.right,
        grounded: true,
        body: const BodyDef(isKinematic: true, useGravity: false),
        collider: const ColliderAabbDef(halfX: 8.0, halfY: 8.0),
        health: const HealthDef(hp: 10000, hpMax: 10000, regenPerSecond100: 0),
        mana: const ManaDef(mana: 0, manaMax: 0, regenPerSecond100: 0),
        stamina: const StaminaDef(
          stamina: 0,
          staminaMax: 0,
          regenPerSecond100: 0,
        ),
      );
      expect(player, isNotNull);

      final hashash = factory.createEnemy(
        enemyId: EnemyId.hashash,
        posX: 60.0,
        posY: 10.0,
        velX: 0.0,
        velY: 0.0,
        facing: Facing.left,
        body: const BodyDef(isKinematic: false, useGravity: true),
        collider: const ColliderAabbDef(halfX: 10.0, halfY: 10.0),
        health: const HealthDef(hp: 5000, hpMax: 5000, regenPerSecond100: 0),
        mana: const ManaDef(mana: 0, manaMax: 0, regenPerSecond100: 0),
        stamina: const StaminaDef(
          stamina: 0,
          staminaMax: 0,
          regenPerSecond100: 0,
        ),
      );

      world.damageQueue.add(
        DamageRequest(
          target: hashash,
          amount100: 1200,
          sourceKind: DeathSourceKind.projectile,
        ),
      );

      final middleware = DamageMiddlewareSystem(
        middlewares: <DamageMiddleware>[
          HashashTeleportEvadeMiddleware(tickHz: 60, evadeChanceBp: 10000),
        ],
      );

      middleware.step(world, currentTick: 10);

      expect(world.damageQueue.length, 1);
      expect(world.damageQueue.flags[0] & DamageQueueFlags.canceled, 1);

      final teleportIndex = world.hashashTeleport.indexOf(hashash);
      expect(
        world.hashashTeleport.phase[teleportIndex],
        HashashTeleportPhase.evadeOut,
      );
      expect(
        world.hashashTeleport.phaseEndTick[teleportIndex],
        greaterThan(10),
      );

      expect(world.activeAbility.hasActiveAbility(hashash), isTrue);
      final activeIndex = world.activeAbility.indexOf(hashash);
      expect(
        world.activeAbility.abilityId[activeIndex],
        'hashash.teleport_out',
      );
    },
  );

  test('Hashash teleport system transitions into ambush and queues strike', () {
    final world = EcsWorld(seed: 19);
    final factory = EntityFactory(world);

    final player = factory.createPlayer(
      posX: 120.0,
      posY: 16.0,
      velX: 0.0,
      velY: 0.0,
      facing: Facing.right,
      grounded: true,
      body: const BodyDef(isKinematic: true, useGravity: false),
      collider: const ColliderAabbDef(halfX: 8.0, halfY: 8.0),
      health: const HealthDef(hp: 10000, hpMax: 10000, regenPerSecond100: 0),
      mana: const ManaDef(mana: 0, manaMax: 0, regenPerSecond100: 0),
      stamina: const StaminaDef(
        stamina: 0,
        staminaMax: 0,
        regenPerSecond100: 0,
      ),
    );

    final hashash = factory.createEnemy(
      enemyId: EnemyId.hashash,
      posX: 40.0,
      posY: 16.0,
      velX: 0.0,
      velY: 0.0,
      facing: Facing.left,
      body: const BodyDef(isKinematic: false, useGravity: true),
      collider: const ColliderAabbDef(halfX: 10.0, halfY: 10.0),
      health: const HealthDef(hp: 5000, hpMax: 5000, regenPerSecond100: 0),
      mana: const ManaDef(mana: 0, manaMax: 0, regenPerSecond100: 0),
      stamina: const StaminaDef(
        stamina: 0,
        staminaMax: 0,
        regenPerSecond100: 0,
      ),
    );

    final teleportIndex = world.hashashTeleport.indexOf(hashash);
    world.hashashTeleport.phase[teleportIndex] = HashashTeleportPhase.evadeOut;
    world.hashashTeleport.phaseEndTick[teleportIndex] = 25;

    final system = HashashTeleportAmbushSystem(tickHz: 60);
    system.step(world, player: player, currentTick: 25);
    final expectedX = 120.0 + system.ambushRightOffsetX;
    final expectedY = 16.0 - system.ambushDropHeightY;

    expect(
      world.hashashTeleport.phase[teleportIndex],
      HashashTeleportPhase.ambush,
    );
    expect(world.hashashTeleport.phaseEndTick[teleportIndex], greaterThan(25));
    expect(
      world.transform.posX[world.transform.indexOf(hashash)],
      closeTo(expectedX, 1e-9),
    );
    expect(
      world.transform.posY[world.transform.indexOf(hashash)],
      closeTo(expectedY, 1e-9),
    );
    expect(world.enemy.facing[world.enemy.indexOf(hashash)], Facing.left);

    final activeIndex = world.activeAbility.indexOf(hashash);
    expect(world.activeAbility.abilityId[activeIndex], 'hashash.ambush');

    final meleeIndex = world.meleeIntent.indexOf(hashash);
    expect(world.meleeIntent.abilityId[meleeIndex], 'hashash.ambush');
    expect(world.meleeIntent.commitTick[meleeIndex], 25);
    expect(world.meleeIntent.tick[meleeIndex], 49);
    expect(world.meleeIntent.activeTicks[meleeIndex], 12);

    expect(world.controlLock.isLocked(hashash, LockFlag.strike, 25), isTrue);
  });

  test('Hashash ambush predicts moving player based on windup lead', () {
    final world = EcsWorld(seed: 33);
    final factory = EntityFactory(world);

    final player = factory.createPlayer(
      posX: 120.0,
      posY: 16.0,
      velX: 180.0,
      velY: 30.0,
      facing: Facing.right,
      grounded: true,
      body: const BodyDef(isKinematic: true, useGravity: false),
      collider: const ColliderAabbDef(halfX: 8.0, halfY: 8.0),
      health: const HealthDef(hp: 10000, hpMax: 10000, regenPerSecond100: 0),
      mana: const ManaDef(mana: 0, manaMax: 0, regenPerSecond100: 0),
      stamina: const StaminaDef(
        stamina: 0,
        staminaMax: 0,
        regenPerSecond100: 0,
      ),
    );

    final hashash = factory.createEnemy(
      enemyId: EnemyId.hashash,
      posX: 30.0,
      posY: 16.0,
      velX: 0.0,
      velY: 0.0,
      facing: Facing.left,
      body: const BodyDef(isKinematic: false, useGravity: true),
      collider: const ColliderAabbDef(halfX: 10.0, halfY: 10.0),
      health: const HealthDef(hp: 5000, hpMax: 5000, regenPerSecond100: 0),
      mana: const ManaDef(mana: 0, manaMax: 0, regenPerSecond100: 0),
      stamina: const StaminaDef(
        stamina: 0,
        staminaMax: 0,
        regenPerSecond100: 0,
      ),
    );

    final teleportIndex = world.hashashTeleport.indexOf(hashash);
    world.hashashTeleport.phase[teleportIndex] = HashashTeleportPhase.evadeOut;
    world.hashashTeleport.phaseEndTick[teleportIndex] = 25;

    final system = HashashTeleportAmbushSystem(tickHz: 60);
    system.step(world, player: player, currentTick: 25);
    final windupTicks = AbilityCatalog.shared
        .resolve('hashash.ambush')!
        .windupTicks;
    final leadSeconds = windupTicks / 60.0;
    final expectedX = 120.0 + 180.0 * leadSeconds + system.ambushRightOffsetX;
    final expectedY = 16.0 + 30.0 * leadSeconds - system.ambushDropHeightY;

    final hashashTransformIndex = world.transform.indexOf(hashash);
    expect(
      world.transform.posX[hashashTransformIndex],
      closeTo(expectedX, 1e-9),
    );
    expect(
      world.transform.posY[hashashTransformIndex],
      closeTo(expectedY, 1e-9),
    );
    expect(world.enemy.facing[world.enemy.indexOf(hashash)], Facing.left);
  });
}
