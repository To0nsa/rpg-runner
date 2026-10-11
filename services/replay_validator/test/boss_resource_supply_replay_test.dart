import 'package:run_protocol/replay_blob.dart';
import 'package:runner_core/commands/command.dart';
import 'package:runner_core/snapshots/entity_render_snapshot.dart';
import 'package:test/test.dart';

import '../../../packages/runner_core/test/test_support/boss_resource_supply_fixture.dart';
import '../lib/src/replay_simulation.dart';

void main() {
  for (final hz in [30, 60, 90]) {
    test('Goddess milestone gem and collection replay at $hz Hz', () {
      final direct = bossResourceSupplyCore(hz: hz);
      final frames = <ReplayCommandFrameV1>[];
      EntityRenderSnapshot? spawned;
      int? spawnTick;
      var collected = false;
      for (var n = 0; n < hz * 90 && !direct.gameOver; n++) {
        final commands = bossResourceSupplyCommands(direct);
        final axis = commands.whereType<MoveAxisCommand>().single.axis;
        final aim = commands.whereType<AimDirCommand>().firstOrNull;
        frames.add(
          ReplayCommandFrameV1(
            tick: direct.tick + 1,
            moveAxis: axis,
            aimDirX: aim?.x,
            aimDirY: aim?.y,
            pressedMask:
                (commands.any((c) => c is StrikePressedCommand)
                    ? ReplayCommandFrameV1.pressedStrikeBit
                    : 0) |
                (commands.any((c) => c is ProjectilePressedCommand)
                    ? ReplayCommandFrameV1.pressedProjectileBit
                    : 0),
          ),
        );
        direct.applyCommands(commands);
        direct.stepOneTick();
        final gem = resourceGem(direct);
        if (spawned == null && gem != null) {
          spawned = gem;
          spawnTick = direct.tick;
        } else if (spawned != null && gem == null) {
          collected = true;
          break;
        }
      }
      expect(spawned, isNotNull);
      expect(collected, isTrue);

      final atSpawn = bossResourceSupplyCore(hz: hz);
      final spawnResult = runReplaySimulation(
        core: atSpawn,
        totalTicks: spawnTick!,
        commandStream: frames,
      );
      expect(spawnResult.runEnded, isNull);
      final replayGem = resourceGem(atSpawn)!;
      expect(
        [
          replayGem.id,
          replayGem.pos.x,
          replayGem.pos.y,
          replayGem.pickupVariant,
        ],
        [spawned!.id, spawned.pos.x, spawned.pos.y, spawned.pickupVariant],
      );

      final replay = bossResourceSupplyCore(hz: hz);
      final result = runReplaySimulation(
        core: replay,
        totalTicks: direct.tick,
        commandStream: frames,
      );
      expect(result.runEnded, isNull);
      expect(resourceGem(replay), isNull);
      final expected = direct.buildSnapshot(), actual = replay.buildSnapshot();
      expect(actual.bossArena!.hp100, expected.bossArena!.hp100);
      expect(
        [actual.hud.hp, actual.hud.mana, actual.hud.stamina],
        [expected.hud.hp, expected.hud.mana, expected.hud.stamina],
      );
      expect(
        actual.entities.map(
          (e) => [e.id, e.pos.x, e.pos.y, e.anim, e.animFrame, e.pickupVariant],
        ),
        expected.entities.map(
          (e) => [e.id, e.pos.x, e.pos.y, e.anim, e.animFrame, e.pickupVariant],
        ),
      );
    });
  }
}
