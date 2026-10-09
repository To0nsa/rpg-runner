import 'package:runner_core/commands/command.dart';
import 'package:runner_core/combat/control_lock.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/events/game_event.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:test/test.dart';

import '../test_support/goddess_combat_fixture.dart';
import '../test_support/combat_pose.dart';
import 'ancient_god_arena_test.dart' show ancientGodTestCore;

void main() {
  test('player commands produce the same dodge and counter in two Core runs', () {
    final a = ancientGodTestCore(EnemyId.voidbornGoddess);
    final b = ancientGodTestCore(EnemyId.voidbornGoddess);
    var vanished = false;
    var countered = false;
    double? floorBodyY;
    for (var n = 0; n < 3000 && !a.gameOver; n++) {
      final before = a.buildSnapshot();
      final boss = before.entities
          .where((e) => e.enemyId == EnemyId.voidbornGoddess)
          .firstOrNull;
      final player = before.playerEntity!;
      final dx = boss == null ? 0.0 : boss.pos.x - player.pos.x;
      if (boss != null) floorBodyY ??= boss.pos.y;
      // Let the protected barrage and its uninterrupted return finish before
      // delivering more eligible attacks; return damage cannot trigger a dodge.
      final attack =
          boss != null &&
          boss.anim != AnimKey.ranged &&
          boss.pos.y >= floorBodyY! - .01;
      final tick = a.tick + 1;
      final commands = <Command>[
        MoveAxisCommand(tick: tick, axis: dx.abs() > 20 ? dx.sign : 0),
        AimDirCommand(tick: tick, x: dx >= 0 ? 1 : -1, y: 0),
        if (attack && n % 20 == 0) StrikePressedCommand(tick: tick),
        if (attack && n % 45 == 0) ProjectilePressedCommand(tick: tick),
      ];
      for (final core in [a, b]) {
        core.applyCommands(commands);
        core.stepOneTick();
      }
      final after = a.buildSnapshot();
      final repeated = b.buildSnapshot();
      expect(repeated.hud.hp, after.hud.hp);
      expect(
        repeated.entities.map(
          (e) => [e.id, e.pos.x, e.pos.y, e.anim, e.animFrame],
        ),
        after.entities.map(
          (e) => [e.id, e.pos.x, e.pos.y, e.anim, e.animFrame],
        ),
      );
      final actor = after.entities
          .where((e) => e.enemyId == EnemyId.voidbornGoddess)
          .firstOrNull;
      if (actor?.anim == AnimKey.teleportOut) vanished = true;
      if (boss?.anim == AnimKey.teleportOut && actor?.anim == AnimKey.strike) {
        expect(
          (boss!.pos.x - player.pos.x) * (actor!.pos.x - player.pos.x),
          lessThan(0),
        );
        expect((actor.pos.x - player.pos.x).abs(), closeTo(35, 1));
        countered = true;
        break;
      }
    }
    expect(vanished, isTrue);
    expect(countered, isTrue);
  });

  for (final hz in [30, 60, 90]) {
    test('seeded dodge intervals and distant sides vary reproducibly at $hz Hz', () {
      final intervals = <int>{};
      final sides = <int>{};
      final histories = <String>{};
      for (final seed in [7, 41, 2026]) {
        final a = GoddessCombatFixture(hz: hz, bossX: 100, seed: seed);
        final b = GoddessCombatFixture(hz: hz, bossX: 100, seed: seed);
        final history = <(int, int)>[];
        for (var cycle = 0; cycle < 12; cycle++) {
          final tick = 10 + cycle * hz * 3;
          for (final f in [a, b]) {
            f.prepare(tick - 1);
            // Recreate ranged pressure while keeping each actor's cadence/RNG.
            f.world.transform.setPosXY(f.boss, 100, f.playerY);
          }
          final hp = a.hp;
          var count = 0;
          for (var attack = 1; attack <= 6; attack++) {
            for (final f in [a, b]) {
              f.queue();
              f.damage(tick);
            }
            expect(b.action, a.action);
            expect(b.hp, a.hp);
            if (a.action == 'goddess.dodge') {
              count = attack;
              break;
            }
            expect(a.hp, hp - attack * 100);
          }
          expect(count, inInclusiveRange(4, 6));
          expect(a.hp, hp - (count - 1) * 100);
          final side = a.world.goddessDodge.landingSide[a.state];
          expect(side, anyOf(-1, 1));
          expect(b.world.goddessDodge.landingSide[b.state], side);
          expect(b.interval, a.interval);
          expect(a.interval, inInclusiveRange(4, 6));
          expect(
            b.world.goddessDodge.rngState[b.state],
            a.world.goddessDodge.rngState[a.state],
          );
          intervals.add(count);
          sides.add(side);
          history.add((count, side));
          for (final f in [a, b]) {
            f.prepare(tick + (8 * hz / 60).ceil());
            expect(f.x, 300 + side * 35);
            expect(f.action, 'goddess.claw_combo');
            expect(
              f.world.activeAbility.facing[f.world.activeAbility.indexOf(
                f.boss,
              )],
              side < 0 ? Facing.right : Facing.left,
            );
          }
        }
        histories.add(history.toString());
      }
      expect(intervals, {4, 5, 6});
      expect(sides, {-1, 1});
      expect(histories.length, greaterThan(1));
    });

    for (final bossX in [255.0, 345.0]) {
      test('close dodge crosses player from $bossX at $hz Hz', () {
        final f = GoddessCombatFixture(hz: hz, bossX: bossX);
        f.world.cooldown.setTicksLeft(f.boss, 0, hz * 5);
        for (var hit = 0; hit < 6; hit++) {
          f.queue();
        }
        f.damage(10);
        expect(
          f.hp,
          35500,
          reason:
              'only the chosen hit is canceled; ${f.combat.utilities.motion.lastSpawnPlacementDiagnostic}',
        );
        expect(f.action, 'goddess.dodge');
        expect(f.attacks, 0);
        final execute = 10 + (8 * hz / 60).ceil();
        final frames = <int>{};
        for (var tick = 10; tick < execute; tick++) {
          f.prepare(tick);
          resolveCombatPoses(f.world, tick, tickHz: hz);
          expect(f.x, bossX, reason: 'vanish precedes relocation');
          final anim = f.world.animState.indexOf(f.boss);
          expect(f.world.animState.anim[anim], AnimKey.teleportOut);
          frames.add(f.world.animState.animFrame[anim]);
        }
        expect(frames.length, 4, reason: 'the full vanish strip plays');
        f.prepare(execute);
        expect(f.x, bossX < 300 ? 335 : 265);
        expect(f.action, 'goddess.claw_combo');
        final active = f.world.activeAbility.indexOf(f.boss);
        expect(
          f.world.activeAbility.facing[active],
          bossX < 300 ? Facing.left : Facing.right,
        );
        expect(f.world.activeAbility.startTick[active], execute);
        expect(
          f.world.meleeIntent.tick[f.world.meleeIntent.indexOf(f.boss)],
          execute + (24 * hz / 60).ceil(),
        );
        expect(f.world.cooldown.getTicksLeft(f.boss, 0), hz * 5);
        expect(f.world.gravityControl.has(f.boss), isFalse);
        f.resolveCounterHits(execute);
        expect(f.world.damageQueue.target, List.filled(4, f.player));
        f.world.damageQueue.clear();
        // A completed counter starts another 4–6 attack interval.
        f.prepare(execute + hz * 3);
        for (var hit = 0; hit < 6; hit++) {
          f.queue();
        }
        f.damage(execute + hz * 3);
        expect(f.hp, 35000);
        expect(f.action, 'goddess.dodge');
      });
    }
  }

  test('distant dodge uses the only legal side when the other is blocked', () {
    for (final blocked in ['arena edge', 'gap', 'wall']) {
      final f = GoddessCombatFixture(blocked: blocked, bossX: 100);
      for (var hit = 0; hit < 6; hit++) {
        f.queue();
      }
      f.damage(10);
      expect(f.action, 'goddess.dodge');
      expect(f.world.goddessDodge.landingSide[f.state], -1);
      f.prepare(18);
      expect(f.x, blocked == 'arena edge' ? 545 : 265);
      expect(f.action, 'goddess.claw_combo');
    }
  });

  test(
    'distant side is fixed through the vanish while following player position',
    () {
      final f = GoddessCombatFixture(bossX: 100);
      for (var hit = 0; hit < 6; hit++) {
        f.queue();
      }
      f.damage(10);
      final side = f.world.goddessDodge.landingSide[f.state];
      final rng = f.world.goddessDodge.rngState[f.state];
      for (var tick = 11; tick < 18; tick++) {
        f.world.transform.setPosXY(f.player, 300 + (tick - 10) * 5, f.playerY);
        f.prepare(tick);
        expect(f.world.goddessDodge.landingSide[f.state], side);
        expect(f.world.goddessDodge.rngState[f.state], rng);
      }
      f.prepare(18);
      expect(f.x, 335 + side * 35);
      expect(f.action, 'goddess.claw_combo');
    },
  );

  test(
    'invalid captured distant side cancels without rerolling during vanish',
    () {
      final f = GoddessCombatFixture(bossX: 100);
      for (var hit = 0; hit < 6; hit++) {
        f.queue();
      }
      f.damage(10);
      final side = f.world.goddessDodge.landingSide[f.state];
      final rng = f.world.goddessDodge.rngState[f.state];
      f.world.transform.setPosXY(f.player, side < 0 ? 10 : 590, f.playerY);
      f.prepare(18);
      expect(f.x, 100);
      expect(f.action, isNull);
      expect(f.world.goddessDodge.rngState[f.state], rng);
    },
  );

  test('each player combo counts once and an evaded combo stays evaded', () {
    final f = GoddessCombatFixture();
    var evaded = 0;
    for (var activation = 1; activation <= 6; activation++) {
      final before = f.hp;
      for (var strike = 1; strike <= 4; strike++) {
        f.queue(combo: f.combo(activation, strike));
        f.damage(activation * 10 + strike);
      }
      if (f.hp == before) {
        evaded = activation;
        break;
      }
    }
    expect(evaded, inInclusiveRange(4, 6));
    final hp = 36000 - (evaded - 1) * 400;
    expect(f.hp, hp, reason: 'only the chosen combo is evaded');
    expect(f.action, 'goddess.dodge');
    expect(f.attacks, 0);
    f.prepare(evaded * 10 + 9);
    expect(f.action, 'goddess.claw_combo');
    f.queue(combo: f.combo(evaded, 5));
    f.damage(evaded * 10 + 10);
    expect(f.hp, hp);
    expect(f.attacks, 0);
  });

  test(
    'projectiles and direct spell impacts also advance the dodge cadence',
    () {
      final f = GoddessCombatFixture();
      for (final kind in [
        DeathSourceKind.projectile,
        DeathSourceKind.spellImpact,
        DeathSourceKind.meleeHitbox,
        DeathSourceKind.projectile,
        DeathSourceKind.spellImpact,
        DeathSourceKind.meleeHitbox,
      ]) {
        f.queue(kind: kind);
      }
      f.damage(10);
      expect(f.hp, 35500);
      expect(f.action, 'goddess.dodge');
    },
  );

  test('damage over time and nonplayer sources do not count', () {
    final f = GoddessCombatFixture();
    for (var hit = 0; hit < 4; hit++) {
      f.queue(kind: DeathSourceKind.statusEffect);
      f.queue(source: f.boss);
    }
    f.damage(10);
    expect(f.hp, 35200);
    expect(f.attacks, 0);
    expect(f.action, isNull);
  });

  for (final blocked in ['arena edge', 'gap', 'wall']) {
    test('$blocked rejects a dodge without spending its cadence', () {
      final f = GoddessCombatFixture(
        blocked: blocked,
        bossX: blocked == 'arena edge' ? 560 : 280,
      );
      for (var hit = 0; hit < 6; hit++) {
        f.queue();
      }
      f.damage(10);
      expect(f.hp, 35400);
      expect(f.attacks, f.interval - 1);
      expect(f.action, isNull);
      expect(f.x, blocked == 'arena edge' ? 560 : 280);
      final interval = f.interval;
      final rng = f.world.goddessDodge.rngState[f.state];
      f.queue();
      f.damage(11);
      expect(f.hp, 35300);
      expect(f.interval, interval, reason: 'blocked attacks do not reroll');
      expect(f.world.goddessDodge.rngState[f.state], rng);
      f.world.transform.setPosXY(f.player, 200, f.playerY);
      f.queue();
      f.damage(12);
      expect(f.hp, 35300);
      expect(f.action, 'goddess.dodge');
    });
  }

  for (final reason in [
    'stun',
    'suspension',
    'player death',
    'blocked landing',
  ]) {
    test('$reason during vanish cancels pending placement and counter', () {
      final f = GoddessCombatFixture();
      for (var hit = 0; hit < 6; hit++) {
        f.queue();
      }
      f.damage(10);
      f.prepare(11);
      switch (reason) {
        case 'stun':
          f.world.controlLock.addLock(f.boss, LockFlag.stun, 30, 12);
        case 'suspension':
          f.world.arenaSuspension.addEntity(f.boss);
        case 'player death':
          f.world.health.hp[f.world.health.indexOf(f.player)] = 0;
        case 'blocked landing':
          f.world.transform.setPosXY(f.player, 590, f.playerY);
      }
      f.prepare(18);
      expect(f.x, 280);
      expect(f.action, isNull);
      expect(f.world.gravityControl.has(f.boss), isFalse);
      expect(
        f.world.goddessDodge.executeTick[f.world.goddessDodge.indexOf(f.boss)],
        -1,
      );
    });
  }

  test('barrage cast and return never trigger a reactive dodge', () {
    final f = GoddessCombatFixture();
    f.world.goddessBarrage.addEntity(f.boss);
    for (var hit = 0; hit < 6; hit++) {
      f.queue();
    }
    f.damage(10);
    expect(f.attacks, 0);
    expect(f.action, isNull);
  });

  test('destroying an actor clears its dodge cadence and combo ledger', () {
    final f = GoddessCombatFixture();
    f.queue(combo: f.combo(1, 1));
    f.damage(10);
    f.world.destroyEntity(f.boss);
    expect(f.world.goddessDodge.has(f.boss), isFalse);
    final replacement = f.world.createEntity();
    expect(replacement, f.boss);
    final recycled = f.world.goddessDodge.addEntity(replacement);
    expect(f.world.goddessDodge.attacks[recycled], 0);
    expect(f.world.goddessDodge.attackInterval[recycled], 0);
    expect(f.world.goddessDodge.landingSide[recycled], 0);
    expect(f.world.goddessDodge.comboDodged[recycled], isEmpty);
  });
}
