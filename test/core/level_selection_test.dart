import 'package:flutter_test/flutter_test.dart';

import 'package:runner_core/commands/command.dart';
import 'package:runner_core/game_core.dart';
import 'package:runner_core/levels/level_assembly.dart';
import '../support/test_level.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/levels/level_registry.dart';
import 'package:runner_core/track/chunk_pattern.dart';
import 'package:runner_core/track/chunk_pattern_source.dart';
import 'package:runner_core/tuning/camera_tuning.dart';
import 'package:runner_core/tuning/core_tuning.dart';
import 'package:runner_core/tuning/track_tuning.dart';

String _snapshotSignature(GameCore core) {
  final s = core.buildSnapshot();
  return <String>[
    '${s.tick}',
    s.levelId.name,
    '${s.visualThemeId}',
    s.distance.toStringAsFixed(6),
    s.camera.centerX.toStringAsFixed(6),
    s.camera.centerY.toStringAsFixed(6),
    s.hud.hp.toStringAsFixed(6),
    s.hud.mana.toStringAsFixed(6),
    s.hud.stamina.toStringAsFixed(6),
    '${s.entities.length}',
    '${s.staticSolids.length}',
    '${s.groundSurfaces.length}',
  ].join('|');
}

void _runDeterministicLevelScript(GameCore a, GameCore b) {
  const ticks = 120;
  for (var t = 1; t <= ticks; t += 1) {
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

ChunkPatternTier _tierForLevelChunkIndex(
  int chunkIndex, {
  required int earlyPatternChunks,
  required int easyPatternChunks,
  required int normalPatternChunks,
}) {
  if (chunkIndex < earlyPatternChunks) {
    return ChunkPatternTier.early;
  }
  final easyStart = earlyPatternChunks;
  final normalStart = easyStart + easyPatternChunks;
  final hardStart = normalStart + normalPatternChunks;
  if (chunkIndex < normalStart) {
    return ChunkPatternTier.easy;
  }
  if (chunkIndex < hardStart) {
    return ChunkPatternTier.normal;
  }
  return ChunkPatternTier.hard;
}

void main() {
  test('levelDefinition selection sets snapshot levelId + visualThemeId', () {
    final forestLevel = LevelRegistry.byId(LevelId.forest);
    final forest = GameCore(
      seed: 1,
      levelDefinition: forestLevel,
      playerCharacter: testPlayerCharacter,
    ).buildSnapshot();
    expect(forest.levelId, LevelId.forest);
    expect(forest.visualThemeId, 'forest');
    expect(forest.camera.centerY, forestLevel.cameraCenterY);
    expect(forest.groundSurfaces.first.topY, forestLevel.groundTopY);

    final fieldLevel = LevelRegistry.byId(LevelId.field);
    final field = GameCore(
      seed: 1,
      levelDefinition: fieldLevel,
      playerCharacter: testPlayerCharacter,
    ).buildSnapshot();
    expect(field.levelId, LevelId.field);
    expect(field.visualThemeId, 'field');
    expect(field.camera.centerY, fieldLevel.cameraCenterY);
    expect(field.groundSurfaces.first.topY, fieldLevel.groundTopY);
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

  test(
    'field level authored assembly is generated and drives selection order',
    () {
      final level = LevelRegistry.byId(LevelId.field);
      final assembly = level.assembly;
      expect(assembly, isNotNull);
      expect(
        assembly!.segments.map((segment) => segment.segmentId).toList(),
        <String>['field_run', 'forest_run', 'none_run'],
      );
      expect(
        assembly.segments.map((segment) => segment.groupId).toList(),
        <String>['default', 'forest', 'none'],
      );

      final selections = <ChunkPatternSelection>[
        for (var chunkIndex = 0; chunkIndex < 6; chunkIndex += 1)
          level.chunkPatternSource.selectionFor(
            seed: 7,
            chunkIndex: chunkIndex,
            tier: _tierForLevelChunkIndex(
              chunkIndex,
              earlyPatternChunks: level.earlyPatternChunks,
              easyPatternChunks: level.easyPatternChunks,
              normalPatternChunks: level.normalPatternChunks,
            ),
          ),
      ];

      expect(
        selections
            .map((selection) => selection.pattern.assemblyGroupId)
            .toList(),
        <String>['default', 'default', 'forest', 'none', 'default', 'default'],
      );
    },
  );

  test(
    'snapshot visualThemeId remains level-scoped with authored assembly',
    () {
      final level = LevelRegistry.byId(LevelId.field).copyWith(
        tuning: const CoreTuning(
          camera: CameraTuning(),
          track: TrackTuning(chunkWidth: 301.0),
        ),
        chunkPatternSource: const ChunkPatternListSource(
          earlyPatterns: <ChunkPattern>[
            ChunkPattern(name: 'forest_chunk', assemblyGroupId: 'forest_group'),
            ChunkPattern(name: 'none_chunk', assemblyGroupId: 'none_group'),
          ],
          easyPatterns: <ChunkPattern>[
            ChunkPattern(name: 'forest_chunk', assemblyGroupId: 'forest_group'),
            ChunkPattern(name: 'none_chunk', assemblyGroupId: 'none_group'),
          ],
        ),
        earlyPatternChunks: 999,
        easyPatternChunks: 0,
        normalPatternChunks: 0,
        noEnemyChunks: 999,
        assembly: const LevelAssemblyDefinition(
          loopSegments: true,
          segments: <LevelAssemblySegment>[
            LevelAssemblySegment(
              segmentId: 'forest_run',
              groupId: 'forest_group',
              minChunkCount: 1,
              maxChunkCount: 1,
              requireDistinctChunks: false,
            ),
            LevelAssemblySegment(
              segmentId: 'none_run',
              groupId: 'none_group',
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
