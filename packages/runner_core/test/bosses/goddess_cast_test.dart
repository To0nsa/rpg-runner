import 'package:runner_core/ecs/systems/boss_flight_system.dart';

import 'dart:math' as math;

import 'package:runner_core/combat/control_lock.dart';
import 'package:runner_core/ecs/actor_facing.dart';
import 'package:runner_core/ecs/stores/enemies/goddess_tactics_store.dart';
import 'package:runner_core/ecs/systems/active_ability_phase_system.dart';
import 'package:runner_core/ecs/systems/projectile_launch_system.dart';
import 'package:runner_core/players/characters/eloise.dart';
import 'package:runner_core/projectiles/projectile_catalog.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:test/test.dart';

import '../test_support/combat_pose.dart';
import '../test_support/goddess_combat_fixture.dart';

void main() {
  for (final hz in [30, 60, 90]) {
    for (final initial in Facing.values) {
      for (final hovering in [false, true]) {
        test(
          'orb tracks through release, $hz Hz $initial hovering=$hovering',
          () {
            final f = _casting(hz, initial, hovering: hovering);
            final world = f.world;
            final intents = world.projectileIntent;
            final pi = intents.indexOf(f.boss);
            final ai = world.activeAbility.indexOf(f.boss);
            final start = world.activeAbility.startTick[ai];
            final release = intents.tick[pi];
            final total = world.activeAbility.totalTicks[ai];
            final cooldown = world.cooldown.getTicksLeft(f.boss, 0);
            final launch = ProjectileLaunchSystem(
              projectiles: const ProjectileCatalog(),
              tickHz: hz,
            );
            for (var tick = 11; tick < release; tick++) {
              final facing = tick.isEven ? Facing.left : Facing.right;
              _placePlayer(f, facing);
              _decide(f, tick);
              f.combat.refreshOrbCast(
                world,
                player: f.player,
                currentTick: tick,
              );
              launch.step(world, currentTick: tick);
              expect(actorFacing(world, f.boss), facing);
              expect(world.activeAbility.facing[ai], facing);
              expect(world.activeAbility.startTick[ai], start);
              expect(world.activeAbility.totalTicks[ai], total);
              expect(world.cooldown.getTicksLeft(f.boss, 0), cooldown);
              expect(intents.tick[pi], release);
              expect(world.projectile.denseEntities, isEmpty);
            }
            // Cross and change height after decisions, as same-tick motion can do.
            _placePlayer(f, initial);
            _decide(f, release);
            final facing = initial == Facing.left ? Facing.right : Facing.left;
            _placePlayer(f, facing, height: -80);
            f.combat.refreshOrbCast(
              world,
              player: f.player,
              currentTick: release,
            );
            expect(actorFacing(world, f.boss), facing);
            expect(world.activeAbility.facing[ai], facing);
            resolveCombatPoses(world, release, tickHz: hz);
            expect(
              world.animState.anim[world.animState.indexOf(f.boss)],
              AnimKey.cast,
            );
            launch.step(world, currentTick: release);
            final orb = world.projectile.denseEntities.single;
            final oi = world.projectile.indexOf(orb);
            final ti = world.transform.indexOf(orb);
            final bi = world.transform.indexOf(f.boss);
            final targetTi = world.transform.indexOf(f.player);
            final dx =
                world.transform.posX[targetTi] +
                eloiseCatalog.colliderOffsetX -
                world.transform.posX[bi];
            final dy =
                world.transform.posY[targetTi] +
                eloiseCatalog.colliderOffsetY -
                world.transform.posY[bi];
            final length = math.sqrt(dx * dx + dy * dy);
            expect(world.projectile.dirX[oi], closeTo(dx / length, 1e-12));
            expect(world.projectile.dirY[oi], closeTo(dy / length, 1e-12));
            expect(
              world.transform.posX[ti],
              closeTo(world.transform.posX[bi] + 30 * dx / length, 1e-12),
            );
            expect(
              world.transform.posY[ti],
              closeTo(world.transform.posY[bi] + 30 * dy / length, 1e-12),
            );
            final dirX = world.projectile.dirX[oi],
                dirY = world.projectile.dirY[oi];
            _placePlayer(f, initial);
            _decide(f, release + 1);
            f.combat.refreshOrbCast(
              world,
              player: f.player,
              currentTick: release + 1,
            );
            launch.step(world, currentTick: release + 1);
            expect(actorFacing(world, f.boss), initial);
            expect(world.projectile.denseEntities, [orb]);
            expect(world.projectile.dirX[oi], dirX);
            expect(world.projectile.dirY[oi], dirY);
            if (hovering) {
              expect(
                world.goddessTactics.stateFor(f.boss).phase,
                GoddessTactic.exitOrb,
              );
              expect(
                world.body.useGravity[world.body.indexOf(f.boss)],
                isFalse,
              );
            }
          },
        );
      }
    }
    for (final reason in [
      'cancel',
      'replace',
      'death',
      'stun',
      'suspend',
      'action lock',
      'target death',
    ]) {
      test('$reason cancels pending orb release at $hz Hz', () {
        final f = _casting(hz, Facing.right);
        final world = f.world;
        final ai = world.activeAbility.indexOf(f.boss);
        final pi = world.projectileIntent.indexOf(f.boss);
        final release = world.projectileIntent.tick[pi];
        switch (reason) {
          case 'cancel':
            world.activeAbility.clear(f.boss);
          case 'replace':
            world.activeAbility.startTick[ai]++;
          case 'death':
            world.health.hp[world.health.indexOf(f.boss)] = 0;
          case 'stun':
            world.controlLock.addLock(f.boss, LockFlag.stun, hz, release);
          case 'suspend':
            world.arenaSuspension.addEntity(f.boss);
          case 'action lock':
            world.controlLock.addLock(f.boss, LockFlag.allActions, hz, release);
          case 'target death':
            world.health.hp[world.health.indexOf(f.player)] = 0;
        }
        f.combat.refreshOrbCast(world, player: f.player, currentTick: release);
        ProjectileLaunchSystem(
          projectiles: const ProjectileCatalog(),
          tickHz: hz,
        ).step(world, currentTick: release);
        expect(world.projectile.denseEntities, isEmpty);
        expect(world.projectileIntent.tick[pi], -1);
      });
    }
    test(
      'overlap dead zone retains facing without restarting the cast at $hz Hz',
      () {
        final f = _casting(hz, Facing.right);
        for (final dx in [-2.0, 0.0, 2.0, -1.0, 1.0]) {
          f.world.transform.setPosXY(f.player, f.x + dx, f.playerY);
          f.combat.refreshOrbCast(f.world, player: f.player, currentTick: 11);
          expect(actorFacing(f.world, f.boss), Facing.right);
        }
      },
    );
  }
}

GoddessCombatFixture _casting(int hz, Facing facing, {bool hovering = false}) {
  final f = GoddessCombatFixture(hz: hz, bossX: 300);
  final s = f.world.goddessTactics.stateFor(f.boss)
    ..initialized = true
    ..orbsRemaining = 1;
  if (hovering) {
    s.phase = GoddessTactic.exitPending;

    final ti = f.world.transform.indexOf(f.boss);
    f.world.transform.posY[ti] -= 150;
  }
  _placePlayer(f, facing);
  _decide(f, 10);
  expect(f.action, 'goddess.orb');
  f.combat.refreshOrbCast(f.world, player: f.player, currentTick: 10);
  return f;
}

void _placePlayer(GoddessCombatFixture f, Facing facing, {double height = 0}) {
  f.world.transform.setPosXY(
    f.player,
    f.x + (facing == Facing.left ? -140 : 140),
    f.playerY + height,
  );
}

void _decide(GoddessCombatFixture f, int tick) {
  const ActiveAbilityPhaseSystem().step(f.world, currentTick: tick);
  f.combat.prepareTactics(f.world, player: f.player, currentTick: tick);
  f.combat.step(f.world, player: f.player, currentTick: tick);
  BossFlightSystem(tickHz: f.hz).step(f.world, currentTick: tick);
}
