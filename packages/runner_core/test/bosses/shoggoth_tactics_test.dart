import 'package:runner_core/abilities/ability_catalog.dart';
import 'package:runner_core/abilities/ability_def.dart';
import 'package:runner_core/collision/terrain/terrain_motion_request.dart';
import 'package:runner_core/combat/control_lock.dart';
import 'package:runner_core/ecs/systems/ability_interrupt.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:test/test.dart';

import '../test_support/shoggoth_combat_fixture.dart';

void main() {
  for (final hz in [30, 60, 90]) {
    for (final (distance, height, direct, expected) in [
      (70.0, 0.0, true, 'shoggoth.tentacle_sweep'),
      (71.0, 0.0, true, 'shoggoth.spinning_charge'),
      (260.0, 0.0, true, 'shoggoth.spinning_charge'),
      (261.0, 0.0, true, 'shoggoth.orb'),
      (150.0, -100.0, true, 'shoggoth.orb'),
      (150.0, 0.0, false, 'shoggoth.orb'),
    ]) {
      test(
        'Shoggoth chooses $expected at $distance/$height/$direct, $hz Hz',
        () {
          final f = ShoggothCombatFixture(hz: hz)..direct = direct;
          f.placePlayer(f.x + distance, y: f.playerY + height);
          f.decide(10);
          expect(f.action, expected);
        },
      );
    }

    test(
      'health thresholds produce capped swarms once, including burst damage, $hz Hz',
      () {
        for (final burst in [false, true]) {
          final f = ShoggothCombatFixture(hz: hz)..hp = burst ? 9000 : 18200;
          f.decide(10);
          expect(f.action, 'shoggoth.summon');
          expect(f.state.phasesReached, burst ? 2 : 1);
          var peak = 0;
          final casts = <String>[f.action!];
          var previous = f.world.activeAbility.startTick[f.ai];
          for (var tick = 11; tick < 10 + hz * 20; tick++) {
            if (tick == 10 + hz) {
              expect(f.utilities.livingSummons(f.world, f.boss), 2);
              f.hp = 9100;
            }
            if (tick == 10 + hz * 4) f.hp = 26000;
            f.decide(tick);
            final count = f.utilities.livingSummons(f.world, f.boss);
            peak = count > peak ? count : peak;
            expect(count, lessThanOrEqualTo(3));
            if (f.action != null &&
                f.world.activeAbility.startTick[f.ai] != previous) {
              casts.add(f.action!);
              previous = f.world.activeAbility.startTick[f.ai];
            }
          }
          expect(peak, 3);
          expect(casts.where((id) => id.startsWith('shoggoth.summon')), [
            'shoggoth.summon',
            'shoggoth.summon_swarm',
          ]);
          expect(f.utilities.livingSummons(f.world, f.boss), 0);
          expect(f.state.phasesCommitted, 2);
        }
      },
    );

    test('phases wait for attack recovery and cooldown, $hz Hz', () {
      final f = ShoggothCombatFixture(hz: hz);
      f.placePlayer(f.x + 45);
      f.decide(10);
      expect(f.action, 'shoggoth.tentacle_sweep');
      f.hp = 9100;
      final end = 10 + f.world.activeAbility.totalTicks[f.ai];
      var summoned = false;
      for (var tick = 11; tick < 10 + 3 * hz; tick++) {
        f.decide(tick);
        expect(f.state.phasesReached, 2);
        if (tick < end) expect(f.action, 'shoggoth.tentacle_sweep');
        if (f.action == 'shoggoth.summon') {
          expect(tick, greaterThanOrEqualTo(10 + (100 * hz / 60).ceil()));
          summoned = true;
          break;
        }
      }
      expect(summoned, isTrue);
    });

    test(
      'failed admission retains phase; cancelled summon cannot repeat it, $hz Hz',
      () {
        final f = ShoggothCombatFixture(hz: hz)..hp = 18200;
        f.world.actorMotionBounds.removeEntity(f.boss);
        f.decide(10);
        expect(f.action, isNull);
        expect(f.state.phasesReached, 1);
        expect(f.state.phasesCommitted, 0);
        f.world.actorMotionBounds.add(
          f.boss,
          TerrainHorizontalBounds(minXTicks: 0, maxXTicks: 600 * 1024),
        );
        f.decide(11);
        expect(f.action, 'shoggoth.summon');
        AbilityInterrupt.clearActiveAndTransient(
          f.world,
          entity: f.boss,
          startDeferredCooldown: true,
        );
        for (var tick = 12; tick < hz * 5; tick++) {
          f.decide(tick);
        }
        expect(f.state.phasesCommitted, 1);
        expect(f.world.bossSummon.denseEntities, isEmpty);
      },
    );

    test(
      'teleport requires sustained separation and marks a fixed safe landing, $hz Hz',
      () {
        final f = ShoggothCombatFixture(hz: hz, bossX: 100)..direct = false;
        f.placePlayer(500);
        int? commit;
        for (var tick = 10; tick < 10 + hz * 6; tick++) {
          f.decide(tick);
          if (f.action == 'shoggoth.teleport') {
            commit = tick;
            break;
          }
          if (tick < 10 + 3 * hz) expect(f.action, isNot('shoggoth.teleport'));
        }
        expect(commit, isNotNull);
        final bi = f.world.bossCombat.indexOf(f.boss);
        final destination = f.world.bossCombat.teleportDestination[bi]!;
        final execute = f.world.bossCombat.executeTick[bi];
        f.placePlayer(450);
        for (var tick = commit! + 1; tick < execute; tick++) {
          f.decide(tick);
          expect(f.x, 100);
          expect(f.world.bossCombat.teleportDestination[bi], destination);
        }
        f.decide(execute);
        expect(f.x, destination.x);
        expect(f.world.bossCombat.teleportDestination[bi], isNull);
        final end = commit + f.world.activeAbility.totalTicks[f.ai];
        for (var tick = execute + 1; tick < end; tick++) {
          f.decide(tick);
          expect(f.action, 'shoggoth.teleport');
        }
        expect(f.state.nextTeleportTick, commit + 8 * hz);
      },
    );

    test(
      'blocked teleport falls back to offense; occupied mark cancels placement, $hz Hz',
      () {
        final blocked = ShoggothCombatFixture(hz: hz)..direct = false;
        blocked.placePlayer(500);
        blocked.world.actorMotionBounds.add(
          blocked.boss,
          TerrainHorizontalBounds(minXTicks: 175 * 1024, maxXTicks: 225 * 1024),
        );
        for (var tick = 10; tick < 10 + hz * 6; tick++) {
          blocked.decide(tick);
          expect(blocked.action, isNot('shoggoth.teleport'));
        }
        expect(blocked.action, 'shoggoth.orb');

        final f = ShoggothCombatFixture(hz: hz, bossX: 100);
        expect(
          f.utilities.commit(
            f.world,
            boss: f.boss,
            ability: AbilityCatalog.shared.resolve('shoggoth.teleport')!,
            targetX: 500,
            tick: 10,
          ),
          isTrue,
        );
        final bi = f.world.bossCombat.indexOf(f.boss);
        final destination = f.world.bossCombat.teleportDestination[bi]!;
        f.placePlayer(destination.x);
        f.decide(f.world.bossCombat.executeTick[bi]);
        expect(f.x, 100);
        expect(f.action, 'shoggoth.teleport');
        expect(f.world.cooldown.isOnCooldown(f.boss, 0), isTrue);
      },
    );

    test(
      'final phase reverses only after completion with a full warning and recovery, $hz Hz',
      () {
        final f = ShoggothCombatFixture(hz: hz, bossX: 150);
        f.state.phasesReached = f.state.phasesCommitted = 2;
        f.hp = 9100;
        f.placePlayer(300);
        f.tick(10);
        expect(f.action, 'shoggoth.spinning_charge');
        final end = 10 + f.world.activeAbility.totalTicks[f.ai];
        for (var tick = 11; tick < end; tick++) {
          f.tick(tick);
        }
        expect(f.x, greaterThan(300));
        f.tick(end);
        expect(f.action, 'shoggoth.return_charge');
        expect(f.world.activeAbility.facing[f.ai], Facing.left);
        expect(f.world.activeAbility.phase[f.ai], AbilityPhase.windup);
        final x = f.x;
        final windup = f.world.activeAbility.windupTicks[f.ai];
        for (var tick = end + 1; tick < end + windup; tick++) {
          f.tick(tick);
          expect(f.x, x);
        }
        f.tick(end + windup);
        expect(f.x, lessThan(x));
        expect(
          f.world.activeAbility.recoveryTicks[f.ai],
          (48 * hz / 60).ceil(),
        );
        final returnEnd = end + f.world.activeAbility.totalTicks[f.ai];
        final recoveryStart =
            end + windup + f.world.activeAbility.activeTicks[f.ai];
        double? recoveryX;
        for (var tick = end + windup + 1; tick < returnEnd; tick++) {
          f.tick(tick);
          if (tick >= recoveryStart) {
            recoveryX ??= f.x;
            expect(f.x, recoveryX);
          }
        }
      },
    );

    for (final interruption in [
      'cancel',
      'replace',
      'stun',
      'death',
      'suspend',
    ]) {
      test(
        '$interruption cancels a captured teleport before placement, $hz Hz',
        () {
          final f = ShoggothCombatFixture(hz: hz, bossX: 100);
          expect(
            f.utilities.commit(
              f.world,
              boss: f.boss,
              ability: AbilityCatalog.shared.resolve('shoggoth.teleport')!,
              targetX: 500,
              tick: 10,
            ),
            isTrue,
          );
          final bi = f.world.bossCombat.indexOf(f.boss);
          final execute = f.world.bossCombat.executeTick[bi];
          switch (interruption) {
            case 'cancel':
              f.world.activeAbility.clear(f.boss);
            case 'replace':
              f.world.activeAbility.startTick[f.ai]++;
            case 'stun':
              f.world.controlLock.addLock(f.boss, LockFlag.stun, hz, execute);
            case 'death':
              f.hp = 0;
            case 'suspend':
              f.world.arenaSuspension.addEntity(f.boss);
          }
          f.decide(execute);
          expect(f.x, 100);
          expect(f.world.bossCombat.executeTick[bi], -1);
          expect(f.world.bossCombat.teleportDestination[bi], isNull);
        },
      );

      test('$interruption cannot revive a return charge, $hz Hz', () {
        final f = ShoggothCombatFixture(hz: hz, bossX: 150);
        f.state.phasesReached = f.state.phasesCommitted = 2;
        f.placePlayer(300);
        f.tick(10);
        final end = f.state.chainEndTick;
        for (var tick = 11; tick < end; tick++) {
          f.tick(tick);
        }
        switch (interruption) {
          case 'cancel':
            f.world.activeAbility.clear(f.boss);
          case 'replace':
            f.world.activeAbility.startTick[f.ai]++;
          case 'stun':
            f.world.controlLock.addLock(f.boss, LockFlag.stun, hz, end);
          case 'death':
            f.hp = 0;
          case 'suspend':
            f.world.arenaSuspension.addEntity(f.boss);
        }
        f.tick(end);
        expect(f.action, isNot('shoggoth.return_charge'));
        expect(f.state.chainStartTick, -1);
      });
    }
  }

  test('Shoggoth state and captured utilities do not survive recycled IDs', () {
    final f = ShoggothCombatFixture();
    f.state.phasesReached = 2;
    f.state.chainEndTick = 400;
    f.world.destroyEntity(f.boss);
    expect(f.world.createEntity(), f.boss);
    expect(f.world.shoggothTactics.has(f.boss), isFalse);
    expect(f.world.bossCombat.has(f.boss), isFalse);
    expect(f.state.phasesReached, 0);
    expect(f.state.chainEndTick, -1);
  });
}
