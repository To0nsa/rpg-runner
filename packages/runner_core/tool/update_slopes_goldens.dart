import 'dart:convert';
import 'dart:io';

import 'package:runner_core/collision/terrain/capsule_segment_kernel.dart';
import 'package:runner_core/collision/terrain/terrain_compiler.dart';
import 'package:runner_core/collision/terrain/terrain_edge_index.dart';
import 'package:runner_core/collision/terrain/terrain_numeric.dart';
import 'package:runner_core/collision/terrain/terrain_polygon.dart';
import 'package:runner_core/commands/command.dart';
import 'package:runner_core/game_core.dart';
import 'package:runner_core/levels/level_definition.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/players/characters/eloise.dart';
import 'package:runner_core/snapshots/terrain_player_debug_snapshot.dart';
import 'package:runner_core/snapshots/enemy_terrain_signatures.dart';
import 'package:runner_core/snapshots/terrain_player_signatures.dart';
import 'package:runner_core/track/chunk_pattern_source.dart';
import 'package:runner_core/tuning/core_tuning.dart';
import 'package:runner_core/tuning/track_tuning.dart';

import '../test/fixtures/slopes_golden_fixture.dart';
import '../test/fixtures/enemy_terrain_run_fixture.dart';

void main(List<String> args) {
  final update = args.contains('--update');
  final printOnly = args.contains('--print');
  if (!update && !printOnly) {
    stderr.writeln(
      'Use --print to inspect or --update to rewrite reviewed slopes goldens.',
    );
    exitCode = 64;
    return;
  }

  const compiler = TerrainCompiler();
  final geometry = compiler.compile(
    buildSlopesGoldenInputs(),
    geometryVersion: slopesGoldenGeometryVersion,
  );
  final index = TerrainEdgeIndex(edges: geometry.edges);
  final kernel = CapsuleSegmentKernel();
  final phase2 = _buildPhase2Signatures();
  final phase3 = buildEnemyTerrainRunFixture();
  final values = <String, String>{
    'slopes_golden_source_v1.sha256': geometry.sourceSignature(),
    'slopes_golden_edges_v1.sha256': geometry.edgeSignature(
      indexMembershipRecords: index.canonicalMembershipRecords(),
    ),
    'slopes_golden_contacts_v1.sha256': kernel.contactOrderSignature(
      buildSlopesGoldenContactHits(geometry),
    ),
    'slopes_golden_contacts_v2.sha256': phase2.contacts,
    'slopes_golden_player_run_v1.sha256': phase2.run,
    'slopes_golden_nav_surfaces_v1.sha256': phase3.surfaceSignature,
    'slopes_golden_nav_graphs_v1.sha256': phase3.graphSignature,
    'slopes_golden_enemy_terrain_run_v1.sha256': enemyTerrainRunSignatureV1(
      phase3,
    ),
  };

  if (printOnly) {
    stdout.writeln(jsonEncode(values));
    return;
  }

  final directory = Directory('test/fixtures/goldens')
    ..createSync(recursive: true);
  for (final entry in values.entries) {
    final file = File('${directory.path}/${entry.key}');
    file.writeAsStringSync('${entry.value}\n');
    stdout.writeln('${entry.key}: ${entry.value}');
  }
}

({String contacts, String run}) _buildPhase2Signatures() {
  const seed = 0x5A17;
  final core = GameCore.terrainMotionHarness(
    seed: seed,
    levelDefinition: LevelDefinition(
      id: LevelId.field,
      chunkPatternSource: const ChunkPatternListSource(easyPatterns: []),
      groundTopY: 700,
      tuning: const CoreTuning(track: TrackTuning(enabled: false)),
      killPlaneY: 1000,
    ),
    playerCharacter: eloiseCharacter,
    terrainGeometry: const TerrainCompiler().compile([
      TerrainPolygonInput.fromWorld(
        sourcePath: 'test/signature-slope',
        identity: TerrainSourceIdentity(
          chunkIndex: 0,
          chunkKey: 'test',
          shapeId: 'signature-slope',
        ),
        vertices: [(0, 700), (1000, -300), (1000, 900), (0, 900)],
      ),
    ], geometryVersion: 3),
  );
  final checkpoints = <TerrainPlayerDebugSnapshot>[];
  final commands = <TerrainPlayerCommandSignatureRecord>[];
  for (var tick = 1; tick <= 60; tick += 1) {
    core.applyCommands([MoveAxisCommand(tick: tick, axis: 1)]);
    commands.add(
      TerrainPlayerCommandSignatureRecord(
        tick: tick,
        kind: 'move-axis-bp',
        value0: 10000,
      ),
    );
    core.stepOneTick();
    if (tick == 1 || tick == 30 || tick == 60) {
      checkpoints.add(core.buildTerrainPlayerDebugSnapshot()!);
    }
  }
  final finalDebug = core.buildTerrainPlayerDebugSnapshot()!;
  final hud = core.buildSnapshot().hud;
  final run = TerrainPlayerRunSignatureInput(
    seed: seed,
    characterId: 'eloise',
    commands: commands,
    contactCheckpoints: checkpoints,
    finalTick: core.tick,
    finalBodyXTicks: finalDebug.finalBodyXTicks,
    finalBodyYTicks: finalDebug.finalBodyYTicks,
    finalVelocityXTicks: finalDebug.finalVelocityXTicks,
    finalVelocityYTicks: finalDebug.finalVelocityYTicks,
    finalHealth100: (hud.hp * 100).round(),
    finalMana100: (hud.mana * 100).round(),
    finalStamina100: (hud.stamina * 100).round(),
    distanceXTicks: physicsCoordinateToTicks(core.distance),
    score: 0,
    eventCodes: const [],
    runEndReason: '',
    rngState: seed,
  );
  return (
    contacts: terrainPlayerContactSignatureV2(checkpoints),
    run: terrainPlayerRunSignatureV1(run),
  );
}
