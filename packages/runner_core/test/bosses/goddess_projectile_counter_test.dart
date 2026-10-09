import 'package:runner_core/combat/damage.dart';
import 'package:runner_core/ecs/stores/enemies/goddess_tactics_store.dart';
import 'package:runner_core/events/game_event.dart';
import 'package:test/test.dart';

import '../test_support/goddess_combat_fixture.dart';

void main() {
  for (final hz in [30, 60, 90]) {
    for (final bossX in [100.0, 280.0, 320.0]) {
      test('two landed projectiles counter from $bossX at $hz Hz', () {
        final a = GoddessCombatFixture(hz: hz, bossX: bossX);
        final b = GoddessCombatFixture(hz: hz, bossX: bossX);
        for (final f in [a, b]) {
          expect(f.hp, 30000);
          expect(f.world.health.hpMax[f.world.health.indexOf(f.boss)], 30000);
          f.queue(kind: DeathSourceKind.projectile);
          f.damage(10);
          expect(f.hp, 29900);
          expect(f.action, isNull);
          expect(_streak(f), 1);
          f.queue(kind: DeathSourceKind.projectile);
          f.damage(11);
          expect(f.hp, 29800, reason: 'both projectiles must deal damage');
          expect(f.action, 'goddess.dodge');
          expect(f.attacks, 0);
          expect(_streak(f), 0);
          expect(f.interval, inInclusiveRange(4, 6));
          final side = f.world.goddessDodge.landingSide[f.state];
          final execute = 11 + (8 * hz / 60).ceil();
          f.prepare(execute);
          expect(
            f.x,
            bossX == 100 ? 300 + side * 35 : (bossX < 300 ? 335 : 265),
          );
          expect(f.action, 'goddess.claw_combo');
          f.resolveCounterHits(execute);
          expect(f.world.damageQueue.target, List.filled(4, f.player));
          expect(f.world.damageQueue.amount100, List.filled(4, 500));
        }
        expect(b.x, a.x);
        expect(b.interval, a.interval);
        expect(
          b.world.goddessDodge.rngState[b.state],
          a.world.goddessDodge.rngState[a.state],
        );
      });
    }
  }

  test('two hits in one damage batch start one counter after both land', () {
    final f = GoddessCombatFixture();
    f.queue(kind: DeathSourceKind.projectile);
    f.queue(kind: DeathSourceKind.projectile);
    f.damage(10);
    expect(f.hp, 29800);
    expect(f.action, 'goddess.dodge');
    final rng = f.world.goddessDodge.rngState[f.state];
    f.queue(kind: DeathSourceKind.projectile);
    f.queue(kind: DeathSourceKind.projectile);
    f.damage(11);
    expect(f.hp, 29600, reason: 'the counter grants no blanket immunity');
    expect(_streak(f), 0, reason: 'a pending counter cannot queue another');
    expect(f.world.goddessDodge.startTick[f.state], 10);
    expect(f.world.goddessDodge.rngState[f.state], rng);
  });

  for (final kind in [
    DeathSourceKind.meleeHitbox,
    DeathSourceKind.spellImpact,
  ]) {
    test('landed $kind breaks the projectile streak', () {
      final f = GoddessCombatFixture();
      f.queue(kind: DeathSourceKind.projectile);
      f.damage(10);
      f.queue(kind: kind);
      f.damage(11);
      expect(_streak(f), 0);
      f.queue(kind: DeathSourceKind.projectile);
      f.damage(12);
      expect(f.hp, 29700);
      expect(_streak(f), 1);
      expect(f.action, isNull);
    });
  }

  test('DoT and NPC hits neither advance nor break the streak', () {
    final f = GoddessCombatFixture();
    f.queue(kind: DeathSourceKind.projectile);
    f.damage(10);
    f.queue(kind: DeathSourceKind.statusEffect);
    f.queue(kind: DeathSourceKind.projectile, source: f.boss);
    f.damage(11);
    expect(_streak(f), 1);
    expect(f.attacks, 1);
    f.queue(kind: DeathSourceKind.projectile);
    f.damage(12);
    expect(f.hp, 29600);
    expect(f.action, 'goddess.dodge');
  });

  test('canceled, immune and zero-damage projectiles do not count', () {
    final f = GoddessCombatFixture();
    f.queue(kind: DeathSourceKind.projectile);
    f.damage(10);
    f.queue(kind: DeathSourceKind.projectile);
    f.world.damageQueue.cancel(0);
    f.damage(11);
    f.world.invulnerability.add(f.boss);
    final ii = f.world.invulnerability.indexOf(f.boss);
    f.world.invulnerability.protect(ii, 10);
    f.queue(kind: DeathSourceKind.projectile);
    f.damage(12);
    f.world.invulnerability.removeEntity(f.boss);
    f.world.damageQueue.add(
      DamageRequest(
        target: f.boss,
        source: f.player,
        sourceKind: DeathSourceKind.projectile,
        amount100: 0,
      ),
    );
    f.damage(13);
    expect(f.hp, 29900);
    expect(_streak(f), 1);
    expect(f.action, isNull);
    f.queue(kind: DeathSourceKind.projectile);
    f.damage(14);
    expect(f.hp, 29800);
    expect(f.action, 'goddess.dodge');
  });

  test('a lethal second projectile cannot start a counter', () {
    final f = GoddessCombatFixture();
    f.world.health.hp[f.world.health.indexOf(f.boss)] = 200;
    f.queue(kind: DeathSourceKind.projectile);
    f.damage(10);
    f.queue(kind: DeathSourceKind.projectile);
    f.damage(11);
    expect(f.hp, 0);
    expect(f.action, isNull);
    expect(f.world.goddessDodge.executeTick[f.state], -1);
  });

  test('blocked counter retains two hits without spending RNG', () {
    final f = GoddessCombatFixture(blocked: 'wall');
    f.queue(kind: DeathSourceKind.projectile);
    f.damage(10);
    final rng = f.world.goddessDodge.rngState[f.state];
    f.queue(kind: DeathSourceKind.projectile);
    f.damage(11);
    expect(f.action, isNull);
    expect(_streak(f), 2);
    expect(f.world.goddessDodge.rngState[f.state], rng);
    f.world.transform.setPosXY(f.player, 200, f.playerY);
    f.queue(kind: DeathSourceKind.projectile);
    f.damage(12);
    expect(f.hp, 29700);
    expect(f.action, 'goddess.dodge');
    expect(_streak(f), 0);
  });

  test('a cadence dodge clears an existing projectile streak', () {
    final f = GoddessCombatFixture();
    f.queue(kind: DeathSourceKind.projectile);
    f.damage(10);
    expect(_streak(f), 1);
    f.world.goddessDodge.attacks[f.state] = f.interval - 1;
    f.queue(kind: DeathSourceKind.projectile);
    f.damage(11);
    expect(f.hp, 29900, reason: 'the eligible cadence hit is evaded');
    expect(f.action, 'goddess.dodge');
    expect(_streak(f), 0);
  });

  test('an active barrage suppresses the projectile reaction', () {
    final f = GoddessCombatFixture();
    f.world.goddessBarrage.addEntity(f.boss);
    for (var tick = 10; tick <= 11; tick++) {
      f.queue(kind: DeathSourceKind.projectile);
      f.damage(tick);
    }
    expect(_streak(f), 0);
    expect(f.action, isNull);
  });

  for (final phase in GoddessTactic.values.where(
    (phase) => phase != GoddessTactic.idle && phase != GoddessTactic.approach,
  )) {
    test('$phase suppresses projectile counters until the transition ends', () {
      final f = GoddessCombatFixture();
      final tactic = f.world.goddessTactics.stateFor(f.boss)..phase = phase;
      for (var tick = 10; tick <= 11; tick++) {
        f.queue(kind: DeathSourceKind.projectile);
        f.damage(tick);
      }
      expect(_streak(f), 0);
      expect(f.action, isNull);
      tactic.clearTransition();
      f.queue(kind: DeathSourceKind.projectile);
      f.damage(12);
      expect(_streak(f), 1);
      expect(f.action, isNull);
    });
  }
}

int _streak(GoddessCombatFixture f) =>
    f.world.goddessDodge.consecutiveProjectileHits[f.state];
