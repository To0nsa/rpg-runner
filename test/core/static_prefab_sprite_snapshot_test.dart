import 'package:flutter_test/flutter_test.dart';

import 'package:runner_core/game_core.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/levels/level_registry.dart';
import 'package:runner_core/players/player_character_registry.dart';

void main() {
  test('field level prewarms static prefab sprite snapshots before startup', () {
    final core = GameCore(
      seed: 42,
      levelDefinition: LevelRegistry.byId(LevelId.field),
      playerCharacter: PlayerCharacterRegistry.eloise,
    );

    final snapshot = core.buildSnapshot();

    expect(snapshot.tick, 0);
    expect(snapshot.staticPrefabSprites, isNotEmpty);
    expect(
      snapshot.staticPrefabSprites.any(
        (sprite) => sprite.assetPath.startsWith('level/'),
      ),
      isTrue,
    );
  });
}
