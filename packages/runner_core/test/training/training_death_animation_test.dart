import 'package:runner_core/commands/command.dart';
import 'package:runner_core/ecs/stores/combat/equipped_loadout_store.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/events/game_event.dart';
import 'package:runner_core/game_core.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:runner_core/players/player_tuning.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/training/authored_training_field.dart';
import 'package:test/test.dart';

void main() {
  for (final character in PlayerCharacterRegistry.playable) {
    test('${character.id.name} completes grounded death before game over', () {
      final core = GameCore.trainingField(
        definition: trainingFieldDefinition,
        playerCharacter: character.copyWith(
          tuning: character.tuning.copyWith(
            resource: const ResourceTuning(
              playerHpMax: 1,
              playerHpRegenPerSecond: 0,
            ),
          ),
        ),
        equippedLoadout: const EquippedLoadoutDef(),
      );
      core.selectTrainingEnemy(EnemyId.grojib);
      for (var i = 0; i < 1200 && core.buildSnapshot().hud.hp > 0; i++) {
        core.applyCommands([
          MoveAxisCommand(
            tick: core.tick + 1,
            axis: core.playerPosX < 850 ? 1 : 0,
          ),
        ]);
        core.stepOneTick();
      }
      expect(core.buildSnapshot().hud.hp, 0);
      expect(core.gameOver, isFalse);
      expect(core.drainEvents().whereType<RunEndedEvent>(), isEmpty);

      final frames = character.renderAnim.frameCountsByKey[AnimKey.death]!;
      final ticksPerFrame =
          (character.renderAnim.stepTimeSecondsByKey[AnimKey.death]! *
                  core.tickHz)
              .round();
      final deathTick = core.tick;
      final deathPosition = core.buildSnapshot().playerEntity!.pos;
      for (var elapsed = 0; elapsed < frames * ticksPerFrame; elapsed++) {
        core.stepOneTick();
        final snapshot = core.buildSnapshot();
        expect(snapshot.playerEntity!.anim, AnimKey.death);
        expect(snapshot.playerEntity!.animFrame, elapsed);
        expect(snapshot.playerEntity!.pos, deathPosition);
        expect(snapshot.gameOver, elapsed == frames * ticksPerFrame - 1);
        if (elapsed == ticksPerFrame) {
          core.paused = true;
          core.stepOneTick();
          expect(core.tick, deathTick + elapsed + 1);
          core.paused = false;
        }
      }
      expect(
        core.drainEvents().whereType<RunEndedEvent>().single.reason,
        RunEndReason.playerDied,
      );
      expect(core.paused, isTrue);
    });
  }
}
