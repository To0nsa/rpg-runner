import 'package:runner_core/game_core.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/levels/level_registry.dart';
import 'package:runner_core/players/player_character_definition.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:test/test.dart';

void main() {
  test('GameCore steps headlessly in runner_core package', () {
    final levelDefinition = LevelRegistry.byId(LevelId.field);
    final playerCharacter = PlayerCharacterRegistry.resolve(
      PlayerCharacterId.eloise,
    );
    final core = GameCore(
      seed: 12345,
      levelDefinition: levelDefinition,
      playerCharacter: playerCharacter,
    );

    expect(core.tick, 0);
    core.stepOneTick();
    expect(core.tick, 1);
  });
}
