/// AOT microbenchmark of stable NPC rosters, targeting, cleanup and encounters.
///
/// Compile this tool for runtime comparisons. The default synthetic fixtures omit
/// navigation, physics, combat and rendering. `--navigation` also measures six
/// bounded graph variants on three repeated authored chunks, excluding the base
/// terrain build; these are allocation timings, not complete run/frame budgets.
library;

import 'dart:convert';
import 'dart:io';

import 'package:runner_core/collision/terrain/terrain_motion_request.dart';
import 'package:runner_core/collision/terrain/terrain_numeric.dart';
import 'package:runner_core/navigation/bounded_terrain_graph.dart';
import 'package:runner_core/navigation/terrain_runtime_bundle.dart';
import 'package:runner_core/npcs/npc_navigation_profiles.dart';
import 'package:runner_core/track/staged_authored_terrain.dart';
import 'package:runner_core/track/staged_terrain_catalog.dart';
import 'package:runner_core/track/staged_terrain_stream_candidate.dart';
import 'package:runner_core/tuning/physics_tuning.dart';

import 'package:runner_core/combat/faction.dart';
import 'package:runner_core/ecs/stores/enemies/enemy_store.dart';
import 'package:runner_core/ecs/stores/faction_store.dart';
import 'package:runner_core/ecs/stores/health_store.dart';
import 'package:runner_core/ecs/systems/ai_target_system.dart';
import 'package:runner_core/ecs/systems/npc_combat_lifecycle.dart';
import 'package:runner_core/ecs/systems/npc_guard_system.dart';
import 'package:runner_core/ecs/world.dart';
import 'package:runner_core/encounters/encounter_definition.dart';
import 'package:runner_core/encounters/encounter_instance.dart';
import 'package:runner_core/encounters/encounter_system.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/npcs/npc_guard_region.dart';
import 'package:runner_core/npcs/npc_id.dart';

final results = <Map<String, Object>>[];

void measure(String name, void Function() step) {
  for (var i = 0; i < 1000; i++) {
    step();
  }
  final samples = <double>[];
  for (var sample = 0; sample < 5; sample++) {
    var iterations = 0;
    final watch = Stopwatch()..start();
    while (watch.elapsedMicroseconds < 100000) {
      for (var i = 0; i < 100; i++) {
        step();
      }
      iterations += 100;
    }
    watch.stop();
    samples.add(watch.elapsedMicroseconds / iterations);
  }
  samples.sort();
  results.add({
    'name': name,
    'median_us': samples[2],
    'max_batch_us': samples.last,
  });
}

int actor(EcsWorld world, double x, Faction faction) {
  final e = world.createEntity();
  world.transform.add(e, posX: x, posY: 0, velX: 0, velY: 0);
  world.health.add(
    e,
    const HealthDef(hp: 10000, hpMax: 10000, regenPerSecond100: 0),
  );
  world.faction.add(e, FactionDef(faction: faction));
  return e;
}

void main(List<String> args) {
  for (final (guardCount, enemyCount) in [
    (0, 0),
    (3, 8),
    (16, 32),
    (64, 128),
  ]) {
    final world = EcsWorld();
    final player = actor(world, 20, Faction.player);
    for (var i = 0; i < guardCount; i++) {
      final e = actor(world, 100 + i * 2.0, Faction.player);
      world.npc.add(e, id: NpcId.warrior, chunkStartX: 0, chunkEndX: 600);
      beginNpcGuarding(
        world,
        e,
        NpcGuardRegion.forChunk(chunkIndex: 0, startX: 0, endX: 600),
      );
    }
    for (var i = 0; i < enemyCount; i++) {
      final e = actor(world, 300 + i * 2.0, Faction.enemy);
      world.enemy.add(e, const EnemyDef(enemyId: EnemyId.grojib));
    }
    final guards = NpcGuardSystem();
    final targets = AiTargetSystem();
    guards.step(world);
    targets.step(world, player: player);
    final label = '$guardCount guards/$enemyCount enemies';
    measure('$label roster refresh', () => guards.step(world));
    measure(
      '$label target selection',
      () => targets.step(world, player: player),
    );
    measure('$label target acquisition', () {
      for (var i = 0; i < world.aiTarget.selected.length; i++) {
        world.aiTarget.selected[i] = null;
      }
      targets.step(world, player: player);
    });
    measure(
      '$label transient destroy',
      () => world.destroyEntity(world.createEntity()),
    );
  }

  for (final (count, active) in [
    (0, false),
    (4, false),
    (16, false),
    (4, true),
    (16, true),
  ]) {
    final world = EcsWorld();
    final system = EncounterSystem();
    EncounterSpawnResult spawn(EncounterOccurrence occurrence) {
      final roster = <String, int>{};
      for (final member in occurrence.participants) {
        final e = actor(
          world,
          member.x,
          member is EncounterNpcPlacement ? Faction.player : Faction.enemy,
        );
        if (member is EncounterNpcPlacement) {
          world.npc.add(e, id: member.npcId, chunkStartX: 0, chunkEndX: 600);
        } else {
          world.enemy.add(
            e,
            EnemyDef(enemyId: (member as EncounterEnemyPlacement).enemyId),
          );
        }
        roster[member.id] = e;
      }
      return EncounterSpawned(roster);
    }

    for (var i = 0; i < count; i++) {
      system.register(
        EncounterOccurrence(
          chunkIndex: i,
          startX: 0,
          endX: 600,
          definition: EncounterDefinition(
            id: 'rescue',
            name: 'Rescue',
            trigger: EncounterTrigger(x: 32, y: -10, width: 20, height: 100),
            npcs: [
              for (var n = 0; n < 4; n++)
                EncounterNpcPlacement(
                  id: 'npc_$n',
                  npcId: NpcId.warrior,
                  x: 100,
                ),
            ],
            enemies: [
              for (var n = 0; n < 8; n++)
                EncounterEnemyPlacement(
                  id: 'enemy_$n',
                  enemyId: EnemyId.grojib,
                  x: 200,
                ),
            ],
          ),
        ),
        tick: 0,
      );
    }
    final playerX = active ? 40.0 : 0.0;
    system.activate(world, playerX: playerX, playerY: 0, tick: 0, spawn: spawn);
    measure('$count ${active ? 'active' : 'dormant'} encounter tick', () {
      system.expire(world, cameraLeft: 0, tick: 1);
      system.activate(
        world,
        playerX: playerX,
        playerY: 0,
        tick: 1,
        spawn: spawn,
      );
      system.expire(world, cameraLeft: 0, tick: 1);
      system.resolve(world, cameraLeft: 0, tick: 1);
      system.drainOutcomes();
      system.drainOutcomes();
    });
  }
  if (args.contains('--navigation')) _measureNavigation();
  stdout.writeln(
    const JsonEncoder.withIndent('  ').convert({
      'dart': Platform.version,
      'os': Platform.operatingSystem,
      'measurements': results,
    }),
  );
}

void _measureNavigation() {
  final catalog = StagedTerrainArtifactCatalog(artifact: stagedAuthoredTerrain);
  final profiles = [
    ...buildDefaultGroundEnemyTerrainGraphProfiles(),
    ...buildNpcNavigationProfiles(tickHz: 60, physics: const PhysicsTuning()),
  ];
  final details = <Map<String, Object>>[];
  var edgeChecksum = 0;
  for (final key in [
    'field_default_normal_002',
    'forest_trainingcamp_normal_004',
    'forest_woodcamp_normal_001',
    'forest_rocky_grove_hard_009',
  ]) {
    final width =
        catalog.requireChunk(key).width * terrainPhysicsTicksPerWorldUnit;
    final candidate = const StagedTerrainStreamCandidateBuilder()
        .buildFromBindings(
          bindings: [
            for (var i = 0; i < 3; i++)
              catalog.bind(
                chunkKey: key,
                chunkIndex: i,
                worldOriginXTicks: i * width,
              ),
          ],
          geometryVersion: 1,
          groundEnemyProfiles: profiles,
        );
    final graphs = [
      for (final id in NpcId.values)
        candidate.runtimeBundle.graphPublication[npcNavigationProfileKey(id)],
    ];
    final bounds = [
      TerrainHorizontalBounds(minXTicks: 0, maxXTicks: width),
      TerrainHorizontalBounds(minXTicks: 0, maxXTicks: width * 3),
    ];
    details.add({
      'key': key,
      'surfaces': graphs.first.surfaces.length,
      'npc_edges': graphs.fold<int>(
        0,
        (sum, graph) => sum + graph.edges.length,
      ),
    });
    measure('$key six bounded graphs', () {
      for (final graph in graphs) {
        for (final bound in bounds) {
          edgeChecksum += restrictTerrainGraph(graph, bound).edges.length;
        }
      }
    });
  }
  results.add({'navigation_fixtures': details, 'edge_checksum': edgeChecksum});
}
