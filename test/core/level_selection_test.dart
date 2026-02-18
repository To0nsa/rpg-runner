import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_runner/core/commands/command.dart';
import 'package:rpg_runner/core/game_core.dart';
import '../support/test_level.dart';
import 'package:rpg_runner/core/levels/level_id.dart';
import 'package:rpg_runner/core/levels/level_registry.dart';

String _snapshotSignature(GameCore core) {
  final s = core.buildSnapshot();
  return <String>[
    '${s.tick}',
    s.levelId.name,
    '${s.themeId}',
    s.distance.toStringAsFixed(6),
    s.camera.centerX.toStringAsFixed(6),
    s.camera.centerY.toStringAsFixed(6),
    s.hud.hp.toStringAsFixed(6),
    s.hud.mana.toStringAsFixed(6),
    s.hud.stamina.toStringAsFixed(6),
    '${s.entities.length}',
    '${s.staticSolids.length}',
    '${s.groundSurfaces.length}',
  ].join('|');
}

void _runDeterministicLevelScript(GameCore a, GameCore b) {
  const ticks = 120;
  for (var t = 1; t <= ticks; t += 1) {
    final cmds = <Command>[];
    cmds.add(MoveAxisCommand(tick: t, axis: t <= 60 ? 1.0 : -1.0));
    if (t == 12) cmds.add(const JumpPressedCommand(tick: 12));
    if (t == 40) cmds.add(const DashPressedCommand(tick: 40));

    a.applyCommands(cmds);
    a.stepOneTick();
    b.applyCommands(cmds);
    b.stepOneTick();
    expect(_snapshotSignature(a), _snapshotSignature(b));
  }
}

void main() {
  test('levelDefinition selection sets snapshot levelId + themeId', () {
    final forestLevel = LevelRegistry.byId(LevelId.forest);
    final forest = GameCore(
      seed: 1,
      levelDefinition: forestLevel,
      playerCharacter: testPlayerCharacter,
    ).buildSnapshot();
    expect(forest.levelId, LevelId.forest);
    expect(forest.themeId, 'forest');
    expect(forest.camera.centerY, forestLevel.cameraCenterY);
    expect(forest.groundSurfaces.first.topY, forestLevel.groundTopY);

    final fieldLevel = LevelRegistry.byId(LevelId.field);
    final field = GameCore(
      seed: 1,
      levelDefinition: fieldLevel,
      playerCharacter: testPlayerCharacter,
    ).buildSnapshot();
    expect(field.levelId, LevelId.field);
    expect(field.themeId, 'field');
    expect(field.camera.centerY, fieldLevel.cameraCenterY);
    expect(field.groundSurfaces.first.topY, fieldLevel.groundTopY);
  });

  test('field level baseline remains deterministic', () {
    final a = GameCore(
      seed: 99,
      levelDefinition: LevelRegistry.byId(LevelId.field),
      playerCharacter: testPlayerCharacter,
    );
    final b = GameCore(
      seed: 99,
      levelDefinition: LevelRegistry.byId(LevelId.field),
      playerCharacter: testPlayerCharacter,
    );
    _runDeterministicLevelScript(a, b);
  });

  test('forest level baseline remains deterministic', () {
    final a = GameCore(
      seed: 99,
      levelDefinition: LevelRegistry.byId(LevelId.forest),
      playerCharacter: testPlayerCharacter,
    );
    final b = GameCore(
      seed: 99,
      levelDefinition: LevelRegistry.byId(LevelId.forest),
      playerCharacter: testPlayerCharacter,
    );
    _runDeterministicLevelScript(a, b);
  });
}
