import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:runner_core/contracts/render_contract.dart' show virtualWidth;
import 'package:runner_core/enemies/enemy_catalog.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/levels/level_registry.dart';
import 'package:runner_core/navigation/actor_navigation_profiles.dart';
import 'package:runner_core/navigation/terrain_graph_artifact.dart';
import 'package:runner_core/navigation/terrain_graph_artifact_manifest.dart';
import 'package:runner_core/navigation/terrain_graph_materializer.dart';
import 'package:runner_core/navigation/terrain_graph_artifact_revision.dart';

import 'update_navigation_revision.dart'
    show requireCurrentNavigationBuildRevision;

import 'package:runner_core/track/connected_chunk_pattern_source.dart';
import 'package:runner_core/track/staged_authored_terrain.dart';
import 'package:runner_core/track/staged_terrain_catalog.dart';
import 'package:runner_core/track/staged_terrain_stream_candidate.dart';
import 'package:runner_core/track/track_streamer.dart';

/// Offline release producer. Run with the app or independent worker package
/// config. Existing exact-key files are validated and reused, never overwritten
/// with unverified bytes. The manifest is published only after all routes finish.
void main(List<String> args) {
  requireCurrentNavigationBuildRevision(terrainGraphArtifactBuildRevision);
  String? option(String name) {
    final values = args.where((arg) => arg.startsWith('--$name='));
    return values.isEmpty ? null : values.single.substring(name.length + 3);
  }

  final planFile = File(
    option('plan') ?? 'functions/src/runs/navigation_routes.json',
  );
  final planText = planFile.readAsStringSync();
  final plan = jsonDecode(planText) as Map<String, dynamic>;
  if (plan['version'] != 1) {
    throw const FormatException('Unsupported route plan.');
  }
  final client = args.contains('--client');
  final horizon = int.parse(
    option('chunks') ??
        '${plan[client ? 'clientHorizonChunks' : 'horizonChunks']}',
  );
  final tickHz = plan['tickHz'] as int;
  if (horizon < 4 || horizon > 512 || tickHz <= 0) {
    throw const FormatException('Invalid navigation preparation horizon/rate.');
  }
  final output = Directory(option('output') ?? 'assets/navigation')
    ..createSync(recursive: true);
  final manifestFile = File('${output.path}/manifest.json');
  final previous = manifestFile.existsSync()
      ? TerrainGraphArtifactManifest.decode(manifestFile.readAsStringSync())
            .entries
      : <String, TerrainGraphArtifactEntry>{};
  final entries = <String, TerrainGraphArtifactEntry>{};
  final catalog = StagedTerrainArtifactCatalog(artifact: stagedAuthoredTerrain);
  final routes = <({String level, int seed})>[
    for (final entry in (plan['practiceSeeds'] as Map<String, dynamic>).entries)
      for (final seed in (entry.value as List).take(
        int.tryParse(option('seed-count') ?? '') ??
            (entry.value as List).length,
      ))
        (level: entry.key, seed: seed as int),
    if (option('seed-count') == null)
      for (final route in plan['additionalRoutes'] as List)
        (level: route['levelId'] as String, seed: route['seed'] as int),
  ];
  var built = 0;
  var reused = 0;
  var windows = 0;
  final started = Stopwatch()..start();
  for (final route in routes) {
    final level = LevelRegistry.byId(LevelId.values.byName(route.level));
    final profiles = buildActorNavigationProfiles(
      enemyCatalog: const EnemyCatalog(),
      locomotion: level.tuning.groundEnemy.locomotion,
      physics: level.tuning.physics,
      tickHz: tickHz,
    );
    final streamer = TrackStreamer(
      seed: route.seed,
      tuning: level.tuning.track,
      groundTopY: level.groundTopY,
      patternSource: ConnectedChunkPatternSource.forLevel(
        level: level,
        catalog: catalog,
      ),
      earlyPatternChunks: level.earlyPatternChunks,
      easyPatternChunks: level.easyPatternChunks,
      normalPatternChunks: level.normalPatternChunks,
      noEnemyChunks: level.noEnemyChunks,
    );
    streamer.step(
      cameraLeft: 0,
      cameraRight: virtualWidth.toDouble(),
      spawnEnemy: (_) {},
    );
    final selections = [
      streamer.activeChunks,
      ...streamer.upcomingSelections(
        viewWidth: virtualWidth.toDouble(),
        count: horizon * 3,
      ),
    ];
    for (final selection in selections) {
      if (selection.isEmpty || selection.last.index >= horizon) continue;
      final candidate = const StagedTerrainStreamCandidateBuilder().build(
        catalog: catalog,
        activeChunks: selection,
        geometryVersion: 0,
        groundEnemyProfiles: profiles,
        graphMaterializer: const TerrainGraphMaterializer.onDemand(),
      );
      windows++;
      for (final profile in profiles) {
        final bundle = candidate.runtimeBundle;
        final key = terrainGraphArtifactKey(
          geometry: bundle.geometry,
          surfaces: bundle.surfaceSet,
          profile: profile,
        );
        if (entries.containsKey(key)) continue;
        final file = File('${output.path}/$key.rng');
        final old = previous[key];
        if (old != null &&
            file.existsSync() &&
            file.lengthSync() == old.bytes) {
          try {
            TerrainGraphArtifactCodec.decode(
              bytes: file.readAsBytesSync(),
              expectedSha256: old.sha256,
              key: key,
              surfaces: bundle.surfaceSet,
              profile: profile,
            );
            entries[key] = old;
            reused++;
            continue;
          } on FormatException {
            /* Rebuild incomplete/corrupt local artifacts. */
          } on ArgumentError {
            /* Invalid graph records also use the deterministic builder. */
          }
        }
        final bytes = TerrainGraphArtifactCodec.encode(
          key: key,
          graph: bundle.graphPublication[profile.profileKey],
        );
        file.writeAsBytesSync(bytes, flush: true);
        entries[key] = TerrainGraphArtifactEntry(
          sha256: sha256.convert(bytes).toString(),
          bytes: bytes.length,
        );
        built++;
      }
    }
    stdout.writeln(
      jsonEncode({
        'level': route.level,
        'seed': route.seed,
        'windows': windows,
        'graphs': entries.length,
        'built': built,
        'reused': reused,
        'seconds': started.elapsedMilliseconds / 1000,
      }),
    );
  }
  final manifest = TerrainGraphArtifactManifest(entries).encode();
  File('${output.path}/manifest.json.tmp')
      .writeAsStringSync(manifest, flush: true);
  File('${output.path}/manifest.json.tmp').renameSync(manifestFile.path);
  // Only remove this producer's obsolete flat artifact files after publication.
  // Never traverse subdirectories or follow links in an operator-owned output.
  final generatedName = RegExp(r'^[0-9a-f]{64}\.rng$');
  for (final entity in output.listSync(followLinks: false)) {
    if (entity is! File) continue;
    final name = entity.uri.pathSegments.last;
    if (generatedName.hasMatch(name) &&
        !entries.containsKey(name.substring(0, 64))) {
      entity.deleteSync();
    }
  }
  File('${output.path}/preparation.json').writeAsStringSync(
    jsonEncode({
      'planSha256': sha256.convert(utf8.encode(planText)).toString(),
      'horizonChunks': horizon,
      'tickHz': tickHz,
      'routeCount': routes.length,
      'selectionPolicy': 'forward-camera-with-deterministic-fallback',
      'viewWidth': virtualWidth,
      'graphs': entries.length,
      'bytes': entries.values.fold<int>(0, (sum, value) => sum + value.bytes),
      'manifestSha256': sha256.convert(utf8.encode(manifest)).toString(),
    }),
  );
}
