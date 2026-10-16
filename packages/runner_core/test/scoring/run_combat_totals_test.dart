import 'package:runner_core/combat/damage_credit.dart';
import 'package:runner_core/combat/damage.dart';
import 'package:runner_core/ecs/stores/health_store.dart';
import 'package:runner_core/ecs/systems/damage_system.dart';
import 'package:runner_core/ecs/world.dart';
import 'package:runner_core/scoring/run_combat_totals.dart';
import 'package:test/test.dart';

void main() {
  test('counts only actual player HP loss and player-credited enemy loss', () {
    final totals = RunCombatTotals();
    totals.recordHpLost(
      playerTarget: false,
      enemyTarget: true,
      credit: DamageCredit.player,
      hpLost100: 250,
    );
    totals.recordHpLost(
      playerTarget: false,
      enemyTarget: true,
      credit: DamageCredit.none,
      hpLost100: 900,
    );
    totals.recordHpLost(
      playerTarget: false,
      enemyTarget: false,
      credit: DamageCredit.player,
      hpLost100: 100,
    );
    totals.recordHpLost(
      playerTarget: true,
      enemyTarget: false,
      credit: DamageCredit.none,
      hpLost100: 75,
    );
    totals.recordHpLost(
      playerTarget: true,
      enemyTarget: false,
      credit: DamageCredit.none,
      hpLost100: 0,
    );
    expect(totals.damageDealt100, 250);
    expect(totals.damageTaken100, 75);
  });

  test('damage callback counts HP lost rather than overkill requests', () {
    final world = EcsWorld();
    final player = world.createEntity();
    final enemy = world.createEntity();
    world.health.add(
      player,
      const HealthDef(hp: 500, hpMax: 500, regenPerSecond100: 0),
    );
    world.health.add(
      enemy,
      const HealthDef(hp: 300, hpMax: 300, regenPerSecond100: 0),
    );
    world.damageQueue.add(
      DamageRequest(
        target: enemy,
        amount100: 700,
        credit: DamageCredit.player,
      ),
    );
    world.damageQueue.add(DamageRequest(target: player, amount100: 900));
    final totals = RunCombatTotals();
    DamageSystem(invulnerabilityTicksOnHit: 0, rngSeed: 1).step(
      world,
      currentTick: 1,
      onParticipationDamage:
          ({required target, required hpLost100, required credit}) {
            totals.recordHpLost(
              playerTarget: target == player,
              enemyTarget: target == enemy,
              credit: credit,
              hpLost100: hpLost100,
            );
          },
    );
    expect(totals.damageDealt100, 300);
    expect(totals.damageTaken100, 500);
  });
}
