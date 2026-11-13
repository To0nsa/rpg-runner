import 'package:runner_core/commands/command.dart';
import 'package:runner_core/ecs/stores/combat/equipped_loadout_store.dart';
import 'package:runner_core/game_core.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/levels/level_registry.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/training/authored_training_field.dart';
import 'package:runner_core/tuning/camera_tuning.dart';
import 'package:runner_core/tuning/core_tuning.dart';
import 'package:runner_core/tuning/track_tuning.dart';
import 'package:test/test.dart';

void main() {
  for (final character in PlayerCharacterRegistry.playable) {
    for (final hz in [30, 60, 120]) {
      for (final training in [false, true]) {
        for (final moving in [false, true]) {
          final host = training ? 'Training Field' : 'runner';
          final state = moving ? 'movement' : 'idle';
          test(
            '${character.id.name} starts directly in $state in $host at $hz Hz',
            () {
              final core = training
                  ? GameCore.trainingField(
                      definition: trainingFieldDefinition,
                      playerCharacter: character,
                      equippedLoadout: const EquippedLoadoutDef(),
                      tickHz: hz,
                    )
                  : GameCore(
                      seed: 42,
                      tickHz: hz,
                      levelDefinition: LevelRegistry.byId(LevelId.field)
                          .copyWith(
                            tuning: const CoreTuning(
                              camera: CameraTuning(
                                speedLagMulX: 0,
                                followThresholdRatio: 1,
                              ),
                              track: TrackTuning(enabled: false),
                            ),
                          ),
                      playerCharacter: character,
                    );
              addTearDown(core.stopTerrainPreparation);
              final startX = core.playerPosX;
              expect(core.buildSnapshot().playerEntity!.anim, AnimKey.idle);

              for (var tick = 1; tick <= hz; tick++) {
                core.applyCommands([
                  MoveAxisCommand(tick: tick, axis: moving ? 1 : 0),
                ]);
                core.stepOneTick();
                final player = core.buildSnapshot().playerEntity!;
                final hasMoveSpeed =
                    player.vel!.x.abs() >
                    character.tuning.movement.minMoveSpeed;
                expect(
                  player.anim,
                  hasMoveSpeed
                      ? isIn([AnimKey.walk, AnimKey.run])
                      : AnimKey.idle,
                  reason:
                      'tick $tick must reflect current movement immediately',
                );
                if (!moving) {
                  expect(player.pos.x, startX);
                  expect(player.animFrame, tick);
                }
              }
              if (moving) {
                expect(core.playerPosX, greaterThan(startX));
              }
            },
          );
        }
      }
    }
  }
}
