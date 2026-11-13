import 'package:runner_core/campaign/campaign_enemy_system.dart';
import 'package:runner_core/ecs/combat_target.dart';
import 'package:runner_core/ecs/stores/enemies/campaign_enemy_store.dart';
import 'package:runner_core/ecs/stores/health_store.dart';
import 'package:runner_core/ecs/world.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:test/test.dart';

void main() {
  late EcsWorld world;
  late CampaignEnemySystem system;
  late int player, enemy;
  setUp(() {
    world = EcsWorld();
    system = CampaignEnemySystem();
    player = _actor(world, 300);
    enemy = _actor(world, 1500);
    world.campaignEnemy.add(
      enemy,
      x: 1500,
      y: 200,
      facing: Facing.left,
      returns: true,
    );
  });
  void step(int tick) => system.step(world, player: player, tick: tick);
  CampaignEnemyPhase phase() =>
      world.campaignEnemy.phase[world.campaignEnemy.indexOf(enemy)];

  test(
    'waiting actors exist and remain damageable without selecting a target',
    () {
      step(1);
      expect(phase(), CampaignEnemyPhase.waiting);
      expect(world.isEntityAlive(enemy), isTrue);
      expect(combatTarget(world, enemy, player), isNull);
      expect(isLivingCombatActor(world, enemy), isTrue);
    },
  );

  for (final direction in [-1, 1]) {
    test(
      'approach from $direction activates, distance hysteresis retains combat',
      () {
        world.transform.setPosXY(player, 1500 + direction * 280, 200);
        step(1);
        expect(phase(), CampaignEnemyPhase.engaged);
        expect(combatTarget(world, enemy, player), player);
        world.transform.setPosXY(player, 1500 + direction * 500, 200);
        step(2);
        expect(phase(), CampaignEnemyPhase.engaged);
        world.transform.setPosXY(enemy, 1500 + direction * 200, 200);
        world.transform.setPosXY(player, 1500 + direction * 601, 200);
        step(3);
        expect(phase(), CampaignEnemyPhase.returning);
        expect(combatTarget(world, enemy, player), isNull);
        world.transform.setPosXY(enemy, 1502, 200);
        step(4);
        expect(phase(), CampaignEnemyPhase.waiting);
        expect(world.health.hp[world.health.indexOf(enemy)], 1000);
      },
    );
  }

  test('persistent pursuit stays active outside its home territory', () {
    world.campaignEnemy.returnWhenPlayerRetreats[0] = false;
    world.transform.setPosXY(player, 1300, 200);
    step(1);
    world.transform.setPosXY(player, 300, 200);
    step(900);
    expect(phase(), CampaignEnemyPhase.engaged);
    expect(combatTarget(world, enemy, player), player);
  });

  for (final hz in [30, 60, 90]) {
    test(
      '$hz Hz: distant damage wakes immediately and allows two seconds to retaliate',
      () {
        world.health.hp[world.health.indexOf(enemy)] = 700;
        system.recordDamage(world, target: enemy, tick: 10, tickHz: hz);
        expect(phase(), CampaignEnemyPhase.engaged);
        expect(combatTarget(world, enemy, player), player);
        step(10 + 2 * hz - 1);
        expect(phase(), CampaignEnemyPhase.engaged);
        world.transform.setPosXY(enemy, 1400, 200);
        step(10 + 2 * hz);
        expect(phase(), CampaignEnemyPhase.returning);
        world.transform.setPosXY(player, 1300, 200);
        step(11 + 2 * hz);
        expect(phase(), CampaignEnemyPhase.engaged);
        expect(world.health.hp[world.health.indexOf(enemy)], 700);
      },
    );
  }

  test(
    'dead and recycled entities cannot inherit activation or home state',
    () {
      world.health.hp[world.health.indexOf(enemy)] = 0;
      system.recordDamage(world, target: enemy, tick: 1, tickHz: 60);
      expect(phase(), CampaignEnemyPhase.waiting);
      world.destroyEntity(enemy);
      expect(world.campaignEnemy.has(enemy), isFalse);
      final replacement = _actor(world, 100);
      expect(replacement, enemy);
      expect(world.campaignEnemy.canFight(replacement), isTrue);
      step(2);
      expect(combatTarget(world, replacement, player), player);
    },
  );

  test('swap removal preserves the other marker home and follow option', () {
    final other = _actor(world, 2400);
    world.campaignEnemy.add(
      other,
      x: 2400,
      y: 200,
      facing: Facing.right,
      returns: false,
    );
    world.destroyEntity(enemy);
    expect(world.campaignEnemy.homeX, [2400]);
    expect(world.campaignEnemy.returnWhenPlayerRetreats, [false]);
    expect(world.campaignEnemy.homeFacing, [Facing.right]);
  });
}

int _actor(EcsWorld world, double x) {
  final id = world.createEntity();
  world.transform.add(id, posX: x, posY: 200, velX: 0, velY: 0);
  world.health.add(
    id,
    const HealthDef(hp: 1000, hpMax: 1000, regenPerSecond100: 0),
  );
  return id;
}
