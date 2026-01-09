import 'package:flutter_test/flutter_test.dart';

import 'package:walkscape_runner/core/game_core.dart';
import 'package:walkscape_runner/core/levels/level_id.dart';
import 'package:walkscape_runner/core/levels/level_registry.dart';

void main() {
  test('levelDefinition selection sets snapshot levelId + themeId', () {
    final forest = GameCore(
      seed: 1,
      levelDefinition: LevelRegistry.byId(LevelId.forest),
    ).buildSnapshot();
    expect(forest.levelId, LevelId.forest);
    expect(forest.themeId, 'forest');

    final field = GameCore(
      seed: 1,
      levelDefinition: LevelRegistry.byId(LevelId.field),
    ).buildSnapshot();
    expect(field.levelId, LevelId.field);
    expect(field.themeId, 'field');

    final defaultLevel = GameCore(
      seed: 1,
      levelDefinition: LevelRegistry.byId(LevelId.defaultLevel),
    ).buildSnapshot();
    expect(defaultLevel.levelId, LevelId.defaultLevel);
    expect(defaultLevel.themeId, 'forest');
  });
}

