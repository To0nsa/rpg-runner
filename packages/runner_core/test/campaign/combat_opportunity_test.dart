import 'package:runner_core/combat/player_combat_opportunity.dart';
import 'package:runner_core/combat/combat_geometry.dart';
import 'package:runner_core/ecs/world.dart';
import 'package:runner_core/ecs/stores/health_store.dart';
import 'package:runner_core/ecs/stores/combat/equipped_loadout_store.dart';
import 'package:test/test.dart';

void main() {
  test('opportunity uses blade/body capsules, projectile lifetime and sightline without mutating actors', () {
    final world = EcsWorld();
    final player = world.createEntity(), enemy = world.createEntity();
    world.transform.add(player, posX: 0, posY: 100, velX: 0, velY: 0);
    world.transform.add(enemy, posX: 35, posY: 100, velX: 0, velY: 0);
    world.health.add(
      enemy,
      const HealthDef(hp: 2000, hpMax: 2000, regenPerSecond100: 0),
    );
    world.equippedLoadout.add(
      player,
      const EquippedLoadoutDef(abilityPrimaryId: 'eloise.seeker_slash'),
    );
    world.combatHurtbox.set(enemy, const CombatCapsule(0, -12, 0, 12, 10));
    bool clear = true;
    read() => playerCombatOpportunity(
      world,
      player: player,
      target: enemy,
      pathClear: (_, _, _, _) => clear,
    )!;
    expect(read().inMeleeReach, isTrue);
    expect(read().inProjectileReach, isTrue);
    clear = false;
    expect(read().inProjectileReach, isFalse);
    clear = true;
    world.transform.setPosXY(enemy, 150, 100);
    expect(read().inMeleeReach, isFalse);
    expect(read().inProjectileReach, isTrue);
    world.transform.setPosXY(enemy, 0, -100);
    expect(read().inMeleeReach, isFalse);
    world.transform.setPosXY(enemy, 800, 100);
    expect(read().inProjectileReach, isFalse);
    expect(world.health.hp[0], 2000);
    expect(world.transform.posX[world.transform.indexOf(player)], 0);
    world.health.hp[0] = 0;
    expect(
      playerCombatOpportunity(
        world,
        player: player,
        target: enemy,
        pathClear: (_, _, _, _) => true,
      ),
      isNull,
    );
  });
}
