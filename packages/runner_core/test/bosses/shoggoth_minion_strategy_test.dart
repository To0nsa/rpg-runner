import 'package:runner_core/abilities/ability_catalog.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/enemies/shoggoth_render_catalog.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:test/test.dart';

import '../test_support/combat_pose.dart';
import '../test_support/shoggoth_combat_fixture.dart';

void main() {
  for (final hz in [30, 60, 90]) {
    for (final (hp, phases) in [
      (20801, 0),
      (20800, 1),
      (15601, 1),
      (15600, 2),
      (10401, 2),
      (10400, 3),
    ]) {
      test('HP $hp earns $phases summon waves at $hz Hz', () {
        final f = ShoggothCombatFixture(hz: hz)..hp = hp;
        f.decide(10);
        expect(f.state.phasesReached, phases);
        expect(f.state.frenzyReached, isFalse);
      });
    }
    test(
      '35% charge milestone is independent of waves and survives healing at $hz Hz',
      () {
        final f = ShoggothCombatFixture(hz: hz)..hp = 9101;
        f.decide(10);
        expect(f.state.phasesReached, 3);
        expect(f.state.frenzyReached, isFalse);
        f.hp = 9100;
        f.decide(11);
        expect(f.state.frenzyReached, isTrue);
        f.hp = 26000;
        f.decide(12);
        expect(f.state.phasesReached, 3);
        expect(f.state.frenzyReached, isTrue);
      },
    );
    for (final (key, count) in [
      ('shoggoth.summon', 2),
      ('shoggoth.summon_swarm', 3),
      ('shoggoth.summon_horde', 4),
    ]) {
      test(
        '$key admits $count minions on its visible release frame at $hz Hz',
        () {
          final f = ShoggothCombatFixture(hz: hz);
          expect(
            f.utilities.commit(
              f.world,
              boss: f.boss,
              ability: AbilityCatalog.shared.resolve(key)!,
              targetX: 300,
              tick: 10,
            ),
            isTrue,
          );
          final bi = f.world.bossCombat.indexOf(f.boss);
          final release = f.world.bossCombat.executeTick[bi];
          f.decide(release - 1);
          expect(f.world.bossSummon.denseEntities, isEmpty);
          f.decide(release);
          expect(f.utilities.livingSummons(f.world, f.boss), count);
          resolveCombatPoses(f.world, release, tickHz: hz);
          final ai = f.world.animState.indexOf(f.boss);
          final frameTicks =
              (ShoggothRenderCatalog.actor.stepTimeSecondsByKey[AnimKey
                          .ranged]! *
                      hz)
                  .round();
          expect(f.world.animState.anim[ai], AnimKey.ranged);
          expect(f.world.animState.animFrame[ai] ~/ frameTicks, 7);
        },
      );
    }
    for (final (distance, height, direct, expected) in [
      (70.0, 0.0, true, 'shoggoth.tentacle_sweep'),
      (71.0, 0.0, true, 'shoggoth.orb'),
      (200.0, 0.0, true, 'shoggoth.orb'),
      (350.0, 0.0, true, 'shoggoth.orb'),
      (45.0, -100.0, true, 'shoggoth.orb'),
      (45.0, 0.0, false, 'shoggoth.orb'),
    ]) {
      test(
        'living minions select $expected at $distance/$height/$direct, $hz Hz',
        () {
          final f = ShoggothCombatFixture(
            hz: hz,
            bossX: 100,
            wall: !direct,
            wallX: 100 + distance / 2,
            wallWidth: 4,
          );
          _minion(f);
          f.placePlayer(f.x + distance, y: f.playerY + height);
          // Make repositioning eligible to verify ranged support takes precedence.
          f.state.separatedSinceTick = 10;
          f.decide(10 + 4 * hz);
          expect(f.action, expected);
        },
      );
    }
    for (final state in ['dead', 'expired', 'destroyed', 'other owner']) {
      test('$state minions do not force ranged support at $hz Hz', () {
        final f = ShoggothCombatFixture(hz: hz);
        final minion = _minion(f);
        switch (state) {
          case 'dead':
            f.world.health.hp[f.world.health.indexOf(minion)] = 0;
          case 'expired':
            f.world.bossSummon.expiresTick[f.world.bossSummon.indexOf(minion)] =
                10;
          case 'destroyed':
            f.world.destroyEntity(minion);
          case 'other owner':
            final other = f.utilities.spawns.spawnGroundEnemy(
              enemyId: EnemyId.shoggoth,
              spawnX: 550,
              groundTopY: 500,
            );
            f.world.bossSummon.owner[f.world.bossSummon.indexOf(minion)] =
                other;
        }
        f.decide(10);
        expect(f.action, 'shoggoth.spinning_charge');
      });
    }
    test('pending waves outrank ranged support at $hz Hz', () {
      final f = ShoggothCombatFixture(hz: hz)..hp = 15600;
      f.state.phasesReached = f.state.phasesCommitted = 1;
      _minion(f);
      f.decide(10);
      expect(f.action, 'shoggoth.summon_swarm');
    });
    test(
      'losing the last minion restores charge decisions after orb recovery at $hz Hz',
      () {
        final f = ShoggothCombatFixture(hz: hz);
        final minion = _minion(f);
        f.decide(10);
        expect(f.action, 'shoggoth.orb');
        final end = 10 + f.world.activeAbility.totalTicks[f.ai];
        f.world.destroyEntity(minion);
        var charged = false;
        for (var tick = 11; tick < 10 + 3 * hz; tick++) {
          f.decide(tick);
          if (tick < end) expect(f.action, 'shoggoth.orb');
          if (f.action == 'shoggoth.spinning_charge') {
            expect(tick, greaterThanOrEqualTo(end));
            charged = true;
            break;
          }
        }
        expect(charged, isTrue);
      },
    );
    test(
      'minions suppress a queued distant return without interrupting the first charge at $hz Hz',
      () {
        final f = ShoggothCombatFixture(hz: hz, bossX: 150)..hp = 9100;
        f.state.phasesReached = f.state.phasesCommitted = 3;
        f.placePlayer(300);
        f.tick(10);
        expect(f.action, 'shoggoth.spinning_charge');
        final end = f.state.chainEndTick;
        _minion(f);
        for (var tick = 11; tick < end; tick++) {
          f.tick(tick);
          expect(f.action, 'shoggoth.spinning_charge');
        }
        f.placePlayer(f.x - 150);
        f.decide(end);
        expect(f.action, isNot('shoggoth.return_charge'));
        expect(f.state.chainStartTick, -1);
        for (var tick = end + 1; tick < end + 2 * hz; tick++) {
          f.decide(tick);
          expect(f.action, isNot('shoggoth.return_charge'));
          if (f.action == 'shoggoth.orb') break;
        }
        expect(f.action, 'shoggoth.orb');
      },
    );
  }
}

int _minion(ShoggothCombatFixture f) {
  final minion = f.utilities.spawns.spawnGroundEnemy(
    enemyId: EnemyId.shoggothMinion,
    spawnX: 400,
    groundTopY: 500,
  );
  final si = f.world.bossSummon.addEntity(minion);
  f.world.bossSummon.owner[si] = f.boss;
  f.world.bossSummon.expiresTick[si] = 100 * f.hz;
  return minion;
}
