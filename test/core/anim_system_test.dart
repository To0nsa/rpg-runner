import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_runner/core/ecs/entity_id.dart';
import 'package:rpg_runner/core/ecs/entity_factory.dart';
import 'package:rpg_runner/core/ecs/stores/body_store.dart';
import 'package:rpg_runner/core/ecs/stores/collider_aabb_store.dart';
import 'package:rpg_runner/core/ecs/stores/health_store.dart';
import 'package:rpg_runner/core/ecs/stores/mana_store.dart';
import 'package:rpg_runner/core/ecs/stores/stamina_store.dart';
import 'package:rpg_runner/core/ecs/systems/active_ability_phase_system.dart';
import 'package:rpg_runner/core/ecs/systems/anim/anim_system.dart';
import 'package:rpg_runner/core/ecs/world.dart';
import 'package:rpg_runner/core/enemies/enemy_catalog.dart';
import 'package:rpg_runner/core/enemies/enemy_id.dart';
import 'package:rpg_runner/core/abilities/ability_def.dart';
import 'package:rpg_runner/core/players/player_character_registry.dart';
import 'package:rpg_runner/core/players/player_tuning.dart';
import 'package:rpg_runner/core/snapshots/enums.dart';

import 'test_spawns.dart';

void main() {
  group('AnimSystem', () {
    late EcsWorld world;
    late AnimSystem animSystem;
    late ActiveAbilityPhaseSystem abilityPhaseSystem;
    late MovementTuningDerived playerMovement;
    late AnimTuningDerived playerAnimTuning;
    const enemyCatalog = EnemyCatalog();

    void stepEnemies(int tick) {
      abilityPhaseSystem.step(world, currentTick: tick);
      animSystem.step(world, player: -1, currentTick: tick);
    }

    void stepPlayer(EntityId player, int tick) {
      abilityPhaseSystem.step(world, currentTick: tick);
      animSystem.step(world, player: player, currentTick: tick);
    }

    setUp(() {
      world = EcsWorld();
      playerMovement = MovementTuningDerived.from(
        PlayerCharacterRegistry.defaultCharacter.tuning.movement,
        tickHz: 60,
      );
      playerAnimTuning = AnimTuningDerived.from(
        PlayerCharacterRegistry.defaultCharacter.tuning.anim,
        tickHz: 60,
      );
      animSystem = AnimSystem(
        tickHz: 60,
        enemyCatalog: enemyCatalog,
        playerMovement: playerMovement,
        playerAnimTuning: playerAnimTuning,
      );
      abilityPhaseSystem = ActiveAbilityPhaseSystem();
    });

    group('Player', () {
      EntityId spawnPlayer({
        double velX = 0,
        double velY = 0,
        bool grounded = true,
        Facing facing = Facing.right,
      }) {
        return EntityFactory(world).createPlayer(
          posX: 0,
          posY: 0,
          velX: velX,
          velY: velY,
          facing: facing,
          grounded: grounded,
          body: const BodyDef(isKinematic: true, useGravity: false),
          collider: const ColliderAabbDef(halfX: 8, halfY: 8),
          health: const HealthDef(hp: 1000, hpMax: 1000, regenPerSecond100: 0),
          mana: const ManaDef(mana: 0, manaMax: 0, regenPerSecond100: 0),
          stamina: const StaminaDef(
            stamina: 0,
            staminaMax: 0,
            regenPerSecond100: 0,
          ),
        );
      }

      test('walk uses movement thresholds when grounded', () {
        final player = spawnPlayer(grounded: true);

        final ti = world.transform.indexOf(player);
        final minSpeed = playerMovement.base.minMoveSpeed;
        final runThreshold = playerMovement.base.runSpeedThresholdX;
        final walkSpeed = minSpeed + (runThreshold - minSpeed) * 0.5;
        world.transform.velX[ti] = walkSpeed;
        world.transform.velY[ti] = 0.0;

        final tick = playerAnimTuning.spawnAnimTicks + 1;
        animSystem.step(world, player: player, currentTick: tick);

        final ai = world.animState.indexOf(player);
        expect(world.animState.anim[ai], equals(AnimKey.walk));
      });

      test('spawn uses spawn anim within window', () {
        expect(playerAnimTuning.spawnAnimTicks, greaterThan(0));
        final player = spawnPlayer(grounded: true);

        animSystem.step(world, player: player, currentTick: 0);

        final ai = world.animState.indexOf(player);
        expect(world.animState.anim[ai], equals(AnimKey.spawn));
      });

      test('dash uses active ability anim and frame', () {
        final player = spawnPlayer(grounded: true);
        final tick = playerAnimTuning.spawnAnimTicks + 5;
        const offset = 2;
        world.activeAbility.set(
          player,
          id: 'eloise.dash',
          slot: AbilitySlot.mobility,
          commitTick: tick - offset,
          windupTicks: 0,
          activeTicks: 10,
          recoveryTicks: 0,
          facingDir: Facing.right,
        );

        stepPlayer(player, tick);

        final ai = world.animState.indexOf(player);
        expect(world.animState.anim[ai], equals(AnimKey.dash));
        expect(world.animState.animFrame[ai], equals(offset));
      });

      test('strike uses active ability anim and frame', () {
        final player = spawnPlayer(grounded: true);
        final tick = playerAnimTuning.spawnAnimTicks + 5;
        const offset = 1;
        world.activeAbility.set(
          player,
          id: 'eloise.sword_strike',
          slot: AbilitySlot.primary,
          commitTick: tick - offset,
          windupTicks: 0,
          activeTicks: 10,
          recoveryTicks: 0,
          facingDir: Facing.right,
        );

        stepPlayer(player, tick);

        final ai = world.animState.indexOf(player);
        expect(world.animState.anim[ai], equals(AnimKey.strike));
        expect(world.animState.animFrame[ai], equals(offset));
      });

      test('cast uses active ability anim and frame', () {
        final player = spawnPlayer(grounded: true);
        final tick = playerAnimTuning.spawnAnimTicks + 5;
        const offset = 1;
        world.activeAbility.set(
          player,
          id: 'eloise.heavy_throw',
          slot: AbilitySlot.projectile,
          commitTick: tick - offset,
          windupTicks: 0,
          activeTicks: 10,
          recoveryTicks: 0,
          facingDir: Facing.right,
        );

        stepPlayer(player, tick);

        final ai = world.animState.indexOf(player);
        expect(world.animState.anim[ai], equals(AnimKey.cast));
        expect(world.animState.animFrame[ai], equals(offset));
      });

      test('ranged uses active ability anim and frame', () {
        final player = spawnPlayer(grounded: true);
        final tick = playerAnimTuning.spawnAnimTicks + 5;
        const offset = 1;
        world.activeAbility.set(
          player,
          id: 'eloise.quick_throw',
          slot: AbilitySlot.projectile,
          commitTick: tick - offset,
          windupTicks: 0,
          activeTicks: 10,
          recoveryTicks: 0,
          facingDir: Facing.right,
        );

        stepPlayer(player, tick);

        final ai = world.animState.indexOf(player);
        expect(world.animState.anim[ai], equals(AnimKey.throwItem));
        expect(world.animState.animFrame[ai], equals(offset));
      });
    });

    group('Unoco demon', () {
      test('idle when stationary', () {
        final enemy = spawnUnocoDemon(
          world,
          posX: 100,
          posY: 100,
          velX: 0,
          velY: 0,
        );

        stepEnemies(1);

        final ai = world.animState.indexOf(enemy);
        expect(world.animState.anim[ai], equals(AnimKey.idle));
      });

      test('run when moving (airborne allowed)', () {
        // Unoco uses run even when airborne (flying demon).
        final enemy = spawnUnocoDemon(
          world,
          posX: 100,
          posY: 100,
          velX: 50,
          velY: 10,
        );
        // Not grounded.
        world.collision.grounded[world.collision.indexOf(enemy)] = false;

        stepEnemies(1);

        final ai = world.animState.indexOf(enemy);
        expect(world.animState.anim[ai], equals(AnimKey.run));
      });

      test('strike mapped to idle (no strike strip)', () {
        final enemy = spawnUnocoDemon(world, posX: 100, posY: 100);

        world.activeAbility.set(
          enemy,
          id: 'common.enemy_strike',
          slot: AbilitySlot.primary,
          commitTick: 5,
          windupTicks: 0,
          activeTicks: 10,
          recoveryTicks: 0,
          facingDir: Facing.right,
        );

        stepEnemies(8);

        final ai = world.animState.indexOf(enemy);
        expect(world.animState.anim[ai], equals(AnimKey.idle));
      });

      test('hit animation on damage', () {
        final enemy = spawnUnocoDemon(world, posX: 100, posY: 100);

        // Add lastDamage component and set tick.
        world.lastDamage.add(enemy);
        final ldi = world.lastDamage.indexOf(enemy);
        world.lastDamage.tick[ldi] = 5;

        stepEnemies(6);

        final ai = world.animState.indexOf(enemy);
        expect(world.animState.anim[ai], equals(AnimKey.hit));
      });

      test('death animation when hp <= 0', () {
        final enemy = spawnUnocoDemon(world, posX: 100, posY: 100);

        // Set HP to zero.
        final hi = world.health.indexOf(enemy);
        world.health.hp[hi] = 0;

        // Set last damage tick for death frame calculation.
        world.lastDamage.add(enemy);
        final ldi = world.lastDamage.indexOf(enemy);
        world.lastDamage.tick[ldi] = 10;

        stepEnemies(15);

        final ai = world.animState.indexOf(enemy);
        expect(world.animState.anim[ai], equals(AnimKey.death));
        expect(world.animState.animFrame[ai], equals(5)); // 15 - 10
      });
    });

    group('Ground enemy', () {
      test('idle when stationary and grounded', () {
        final enemy = spawnGroundEnemy(
          world,
          posX: 100,
          posY: 100,
          velX: 0,
          velY: 0,
        );
        world.collision.grounded[world.collision.indexOf(enemy)] = true;

        stepEnemies(1);

        final ai = world.animState.indexOf(enemy);
        expect(world.animState.anim[ai], equals(AnimKey.idle));
      });

      test('walk when moving slowly and grounded', () {
        final profile = enemyCatalog.get(EnemyId.grojib).animProfile;
        final walkSpeed =
            profile.minMoveSpeed +
            (profile.runSpeedThresholdX - profile.minMoveSpeed) * 0.5;
        final enemy = spawnGroundEnemy(
          world,
          posX: 100,
          posY: 100,
          velX: walkSpeed,
          velY: 0,
        );
        world.collision.grounded[world.collision.indexOf(enemy)] = true;

        stepEnemies(1);

        final ai = world.animState.indexOf(enemy);
        expect(world.animState.anim[ai], equals(AnimKey.walk));
      });

      test('run when moving fast and grounded', () {
        final profile = enemyCatalog.get(EnemyId.grojib).animProfile;
        final enemy = spawnGroundEnemy(
          world,
          posX: 100,
          posY: 100,
          velX: profile.runSpeedThresholdX + 10,
          velY: 0,
        );
        world.collision.grounded[world.collision.indexOf(enemy)] = true;

        stepEnemies(1);

        final ai = world.animState.indexOf(enemy);
        expect(world.animState.anim[ai], equals(AnimKey.run));
      });

      test('jump when airborne with negative velY', () {
        // Ground enemy uses jump animation when moving upward while airborne.
        final enemy = spawnGroundEnemy(
          world,
          posX: 100,
          posY: 100,
          velX: 50,
          velY: -100,
        );
        world.collision.grounded[world.collision.indexOf(enemy)] = false;

        stepEnemies(1);

        final ai = world.animState.indexOf(enemy);
        expect(world.animState.anim[ai], equals(AnimKey.jump));
      });

      test('fall when airborne with positive velY', () {
        // Ground enemy uses fall animation when moving downward while airborne.
        final enemy = spawnGroundEnemy(
          world,
          posX: 100,
          posY: 100,
          velX: 50,
          velY: 100,
        );
        world.collision.grounded[world.collision.indexOf(enemy)] = false;

        stepEnemies(1);

        final ai = world.animState.indexOf(enemy);
        expect(world.animState.anim[ai], equals(AnimKey.fall));
      });

      test('fall when airborne with zero velY', () {
        // At the apex of a jump (velY == 0), use fall animation.
        final enemy = spawnGroundEnemy(
          world,
          posX: 100,
          posY: 100,
          velX: 50,
          velY: 0,
        );
        world.collision.grounded[world.collision.indexOf(enemy)] = false;

        stepEnemies(1);

        final ai = world.animState.indexOf(enemy);
        expect(world.animState.anim[ai], equals(AnimKey.fall));
      });

      test('strike animation on strike', () {
        final enemy = spawnGroundEnemy(world, posX: 100, posY: 100);

        world.activeAbility.set(
          enemy,
          id: 'common.enemy_strike',
          slot: AbilitySlot.primary,
          commitTick: 5,
          windupTicks: 0,
          activeTicks: 10,
          recoveryTicks: 0,
          facingDir: Facing.right,
        );

        stepEnemies(8);

        final ai = world.animState.indexOf(enemy);
        expect(world.animState.anim[ai], equals(AnimKey.strike));
        expect(world.animState.animFrame[ai], equals(3)); // 8 - 5
      });

      test('hit animation on damage', () {
        final enemy = spawnGroundEnemy(world, posX: 100, posY: 100);

        world.lastDamage.add(enemy);
        final ldi = world.lastDamage.indexOf(enemy);
        world.lastDamage.tick[ldi] = 10;

        stepEnemies(11);

        final ai = world.animState.indexOf(enemy);
        expect(world.animState.anim[ai], equals(AnimKey.hit));
        expect(world.animState.animFrame[ai], equals(1)); // 11 - 10
      });

      test('death animation when hp <= 0', () {
        final enemy = spawnGroundEnemy(world, posX: 100, posY: 100);

        final hi = world.health.indexOf(enemy);
        world.health.hp[hi] = 0;

        world.lastDamage.add(enemy);
        final ldi = world.lastDamage.indexOf(enemy);
        world.lastDamage.tick[ldi] = 10;

        stepEnemies(20);

        final ai = world.animState.indexOf(enemy);
        expect(world.animState.anim[ai], equals(AnimKey.death));
        expect(world.animState.animFrame[ai], equals(10)); // 20 - 10
      });
    });

    group('Animation priority', () {
      test('death overrides hit', () {
        final enemy = spawnUnocoDemon(world, posX: 100, posY: 100);

        // Both dead and recently damaged.
        final hi = world.health.indexOf(enemy);
        world.health.hp[hi] = 0;
        world.lastDamage.add(enemy);
        final ldi = world.lastDamage.indexOf(enemy);
        world.lastDamage.tick[ldi] = 1;

        stepEnemies(2);

        final ai = world.animState.indexOf(enemy);
        expect(world.animState.anim[ai], equals(AnimKey.death));
      });

      test('hit overrides strike', () {
        final enemy = spawnGroundEnemy(world, posX: 100, posY: 100);

        // Both strikeing and recently damaged.
        world.activeAbility.set(
          enemy,
          id: 'common.enemy_strike',
          slot: AbilitySlot.primary,
          commitTick: 1,
          windupTicks: 0,
          activeTicks: 10,
          recoveryTicks: 0,
          facingDir: Facing.right,
        );
        world.lastDamage.add(enemy);
        final ldi = world.lastDamage.indexOf(enemy);
        world.lastDamage.tick[ldi] = 2;

        stepEnemies(3);

        final ai = world.animState.indexOf(enemy);
        expect(world.animState.anim[ai], equals(AnimKey.hit));
      });

      test('strike overrides movement', () {
        final enemy = spawnGroundEnemy(world, posX: 100, posY: 100, velX: 100);
        world.collision.grounded[world.collision.indexOf(enemy)] = true;

        // Strikeing while moving.
        world.activeAbility.set(
          enemy,
          id: 'common.enemy_strike',
          slot: AbilitySlot.primary,
          commitTick: 1,
          windupTicks: 0,
          activeTicks: 10,
          recoveryTicks: 0,
          facingDir: Facing.right,
        );

        stepEnemies(5);

        final ai = world.animState.indexOf(enemy);
        expect(world.animState.anim[ai], equals(AnimKey.strike));
      });
    });
  });
}
