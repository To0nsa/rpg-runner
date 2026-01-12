import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_runner/core/commands/command.dart';
import 'package:rpg_runner/core/ecs/stores/body_store.dart';
import 'package:rpg_runner/core/game_core.dart';
import 'package:rpg_runner/core/players/player_character_registry.dart';
import 'package:rpg_runner/core/players/player_catalog.dart';

void _expectSolidsEqual(GameCore a, GameCore b) {
  final sa = a.buildSnapshot().staticSolids;
  final sb = b.buildSnapshot().staticSolids;
  expect(sb.length, sa.length);

  for (var i = 0; i < sa.length; i += 1) {
    final x = sa[i];
    final y = sb[i];
    expect(y.minX, x.minX);
    expect(y.minY, x.minY);
    expect(y.maxX, x.maxX);
    expect(y.maxY, x.maxY);
    expect(y.sides, x.sides);
    expect(y.oneWayTop, x.oneWayTop);
  }
}

void main() {
  test('track streaming is deterministic and stays bounded (culling)', () {
    const seed = 12345;
    // Disable right-side wall collision so the player never gets stuck on a
    // chunk obstacle and can run long enough to exercise spawn/cull.
    //
    // Also disable gravity so gaps (introduced by track patterns) don't end the
    // run; this test only cares about deterministic streaming + culling.
    final base = PlayerCharacterRegistry.eloise;
    final playerCharacter = base.copyWith(
      catalog: const PlayerCatalog(
        bodyTemplate: BodyDef(sideMask: BodyDef.sideLeft, useGravity: false),
      ),
    );
    final a = GameCore(seed: seed, playerCharacter: playerCharacter);
    final b = GameCore(seed: seed, playerCharacter: playerCharacter);

    // Always move right so the player stays in view and the camera keeps advancing.
    const ticks =
        1800; // ~30 seconds at 60Hz (enough to trigger multiple spawn/cull cycles).
    var maxSolids = 0;

    for (var t = 1; t <= ticks; t += 1) {
      final cmds = <Command>[MoveAxisCommand(tick: t, axis: 1.0)];
      a.applyCommands(cmds);
      b.applyCommands(cmds);
      a.stepOneTick();
      b.stepOneTick();

      if (t % 20 == 0) {
        _expectSolidsEqual(a, b);
      }

      final solids = a.buildSnapshot().staticSolids.length;
      if (solids > maxSolids) maxSolids = solids;

      expect(a.gameOver, isFalse);
      expect(b.gameOver, isFalse);
    }

    // Culling keeps the streamed world bounded (does not grow without limit).
    // This threshold is intentionally loose; it only exists to catch “no cull” regressions.
    expect(maxSolids, lessThan(120));
  });
}
