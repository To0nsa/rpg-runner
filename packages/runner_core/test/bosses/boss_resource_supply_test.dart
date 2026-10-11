import 'package:runner_core/bosses/boss_resource_supply_definition.dart';
import 'package:runner_core/bosses/boss_resource_supply_system.dart';
import 'package:runner_core/ecs/resource_restoration.dart';
import 'package:runner_core/ecs/stores/collider_aabb_store.dart';
import 'package:runner_core/ecs/stores/health_store.dart';
import 'package:runner_core/ecs/stores/mana_store.dart';
import 'package:runner_core/ecs/stores/stamina_store.dart';
import 'package:runner_core/ecs/stores/restoration_item_store.dart';
import 'package:runner_core/ecs/systems/restoration_item_system.dart';
import 'package:runner_core/ecs/world.dart';
import 'package:runner_core/enemies/enemy_catalog.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/tuning/restoration_item_tuning.dart';
import 'package:test/test.dart';

void main() {
  test('only Goddess opts into the half-health supply milestone', () {
    const catalog = EnemyCatalog();
    expect(
      catalog.get(EnemyId.voidbornGoddess).resourceSupply!.healthThresholdBp,
      5000,
    );
    for (final id in [
      EnemyId.bringerOfDeath,
      EnemyId.shoggoth,
      EnemyId.voidcaller,
    ]) {
      expect(catalog.get(id).resourceSupply, isNull);
    }
  });

  test(
    'inclusive threshold grants once, despite healing and later crossings',
    () {
      final f = _Fixture();
      f.hp = 15001;
      f.step();
      expect(f.pickups, isEmpty);
      f.hp = 15000;
      f.step();
      expect(f.pickups, hasLength(1));
      f.hp = 30000;
      f.step();
      f.world.destroyEntity(f.pickups.single);
      f.hp = 5000;
      f.step();
      expect(f.pickups, isEmpty);
      expect(f.attempts, 1);
    },
  );

  test('a hit skipping the threshold still earns supply', () {
    final f = _Fixture();
    f.step();
    f.hp = 10000;
    f.step();
    expect(f.pickups, hasLength(1));
  });

  test(
    'selection compares fractions, ignores health, and freezes the gem type',
    () {
      final f = _Fixture();
      f.world.health.hp[f.world.health.indexOf(f.player)] = 1;
      f.world.mana.mana[0] = 2000;
      f.world.stamina.stamina[0] = 3000;
      f.world.stamina.staminaMax[0] = 20000;
      f.hp = 15000;
      f.step();
      expect(f.world.restorationItem.stat.single, RestorationStat.stamina);
      f.world.mana.mana[0] = 0;
      f.world.stamina.stamina[0] = 19000;
      f.step();
      expect(f.world.restorationItem.stat.single, RestorationStat.stamina);
      // Collection restores the locked pool, capped at its current maximum.
      f.collect();
      expect(f.world.stamina.stamina[0], 20000);
      expect(f.world.mana.mana[0], 0);
      expect(f.world.health.hp[f.world.health.indexOf(f.player)], 1);
      expect(f.world.bossResourcePickup.denseEntities, isEmpty);
      f.step();
      expect(f.pickups, isEmpty);
    },
  );

  test('mana wins equal fractions, including full pools', () {
    final f = _Fixture();
    f.hp = 15000;
    f.step();
    expect(f.world.restorationItem.stat.single, RestorationStat.mana);
  });

  test('collection uses the normal 30 percent restoration', () {
    final f = _Fixture();
    f.world.mana.mana[0] = 1000;
    f.hp = 15000;
    f.step();
    f.collect();
    expect(f.world.mana.mana[0], 4000);
  });

  test('missing and zero-capacity pools are excluded', () {
    final f = _Fixture();
    f.world.mana.manaMax[0] = 0;
    f.hp = 15000;
    f.step();
    expect(f.world.restorationItem.stat.single, RestorationStat.stamina);
    f.system.endCombat(f.world);
    f.world.stamina.removeEntity(f.player);
    f.step(occurrence: 2);
    expect(f.pickups, isEmpty);
  });

  test(
    'failed placement retries through healing, selecting at actual spawn',
    () {
      final f = _Fixture()..rejectPlacement = true;
      f.hp = 15000;
      f.step();
      expect(f.pickups, isEmpty);
      f.hp = 30000;
      f.world.stamina.stamina[0] = 100;
      f.rejectPlacement = false;
      f.step();
      expect(f.world.restorationItem.stat.single, RestorationStat.stamina);
    },
  );

  for (final victim in ['player', 'boss']) {
    test('$victim death cancels an earned pending gem', () {
      final f = _Fixture()..rejectPlacement = true;
      f.hp = 15000;
      f.step();
      f.world.health.hp[f.world.health.indexOf(
            victim == 'player' ? f.player : f.boss,
          )] =
          0;
      f.rejectPlacement = false;
      f.step();
      expect(f.pickups, isEmpty);
      expect(f.attempts, 1);
    });
  }

  test(
    'combat end cleans only supply, never a recycled ID or ambient pickup',
    () {
      final f = _Fixture();
      f.hp = 15000;
      f.step();
      final gem = f.pickups.single;
      f.world.destroyEntity(gem);
      final recycled = f.world.createEntity();
      expect(recycled, gem);
      f.world.restorationItem.add(
        recycled,
        const RestorationItemDef(stat: RestorationStat.health),
      );
      f.end();
      expect(f.world.isEntityAlive(recycled), isTrue);
      expect(f.world.restorationItem.has(recycled), isTrue);
      f.step();
      expect(f.attempts, 1);
      f.step(occurrence: 2);
      expect(f.world.bossResourcePickup.denseEntities, hasLength(1));
      f.end();
      expect(f.world.restorationItem.denseEntities, [recycled]);
    },
  );

  test('a different encounter can use a different health milestone', () {
    final f = _Fixture();
    f.hp = 15000;
    f.step(threshold: 2500);
    expect(f.pickups, isEmpty);
    f.hp = 7500;
    f.step(threshold: 2500);
    expect(f.pickups, hasLength(1));
    f.step(occurrence: 9, threshold: 2500);
    expect(f.pickups, hasLength(1));
    expect(f.attempts, 2);
  });

  test('shared ambient selection retains health-first tie priority', () {
    final f = _Fixture();
    expect(
      ResourceRestoration.lowestStat(
        f.world,
        entity: f.player,
        candidates: RestorationStat.values,
      ),
      RestorationStat.health,
    );
    f.world.mana.mana[0] = 1000;
    expect(
      ResourceRestoration.lowestStat(
        f.world,
        entity: f.player,
        candidates: RestorationStat.values,
      ),
      RestorationStat.mana,
    );
  });
}

class _Fixture {
  _Fixture() {
    player = world.createEntity();
    boss = world.createEntity();
    world.health.add(
      player,
      const HealthDef(hp: 10000, hpMax: 10000, regenPerSecond100: 0),
    );
    world.health.add(
      boss,
      const HealthDef(hp: 30000, hpMax: 30000, regenPerSecond100: 0),
    );
    world.mana.add(
      player,
      const ManaDef(mana: 10000, manaMax: 10000, regenPerSecond100: 0),
    );
    world.stamina.add(
      player,
      const StaminaDef(stamina: 10000, staminaMax: 10000, regenPerSecond100: 0),
    );
    world.transform.add(player, posX: 100, posY: 100, velX: 0, velY: 0);
    world.colliderAabb.add(player, const ColliderAabbDef(halfX: 8, halfY: 24));
  }
  final world = EcsWorld();
  final system = BossResourceSupplySystem();
  late final int player;
  late final int boss;
  bool rejectPlacement = false;
  int attempts = 0;
  List<int> get pickups => world.restorationItem.denseEntities;
  set hp(int value) => world.health.hp[world.health.indexOf(boss)] = value;

  void step({int occurrence = 1, int threshold = 5000}) => system.step(
    world,
    player: player,
    encounter: BossResourceSupplyEncounter(
      occurrence: occurrence,
      boss: boss,
      minX: 24,
      maxX: 576,
      definition: BossResourceSupplyDefinition(healthThresholdBp: threshold),
    ),
    spawn: (_, stat) {
      attempts++;
      if (rejectPlacement) return null;
      final entity = world.createEntity();
      world.restorationItem.add(entity, RestorationItemDef(stat: stat));
      world.transform.add(entity, posX: 100, posY: 100, velX: 0, velY: 0);
      world.colliderAabb.add(entity, const ColliderAabbDef(halfX: 8, halfY: 8));
      return entity;
    },
  );

  void end() => system.step(
    world,
    player: player,
    encounter: null,
    spawn: (_, _) => throw StateError('No spawn outside combat'),
  );

  void collect() => RestorationItemSystem().step(
    world,
    player: player,
    cameraLeft: 0,
    tuning: const RestorationItemTuning(),
  );
}
