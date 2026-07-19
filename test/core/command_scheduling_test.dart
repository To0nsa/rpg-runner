import 'package:flutter_test/flutter_test.dart';

import 'package:runner_core/commands/command.dart';
import 'package:runner_core/game_core.dart';
import 'package:runner_core/players/player_character_registry.dart';

import '../support/test_level.dart';
import '../test_tunings.dart';

void main() {
  GameCore createCore() => GameCore(
    seed: 1,
    levelDefinition: testFieldLevel(tuning: noAutoscrollTuning),
    playerCharacter: PlayerCharacterRegistry.eloise,
  );

  test('applies commands only for the next simulation tick', () {
    final core = createCore();

    core.applyCommands(const <Command>[MoveAxisCommand(tick: 1, axis: 1)]);
    core.stepOneTick();

    expect(core.tick, 1);
    expect(core.playerVelX, greaterThan(0));
  });

  test(
    'rejects stale and future commands without mutating tick input state',
    () {
      final core = createCore();

      expect(
        () => core.applyCommands(const <Command>[
          MoveAxisCommand(tick: 0, axis: 1),
        ]),
        throwsArgumentError,
      );
      expect(
        () => core.applyCommands(const <Command>[
          MoveAxisCommand(tick: 2, axis: 1),
        ]),
        throwsArgumentError,
      );

      core.applyCommands(const <Command>[]);
      core.stepOneTick();

      expect(core.playerVelX, 0);
    },
  );
}
