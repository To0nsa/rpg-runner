import 'package:flutter_test/flutter_test.dart';
import 'package:runner_core/events/game_event.dart';
import 'package:runner_core/events/player_impact_feedback_gate.dart';

void main() {
  const gate = PlayerImpactFeedbackGate();

  test('emits every direct combo hit within one second', () {
    final events = [
      for (final tick in [10, 11, 15, 20])
        gate.eventForAppliedDamage(
          tick: tick,
          playerTarget: true,
          appliedAmount100: 700,
          sourceKind: DeathSourceKind.meleeHitbox,
        ),
    ];
    expect(events.map((event) => event?.tick), [10, 11, 15, 20]);
    expect(events.map((event) => event?.amount100), [700, 700, 700, 700]);
  });

  test('preserves separate accepted hits on the same tick', () {
    final events = [
      for (final amount in [300, 1200, 700])
        gate.eventForAppliedDamage(
          tick: 42,
          playerTarget: true,
          appliedAmount100: amount,
          sourceKind: DeathSourceKind.projectile,
        ),
    ];
    expect(events.map((event) => event?.amount100), [300, 1200, 700]);
  });

  test('ignores status ticks, non-player targets, and non-positive damage', () {
    for (final (player, amount, source) in [
      (true, 900, DeathSourceKind.statusEffect),
      (false, 900, DeathSourceKind.projectile),
      (true, 0, DeathSourceKind.projectile),
      (true, -100, DeathSourceKind.projectile),
    ]) {
      expect(
        gate.eventForAppliedDamage(
          tick: 8,
          playerTarget: player,
          appliedAmount100: amount,
          sourceKind: source,
        ),
        isNull,
      );
    }
  });

  test('spell impacts retain direct-hit feedback', () {
    final event = gate.eventForAppliedDamage(
      tick: 30,
      playerTarget: true,
      appliedAmount100: 750,
      sourceKind: DeathSourceKind.spellImpact,
    );
    expect(event?.amount100, 750);
    expect(event?.sourceKind, DeathSourceKind.spellImpact);
  });
}
