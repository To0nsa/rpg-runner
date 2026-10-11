/// Offline AOT comparison using a digest-verified real replay. Captures only
/// the exact replay's used graphs; this is not a route-coverage certificate.
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:runner_core/accessories/accessory_id.dart';
import 'package:runner_core/collision/terrain/terrain_edge_index.dart';
import 'package:runner_core/ecs/stores/combat/equipped_loadout_store.dart';
import 'package:runner_core/game_core.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/levels/level_registry.dart';
import 'package:runner_core/navigation/terrain_graph_artifact.dart';
import 'package:runner_core/navigation/terrain_graph_artifact_manifest.dart';
import 'package:runner_core/navigation/terrain_graph_materializer.dart';
import 'package:runner_core/navigation/terrain_surface_graph_builder.dart';
import 'package:runner_core/navigation/terrain_surface_spatial_index.dart';
import 'package:runner_core/navigation/terrain_placement_query.dart';
import 'package:runner_core/players/player_character_definition.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:runner_core/projectiles/projectile_id.dart';
import 'package:runner_core/spellBook/spell_book_id.dart';
import 'package:runner_core/weapons/weapon_id.dart';
import 'package:run_protocol/replay_blob.dart';
import 'package:replay_validator/src/replay_simulation.dart';
import 'package:replay_validator/src/navigation_artifact_store.dart';

void main(List<String> args) {
  if (args.length != 2) {
    stderr.writeln(
      'Usage: benchmark_reward_verification <replay.json[.gz]> <capture-directory>',
    );
    exitCode = 64;
    return;
  }
  final directory = Directory(args[1])..createSync(recursive: true);
  final decode = Stopwatch()..start();
  final bytes = File(args.first).readAsBytesSync();
  final payload = bytes[0] == 0x1f && bytes[1] == 0x8b
      ? gzip.decode(bytes)
      : bytes;
  final replay = ReplayBlobV1.fromJson(
    jsonDecode(utf8.decode(payload)) as Map<String, dynamic>,
    verifyDigest: true,
  );
  decode.stop();
  final s = replay.loadoutSnapshot;
  final loadout = EquippedLoadoutDef(
    mask: s['mask'] as int,
    mainWeaponId: WeaponId.values.byName(s['mainWeaponId'] as String),
    offhandWeaponId: WeaponId.values.byName(s['offhandWeaponId'] as String),
    spellBookId: SpellBookId.values.byName(s['spellBookId'] as String),
    projectileSlotSpellId: playerEquippableProjectileIds.byName(
      s['projectileSlotSpellId'] as String,
    ),
    accessoryId: AccessoryId.values.byName(s['accessoryId'] as String),
    abilityPrimaryId: s['abilityPrimaryId'] as String,
    abilitySecondaryId: s['abilitySecondaryId'] as String,
    abilityProjectileId: s['abilityProjectileId'] as String,
    abilitySpellId: s['abilitySpellId'] as String,
    abilityMobilityId: s['abilityMobilityId'] as String,
    abilityJumpId: s['abilityJumpId'] as String,
  );
  final entries = <String, TerrainGraphArtifactEntry>{};
  String? baselineOutcome;
  NavigationArtifactStore? store;
  final capture = TerrainGraphMaterializer.onDemand(
    lookup: (geometry, surfaces, profile) {
      final graph = TerrainSurfaceGraphBuilder(
        placementQuery: TerrainPlacementQuery(
          geometry: geometry,
          terrainIndex: TerrainEdgeIndex(edges: geometry.edges),
          surfaceIndex: TerrainSurfaceSpatialIndex(surfaceSet: surfaces),
        ),
      ).build(profile);
      final key = terrainGraphArtifactKey(
        geometry: geometry,
        surfaces: surfaces,
        profile: profile,
      );
      final encoded = TerrainGraphArtifactCodec.encode(key: key, graph: graph);
      File('${directory.path}/$key.rng').writeAsBytesSync(encoded);
      entries[key] = TerrainGraphArtifactEntry(
        sha256: sha256.convert(encoded).toString(),
        bytes: encoded.length,
      );
      return graph;
    },
  );
  for (final mode in [
    'eager',
    'on-demand',
    'capture',
    'prepared-cold',
    'prepared-warm',
  ]) {
    final construction = Stopwatch()..start();
    if (mode == 'prepared-cold')
      store = NavigationArtifactStore(directory: directory.path);
    final hitsBefore = store?.hits ?? 0;
    final missesBefore = store?.misses ?? 0;
    final materializer = switch (mode) {
      'eager' => const TerrainGraphMaterializer.eager(),
      'on-demand' => const TerrainGraphMaterializer.onDemand(),
      'capture' => capture,
      _ => store!.materializer,
    };
    final core = GameCore(
      seed: replay.seed,
      runId: 1,
      tickHz: replay.tickHz,
      levelDefinition: LevelRegistry.byId(
        LevelId.values.byName(replay.levelId),
      ),
      playerCharacter: PlayerCharacterRegistry.resolve(
        PlayerCharacterId.values.byName(replay.playerCharacterId),
      ),
      equippedLoadoutOverride: loadout,
      graphMaterializer: materializer,
    );
    construction.stop();
    final simulation = Stopwatch()..start();
    final result = runReplaySimulation(
      core: core,
      totalTicks: replay.totalTicks,
      commandStream: replay.commandStream,
    );
    if (!core.gameOver) core.giveUp();
    final ended = result.runEnded ?? latestRunEndedEvent(core.drainEvents());
    simulation.stop();
    if (ended == null) throw StateError('Missing replay end');
    final outcome = jsonEncode([
      result.ticksExecuted,
      ended.tick,
      ended.reason.name,
      ended.distance,
      ended.goldEarned,
      ended.stats.collectibles,
      ended.stats.collectibleScore,
      ended.stats.enemyKillCounts,
      ended.stats.rescuedNpcs,
      ended.stats.rescuePoints,
      core.buildSnapshot().stagedTerrainRenderSnapshot?.geometryVersion,
    ]);
    baselineOutcome ??= outcome;
    if (outcome != baselineOutcome)
      throw StateError('$mode differs from eager replay');
    if (mode == 'capture') {
      File('${directory.path}/manifest.json')
          .writeAsStringSync(TerrainGraphArtifactManifest(entries).encode());
      continue;
    }
    stdout.writeln(
      jsonEncode({
        'mode': mode,
        'level': replay.levelId,
        'seed': replay.seed,
        'tickHz': replay.tickHz,
        'totalTicks': replay.totalTicks,
        'decodeMs': decode.elapsedMicroseconds / 1000,
        'constructionMs': construction.elapsedMicroseconds / 1000,
        'simulationMs': simulation.elapsedMicroseconds / 1000,
        'graphHits': (store?.hits ?? 0) - hitsBefore,
        'graphMisses': (store?.misses ?? 0) - missesBefore,
        'cacheBytes': store?.cachedBytes,
        'processRssBytes': ProcessInfo.currentRss,
        'exactOutcomeParity': outcome == baselineOutcome,
        'outcome': jsonDecode(outcome),
      }),
    );
  }
}
