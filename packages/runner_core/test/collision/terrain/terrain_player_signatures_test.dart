import 'dart:convert';
import 'dart:io';

import 'package:runner_core/collision/terrain/terrain_compiler.dart';
import 'package:runner_core/collision/terrain/terrain_numeric.dart';
import 'package:runner_core/collision/terrain/terrain_polygon.dart';
import 'package:runner_core/commands/command.dart';
import 'package:runner_core/game_core.dart';
import 'package:runner_core/levels/level_definition.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/players/characters/eloise.dart';
import 'package:runner_core/players/characters/eloise_wip.dart';
import 'package:runner_core/players/player_character_definition.dart';
import 'package:runner_core/snapshots/terrain_player_debug_snapshot.dart';
import 'package:runner_core/snapshots/terrain_player_signatures.dart';
import 'package:runner_core/track/chunk_pattern_source.dart';
import 'package:runner_core/tuning/core_tuning.dart';
import 'package:runner_core/tuning/track_tuning.dart';
import 'package:test/test.dart';

void main() {
  test(
    'terrain contact and player-run signatures repeat across fresh cores',
    () {
      final first = _runFixture();
      final second = _runFixture();

      expect(
        terrainPlayerContactSignatureV2(first.checkpoints.reversed),
        terrainPlayerContactSignatureV2(first.checkpoints),
      );
      expect(
        terrainPlayerContactSignatureV2(second.checkpoints),
        terrainPlayerContactSignatureV2(first.checkpoints),
      );
      expect(
        terrainPlayerRunSignatureV1(second.run),
        terrainPlayerRunSignatureV1(first.run),
      );
      expect(
        terrainPlayerRunSignatureV1(first.run),
        matches(RegExp(r'^[0-9a-f]{64}$')),
      );
      expect(
        terrainPlayerContactSignatureV2(first.checkpoints),
        _golden('slopes_golden_contacts_v2.sha256'),
      );
      expect(
        terrainPlayerRunSignatureV1(first.run),
        _golden('slopes_golden_player_run_v1.sha256'),
      );
    },
  );

  test('player-run signatures repeat for both Phase 2 player definitions', () {
    for (final fixture in <(String, PlayerCharacterDefinition)>[
      ('eloise', eloiseCharacter),
      ('eloise-wip', eloiseWipCharacter),
    ]) {
      final first = _runFixture(characterId: fixture.$1, character: fixture.$2);
      final second = _runFixture(
        characterId: fixture.$1,
        character: fixture.$2,
      );
      expect(
        terrainPlayerContactSignatureV2(second.checkpoints),
        terrainPlayerContactSignatureV2(first.checkpoints),
        reason: fixture.$1,
      );
      expect(
        terrainPlayerRunSignatureV1(second.run),
        terrainPlayerRunSignatureV1(first.run),
        reason: fixture.$1,
      );
    }
  });

  test(
    'ordered quantized commands participate in the player-run signature',
    () {
      final fixture = _runFixture();
      final changed = TerrainPlayerRunSignatureInput(
        seed: fixture.run.seed,
        characterId: fixture.run.characterId,
        commands: [
          ...fixture.run.commands.take(fixture.run.commands.length - 1),
          const TerrainPlayerCommandSignatureRecord(
            tick: 60,
            kind: 'move-axis-bp',
            value0: -10000,
          ),
        ],
        contactCheckpoints: fixture.run.contactCheckpoints,
        finalTick: fixture.run.finalTick,
        finalBodyXTicks: fixture.run.finalBodyXTicks,
        finalBodyYTicks: fixture.run.finalBodyYTicks,
        finalVelocityXTicks: fixture.run.finalVelocityXTicks,
        finalVelocityYTicks: fixture.run.finalVelocityYTicks,
        finalHealth100: fixture.run.finalHealth100,
        finalMana100: fixture.run.finalMana100,
        finalStamina100: fixture.run.finalStamina100,
        distanceXTicks: fixture.run.distanceXTicks,
        score: fixture.run.score,
        eventCodes: fixture.run.eventCodes,
        runEndReason: fixture.run.runEndReason,
        rngState: fixture.run.rngState,
      );

      expect(
        terrainPlayerRunSignatureV1(changed),
        isNot(terrainPlayerRunSignatureV1(fixture.run)),
      );
    },
  );

  test('phase 2 signatures repeat in fresh Dart processes', () {
    Map<String, dynamic> runTool() {
      final process = Process.runSync(Platform.resolvedExecutable, [
        'run',
        'tool/update_slopes_goldens.dart',
        '--print',
      ], workingDirectory: Directory.current.path);
      expect(process.exitCode, 0, reason: process.stderr.toString());
      return jsonDecode(process.stdout.toString()) as Map<String, dynamic>;
    }

    final first = runTool();
    final second = runTool();
    for (final key in const [
      'slopes_golden_contacts_v2.sha256',
      'slopes_golden_player_run_v1.sha256',
    ]) {
      expect(second[key], first[key], reason: key);
      expect(first[key], _golden(key), reason: key);
    }
  });
}

({
  List<TerrainPlayerDebugSnapshot> checkpoints,
  TerrainPlayerRunSignatureInput run,
})
_runFixture({
  String characterId = 'eloise',
  PlayerCharacterDefinition character = eloiseCharacter,
}) {
  const seed = 0x5A17;
  final core = GameCore.terrainMotionHarness(
    seed: seed,
    levelDefinition: _level,
    playerCharacter: character,
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
  final snapshot = core.buildSnapshot();
  final hud = snapshot.hud;
  return (
    checkpoints: checkpoints,
    run: TerrainPlayerRunSignatureInput(
      seed: seed,
      characterId: characterId,
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
    ),
  );
}

final LevelDefinition _level = LevelDefinition(
  id: LevelId.field,
  chunkPatternSource: const ChunkPatternListSource(easyPatterns: []),
  groundTopY: 700,
  tuning: const CoreTuning(track: TrackTuning(enabled: false)),
  killPlaneY: 1000,
);

String _golden(String name) =>
    File('test/fixtures/goldens/$name').readAsStringSync().trim();
