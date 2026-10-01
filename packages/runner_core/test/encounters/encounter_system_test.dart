import 'package:runner_core/combat/damage.dart';
import 'package:runner_core/combat/damage_credit.dart';
import 'package:runner_core/combat/faction.dart';
import 'package:runner_core/ecs/stores/enemies/enemy_store.dart';
import 'package:runner_core/ecs/stores/faction_store.dart';
import 'package:runner_core/ecs/stores/health_store.dart';
import 'package:runner_core/ecs/systems/damage_system.dart';
import 'package:runner_core/ecs/systems/enemy_cull_system.dart';
import 'package:runner_core/ecs/world.dart';
import 'package:runner_core/encounters/encounter_definition.dart';
import 'package:runner_core/encounters/encounter_instance.dart';
import 'package:runner_core/encounters/encounter_limits.dart';
import 'package:runner_core/encounters/encounter_system.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/npcs/npc_id.dart';
import 'package:runner_core/tuning/track_tuning.dart';
import 'package:test/test.dart';

void main() {
  test('dormant triggers sweep inclusively in stable occurrence and local ID order', () {
    final f = _Fixture();
    f.add(index: 1, id: 'second', start: 0);
    f.add(id: 'z_group');
    f.add(id: 'a_group');
    f.activate(x: 0);
    expect(f.world.encounterMember.denseEntities, isEmpty);
    f.activate(x: 200);
    expect(f.spawned.map((k) => '${k.chunkIndex}/${k.encounterId}'), [
      '0/a_group',
      '0/z_group',
      '1/second',
    ]);
    f.activate(x: 100);
    expect(f.spawned.length, 3);
    final boundary = _Fixture();
    final key = boundary.add();
    boundary.activate(x: 32, y: -10);
    expect(boundary.system.phase(key), EncounterPhase.active);
  });

  test(
    'complete rescue needs positive player HP damage, but not the final hit',
    () {
      final f = _Fixture();
      final key = f.add(points: 321, npcs: 2);
      f.activate();
      final enemy = f.enemy(key);
      f.damage(enemy, 1, DamageCredit.player);
      f.damage(enemy, 5000, DamageCredit.none);
      f.resolve();
      expect(f.system.outcome(key)!.reason, EncounterEndReason.rescued);
      expect(f.system.rescuedNpcs, 2);
      expect(f.system.rescuePoints, 642);
      expect(f.world.npc.protected, everyElement(isFalse));
      expect(f.world.npc.guardRegion, everyElement(isNotNull));
      f.resolve();
      f.system.endRun(f.world, tick: 2);
      expect(f.system.rescuePoints, 642);
      expect(f.system.drainOutcomes().length, 1);
      expect(f.system.drainOutcomes(), isEmpty);
    },
  );

  test('zero damage and NPC damage cannot qualify; unassisted survivors guard without credit', () {
    final f = _Fixture();
    final key = f.add();
    f.activate();
    f.damage(f.enemy(key), 0, DamageCredit.player);
    f.damage(f.enemy(key), 5000, DamageCredit.none);
    f.resolve();
    expect(f.system.outcome(key)!.reason, EncounterEndReason.unassisted);
    expect(f.world.npc.isProtected(f.npc(key)), isFalse);
    expect(f.world.npc.guardRegion.single, isNotNull);
    expect(f.system.rescuePoints, 0);
    expect(f.system.rescuedNpcs, 0);
  });

  test(
    'later guard death and origin retirement never change settled awards',
    () {
      final f = _Fixture();
      final key = f.add(points: 333);
      f.activate();
      f.damage(f.enemy(key), 5000, DamageCredit.player);
      f.resolve();
      final npc = f.npc(key);
      f.system.retireChunk(f.world, 0);
      expect(f.world.npc.guardRegion.single, isNotNull);
      expect(f.world.encounterMember.has(npc), isFalse);
      expect(f.system.retainsActor(f.world, npc), isFalse);
      f.damage(npc, 5000, DamageCredit.none);
      expect(f.world.health.hp[f.world.health.indexOf(npc)], 0);
      f.resolve();
      f.system.endRun(f.world, tick: 2);
      expect((f.system.rescuedNpcs, f.system.rescuePoints), (1, 333));
      expect(f.system.drainOutcomes(), hasLength(1));
      expect(f.world.npc.guardRegion.single, isNull);
    },
  );

  test('camera abandonment keeps survivors protected instead of guarding', () {
    final f = _Fixture();
    final key = f.add();
    f.activate();
    f.resolve(camera: 1200);
    expect(f.world.npc.isProtected(f.npc(key)), isTrue);
    expect(f.world.npc.guardRegion.single, isNull);
    expect(f.world.aiTarget.has(f.npc(key)), isFalse);
  });

  test(
    'enemy victory releases targeting without changing committed combat state',
    () {
      final f = _Fixture();
      final key = f.add();
      f.activate();
      final enemy = f.enemy(key);
      f.world.cooldown.add(enemy);
      f.world.cooldown.startCooldown(enemy, 0, 42);
      f.world.activeAbility.add(enemy);
      f.world.activeAbility.abilityId[0] = 'grojib.strike';
      f.damage(enemy, 12, DamageCredit.player);
      f.damage(f.npc(key), 5000, DamageCredit.none);
      f.resolve();
      expect(f.system.outcome(key)!.reason, EncounterEndReason.npcsDefeated);
      expect(f.world.aiTarget.has(enemy), isFalse);
      expect(f.world.health.hp[f.world.health.indexOf(enemy)], 4988);
      expect(f.world.cooldown.getTicksLeft(enemy, 0), 42);
      expect(f.world.activeAbility.abilityId[0], 'grojib.strike');
      f.damage(enemy, 5000, DamageCredit.player);
      f.resolve();
      expect(f.system.rescuePoints, 0);
    },
  );

  for (final cause in [
    'all_dead',
    'run_end',
    'distance',
    'unexpected_removal',
  ]) {
    test('$cause beats enemy completion on the same tick', () {
      final f = _Fixture();
      final key = f.add(npcs: 2);
      f.activate();
      f.damage(f.enemy(key), 5000, DamageCredit.player);
      if (cause == 'all_dead') {
        for (final npc in f.npcs(key)) {
          f.damage(npc, 5000, DamageCredit.none);
        }
      }
      if (cause == 'unexpected_removal') f.world.destroyEntity(f.npc(key));
      f.resolve(
        camera: cause == 'distance' ? 1200 : 0,
        runEnded: cause == 'run_end',
      );
      expect(f.system.rescuePoints, 0);
      expect(f.system.outcome(key)!.reason, switch (cause) {
        'all_dead' => EncounterEndReason.npcsDefeated,
        'run_end' => EncounterEndReason.runEnded,
        'distance' => EncounterEndReason.passedCamera,
        _ => EncounterEndReason.invalidMember,
      });
    });
  }

  test('one-owning-width threshold retains early actors and terrain until equality', () {
    final f = _Fixture();
    final key = f.add(start: 1000, width: 400);
    f.activate(x: 1050);
    final enemy = f.enemy(key);
    final cull = EnemyCullSystem();
    cull.step(
      f.world,
      cameraLeft: 1700,
      groundTopY: 128,
      tuning: const TrackTuning(cullBehindMargin: 0),
      retainForEncounter: (e) => f.system.retainsActor(f.world, e),
    );
    expect(f.world.enemy.has(enemy), isTrue);
    f.system.expire(f.world, cameraLeft: 1799.999, tick: 1);
    expect(f.system.phase(key), EncounterPhase.active);
    expect(() => f.system.retireChunk(f.world, 0), throwsStateError);
    f.system.expire(f.world, cameraLeft: 1800, tick: 2);
    expect(f.system.outcome(key)!.reason, EncounterEndReason.passedCamera);
    expect(f.system.retainsActor(f.world, enemy), isFalse);
    f.system.retireChunk(f.world, 0);
    expect(f.system.retainedEncounters, 0);
  });

  test('required enemy falling out of the world fails even with zero HP', () {
    final f = _Fixture();
    final key = f.add();
    f.activate();
    final enemy = f.enemy(key);
    f.damage(enemy, 5000, DamageCredit.player);
    f.world.transform.posY[f.world.transform.indexOf(enemy)] = 1000;
    EnemyCullSystem().step(
      f.world,
      cameraLeft: 0,
      groundTopY: 128,
      tuning: const TrackTuning(),
      retainForEncounter: (e) => f.system.retainsActor(f.world, e),
    );
    f.resolve();
    expect(f.system.outcome(key)!.reason, EncounterEndReason.invalidMember);
    expect(f.system.rescuePoints, 0);
  });

  test(
    'fatal NPC loss counts as death; a surviving NPC may still be rescued',
    () {
      final f = _Fixture();
      final key = f.add(npcs: 2);
      f.activate();
      f.world.destroyEntity(f.npc(key), fatalWorldLoss: true);
      f.damage(f.enemy(key), 5000, DamageCredit.player);
      f.resolve();
      expect(f.system.rescuedNpcs, 1);
      expect(f.system.rescuePoints, 250);
    },
  );

  test(
    'defeat evidence survives entity-ID reuse while deletion is never victory',
    () {
      final f = _Fixture();
      final key = f.add();
      f.activate();
      final enemy = f.enemy(key);
      f.damage(enemy, 5000, DamageCredit.player);
      f.world.destroyEntity(enemy);
      expect(f.world.createEntity(), enemy);
      f.resolve();
      expect(f.system.rescuePoints, 250);
    },
  );

  test('repeated chunk occurrences and mixed overrides have independent credit and awards', () {
    final f = _Fixture();
    final keys = [
      f.add(points: 0),
      f.add(index: 1, points: 77),
      f.add(index: 2),
    ];
    for (var i = 0; i < keys.length; i++) {
      f.activate(x: i * 600 + 50.0);
      f.damage(f.enemy(keys[i]), 5000, DamageCredit.player);
      f.resolve();
    }
    expect(f.system.rescuedNpcs, 3);
    expect(f.system.rescuePoints, 327);
    expect(f.system.drainOutcomes().map((e) => e.points), [0, 77, 250]);
  });

  test('opening suppression skips the complete group and rejected spawns cannot win', () {
    final f = _Fixture();
    final suppressed = f.add(suppressed: true);
    f.activate();
    expect(f.spawned, isEmpty);
    expect(f.system.phase(suppressed), EncounterPhase.skipped);
    final rejected = f.add(index: 1);
    f.system.activate(
      f.world,
      playerX: 650,
      playerY: 0,
      tick: 1,
      spawn: (_) => const EncounterSpawnRejected('No valid terrain support.'),
    );
    expect(f.system.outcome(rejected)!.reason, EncounterEndReason.invalidSpawn);
    expect(f.system.outcome(rejected)!.diagnostic, contains('terrain'));
    expect(f.world.encounterMember.denseEntities, isEmpty);
  });

  test(
    'a partial spawn is rolled back; an expired dormant group never spawns',
    () {
      final f = _Fixture();
      final key = f.add();
      f.system.activate(
        f.world,
        playerX: 50,
        playerY: 0,
        tick: 1,
        spawn: (o) {
          final all = f.spawn(o) as EncounterSpawned;
          final enemy = all.entities['guard']!;
          f.world.destroyEntity(enemy);
          return EncounterSpawned({'npc_0': all.entities['npc_0']!});
        },
      );
      expect(f.system.outcome(key)!.reason, EncounterEndReason.invalidSpawn);
      expect(f.world.npc.denseEntities, isEmpty);
      final dormant = f.add(index: 1);
      f.system.expire(f.world, cameraLeft: 1800, tick: 2);
      final count = f.spawned.length;
      f.activate(x: 650);
      expect(f.spawned.length, count);
      expect(f.system.phase(dormant), EncounterPhase.abandoned);
    },
  );

  test(
    'runtime capacity rejects whole groups and retirement remains bounded',
    () {
      final f = _Fixture();
      for (var i = 0; i < EncounterLimits.maxLiveEncounters + 1; i++) {
        f.add(index: i);
      }
      expect(f.system.retainedEncounters, EncounterLimits.maxLiveEncounters);
      expect(
        f.system.drainOutcomes().single.reason,
        EncounterEndReason.capacity,
      );
      f.system.endRun(f.world, tick: 1);
      f.system.drainOutcomes();
      for (var i = 0; i < EncounterLimits.maxLiveEncounters; i++) {
        f.system.retireChunk(f.world, i);
      }
      expect(f.system.retainedEncounters, 0);
      expect(() => f.add(index: 0), throwsStateError);
      f.add(index: 100);
      expect(f.system.retainedEncounters, 1);
    },
  );
}

class _Fixture {
  final world = EcsWorld();
  final system = EncounterSystem();
  final spawned = <EncounterKey>[];
  final entities = <EncounterKey, Map<String, int>>{};
  final damageSystem = DamageSystem(invulnerabilityTicksOnHit: 0, rngSeed: 1);

  EncounterKey add({
    int index = 0,
    String id = 'rescue',
    double? start,
    double width = 600,
    int? points,
    int npcs = 1,
    bool suppressed = false,
  }) {
    final occurrence = EncounterOccurrence(
      chunkIndex: index,
      startX: start ?? index * 600.0,
      endX: (start ?? index * 600.0) + width,
      definition: EncounterDefinition(
        id: id,
        name: 'Rescue',
        pointsPerNpc: points,
        trigger: EncounterTrigger(x: 32, y: -10, width: 20, height: 100),
        npcs: List.generate(
          npcs,
          (i) =>
              EncounterNpcPlacement(id: 'npc_$i', npcId: NpcId.warrior, x: 100),
        ),
        enemies: [
          EncounterEnemyPlacement(id: 'guard', enemyId: EnemyId.grojib, x: 200),
        ],
      ),
    );
    system.register(occurrence, tick: 0, suppressOpening: suppressed);
    return occurrence.key;
  }

  EncounterSpawnResult spawn(EncounterOccurrence occurrence) {
    spawned.add(occurrence.key);
    final members = occurrence.participants;
    final roster = <String, int>{};
    for (final member in members) {
      final id = world.createEntity();
      world.transform.add(
        id,
        posX: occurrence.startX + member.x,
        posY: 0,
        velX: 0,
        velY: 0,
      );
      world.health.add(
        id,
        const HealthDef(hp: 5000, hpMax: 5000, regenPerSecond100: 0),
      );
      world.faction.add(
        id,
        FactionDef(
          faction: member is EncounterNpcPlacement
              ? Faction.player
              : Faction.enemy,
        ),
      );
      if (member is EncounterNpcPlacement) {
        world.npc.add(
          id,
          id: member.npcId,
          chunkStartX: occurrence.startX,
          chunkEndX: occurrence.endX,
        );
      } else {
        world.enemy.add(
          id,
          EnemyDef(enemyId: (member as EncounterEnemyPlacement).enemyId),
        );
      }
      roster[member.id] = id;
    }
    entities[occurrence.key] = roster;
    return EncounterSpawned(roster);
  }

  void activate({double x = 50, double y = 0}) =>
      system.activate(world, playerX: x, playerY: y, tick: 1, spawn: spawn);
  int enemy(EncounterKey key) => entities[key]!['guard']!;
  int npc(EncounterKey key) => entities[key]!['npc_0']!;
  Iterable<int> npcs(EncounterKey key) => entities[key]!.entries
      .where((e) => e.key.startsWith('npc_'))
      .map((e) => e.value);
  void damage(int target, int amount, DamageCredit credit) {
    world.damageQueue.add(
      DamageRequest(target: target, amount100: amount, credit: credit),
    );
    damageSystem.step(
      world,
      currentTick: 1,
      onParticipationDamage:
          ({required target, required hpLost100, required credit}) =>
              system.recordDamage(
                world,
                target: target,
                hpLost100: hpLost100,
                credit: credit,
              ),
    );
  }

  void resolve({double camera = 0, bool runEnded = false}) =>
      system.resolve(world, tick: 1, cameraLeft: camera, runEnded: runEnded);
}
