import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_runner/core/ecs/entity_id.dart';
import 'package:rpg_runner/core/ecs/entity_factory.dart';
import 'package:rpg_runner/core/ecs/stores/body_store.dart';
import 'package:rpg_runner/core/ecs/stores/collider_aabb_store.dart';
import 'package:rpg_runner/core/ecs/stores/health_store.dart';
import 'package:rpg_runner/core/ecs/stores/mana_store.dart';
import 'package:rpg_runner/core/ecs/stores/stamina_store.dart';
import 'package:rpg_runner/core/ecs/stores/death_state_store.dart';
import 'package:rpg_runner/core/ecs/systems/active_ability_phase_system.dart';
import 'package:rpg_runner/core/ecs/systems/anim/anim_system.dart';
import 'package:rpg_runner/core/ecs/world.dart';
import 'package:rpg_runner/core/enemies/enemy_catalog.dart';
import 'package:rpg_runner/core/enemies/enemy_id.dart';
import 'package:rpg_runner/core/abilities/ability_catalog.dart';
import 'package:rpg_runner/core/abilities/ability_def.dart';
import 'package:rpg_runner/core/combat/control_lock.dart';
import 'package:rpg_runner/core/players/player_character_registry.dart';
import 'package:rpg_runner/core/players/player_tuning.dart';
import 'package:rpg_runner/core/enemies/death_behavior.dart';
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

    void stepPlayer(
      EntityId player,
      int tick, {
      DeathPhase deathPhase = DeathPhase.none,
      int deathStartTick = -1,
      int spawnStartTick = 0,
    }) {
      abilityPhaseSystem.step(world, currentTick: tick);
      animSystem.step(
        world,
        player: player,
        currentTick: tick,
        playerDeathPhase: deathPhase,
        playerDeathStartTick: deathStartTick,
        playerSpawnStartTick: spawnStartTick,
      );
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

      test('spawn uses spawnStartTick as frame origin', () {
        expect(playerAnimTuning.spawnAnimTicks, greaterThan(2));
        final player = spawnPlayer(grounded: true);
        const spawnStartTick = 100;

        stepPlayer(player, spawnStartTick + 2, spawnStartTick: spawnStartTick);

        final ai = world.animState.indexOf(player);
        expect(world.animState.anim[ai], equals(AnimKey.spawn));
        expect(world.animState.animFrame[ai], equals(2));
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

      test('dash movement ticks alone do not drive dash animation', () {
        final player = spawnPlayer(grounded: true);
        final tick = playerAnimTuning.spawnAnimTicks + 5;
        final movementIndex = world.movement.indexOf(player);
        world.movement.dashTicksLeft[movementIndex] = 5;

        stepPlayer(player, tick);

        final ai = world.animState.indexOf(player);
        expect(world.animState.anim[ai], equals(AnimKey.idle));
      });

      test('stun animation frame uses stun start tick', () {
        final player = spawnPlayer(grounded: true);
        const stunStartTick = 30;
        world.controlLock.addLock(player, LockFlag.stun, 10, stunStartTick);

        stepPlayer(player, stunStartTick + 3);

        final ai = world.animState.indexOf(player);
        expect(world.animState.anim[ai], equals(AnimKey.stun));
        expect(world.animState.animFrame[ai], equals(3));
      });

      test('stun refresh keeps continuous frame origin', () {
        final player = spawnPlayer(grounded: true);
        world.controlLock.addLock(player, LockFlag.stun, 8, 40);
        world.controlLock.addLock(player, LockFlag.stun, 6, 44);

        stepPlayer(player, 45);

        final ai = world.animState.indexOf(player);
        expect(world.animState.anim[ai], equals(AnimKey.stun));
        expect(world.animState.animFrame[ai], equals(5));
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

      test(
        'backStrike is selected when strike facing opposes current facing',
        () {
          final player = spawnPlayer(grounded: true);
          final movementIndex = world.movement.indexOf(player);
          world.movement.facing[movementIndex] = Facing.right;

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
            facingDir: Facing.left,
          );

          final meleeIndex = world.meleeIntent.indexOf(player);
          world.meleeIntent.abilityId[meleeIndex] = 'eloise.sword_strike';
          world.meleeIntent.dirX[meleeIndex] = -1.0;

          stepPlayer(player, tick);

          final ai = world.animState.indexOf(player);
          expect(world.animState.anim[ai], equals(AnimKey.backStrike));
          expect(world.animState.animFrame[ai], equals(offset));
        },
      );

      test('charged shot uses active ability anim and frame', () {
        final player = spawnPlayer(grounded: true);
        final tick = playerAnimTuning.spawnAnimTicks + 5;
        const offset = 1;
        world.activeAbility.set(
          player,
          id: 'eloise.charged_shot',
          slot: AbilitySlot.projectile,
          commitTick: tick - offset,
          windupTicks: 0,
          activeTicks: 10,
          recoveryTicks: 0,
          facingDir: Facing.right,
        );

        stepPlayer(player, tick);

        final ai = world.animState.indexOf(player);
        final expectedAnim = AbilityCatalog.shared
            .resolve('eloise.charged_shot')!
            .animKey;
        expect(world.animState.anim[ai], equals(expectedAnim));
        expect(world.animState.animFrame[ai], equals(offset));
      });

      test('quick shot uses active ability anim and frame', () {
        final player = spawnPlayer(grounded: true);
        final tick = playerAnimTuning.spawnAnimTicks + 5;
        const offset = 1;
        world.activeAbility.set(
          player,
          id: 'eloise.quick_shot',
          slot: AbilitySlot.projectile,
          commitTick: tick - offset,
          windupTicks: 0,
          activeTicks: 10,
          recoveryTicks: 0,
          facingDir: Facing.right,
        );

        stepPlayer(player, tick);

        final ai = world.animState.indexOf(player);
        final expectedAnim = AbilityCatalog.shared
            .resolve('eloise.quick_shot')!
            .animKey;
        expect(world.animState.anim[ai], equals(expectedAnim));
        expect(world.animState.animFrame[ai], equals(offset));
      });

      test('does not clear active ability when ability id is unknown', () {
        final player = spawnPlayer(grounded: true);
        final tick = playerAnimTuning.spawnAnimTicks + 5;
        const unknownAbilityId = 'test.unknown_ability';
        world.activeAbility.set(
          player,
          id: unknownAbilityId,
          slot: AbilitySlot.primary,
          commitTick: tick - 1,
          windupTicks: 0,
          activeTicks: 10,
          recoveryTicks: 0,
          facingDir: Facing.right,
        );

        // Step only AnimSystem to assert render-only behavior in isolation.
        animSystem.step(world, player: player, currentTick: tick);

        expect(world.activeAbility.hasActiveAbility(player), isTrue);
        final activeIndex = world.activeAbility.indexOf(player);
        expect(world.activeAbility.abilityId[activeIndex], unknownAbilityId);
      });

      test(
        'does not clear active ability when elapsed already exceeds total',
        () {
          final player = spawnPlayer(grounded: true);
          final tick = playerAnimTuning.spawnAnimTicks + 5;
          world.activeAbility.set(
            player,
            id: 'eloise.quick_shot',
            slot: AbilitySlot.projectile,
            commitTick: tick - 1,
            windupTicks: 0,
            activeTicks: 1,
            recoveryTicks: 0,
            facingDir: Facing.right,
          );
          final activeIndex = world.activeAbility.indexOf(player);
          world.activeAbility.elapsedTicks[activeIndex] = 10;

          // Step only AnimSystem to assert render-only behavior in isolation.
          animSystem.step(world, player: player, currentTick: tick);

          expect(world.activeAbility.hasActiveAbility(player), isTrue);
          expect(
            world.activeAbility.abilityId[activeIndex],
            'eloise.quick_shot',
          );
        },
      );

      test('player death animation frame uses provided deathStartTick', () {
        final player = spawnPlayer(grounded: true);
        const deathStartTick = 70;
        const tick = 73;

        stepPlayer(
          player,
          tick,
          deathPhase: DeathPhase.deathAnim,
          deathStartTick: deathStartTick,
        );

        final ai = world.animState.indexOf(player);
        expect(world.animState.anim[ai], equals(AnimKey.death));
        expect(world.animState.animFrame[ai], equals(tick - deathStartTick));
      });

      test('is read-only for gameplay stores', () {
        final player = spawnPlayer(grounded: true);
        const tick = 80;

        world.activeAbility.set(
          player,
          id: 'eloise.quick_shot',
          slot: AbilitySlot.projectile,
          commitTick: tick - 2,
          windupTicks: 0,
          activeTicks: 10,
          recoveryTicks: 0,
          facingDir: Facing.right,
        );

        world.controlLock.addLock(player, LockFlag.stun, 10, tick);
        final aiBefore = world.activeAbility.indexOf(player);
        final miBefore = world.movement.indexOf(player);
        final tiBefore = world.transform.indexOf(player);
        final hiBefore = world.health.indexOf(player);
        final cliBefore = world.controlLock.indexOf(player);

        final activeIdBefore = world.activeAbility.abilityId[aiBefore];
        final activeStartBefore = world.activeAbility.startTick[aiBefore];
        final activePhaseBefore = world.activeAbility.phase[aiBefore];
        final activeElapsedBefore = world.activeAbility.elapsedTicks[aiBefore];
        final dashTicksBefore = world.movement.dashTicksLeft[miBefore];
        final velXBefore = world.transform.velX[tiBefore];
        final velYBefore = world.transform.velY[tiBefore];
        final hpBefore = world.health.hp[hiBefore];
        final stunUntilBefore = world.controlLock.untilTickStun[cliBefore];
        final stunStartBefore = world.controlLock.stunStartTick[cliBefore];

        // Step only AnimSystem to isolate render-path behavior.
        animSystem.step(world, player: player, currentTick: tick);

        final aiAfter = world.activeAbility.indexOf(player);
        final miAfter = world.movement.indexOf(player);
        final tiAfter = world.transform.indexOf(player);
        final hiAfter = world.health.indexOf(player);
        final cliAfter = world.controlLock.indexOf(player);

        expect(world.activeAbility.abilityId[aiAfter], equals(activeIdBefore));
        expect(
          world.activeAbility.startTick[aiAfter],
          equals(activeStartBefore),
        );
        expect(world.activeAbility.phase[aiAfter], equals(activePhaseBefore));
        expect(
          world.activeAbility.elapsedTicks[aiAfter],
          equals(activeElapsedBefore),
        );
        expect(world.movement.dashTicksLeft[miAfter], equals(dashTicksBefore));
        expect(world.transform.velX[tiAfter], equals(velXBefore));
        expect(world.transform.velY[tiAfter], equals(velYBefore));
        expect(world.health.hp[hiAfter], equals(hpBefore));
        expect(
          world.controlLock.untilTickStun[cliAfter],
          equals(stunUntilBefore),
        );
        expect(
          world.controlLock.stunStartTick[cliAfter],
          equals(stunStartBefore),
        );
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

        // Deliberately stale hit tick: resolver should use deathStartTick.
        world.lastDamage.add(enemy);
        final ldi = world.lastDamage.indexOf(enemy);
        world.lastDamage.tick[ldi] = 3;
        world.deathState.add(
          enemy,
          const DeathStateDef(
            phase: DeathPhase.deathAnim,
            deathStartTick: 10,
            despawnTick: -1,
            maxFallDespawnTick: -1,
          ),
        );

        stepEnemies(15);

        final ai = world.animState.indexOf(enemy);
        expect(world.animState.anim[ai], equals(AnimKey.death));
        expect(world.animState.animFrame[ai], equals(5)); // 15 - deathStartTick
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

        // Deliberately stale hit tick: resolver should use deathStartTick.
        world.lastDamage.add(enemy);
        final ldi = world.lastDamage.indexOf(enemy);
        world.lastDamage.tick[ldi] = 4;
        world.deathState.add(
          enemy,
          const DeathStateDef(
            phase: DeathPhase.deathAnim,
            deathStartTick: 14,
            despawnTick: -1,
            maxFallDespawnTick: -1,
          ),
        );

        stepEnemies(20);

        final ai = world.animState.indexOf(enemy);
        expect(world.animState.anim[ai], equals(AnimKey.death));
        expect(world.animState.animFrame[ai], equals(6)); // 20 - deathStartTick
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
