import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/game/game_controller.dart';
import 'package:rpg_runner/ui/haptics/boss_entrance_haptics_binding.dart';
import 'package:rpg_runner/ui/haptics/haptics_cue.dart';
import 'package:rpg_runner/ui/haptics/haptics_service.dart';
import 'package:runner_core/bosses/boss_arena_definition.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/game_core.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/levels/level_registry.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:runner_core/track/chunk_pattern.dart';
import 'package:runner_core/track/chunk_pattern_source.dart';

GameController _controller(int hz) => GameController(
  tickHz: hz,
  core: GameCore(
    seed: 7,
    tickHz: hz,
    playerCharacter: PlayerCharacterRegistry.eloise,
    levelDefinition: LevelRegistry.byId(LevelId.field).copyWith(
      noEnemyChunks: 0,
      earlyPatternChunks: 0,
      clearAssembly: true,
      clearFirstChunkKey: true,
      chunkPatternSource: ChunkPatternListSource(
        easyPatterns: [],
        normalPatterns: [
          ChunkPattern(
            name: 'field_default_normal_001',
            chunkKey: 'field_default_normal_001',
            bossArena: BossArenaDefinition(
              id: 'haptics_boss',
              enemyId: EnemyId.bringerOfDeath,
              spawnX: 440,
              minX: 24,
              maxX: 576,
            ),
          ),
        ],
      ),
    ),
  ),
);

class _Haptics implements UiHaptics {
  final calls = <UiHapticsCue>[];
  @override
  void trigger(UiHapticsCue cue, {UiHapticsIntensity? intensityOverride}) =>
      calls.add(cue);
}

void main() {
  for (final hz in [30, 60, 90]) {
    test(
      'entrance emits three platform cues, pause and teardown are fenced ($hz Hz)',
      () {
        final controller = _controller(hz);
        addTearDown(controller.dispose);
        final haptics = _Haptics();
        final binding = BossEntranceHapticsBinding(
          controller: controller,
          haptics: haptics,
        );
        addTearDown(binding.dispose);
        controller.advanceFrame(2.01 / hz);
        expect(haptics.calls, [UiHapticsCue.bossEntrancePulse]);
        final entrance = controller.snapshot.bossArena!.entrance!;
        expect(entrance.startTick, 2);
        expect(entrance.durationTicks, 10 * (.12 * hz).round());
        controller.setPaused(true);
        for (var n = 0; n < 10; n++) {
          controller.advanceFrame(.1);
        }
        expect(haptics.calls.length, 1);
        controller.setPaused(false);
        while (controller.tick < entrance.startTick + entrance.durationTicks) {
          controller.advanceFrame(1.01 / hz);
        }
        expect(haptics.calls, List.filled(3, UiHapticsCue.bossEntrancePulse));
        expect(controller.snapshot.bossArena!.entrance, isNull);
        binding.dispose();
        controller.advanceFrame(.1);
        expect(haptics.calls.length, 3);
      },
    );
  }
  test('disposing a binding mid entrance cancels later cues', () {
    final controller = _controller(60);
    addTearDown(controller.dispose);
    final haptics = _Haptics();
    final binding = BossEntranceHapticsBinding(
      controller: controller,
      haptics: haptics,
    );
    controller.advanceFrame(.05);
    expect(haptics.calls.length, 1);
    binding.dispose();
    for (var n = 0; n < 15; n++) {
      controller.advanceFrame(.1);
    }
    expect(haptics.calls.length, 1);
  });
}
