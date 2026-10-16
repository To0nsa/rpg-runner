import '../combat/damage_credit.dart';

/// Per-run player combat totals from actual HP lost after hit resolution.
final class RunCombatTotals {
  int damageDealt100 = 0;
  int damageTaken100 = 0;

  void recordHpLost({
    required bool playerTarget,
    required bool enemyTarget,
    required DamageCredit credit,
    required int hpLost100,
  }) {
    if (hpLost100 <= 0) return;
    if (playerTarget) {
      damageTaken100 += hpLost100;
    } else if (enemyTarget && credit == DamageCredit.player) {
      damageDealt100 += hpLost100;
    }
  }
}
