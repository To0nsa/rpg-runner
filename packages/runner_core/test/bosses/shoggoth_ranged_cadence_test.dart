import 'package:runner_core/collision/terrain/terrain_motion_request.dart';
import 'package:runner_core/combat/control_lock.dart';
import 'package:runner_core/ecs/stores/enemies/shoggoth_tactics_store.dart';
import 'package:test/test.dart';

import '../test_support/shoggoth_combat_fixture.dart';

void main() {
  for (final hz in [30, 60, 90]) {
    test('five whole melee actions retreat, hold, then cast at $hz Hz', () {
      final f = ShoggothCombatFixture(hz: hz);
      f.placePlayer(f.x + 45);
      var tick = 10;
      f.decide(tick);
      for (var count = 1; count <= 5; count++) {
        expect(f.action, 'shoggoth.tentacle_sweep');
        final end =
            f.world.activeAbility.startTick[f.ai] +
            f.world.activeAbility.totalTicks[f.ai];
        while (++tick < end) {
          f.decide(tick);
          expect(f.state.meleeActionsSinceOrb, count - 1);
        }
        f.decide(tick);
        // Re-observing a completion must not count it twice.
        f.combat.prepare(f.world, currentTick: tick);
        expect(f.state.meleeActionsSinceOrb, count);
        expect(f.action, isNull);
        tick = _nextAction(f, tick);
      }
      expect(f.action, 'shoggoth.teleport');
      expect(f.state.rangedPhase, ShoggothRangedPhase.retreating);
      final bi = f.world.bossCombat.indexOf(f.boss);
      final destination = f.world.bossCombat.teleportDestination[bi]!;
      expect((destination.x - (200 + 45)).abs(), 150);
      final execute = f.world.bossCombat.executeTick[bi];
      final end = tick + f.world.activeAbility.totalTicks[f.ai];
      final ready = tick + (110 * hz / 60).ceil();
      final origin = f.x;
      var observedCooldownGap = false;
      while (++tick <= ready) {
        f.tick(tick);
        if (tick < execute) {
          expect(f.x, origin);
        } else {
          expect(f.x, destination.x);
          if (tick == execute) {
            // Closing the new gap cannot change the reserved orb into a sweep.
            f.placePlayer(f.x - 45);
          }
        }
        if (tick < end) expect(f.action, 'shoggoth.teleport');
        if (tick >= end && tick < ready) {
          observedCooldownGap = true;
          expect(f.action, isNull);
          expect(f.state.rangedPhase, ShoggothRangedPhase.orbPending);
        }
      }
      expect(observedCooldownGap, isTrue);
      expect(f.action, 'shoggoth.orb');
      expect(f.state.meleeActionsSinceOrb, 5);
      final orbEnd =
          f.world.activeAbility.startTick[f.ai] +
          f.world.activeAbility.totalTicks[f.ai];
      for (; tick <= orbEnd; tick++) {
        f.decide(tick);
      }
      expect(f.state.meleeActionsSinceOrb, 0);
      expect(f.state.rangedPhase, ShoggothRangedPhase.none);
      _nextAction(f, orbEnd);
      expect(f.action, 'shoggoth.tentacle_sweep');
    });

    test('a completed ordinary orb resets melee cadence at $hz Hz', () {
      final f = ShoggothCombatFixture(hz: hz);
      f.state.meleeActionsSinceOrb = 4;
      f.placePlayer(500);
      f.decide(10);
      expect(f.action, 'shoggoth.orb');
      final end = 10 + f.world.activeAbility.totalTicks[f.ai];
      for (var tick = 11; tick < end; tick++) {
        f.decide(tick);
        expect(f.state.meleeActionsSinceOrb, 4);
      }
      f.decide(end);
      expect(f.state.meleeActionsSinceOrb, 0);
    });

    test(
      'a fifth charge completes its accepted return before retreat at $hz Hz',
      () {
        final f = ShoggothCombatFixture(hz: hz, bossX: 150);
        f.state.phasesReached = f.state.phasesCommitted = 3;
        f.state.meleeActionsSinceOrb = 4;
        f.hp = 10500;
        f.placePlayer(300);
        f.tick(10);
        expect(f.action, 'shoggoth.spinning_charge');
        final end = 10 + f.world.activeAbility.totalTicks[f.ai];
        for (var tick = 11; tick <= end; tick++) {
          f.tick(tick);
        }
        expect(f.action, 'shoggoth.return_charge');
        expect(f.state.meleeActionsSinceOrb, 5);
        final returnEnd = end + f.world.activeAbility.totalTicks[f.ai];
        for (var tick = end + 1; tick <= returnEnd; tick++) {
          f.tick(tick);
        }
        expect(f.state.meleeActionsSinceOrb, 5);
        _nextAction(f, returnEnd);
        expect(f.action, 'shoggoth.teleport');
      },
    );

    for (final failure in ['blocked', 'cooldown', 'missing bounds']) {
      test(
        '$failure retreat casts in place instead of a sixth melee at $hz Hz',
        () {
          final f = ShoggothCombatFixture(hz: hz);
          f.state.meleeActionsSinceOrb = 5;
          f.placePlayer(f.x + 45);
          switch (failure) {
            case 'blocked':
              f.world.actorMotionBounds.add(
                f.boss,
                TerrainHorizontalBounds(
                  minXTicks: 175 * 1024,
                  maxXTicks: 225 * 1024,
                ),
              );
            case 'cooldown':
              f.state.nextTeleportTick = 10 + hz;
            case 'missing bounds':
              f.world.actorMotionBounds.removeEntity(f.boss);
          }
          f.tick(10);
          expect(f.action, 'shoggoth.orb');
          expect(f.x, 200);
          expect(
            f.world.bossCombat.teleportDestination[f.world.bossCombat.indexOf(
              f.boss,
            )],
            isNull,
          );
        },
      );
    }

    test(
      'a spell lock delays rather than loses a due ranged break at $hz Hz',
      () {
        final f = ShoggothCombatFixture(hz: hz);
        f.state.meleeActionsSinceOrb = 5;
        f.state.nextTeleportTick = hz * 10;
        f.placePlayer(f.x + 45);
        f.world.controlLock.addLock(f.boss, LockFlag.cast, hz, 10);
        for (var tick = 10; tick < 10 + hz; tick++) {
          f.decide(tick);
          expect(f.action, isNull);
          expect(f.state.meleeActionsSinceOrb, 5);
        }
        f.decide(10 + hz);
        expect(f.action, 'shoggoth.orb');
      },
    );

    test(
      'earned waves precede retreat; an accepted retreat owns its orb at $hz Hz',
      () {
        final f = ShoggothCombatFixture(hz: hz)..hp = 24000;
        f.state.meleeActionsSinceOrb = 5;
        f.placePlayer(f.x + 45);
        f.decide(10);
        expect(f.action, 'shoggoth.summon');
        var tick = 10 + f.world.activeAbility.totalTicks[f.ai];
        for (var t = 11; t <= tick; t++) {
          f.decide(t);
        }
        tick = _nextAction(f, tick);
        expect(f.action, 'shoggoth.teleport');
        f.hp = 18000;
        final end = tick + f.world.activeAbility.totalTicks[f.ai];
        for (var t = tick + 1; t <= end; t++) {
          f.decide(t);
        }
        tick = _nextAction(f, end);
        expect(f.action, 'shoggoth.orb');
        expect(f.state.phasesCommitted, 1);
        final orbEnd = tick + f.world.activeAbility.totalTicks[f.ai];
        for (var t = tick + 1; t <= orbEnd; t++) {
          f.decide(t);
        }
        _nextAction(f, orbEnd);
        expect(f.action, 'shoggoth.summon_swarm');
      },
    );

    for (final action in ['melee', 'orb', 'retreat']) {
      for (final interruption in [
        'cancel',
        'replace',
        'stun',
        'death',
        'suspend',
        'target loss',
      ]) {
        test('$interruption does not complete $action cadence at $hz Hz', () {
          final f = ShoggothCombatFixture(hz: hz);
          final count = action == 'retreat' ? 5 : 4;
          f.state.meleeActionsSinceOrb = count;
          f.placePlayer(action == 'orb' ? 500 : f.x + 45);
          f.decide(10);
          expect(f.action, switch (action) {
            'melee' => 'shoggoth.tentacle_sweep',
            'orb' => 'shoggoth.orb',
            _ => 'shoggoth.teleport',
          });
          final end = 10 + f.world.activeAbility.totalTicks[f.ai];
          for (var tick = 11; tick < end - 1; tick++) {
            f.decide(tick);
          }
          switch (interruption) {
            case 'cancel':
              f.world.activeAbility.clear(f.boss);
            case 'replace':
              // Even the same ability belongs to a different activation.
              f.world.activeAbility.startTick[f.ai]++;
            case 'stun':
              f.world.controlLock.addLock(f.boss, LockFlag.stun, hz, end - 1);
            case 'death':
              f.hp = 0;
            case 'suspend':
              f.world.arenaSuspension.addEntity(f.boss);
            case 'target loss':
              f.world.health.hp[f.world.health.indexOf(f.player)] = 0;
          }
          f.decide(end - 1);
          f.decide(end);
          expect(f.state.meleeActionsSinceOrb, count);
          expect(f.state.rangedPhase, ShoggothRangedPhase.none);
          expect(f.state.observedAbilityId, isNull);
        });
      }
    }
  }

  test('destroyed Shoggoth cannot leave a ranged break on a recycled ID', () {
    final f = ShoggothCombatFixture();
    f.state.meleeActionsSinceOrb = 5;
    f.placePlayer(f.x + 45);
    f.decide(10);
    expect(f.state.rangedPhase, ShoggothRangedPhase.retreating);
    f.world.destroyEntity(f.boss);
    expect(f.world.createEntity(), f.boss);
    expect(f.state.meleeActionsSinceOrb, 0);
    expect(f.state.rangedPhase, ShoggothRangedPhase.none);
    expect(f.state.observedAbilityId, isNull);
  });
}

int _nextAction(ShoggothCombatFixture f, int after) {
  for (var tick = after + 1; tick <= after + 5 * f.hz; tick++) {
    f.decide(tick);
    if (f.action != null) return tick;
  }
  fail('Shoggoth did not admit another action after tick $after');
}
