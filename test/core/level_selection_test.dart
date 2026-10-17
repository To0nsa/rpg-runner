import 'package:flutter_test/flutter_test.dart';

import 'package:runner_core/commands/command.dart';
import 'package:runner_core/game_core.dart';
import 'package:runner_core/levels/level_assembly.dart';

import '../support/test_level.dart';

import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/levels/level_registry.dart';
import 'package:runner_core/track/chunk_pattern.dart';
import 'package:runner_core/track/chunk_pattern_source.dart';
import 'package:runner_core/track/connected_chunk_pattern_source.dart';
import 'package:runner_core/track/staged_authored_terrain.dart';
import 'package:runner_core/track/staged_terrain_catalog.dart';
import 'package:runner_core/tuning/camera_tuning.dart';
import 'package:runner_core/tuning/core_tuning.dart';
import 'package:runner_core/tuning/track_tuning.dart';

String _snapshotSignature(GameCore core) {
  final s = core.buildSnapshot();
  return <String>[
    '${s.tick}',
    s.levelIdentity.value,
    '${s.visualThemeId}',
    s.distance.toStringAsFixed(6),
    s.camera.centerX.toStringAsFixed(6),
    s.camera.centerY.toStringAsFixed(6),
    s.hud.hp.toStringAsFixed(6),
    s.hud.mana.toStringAsFixed(6),
    s.hud.stamina.toStringAsFixed(6),
    '${s.entities.length}',
  ].join('|');
}

void _runDeterministicLevelScript(GameCore a, GameCore b) {
  const ticks = 120;
  for (var step = 1; step <= ticks; step += 1) {
    expect(a.tick, b.tick);
    expect(a.gameOver, b.gameOver);
    if (a.gameOver) break;

    final t = a.tick + 1;
    final cmds = <Command>[];
    cmds.add(MoveAxisCommand(tick: t, axis: t <= 60 ? 1.0 : -1.0));
    if (t == 12) cmds.add(const JumpPressedCommand(tick: 12));
    if (t == 40) cmds.add(const DashPressedCommand(tick: 40));

    a.applyCommands(cmds);
    a.stepOneTick();
    b.applyCommands(cmds);
    b.stepOneTick();
    expect(_snapshotSignature(a), _snapshotSignature(b));
  }
}

void main() {
  test('levelDefinition selection sets snapshot levelId + visualThemeId', () {
    final forestLevel = LevelRegistry.byId(LevelId.forest);
    final forest = GameCore(
      seed: 1,
      levelDefinition: forestLevel,
      playerCharacter: testPlayerCharacter,
    ).buildSnapshot();
    expect(forest.levelIdentity.requireRegisteredId(), LevelId.forest);
    expect(forest.visualThemeId, 'forest');
    expect(forest.camera.centerY, forestLevel.cameraCenterY);
    expect(forest.stagedTerrainRenderSnapshot, isNotNull);

    final fieldLevel = LevelRegistry.byId(LevelId.field);
    final field = GameCore(
      seed: 1,
      levelDefinition: fieldLevel,
      playerCharacter: testPlayerCharacter,
    ).buildSnapshot();
    expect(field.levelIdentity.requireRegisteredId(), LevelId.field);
    expect(field.visualThemeId, 'field');
    expect(field.camera.centerY, fieldLevel.cameraCenterY);
    expect(field.stagedTerrainRenderSnapshot, isNotNull);
  });

  test('field level baseline remains deterministic', () {
    final a = GameCore(
      seed: 99,
      levelDefinition: LevelRegistry.byId(LevelId.field),
      playerCharacter: testPlayerCharacter,
    );
    final b = GameCore(
      seed: 99,
      levelDefinition: LevelRegistry.byId(LevelId.field),
      playerCharacter: testPlayerCharacter,
    );
    _runDeterministicLevelScript(a, b);
  });

  test('forest level baseline remains deterministic', () {
    final a = GameCore(
      seed: 99,
      levelDefinition: LevelRegistry.byId(LevelId.forest),
      playerCharacter: testPlayerCharacter,
    );
    final b = GameCore(
      seed: 99,
      levelDefinition: LevelRegistry.byId(LevelId.forest),
      playerCharacter: testPlayerCharacter,
    );
    _runDeterministicLevelScript(a, b);
  });

  test('field loops an early chunk and nine distinct easy chunks at 224', () {
    final level = LevelRegistry.byId(LevelId.field);
    expect(level.groundTopY, 224);
    expect(level.noEnemyChunks, 3);
    expect(level.assembly!.loopSegments, isTrue);
    final source = ConnectedChunkPatternSource.forLevel(
      level: level,
      catalog: StagedTerrainArtifactCatalog(artifact: stagedAuthoredTerrain),
    );
    for (final seed in [7, 42, 2026]) {
      final keys = [
        for (var index = 0; index < 20; index++)
          source.explainSelection(seed: seed, chunkIndex: index).chunk.chunkKey,
      ];
      for (final offset in [0, 10]) {
        expect(keys[offset], 'field_default_early_001');
        expect(keys.sublist(offset + 1, offset + 10).toSet(), {
          for (var i = 1; i <= 9; i++) 'field_default_easy_00$i',
        });
      }
    }
  });

  test(
    'snapshot visualThemeId remains level-scoped with authored assembly',
    () {
      final level = LevelRegistry.byId(LevelId.field).copyWith(
        tuning: const CoreTuning(camera: CameraTuning(), track: TrackTuning()),
        chunkPatternSource: const ChunkPatternListSource(
          easyPatterns: <ChunkPattern>[
            ChunkPattern(
              name: 'field_default_easy_004',
              chunkKey: 'field_default_easy_004',
            ),
          ],
          hardPatterns: <ChunkPattern>[],
        ),
        clearFirstChunkKey: true,
        earlyPatternChunks: 0,
        easyPatternChunks: 0,
        normalPatternChunks: 0,
        noEnemyChunks: 999,
        assembly: const LevelAssemblyDefinition(
          loopSegments: true,
          segments: <LevelAssemblySegment>[
            LevelAssemblySegment(
              segmentId: 'forest_run',
              groupId: 'default',
              difficulty: ChunkPatternTier.easy,
              minChunkCount: 1,
              maxChunkCount: 1,
              requireDistinctChunks: false,
            ),
            LevelAssemblySegment(
              segmentId: 'none_run',
              groupId: 'default',
              minChunkCount: 1,
              maxChunkCount: 1,
              requireDistinctChunks: false,
            ),
          ],
        ),
      );
      final core = GameCore(
        seed: 7,
        levelDefinition: level,
        playerCharacter: testPlayerCharacter,
      );

      String? forestThemeSeen;
      String? noneThemeSeen;
      for (var tick = 1; tick <= 120; tick += 1) {
        core.applyCommands(<Command>[MoveAxisCommand(tick: tick, axis: 1.0)]);
        core.stepOneTick();
        final snapshot = core.buildSnapshot();
        forestThemeSeen ??= snapshot.visualThemeId == 'forest'
            ? snapshot.visualThemeId
            : null;
        noneThemeSeen ??= snapshot.visualThemeId == 'none'
            ? snapshot.visualThemeId
            : null;
        if (forestThemeSeen != null && noneThemeSeen != null) {
          break;
        }
        expect(snapshot.visualThemeId, level.visualThemeId);
      }

      expect(forestThemeSeen, isNull);
      expect(noneThemeSeen, isNull);
    },
  );
}
