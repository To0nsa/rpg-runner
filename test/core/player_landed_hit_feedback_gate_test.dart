import 'package:flutter_test/flutter_test.dart';
import 'package:runner_core/combat/damage_credit.dart';
import 'package:runner_core/events/game_event.dart';
import 'package:runner_core/events/player_landed_hit_feedback_gate.dart';

void main() {
  test('accepts player melee and projectile damage on separate ticks', () {
    final gate = PlayerLandedHitFeedbackGate();
    for (final (tick, sourceKind) in [
      (10, DeathSourceKind.meleeHitbox),
      (12, DeathSourceKind.projectile),
    ]) {
      expect(
        gate
            .eventForAppliedDamage(
              tick: tick,
              enemyTarget: true,
              credit: DamageCredit.player,
              appliedAmount100: 100,
              sourceKind: sourceKind,
            )
            ?.tick,
        tick,
      );
    }
  });

  test('shares one cue across same-tick multi-target damage', () {
    final gate = PlayerLandedHitFeedbackGate();
    PlayerLandedHitFeedbackEvent? hit(int tick) => gate.eventForAppliedDamage(
      tick: tick,
      enemyTarget: true,
      credit: DamageCredit.player,
      appliedAmount100: 100,
      sourceKind: DeathSourceKind.meleeHitbox,
    );

    expect(hit(20), isNotNull);
    expect(hit(20), isNull);
    expect(hit(21), isNotNull);
  });

  test('ignores blocked, unrelated, and damage-over-time hits', () {
    final gate = PlayerLandedHitFeedbackGate();
    for (final (enemyTarget, credit, amount, kind) in [
      (true, DamageCredit.player, 0, DeathSourceKind.meleeHitbox),
      (true, DamageCredit.none, 100, DeathSourceKind.projectile),
      (false, DamageCredit.player, 100, DeathSourceKind.meleeHitbox),
      (true, DamageCredit.player, 100, DeathSourceKind.statusEffect),
    ]) {
      expect(
        gate.eventForAppliedDamage(
          tick: 30,
          enemyTarget: enemyTarget,
          credit: credit,
          appliedAmount100: amount,
          sourceKind: kind,
        ),
        isNull,
      );
    }
    expect(
      gate.eventForAppliedDamage(
        tick: 30,
        enemyTarget: true,
        credit: DamageCredit.player,
        appliedAmount100: 100,
        sourceKind: DeathSourceKind.projectile,
      ),
      isNotNull,
    );
  });
}
