import 'package:flutter_test/flutter_test.dart';

import 'package:walkscape_runner/core/commands/command.dart';
import 'package:walkscape_runner/core/game_core.dart';

String _digest(GameCore core) {
  final s = core.buildSnapshot();
  final parts = <String>[
    't=${s.tick}',
    'dist=${s.distance.toStringAsFixed(6)}',
    'hp=${s.hud.hp.toStringAsFixed(6)}',
    'mana=${s.hud.mana.toStringAsFixed(6)}',
    'stamina=${s.hud.stamina.toStringAsFixed(6)}',
    'solids=${s.staticSolids.length}',
    'ents=${s.entities.length}',
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
      'f=${e.facing.name}',
      'a=${e.anim.name}',
      'g=${e.grounded}',
    ]);
  }

  return parts.join('|');
}

void main() {
  test('same seed + same commands => identical snapshots', () {
    const seed = 42;
    final a = GameCore(seed: seed);
    final b = GameCore(seed: seed);

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
  });
}
