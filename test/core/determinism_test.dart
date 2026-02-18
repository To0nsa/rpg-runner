import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_runner/core/commands/command.dart';
import 'package:rpg_runner/core/game_core.dart';
import '../support/test_level.dart';
import 'package:rpg_runner/core/levels/level_definition.dart';
import 'package:rpg_runner/core/levels/level_id.dart';
import 'package:rpg_runner/core/levels/level_registry.dart';

String _digest(GameCore core) {
  final s = core.buildSnapshot();
  final parts = <String>[
    't=${s.tick}',
    'dist=${s.distance.toStringAsFixed(6)}',
    'camx=${s.camera.centerX.toStringAsFixed(6)}',
    'camy=${s.camera.centerY.toStringAsFixed(6)}',
    'level=${s.levelId.name}',
    'theme=${s.themeId}',
    'hp=${s.hud.hp.toStringAsFixed(6)}',
    'mana=${s.hud.mana.toStringAsFixed(6)}',
    'stamina=${s.hud.stamina.toStringAsFixed(6)}',
    'collectibles=${s.hud.collectibles}',
    'collectibleScore=${s.hud.collectibleScore}',
    'solids=${s.staticSolids.length}',
    'groundSurfaces=${s.groundSurfaces.length}',
    'ents=${s.entities.length}',
    'paused=${s.paused}',
    'gameOver=${s.gameOver}',
  ];

  for (final e in s.entities) {
    parts.addAll([
      'id=${e.id}',
      'k=${e.kind.name}',
      'px=${e.pos.x.toStringAsFixed(6)}',
      'py=${e.pos.y.toStringAsFixed(6)}',
      if (e.vel != null) 'vx=${e.vel!.x.toStringAsFixed(6)}',
      if (e.vel != null) 'vy=${e.vel!.y.toStringAsFixed(6)}',
      if (e.size != null) 'sx=${e.size!.x.toStringAsFixed(6)}',
      if (e.size != null) 'sy=${e.size!.y.toStringAsFixed(6)}',
      if (e.projectileId != null) 'pid=${e.projectileId!.name}',
      'rot=${e.rotationRad.toStringAsFixed(6)}',
      'f=${e.facing.name}',
      'a=${e.anim.name}',
      'g=${e.grounded}',
    ]);
  }

  return parts.join('|');
}

void main() {
  void runDeterminismScenario({
    required int seed,
    required LevelDefinition level,
  }) {
    final a = GameCore(
      seed: seed,
      levelDefinition: level,
      playerCharacter: testPlayerCharacter,
    );
    final b = GameCore(
      seed: seed,
      levelDefinition: level,
      playerCharacter: testPlayerCharacter,
    );
    // Deterministic command schedule. Note that MoveAxis must be sent each tick
    // while held because Core resets tick inputs before applying commands.
    const ticks = 240;
    for (var t = 1; t <= ticks; t += 1) {
      final cmds = <Command>[];

      final axis = (t <= 120) ? 1.0 : -1.0;
      cmds.add(MoveAxisCommand(tick: t, axis: axis));

      if (t == 10) cmds.add(const JumpPressedCommand(tick: 10));
      if (t == 60) cmds.add(const DashPressedCommand(tick: 60));

      a.applyCommands(cmds);
      a.stepOneTick();
      b.applyCommands(cmds);
      b.stepOneTick();

      expect(_digest(a), _digest(b));
    }
  }

  test('same seed + same commands => identical snapshots (field)', () {
    runDeterminismScenario(seed: 42, level: LevelRegistry.byId(LevelId.field));
  });

  test('same seed + same commands => identical snapshots (forest)', () {
    runDeterminismScenario(seed: 42, level: LevelRegistry.byId(LevelId.forest));
  });
}
