import 'package:runner_core/collision/terrain/terrain_motion_request.dart';
import 'package:runner_core/combat/control_lock.dart';
import 'package:runner_core/ecs/combat_eligibility.dart';
import 'package:runner_core/ecs/stores/enemies/goddess_tactics_store.dart';
import 'package:runner_core/ecs/systems/active_ability_phase_system.dart';
import 'package:runner_core/ecs/systems/control_lock_system.dart';
import 'package:runner_core/ecs/systems/cooldown_system.dart';
import 'package:test/test.dart';

import '../test_support/goddess_combat_fixture.dart';

void main() {
  for (final hz in [30, 60, 90]) {
    test('medium range holds ground for a seeded orb sequence at $hz Hz', () {
      for (final budget in [1, 2]) {
        final f = GoddessCombatFixture(hz: hz, bossX: 100);
        final s = f.world.goddessTactics.stateFor(f.boss)
          ..initialized = true
          ..orbsRemaining = budget;
        var casts = 0;
        for (var tick = 1; tick <= hz * 6; tick++) {
          final before = f
              .world
              .bossCombat
              .actionIndex[f.world.bossCombat.indexOf(f.boss)];
          _tick(f, tick);
          if (s.phase == GoddessTactic.teleportOut) break;
          if (f.world.bossCombat.actionIndex[f.world.bossCombat.indexOf(
                f.boss,
              )] !=
              before) {
            casts++;
          }
          expect(f.action, anyOf(isNull, 'goddess.orb'));
          expect(
            f.world.controlLock.isLocked(f.boss, LockFlag.move, tick),
            isTrue,
          );
          expect(
            f.world.engagementIntent.speedScale[f.world.engagementIntent
                .indexOf(f.boss)],
            0,
          );
        }
        expect(casts, budget);
        expect(s.phase, GoddessTactic.teleportOut);
      }
    });

    test(
      'far teleport has a fixed legal destination and recovery at $hz Hz',
      () {
        final f = GoddessCombatFixture(hz: hz, bossX: 30);
        final s = f.world.goddessTactics.stateFor(f.boss)..initialized = true;
        _tick(f, 10);
        final destination = s.destination!;
        expect((destination.x - 300).abs(), inInclusiveRange(140, 220));
        expect(destination.x, inInclusiveRange(9, 591));
        expect(f.action, 'goddess.reposition_out');
        final landing = s.endTick;
        expect(landing - 10, (.3 * hz).ceil());
        // The warning is a commitment: moving the player cannot move the mark.
        f.world.transform.setPosXY(f.player, 400, f.playerY);
        for (var tick = 11; tick < landing; tick++) {
          _tick(f, tick);
          expect(f.x, 30);
          expect(s.destination, same(destination));
          expect(isCombatProtected(f.world, f.boss), isFalse);
        }
        _tick(f, landing);
        expect(f.x, destination.x);
        expect(f.action, 'goddess.reposition_in');
        expect(s.destination, isNull);
        expect(s.nextTeleportTick - landing, inInclusiveRange(4 * hz, 6 * hz));
        final recoveryEnd = s.endTick;
        for (var tick = landing + 1; tick < recoveryEnd; tick++) {
          _tick(f, tick);
          expect(f.action, 'goddess.reposition_in');
          expect(isCombatProtected(f.world, f.boss), isFalse);
        }
        _tick(f, recoveryEnd);
        expect(f.action, isNot('goddess.reposition_out'));
      },
    );

    test('short approach has a fixed endpoint and deadline at $hz Hz', () {
      final f = GoddessCombatFixture(hz: hz, bossX: 240);
      final ni = f.world.navIntent.indexOf(f.boss);
      f.world.navIntent.canWalkDirectlyToTarget[ni] = true;
      _tick(f, 10);
      final s = f.world.goddessTactics.stateFor(f.boss);
      expect(s.phase, GoddessTactic.approach);
      expect(s.approachX, 265);
      final end = s.approachEndTick;
      // Moving away cannot extend either the deadline or the approach endpoint.
      f.world.transform.setPosXY(f.player, 340, f.playerY);
      _tick(f, end - 1);
      expect(s.approachX, 265);
      final ti = f.world.transform.indexOf(f.boss);
      f.world.transform.setPosXY(f.boss, 264, f.world.transform.posY[ti]);
      f.world.transform.velX[ti] = 500;
      f.combat.composeMotion(f.world);
      expect(f.world.transform.velX[ti], hz.toDouble());
      _tick(f, end);
      expect(s.phase, GoddessTactic.idle);
      expect(f.action, 'goddess.orb');
    });

    test(
      'a narrow arena falls back to attacking instead of an unsafe blink at $hz Hz',
      () {
        final f = GoddessCombatFixture(hz: hz, bossX: 280);
        f.world.actorMotionBounds.add(
          f.boss,
          TerrainHorizontalBounds(minXTicks: 250 * 1024, maxXTicks: 350 * 1024),
        );
        final s = f.world.goddessTactics.stateFor(f.boss)
          ..initialized = true
          ..orbsRemaining = 0;
        f.world.transform.setPosXY(f.player, 340, f.playerY + 100);
        _tick(f, 10);
        expect(f.action, 'goddess.orb');
        expect(s.destination, isNull);
        expect(s.nextTeleportTick, 10 + hz);
      },
    );

    test(
      'reactive dodge always commits claws and resets voluntary teleport cadence at $hz Hz',
      () {
        final f = GoddessCombatFixture(hz: hz);
        final s = f.world.goddessTactics.stateFor(f.boss)..initialized = true;
        expect(f.combat.tryBeginDodge(f.world, f.boss, f.player, 10), isTrue);
        final end = f.world.goddessDodge.executeTick[f.state];
        f.prepare(end);
        expect(f.action, 'goddess.claw_combo');
        expect(s.nextTeleportTick - end, inInclusiveRange(4 * hz, 6 * hz));
        for (var tick = end + 1; tick < end + (1.6 * hz).ceil(); tick++) {
          _tick(f, tick);
          expect(f.action, 'goddess.claw_combo');
        }
      },
    );

    test(
      'threshold beats a ready relocation and survives a queued exit at $hz Hz',
      () {
        final f = GoddessCombatFixture(hz: hz, bossX: 30);
        final s = f.world.goddessTactics.stateFor(f.boss)..initialized = true;
        f.world.health.hp[f.world.health.indexOf(f.boss)] = 15000;
        _tick(f, 10);
        expect(f.action, 'goddess.eruption');
        expect(s.destination, isNull);
        final hi = f.world.goddessHealthPhase.indexOf(f.boss);
        expect(f.world.goddessHealthPhase.reached[hi], 2);
        expect(f.world.goddessHealthPhase.committed[hi], 1);
      },
    );

    test(
      'an exit with no supported medium-range landing releases hover at $hz Hz',
      () {
        final f = GoddessCombatFixture(hz: hz, bossX: 280);
        f.world.actorMotionBounds.add(
          f.boss,
          TerrainHorizontalBounds(minXTicks: 250 * 1024, maxXTicks: 350 * 1024),
        );
        final s = f.world.goddessTactics.stateFor(f.boss)
          ..initialized = true
          ..phase = GoddessTactic.exitPending
          ..hovering = true;
        _tick(f, 10);
        expect(f.action, 'goddess.orb');
        final end = s.endTick;
        for (var tick = 11; tick <= end; tick++) {
          _tick(f, tick);
        }
        expect(s.phase, GoddessTactic.idle);
        expect(f.world.gravityControl.has(f.boss), isFalse);
        expect(s.destination, isNull);
        expect(f.x, 280);
      },
    );

    for (final interruption in [
      'cancelled',
      'replaced',
      'stunned',
      'dead',
      'suspended',
    ]) {
      test(
        'teleport/exit cleanup preserves replacement actions on $interruption at $hz Hz',
        () {
          for (final exit in [false, true]) {
            final f = GoddessCombatFixture(hz: hz, bossX: 30);
            final s = f.world.goddessTactics.stateFor(f.boss)
              ..initialized = true;
            if (exit) {
              s.phase = GoddessTactic.exitPending;
              s.hovering = true;
            }
            _tick(f, 10);
            final ai = f.world.activeAbility.indexOf(f.boss);
            switch (interruption) {
              case 'cancelled':
                f.world.activeAbility.clear(f.boss);
              case 'replaced':
                f.world.activeAbility.startTick[ai]++;
              case 'stunned':
                f.world.controlLock.addLock(f.boss, LockFlag.stun, hz, 11);
              case 'dead':
                f.world.health.hp[f.world.health.indexOf(f.boss)] = 0;
              case 'suspended':
                f.world.arenaSuspension.addEntity(f.boss);
            }
            f.combat.prepareTactics(f.world, player: f.player, currentTick: 11);
            expect(s.phase, GoddessTactic.idle);
            expect(s.destination, isNull);
            expect(f.world.gravityControl.has(f.boss), isFalse);
            expect(f.x, 30);
            if (interruption == 'replaced') {
              expect(f.world.activeAbility.hasActiveAbility(f.boss), isTrue);
            }
          }
        },
      );
    }
  }

  test('close decisions favor combos but vary with seed', () {
    final actions = <String, int>{};
    for (var seed = 1; seed <= 100; seed++) {
      final f = GoddessCombatFixture(seed: seed);
      f.world.goddessTactics.stateFor(f.boss).initialized = true;
      _tick(f, 10);
      actions.update(f.action!, (n) => n + 1, ifAbsent: () => 1);
    }
    expect(actions.keys.toSet(), {
      'goddess.claw_combo',
      'goddess.reposition_out',
    });
    expect(actions['goddess.claw_combo'], inInclusiveRange(55, 85));
  });

  test('arena-edge candidates are rejected before querying invalid local coordinates', () {
    for (final x in [20.0, 580.0]) {
      final f = GoddessCombatFixture(bossX: x < 300 ? 500 : 100);
      f.world.transform.setPosXY(f.player, x, f.playerY);
      final s = f.world.goddessTactics.stateFor(f.boss)..initialized = true;
      _tick(f, 10);
      expect(s.phase, GoddessTactic.teleportOut);
      expect((s.destination!.x - x).abs(), inInclusiveRange(140, 220));
      expect(s.destination!.x, inInclusiveRange(9, 591));
    }
  });

  test('destroying an actor discards pending destinations and RNG state', () {
    final f = GoddessCombatFixture(bossX: 30);
    final old = f.world.goddessTactics.stateFor(f.boss)..initialized = true;
    _tick(f, 10);
    expect(old.destination, isNotNull);
    f.world.destroyEntity(f.boss);
    final replacement = f.world.createEntity();
    expect(replacement, f.boss);
    final fresh = f.world.goddessTactics.stateFor(replacement);
    expect(fresh, isNot(same(old)));
    expect(fresh.destination, isNull);
    expect(fresh.initialized, isFalse);
  });
}

void _tick(GoddessCombatFixture f, int tick) {
  CooldownSystem().step(f.world);
  ControlLockSystem().step(f.world, currentTick: tick);
  const ActiveAbilityPhaseSystem().step(f.world, currentTick: tick);
  f.combat.prepareDodge(f.world, currentTick: tick);
  f.combat.prepareBarrage(f.world, currentTick: tick);
  f.combat.prepareTactics(f.world, player: f.player, currentTick: tick);
  f.combat.step(f.world, player: f.player, currentTick: tick);
  f.combat.composeMotion(f.world);
}
