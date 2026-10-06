import 'package:replay_validator/src/replay_simulation.dart';
import 'package:runner_core/game_core.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:runner_core/projectiles/projectile_id.dart';
import 'package:runner_core/traps/trap_id.dart';
import 'package:test/test.dart';

import '../../../packages/runner_core/test/test_support/trap_run_fixture.dart';

void main() {
  test(
    'falling trap darts replay with identical physics, impacts and statuses',
    () {
      final direct = trapRunCore(
        PlayerCharacterRegistry.eloise,
        TrapId.poisonDarts,
      );
      final replayed = trapRunCore(
        PlayerCharacterRegistry.eloise,
        TrapId.poisonDarts,
      );
      final checkpoints = <int, List<Object?>>{};
      var sawDrop = false;
      for (var tick = 1; tick <= 300; tick++) {
        if (tick == 1 || tick % 256 == 0)
          checkpoints[tick] = _signature(direct);
        direct.applyCommands(const []);
        direct.stepOneTick();
        sawDrop |= direct.buildSnapshot().entities.any(
          (e) =>
              e.projectileId == ProjectileId.poisonDart && (e.vel?.y ?? 0) > 0,
        );
        direct.drainEvents();
      }
      final result = runReplaySimulation(
        core: replayed,
        totalTicks: 300,
        commandStream: const [],
        onCheckpoint: (tick) => expect(_signature(replayed), checkpoints[tick]),
      );
      expect(sawDrop, isTrue);
      expect(result.ticksExecuted, 300);
      expect(_signature(replayed), _signature(direct));
    },
  );
}

List<Object?> _signature(GameCore core) {
  final snapshot = core.buildSnapshot();
  return [
    core.tick,
    core.gameOver,
    snapshot.hud.hp,
    for (final e in snapshot.entities)
      (
        e.id,
        e.projectileId,
        e.pos.x,
        e.pos.y,
        e.vel?.x,
        e.vel?.y,
        e.rotationRad,
        e.anim,
        e.animFrame,
        e.statusVisualMask,
      ),
    for (final t in snapshot.traps) (t.source.runtimeId, t.phase, t.frameIndex),
  ];
}
