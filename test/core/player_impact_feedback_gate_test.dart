import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_runner/core/events/game_event.dart';
import 'package:rpg_runner/core/events/player_impact_feedback_gate.dart';

void main() {
  test('emits direct player impact at most once per second', () {
    final gate = PlayerImpactFeedbackGate(tickHz: 60);

    gate.recordAppliedDamage(
      tick: 10,
      playerTarget: true,
      appliedAmount100: 500,
      sourceKind: DeathSourceKind.projectile,
    );
    final first = gate.flushTick(10);
    expect(first, isNotNull);
    expect(first!.amount100, equals(500));
    expect(first.sourceKind, equals(DeathSourceKind.projectile));

    gate.recordAppliedDamage(
      tick: 20,
      playerTarget: true,
      appliedAmount100: 800,
      sourceKind: DeathSourceKind.meleeHitbox,
    );
    expect(gate.flushTick(20), isNull);

    gate.recordAppliedDamage(
      tick: 70,
      playerTarget: true,
      appliedAmount100: 900,
      sourceKind: DeathSourceKind.meleeHitbox,
    );
    final second = gate.flushTick(70);
    expect(second, isNotNull);
    expect(second!.amount100, equals(900));
    expect(second.sourceKind, equals(DeathSourceKind.meleeHitbox));
  });

  test('coalesces same-tick impacts using the highest applied damage', () {
    final gate = PlayerImpactFeedbackGate(tickHz: 60);

    gate.recordAppliedDamage(
      tick: 42,
      playerTarget: true,
      appliedAmount100: 300,
      sourceKind: DeathSourceKind.meleeHitbox,
    );
    gate.recordAppliedDamage(
      tick: 42,
      playerTarget: true,
      appliedAmount100: 1200,
      sourceKind: DeathSourceKind.projectile,
    );
    gate.recordAppliedDamage(
      tick: 42,
      playerTarget: true,
      appliedAmount100: 700,
      sourceKind: DeathSourceKind.meleeHitbox,
    );

    final event = gate.flushTick(42);
    expect(event, isNotNull);
    expect(event!.amount100, equals(1200));
    expect(event.sourceKind, equals(DeathSourceKind.projectile));
  });

  test('ignores status-effect and non-player damage records', () {
    final gate = PlayerImpactFeedbackGate(tickHz: 60);

    gate.recordAppliedDamage(
      tick: 8,
      playerTarget: true,
      appliedAmount100: 900,
      sourceKind: DeathSourceKind.statusEffect,
    );
    gate.recordAppliedDamage(
      tick: 8,
      playerTarget: false,
      appliedAmount100: 900,
      sourceKind: DeathSourceKind.projectile,
    );
    gate.recordAppliedDamage(
      tick: 8,
      playerTarget: true,
      appliedAmount100: 0,
      sourceKind: DeathSourceKind.projectile,
    );

    expect(gate.flushTick(8), isNull);
  });
}
