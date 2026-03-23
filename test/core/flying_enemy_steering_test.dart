import 'package:flutter_test/flutter_test.dart';

import 'package:runner_core/ecs/entity_factory.dart';
import 'package:runner_core/ecs/stores/body_store.dart';
import 'package:runner_core/ecs/stores/collider_aabb_store.dart';
import 'package:runner_core/ecs/stores/health_store.dart';
import 'package:runner_core/ecs/stores/mana_store.dart';
import 'package:runner_core/ecs/stores/stamina_store.dart';
import 'package:runner_core/ecs/systems/flying_enemy_combat_mode_system.dart';
import 'package:runner_core/ecs/systems/flying_enemy_locomotion_system.dart';
import 'package:runner_core/ecs/world.dart';
import 'package:runner_core/abilities/ability_catalog.dart';
import 'package:runner_core/projectiles/projectile_catalog.dart';
import 'package:runner_core/projectiles/projectile_id.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/tuning/flying_enemy_tuning.dart';

import 'test_spawns.dart';

void main() {
  test('flying enemy steering is deterministic for the same seed', () {
    const seed = 12345;
    final worldA = EcsWorld(seed: seed);
    final worldB = EcsWorld(seed: seed);

    final playerA = EntityFactory(worldA).createPlayer(
      posX: 300,
      posY: 120,
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
    final playerB = EntityFactory(worldB).createPlayer(
      posX: 300,
      posY: 120,
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

    final unocoDemonA = spawnUnocoDemon(worldA, posX: 100, posY: 120);
    final unocoDemonB = spawnUnocoDemon(worldB, posX: 100, posY: 120);

    final system = FlyingEnemyLocomotionSystem(
      unocoDemonTuning: UnocoDemonTuningDerived.from(
        const UnocoDemonTuning(),
        tickHz: 60,
      ),
    );

    const dtSeconds = 1.0 / 60.0;
    const groundTopY = 200.0;

    for (var i = 0; i < 5; i += 1) {
      system.step(
        worldA,
        player: playerA,
        groundTopY: groundTopY,
        dtSeconds: dtSeconds,
        currentTick: i,
      );
      system.step(
        worldB,
        player: playerB,
        groundTopY: groundTopY,
        dtSeconds: dtSeconds,
        currentTick: i,
      );

      final tiA = worldA.transform.indexOf(unocoDemonA);
      final tiB = worldB.transform.indexOf(unocoDemonB);
      expect(
        worldA.transform.velX[tiA],
        closeTo(worldB.transform.velX[tiB], 1e-9),
      );
      expect(
        worldA.transform.velY[tiA],
        closeTo(worldB.transform.velY[tiB], 1e-9),
      );
    }
  });

  test(
    'OOM flying enemy closes for melee while cast-ready one holds range',
    () {
      const seed = 2468;
      final worldRanged = EcsWorld(seed: seed);
      final worldMelee = EcsWorld(seed: seed);

      final playerRanged = EntityFactory(worldRanged).createPlayer(
        posX: 300,
        posY: 120,
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
      final playerMelee = EntityFactory(worldMelee).createPlayer(
        posX: 300,
        posY: 120,
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

      final castAbility = AbilityCatalog.shared.resolve('unoco.fire_bolt_cast')!;
      final fireBolt = const ProjectileCatalog().get(ProjectileId.fireBolt);
      final castCost = castAbility.resolveCostForWeaponType(
        fireBolt.weaponType,
      );

      final unocoRanged = spawnUnocoDemon(
        worldRanged,
        posX: 230,
        posY: 120,
        mana: ManaDef(
          mana: castCost.manaCost100 + 500,
          manaMax: castCost.manaCost100 + 500,
          regenPerSecond100: 0,
        ),
      );
      final unocoMelee = spawnUnocoDemon(
        worldMelee,
        posX: 230,
        posY: 120,
        mana: ManaDef(
          mana: castCost.manaCost100 - 100,
          manaMax: castCost.manaCost100 + 500,
          regenPerSecond100: 0,
        ),
      );

      final system = FlyingEnemyLocomotionSystem(
        unocoDemonTuning: UnocoDemonTuningDerived.from(
          const UnocoDemonTuning(),
          tickHz: 60,
        ),
      );
      final combatModeSystem = FlyingEnemyCombatModeSystem();

      combatModeSystem.step(worldRanged);
      combatModeSystem.step(worldMelee);
      system.step(
        worldRanged,
        player: playerRanged,
        groundTopY: 200.0,
        dtSeconds: 1.0 / 60.0,
        currentTick: 0,
      );
      system.step(
        worldMelee,
        player: playerMelee,
        groundTopY: 200.0,
        dtSeconds: 1.0 / 60.0,
        currentTick: 0,
      );

      final tiRanged = worldRanged.transform.indexOf(unocoRanged);
      final tiMelee = worldMelee.transform.indexOf(unocoMelee);
      expect(worldRanged.transform.velX[tiRanged].abs(), equals(0.0));
      expect(worldMelee.transform.velX[tiMelee], greaterThan(0.0));
    },
  );

  test(
    'melee fallback locomotion targets player contact on Y while ranged mode keeps hover target',
    () {
      const seed = 97531;
      final worldRanged = EcsWorld(seed: seed);
      final worldMelee = EcsWorld(seed: seed);

      final playerRanged = EntityFactory(worldRanged).createPlayer(
        posX: 300,
        posY: 200,
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
      final playerMelee = EntityFactory(worldMelee).createPlayer(
        posX: 300,
        posY: 200,
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

      final castAbility = AbilityCatalog.shared.resolve('unoco.fire_bolt_cast')!;
      final fireBolt = const ProjectileCatalog().get(ProjectileId.fireBolt);
      final castCost = castAbility.resolveCostForWeaponType(
        fireBolt.weaponType,
      );

      final unocoRanged = spawnUnocoDemon(
        worldRanged,
        posX: 230,
        posY: 160,
        mana: ManaDef(
          mana: castCost.manaCost100 + 500,
          manaMax: castCost.manaCost100 + 500,
          regenPerSecond100: 0,
        ),
      );
      final unocoMelee = spawnUnocoDemon(
        worldMelee,
        posX: 230,
        posY: 160,
        mana: ManaDef(
          mana: castCost.manaCost100 - 100,
          manaMax: castCost.manaCost100 + 500,
          regenPerSecond100: 0,
        ),
      );

      final system = FlyingEnemyLocomotionSystem(
        unocoDemonTuning: UnocoDemonTuningDerived.from(
          const UnocoDemonTuning(),
          tickHz: 60,
        ),
      );
      final combatModeSystem = FlyingEnemyCombatModeSystem();

      combatModeSystem.step(worldRanged);
      combatModeSystem.step(worldMelee);
      system.step(
        worldRanged,
        player: playerRanged,
        groundTopY: 200.0,
        dtSeconds: 1.0 / 60.0,
        currentTick: 0,
      );
      system.step(
        worldMelee,
        player: playerMelee,
        groundTopY: 200.0,
        dtSeconds: 1.0 / 60.0,
        currentTick: 0,
      );

      final tiRanged = worldRanged.transform.indexOf(unocoRanged);
      final tiMelee = worldMelee.transform.indexOf(unocoMelee);

      expect(worldRanged.transform.velY[tiRanged], lessThan(0.0));
      expect(worldMelee.transform.velY[tiMelee], greaterThan(0.0));
    },
  );

  test(
    'melee fallback ignores slow radius and keeps pushing to max chase speed',
    () {
      final world = EcsWorld(seed: 24680);

      final player = EntityFactory(world).createPlayer(
        posX: 300,
        posY: 120,
        velX: 200,
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

      final castAbility = AbilityCatalog.shared.resolve('unoco.fire_bolt_cast')!;
      final fireBolt = const ProjectileCatalog().get(ProjectileId.fireBolt);
      final castCost = castAbility.resolveCostForWeaponType(
        fireBolt.weaponType,
      );

      final unocoMelee = spawnUnocoDemon(
        world,
        posX: 260,
        posY: 120,
        velX: 250,
        velY: 0,
        mana: ManaDef(
          mana: castCost.manaCost100 - 100,
          manaMax: castCost.manaCost100 + 500,
          regenPerSecond100: 0,
        ),
      );

      final system = FlyingEnemyLocomotionSystem(
        unocoDemonTuning: UnocoDemonTuningDerived.from(
          const UnocoDemonTuning(),
          tickHz: 60,
        ),
      );
      final combatModeSystem = FlyingEnemyCombatModeSystem();

      combatModeSystem.step(world);
      system.step(
        world,
        player: player,
        groundTopY: 200.0,
        dtSeconds: 1.0 / 60.0,
        currentTick: 0,
      );

      final tiMelee = world.transform.indexOf(unocoMelee);
      expect(world.transform.velX[tiMelee], greaterThan(250.0));
    },
  );
}
