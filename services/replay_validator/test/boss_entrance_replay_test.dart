import 'package:run_protocol/replay_blob.dart';
import 'package:runner_core/bosses/boss_arena_definition.dart';
import 'package:runner_core/collision/terrain/terrain_numeric.dart';
import 'package:runner_core/commands/command.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/game_core.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/levels/level_registry.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:runner_core/snapshots/boss_arena_snapshot.dart';
import 'package:runner_core/track/chunk_pattern.dart';
import 'package:runner_core/track/chunk_pattern_source.dart';
import 'package:test/test.dart';

import '../lib/src/replay_simulation.dart';

void main() {
  for (final hz in [30, 60, 90]) {
    test('quarter-chunk stop and airborne landing replay at $hz Hz', () {
      final direct = _core(hz), replay = _core(hz);
      final frames = <ReplayCommandFrameV1>[];
      double? heldY;
      var landed = false;
      for (var n = 0; n < hz * 3; n++) {
        final tick = direct.tick + 1;
        frames.add(
          ReplayCommandFrameV1(
            tick: tick,
            moveAxis: 1,
            pressedMask: ReplayCommandFrameV1.pressedJumpBit,
          ),
        );
        direct.applyCommands([
          MoveAxisCommand(tick: tick, axis: 1),
          JumpPressedCommand(tick: tick),
        ]);
        direct.stepOneTick();
        if (direct.buildSnapshot().bossArena?.playerHeld != true) continue;
        expect(
          direct.buildTerrainPlayerDebugSnapshot()!.capsuleCenterXTicks,
          150 * terrainPhysicsTicksPerWorldUnit,
        );
        if (heldY == null) {
          expect(direct.playerGrounded, isFalse);
          heldY = direct.playerPosY;
        }
        if (direct.playerGrounded) {
          expect(direct.playerPosY, greaterThan(heldY));
          landed = true;
          break;
        }
      }
      expect(landed, isTrue);
      final result = runReplaySimulation(
        core: replay,
        totalTicks: direct.tick,
        commandStream: frames,
      );
      expect(result.runEnded, isNull);
      expect(replay.playerPosX, direct.playerPosX);
      expect(replay.playerPosY, direct.playerPosY);
      expect(replay.playerGrounded, isTrue);
      expect(
        replay.buildSnapshot().bossArena?.phase,
        BossArenaPhase.introduction,
      );
    });
  }
}

GameCore _core(int hz) {
  final level = LevelRegistry.byId(LevelId.field);
  return GameCore(
    seed: 7,
    tickHz: hz,
    playerCharacter: PlayerCharacterRegistry.eloise,
    levelDefinition: level.copyWith(
      tuning: level.tuning.copyWith(
        track: level.tuning.track.copyWith(playerStartX: 120),
      ),
      noEnemyChunks: 0,
      earlyPatternChunks: 0,
      clearAssembly: true,
      clearFirstChunkKey: true,
      chunkPatternSource: ChunkPatternListSource(
        easyPatterns: const [],
        normalPatterns: [
          ChunkPattern(
            name: 'field_default_normal_001',
            chunkKey: 'field_default_normal_001',
            bossArena: BossArenaDefinition(
              id: 'replay_entrance',
              enemyId: EnemyId.bringerOfDeath,
              spawnX: 440,
              minX: 24,
              maxX: 576,
            ),
          ),
        ],
      ),
    ),
  );
}
