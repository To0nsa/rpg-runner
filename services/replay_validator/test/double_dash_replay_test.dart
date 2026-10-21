import 'package:test/test.dart';
import 'package:replay_validator/src/replay_simulation.dart';
import 'package:run_protocol/replay_blob.dart';
import 'package:runner_core/commands/command.dart';
import 'package:runner_core/ecs/stores/combat/equipped_loadout_store.dart';
import 'package:runner_core/game_core.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/levels/level_registry.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:runner_core/tuning/camera_tuning.dart';
import 'package:runner_core/tuning/core_tuning.dart';
import 'package:runner_core/tuning/track_tuning.dart';

void main() {
  test(
    'existing dash command frames reproduce follow-ups and rejected taps',
    () {
      final direct = _core();
      final replayed = _core();
      final frames = <ReplayCommandFrameV1>[];
      const presses = {1, 2, 9, 17, 121, 158, 241, 279};
      for (var tick = 1; tick <= 300; tick++) {
        final pressed = presses.contains(tick);
        final axis = tick >= 121 && tick < 241 ? -1.0 : 1.0;
        frames.add(
          ReplayCommandFrameV1.fromJson(
            ReplayCommandFrameV1(
              tick: tick,
              moveAxis: axis,
              pressedMask: pressed ? ReplayCommandFrameV1.pressedDashBit : 0,
            ).toJson(),
          ),
        );
        direct.applyCommands([
          MoveAxisCommand(tick: tick, axis: axis),
          if (pressed) DashPressedCommand(tick: tick),
        ]);
        direct.stepOneTick();
      }
      final result = runReplaySimulation(
        core: replayed,
        totalTicks: 300,
        commandStream: frames,
      );
      expect(result.ticksExecuted, 300);
      expect(result.runEnded, isNull);
      expect(replayed.playerPosX, direct.playerPosX);
      expect(replayed.playerPosY, direct.playerPosY);
      expect(replayed.playerVelX, direct.playerVelX);
      final actual = replayed.buildSnapshot();
      final expected = direct.buildSnapshot();
      expect(actual.hud.stamina, expected.hud.stamina);
      expect(actual.hud.cooldownTicksLeft, expected.hud.cooldownTicksLeft);
      expect(
        actual.hud.mobilityRecastTicksLeft,
        expected.hud.mobilityRecastTicksLeft,
      );
      expect(actual.distance, expected.distance);
    },
  );
}

GameCore _core() => GameCore(
  seed: 98,
  playerCharacter: PlayerCharacterRegistry.eloise,
  equippedLoadoutOverride: const EquippedLoadoutDef(
    abilityMobilityId: 'eloise.double_dash',
  ),
  levelDefinition: LevelRegistry.byId(LevelId.field).copyWith(
    tuning: const CoreTuning(
      camera: CameraTuning(speedLagMulX: 0, followThresholdRatio: 1),
      track: TrackTuning(enabled: false),
    ),
  ),
);
