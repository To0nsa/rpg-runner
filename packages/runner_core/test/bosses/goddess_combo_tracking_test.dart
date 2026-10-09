import 'package:runner_core/combat/control_lock.dart';
import 'package:runner_core/combat/voidborn_goddess_pose_catalog.dart';
import 'package:runner_core/ecs/actor_facing.dart';
import 'package:runner_core/ecs/spatial/broadphase_grid.dart';
import 'package:runner_core/ecs/spatial/grid_index_2d.dart';
import 'package:runner_core/ecs/systems/ability_interrupt.dart';
import 'package:runner_core/ecs/systems/active_ability_phase_system.dart';
import 'package:runner_core/ecs/systems/control_lock_system.dart';
import 'package:runner_core/ecs/systems/cooldown_system.dart';
import 'package:runner_core/ecs/systems/gravity_system.dart';
import 'package:runner_core/ecs/systems/ground_enemy_locomotion_system.dart';
import 'package:runner_core/ecs/systems/hitbox_damage_system.dart';
import 'package:runner_core/ecs/systems/hitbox_follow_owner_system.dart';
import 'package:runner_core/ecs/systems/melee_strike_system.dart';
import 'package:runner_core/players/characters/eloise.dart';
import 'package:runner_core/players/player_tuning.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/tuning/ground_enemy_tuning.dart';
import 'package:runner_core/tuning/physics_tuning.dart';
import 'package:test/test.dart';

import '../test_support/combat_pose.dart';
import '../test_support/goddess_combat_fixture.dart';

void main() {
  for (final hz in [30, 60, 90]) {
    for (final counter in [false, true]) {
      test(
        'combo turns per swipe with matching damage at $hz Hz (counter=$counter)',
        () {
          final h = _Harness(hz)..start(counter: counter);
          final f = h.f;
          final grid = BroadphaseGrid(index: GridIndex2D(cellSize: 64));
          final active = f.world.activeAbility;
          final ai = active.indexOf(f.boss);
          final commit = active.startTick[ai];
          final total = active.totalTicks[ai];
          final profile = VoidbornGoddessPoseCatalog.goddessClaws;
          var previousWindow = 0;
          var strikeDirection = Facing.right;
          final seen = <int>{};
          for (var age = 0; age < total; age++) {
            final tick = commit + age;
            final frame = profile.timing.frameAt(
              elapsed: age,
              windup: active.windupTicks[ai],
              active: active.activeTicks[ai],
              recovery: active.recoveryTicks[ai],
            );
            final window = profile.combo!.strikeWindowAt(frame);
            final newSwipe =
                window != previousWindow && profile.frames[frame].isNotEmpty;
            if (newSwipe) {
              strikeDirection = window.isOdd ? Facing.right : Facing.left;
              seen.add(window);
            }
            // Cross during every live swipe: only the next swipe may turn.
            final side = newSwipe
                ? (strikeDirection == Facing.right ? 1 : -1)
                : (strikeDirection == Facing.right ? -1 : 1);
            f.world.transform.setPosXY(f.player, f.x + side * 35, f.playerY);
            h.decide(tick);
            h.locomote(tick);
            resolveCombatPoses(f.world, tick, tickHz: hz);
            MeleeStrikeSystem().step(f.world, currentTick: tick);
            HitboxFollowOwnerSystem(tickHz: hz)
                .step(f.world, currentTick: tick);
            grid.rebuild(f.world);
            HitboxDamageSystem().step(f.world, grid, currentTick: tick);
            if (profile.frames[frame].isNotEmpty) {
              expect(actorFacing(f.world, f.boss), strikeDirection);
              final hi = f.world.hitbox.indexOf(
                f.world.hitbox.denseEntities.single,
              );
              final capsules = f.world.hitbox.capsules[hi]!;
              expect(capsules, isNotEmpty);
              for (final capsule in capsules) {
                expect(
                  strikeDirection == Facing.right
                      ? capsule.minX > 0
                      : capsule.maxX < 0,
                  isTrue,
                );
              }
            }
            previousWindow = window;
          }
          expect(seen, {1, 2, 3, 4});
          expect(f.world.damageQueue.target, List.filled(4, f.player));
        },
      );

      test(
        'combo follows through terrain then stops in recovery at $hz Hz (counter=$counter)',
        () {
          final a = _Harness(hz)..start(counter: counter);
          final b = _Harness(hz)..start(counter: counter);
          final f = a.f;
          final ai = f.world.activeAbility.indexOf(f.boss);
          final commit = f.world.activeAbility.startTick[ai];
          final recovery =
              commit +
              f.world.activeAbility.windupTicks[ai] +
              f.world.activeAbility.activeTicks[ai];
          final end = commit + f.world.activeAbility.totalTicks[ai];
          final startX = f.x;
          var movedDuringSwipes = false;
          double? recoveryX;
          for (var tick = commit + 1; tick < end; tick++) {
            final age = tick - commit;
            for (final h in [a, b]) {
              // Retreat, then cross behind her halfway through the attack.
              final x = age < hz ~/ 2 ? 420.0 : 140.0;
              h.placePlayer(x);
              h.tick(tick);
            }
            expect(b.f.x, f.x);
            expect(
              actorFacing(b.f.world, b.f.boss),
              actorFacing(f.world, f.boss),
            );
            expect(f.action, 'goddess.claw_combo');
            expect(f.x, inInclusiveRange(9, 591));
            if (age >= f.world.activeAbility.windupTicks[ai] &&
                tick < recovery) {
              movedDuringSwipes |=
                  f.world.transform.velX[f.world.transform.indexOf(f.boss)]
                      .abs() >
                  1;
            }
            if (tick >= recovery) {
              recoveryX ??= f.x;
              expect(f.x, recoveryX);
            }
          }
          expect(movedDuringSwipes, isTrue);
          expect(f.x, lessThan(startX - 20));
          expect(actorFacing(f.world, f.boss), Facing.left);
        },
      );
    }

    test(
      'tracking respects blocked routes, movement locks and cancellation at $hz Hz',
      () {
        for (final stop in ['route', 'move lock', 'cancelled', 'stunned']) {
          final h = _Harness(hz)..start();
          final f = h.f;
          h.placePlayer(420);
          h.tick(11);
          final x = f.x;
          switch (stop) {
            case 'route':
              f.world.navIntent.canWalkDirectlyToTarget[f.world.navIntent
                      .indexOf(f.boss)] =
                  false;
            case 'move lock':
              f.world.controlLock.addLock(f.boss, LockFlag.move, hz, 12);
            case 'cancelled':
              AbilityInterrupt.clearActiveAndTransient(
                f.world,
                entity: f.boss,
                startDeferredCooldown: true,
              );
            case 'stunned':
              f.world.controlLock.addLock(f.boss, LockFlag.stun, hz, 12);
          }
          for (var tick = 12; tick < 12 + hz ~/ 3; tick++) {
            h.tick(tick);
          }
          expect(f.x, x, reason: stop);
        }
      },
    );

    test(
      'follow stops at claw spacing without crossing the player at $hz Hz',
      () {
        final h = _Harness(hz)..start();
        h.placePlayer(350);
        for (var tick = 11; tick < 10 + hz; tick++) {
          h.tick(tick);
          expect(h.f.x, lessThanOrEqualTo(315.01));
        }
        expect(h.f.x, inInclusiveRange(309, 315.01));
      },
    );
  }
}

class _Harness {
  _Harness(int hz)
    : f = GoddessCombatFixture(hz: hz),
      movement = MovementTuningDerived.from(
        eloiseCharacter.tuning.movement,
        tickHz: hz,
      ),
      locomotion = GroundEnemyLocomotionSystem(
        groundEnemyTuning: GroundEnemyTuningDerived.from(
          const GroundEnemyTuning(),
          tickHz: hz,
        ),
      ) {
    // Settle both catalog capsules on the real finite 600-unit floor.
    for (var tick = 1; tick < 10; tick++) {
      integrate(tick);
    }
    f.world.navIntent.canWalkDirectlyToTarget[f.world.navIntent.indexOf(
          f.boss,
        )] =
        true;
  }
  final GoddessCombatFixture f;
  final MovementTuningDerived movement;
  final GroundEnemyLocomotionSystem locomotion;

  void start({bool counter = false}) {
    if (counter) {
      expect(f.combat.tryBeginDodge(f.world, f.boss, f.player, 10), isTrue);
      final execute = f.world.goddessDodge.executeTick[f.state];
      for (var tick = 10; tick < execute; tick++) {
        f.prepare(tick);
        integrate(tick);
      }
      f.prepare(execute);
      decide(execute);
      locomote(execute);
      integrate(execute);
    } else {
      decide(10);
      locomote(10);
      integrate(10);
    }
    expect(f.action, 'goddess.claw_combo');
  }

  void placePlayer(double x) {
    f.motion.beginBodyTeleport(f.world, f.player);
    expect(
      f.motion.tryCommitBodyTeleport(
        f.world,
        f.player,
        bodyX: x,
        bodyY: f.playerY,
        facing: Facing.right,
      ),
      isTrue,
    );
  }

  void decide(int tick) {
    CooldownSystem().step(f.world);
    ControlLockSystem().step(f.world, currentTick: tick);
    const ActiveAbilityPhaseSystem().step(f.world, currentTick: tick);
    f.combat.prepareTactics(f.world, player: f.player, currentTick: tick);
    f.combat.step(f.world, player: f.player, currentTick: tick);
  }

  void locomote(int tick) {
    locomotion.step(
      f.world,
      player: f.player,
      dtSeconds: movement.dtSeconds,
      currentTick: tick,
    );
    f.combat.composeMotion(f.world);
  }

  void integrate(int tick) {
    GravitySystem().step(f.world, movement, physics: const PhysicsTuning());
    f.motion.step(
      f.world,
      player: f.player,
      movement: movement,
      fixedPointPilotEnabled: false,
      fixedPointSubpixelScale: 1024,
      currentTick: tick,
    );
    f.motion.prepareTick(f.world, player: f.player, currentTick: tick + 1);
  }

  void tick(int tick) {
    decide(tick);
    locomote(tick);
    integrate(tick);
  }
}
