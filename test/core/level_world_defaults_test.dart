import 'package:flutter_test/flutter_test.dart';

import 'package:runner_core/levels/level_assembly.dart';
import 'package:runner_core/levels/level_definition.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/levels/level_registry.dart';
import 'package:runner_core/game_core.dart';
import 'package:runner_core/track/chunk_pattern.dart';
import 'package:runner_core/track/chunk_pattern_source.dart';
import '../support/test_level.dart';
import 'package:runner_core/commands/command.dart';
import 'package:runner_core/tuning/core_tuning.dart';
import 'package:runner_core/tuning/track_tuning.dart';

import '../test_tunings.dart';

void main() {
  test('level definition retains its authored ground reference', () {
    final level = LevelDefinition(
      id: LevelId.field,
      chunkPatternSource: defaultChunkPatternSource,
      cameraCenterY: 120,
      groundTopY: 210,
    );

    expect(level.groundTopY, 210);
  });

  test('level definition requires a finite ground reference', () {
    expect(
      () => LevelDefinition(
        id: LevelId.field,
        chunkPatternSource: defaultChunkPatternSource,
        groundTopY: double.nan,
      ),
      throwsA(anyOf(isA<AssertionError>(), isA<ArgumentError>())),
    );
  });

  test(
    'changing level-authored ground/camera values moves snapshot framing',
    () {
      const customGroundTopY = 212.0;
      const customCameraCenterY = 118.0;
      final level = LevelDefinition(
        id: LevelId.field,
        chunkPatternSource: defaultChunkPatternSource,
        cameraCenterY: customCameraCenterY,
        groundTopY: customGroundTopY,
        tuning: CoreTuning(
          camera: noAutoscrollCameraTuning,
          track: TrackTuning(enabled: false),
        ),
      );

      final core = GameCore(
        seed: 7,
        levelDefinition: level,
        playerCharacter: testPlayerCharacter,
      );
      final snapshot = core.buildSnapshot();

      expect(level.groundTopY, customGroundTopY);
      expect(core.playerGrounded, isTrue);
      expect(core.buildTerrainPlayerDebugSnapshot(), isNotNull);
      expect(snapshot.camera.centerY, customCameraCenterY);
    },
  );

  test('visualThemeId changes do not affect collision or geometry framing', () {
    const groundTopY = 214.0;
    const cameraCenterY = 122.0;
    final fieldTheme = LevelDefinition(
      id: LevelId.field,
      chunkPatternSource: defaultChunkPatternSource,
      cameraCenterY: cameraCenterY,
      groundTopY: groundTopY,
      visualThemeId: 'field',
      tuning: const CoreTuning(
        camera: noAutoscrollCameraTuning,
        track: TrackTuning(enabled: false),
      ),
    );
    final forestTheme = LevelDefinition(
      id: LevelId.field,
      chunkPatternSource: defaultChunkPatternSource,
      cameraCenterY: cameraCenterY,
      groundTopY: groundTopY,
      visualThemeId: 'forest',
      tuning: const CoreTuning(
        camera: noAutoscrollCameraTuning,
        track: TrackTuning(enabled: false),
      ),
    );

    final a = GameCore(
      seed: 11,
      levelDefinition: fieldTheme,
      playerCharacter: testPlayerCharacter,
    );
    final b = GameCore(
      seed: 11,
      levelDefinition: forestTheme,
      playerCharacter: testPlayerCharacter,
    );

    const ticks = 60;
    for (var t = 1; t <= ticks; t += 1) {
      final commands = <Command>[MoveAxisCommand(tick: t, axis: 1.0)];
      if (t == 20) commands.add(const JumpPressedCommand(tick: 20));
      a.applyCommands(commands);
      b.applyCommands(commands);
      a.stepOneTick();
      b.stepOneTick();
    }

    final sa = a.buildSnapshot();
    final sb = b.buildSnapshot();
    expect(sa.visualThemeId, 'field');
    expect(sb.visualThemeId, 'forest');
    expect(a.playerPosX, closeTo(b.playerPosX, 1e-9));
    expect(a.playerPosY, closeTo(b.playerPosY, 1e-9));
    expect(a.playerVelX, closeTo(b.playerVelX, 1e-9));
    expect(a.playerVelY, closeTo(b.playerVelY, 1e-9));
    expect(sa.camera.centerY, sb.camera.centerY);
    expect(sa.camera.centerY, cameraCenterY);
  });

  test(
    'level definition keeps assembly as the single scheduling authority',
    () {
      const initialAssembly = LevelAssemblyDefinition(
        loopSegments: true,
        segments: <LevelAssemblySegment>[
          LevelAssemblySegment(
            segmentId: 'forest_run',
            groupId: 'forest_group',
            minChunkCount: 1,
            maxChunkCount: 1,
            requireDistinctChunks: false,
          ),
        ],
      );
      const nextAssembly = LevelAssemblyDefinition(
        loopSegments: true,
        segments: <LevelAssemblySegment>[
          LevelAssemblySegment(
            segmentId: 'none_run',
            groupId: 'none_group',
            minChunkCount: 1,
            maxChunkCount: 1,
            requireDistinctChunks: false,
          ),
        ],
      );
      final level = LevelDefinition(
        id: LevelId.field,
        chunkPatternSource: AssembledChunkPatternSource(
          baseSource: const ChunkPatternListSource(
            easyPatterns: <ChunkPattern>[
              ChunkPattern(
                name: 'forest_chunk',
                assemblyGroupId: 'forest_group',
              ),
              ChunkPattern(name: 'none_chunk', assemblyGroupId: 'none_group'),
            ],
          ),
          assembly: initialAssembly,
        ),
        groundTopY: 224,
      );

      expect(level.assembly?.segments.single.segmentId, 'forest_run');
      expect(
        level.chunkPatternSource
            .selectionFor(seed: 7, chunkIndex: 0, tier: ChunkPatternTier.easy)
            .pattern
            .assemblyGroupId,
        'forest_group',
      );

      final updated = level.copyWith(assembly: nextAssembly);
      expect(updated.assembly?.segments.single.segmentId, 'none_run');
      expect(
        updated.chunkPatternSource
            .selectionFor(seed: 7, chunkIndex: 0, tier: ChunkPatternTier.easy)
            .pattern
            .assemblyGroupId,
        'none_group',
      );
    },
  );
}
