import 'package:replay_validator/src/replay_simulation.dart';
import 'package:run_protocol/replay_blob.dart';
import 'package:runner_core/commands/command.dart';
import 'package:runner_core/events/game_event.dart';
import 'package:runner_core/game_core.dart';
import 'package:runner_core/npcs/npc_id.dart';
import 'package:test/test.dart';

import '../../../packages/runner_core/test/test_support/npc_section_guard_scenario.dart';

void main() {
  for (final id in NpcId.values) {
    for (final seed in [7, 42, 2026]) {
      for (final tickHz in [30, 60]) {
        test(
          '${id.name} section combat replays at ${tickHz} Hz, seed $seed',
          () {
            final direct = sectionGuardCore(
              npcId: id,
              seed: seed,
              tickHz: tickHz,
            );
            final replayed = sectionGuardCore(
              npcId: id,
              seed: seed,
              tickHz: tickHz,
            );
            final frames = <ReplayCommandFrameV1>[];
            final checkpoints = <int, List<Object?>>{};
            EncounterResolvedEvent? rescue;
            RunEndedEvent? directEnd;
            var crossedSeam = false;
            var damaged = false;
            int? rescueHp;
            for (
              var tick = 1;
              tick <= tickHz * 15 && !direct.gameOver;
              tick++
            ) {
              if (tick == 1 || tick % 256 == 0) {
                checkpoints[tick] = _signature(direct);
              }
              if (rescue == null) {
                frames.add(
                  ReplayCommandFrameV1(
                    tick: tick,
                    pressedMask: ReplayCommandFrameV1.pressedStrikeBit,
                  ),
                );
              }
              direct.applyCommands([
                if (rescue == null) StrikePressedCommand(tick: tick),
              ]);
              direct.stepOneTick();
              for (final event in direct.drainEvents()) {
                if (event is EncounterResolvedEvent) {
                  expect(rescue, isNull);
                  rescue = event;
                }
                if (event is RunEndedEvent) directEnd = event;
              }
              for (final npc in direct.buildSnapshot().entities.where(
                (e) => e.npcId == id,
              )) {
                crossedSeam |= npc.pos.x > 600;
                if (rescue != null) {
                  rescueHp ??= npc.npcHealth!.hp100;
                  damaged |= npc.npcHealth!.hp100 < rescueHp;
                }
              }
            }
            expect(rescue, isNotNull);
            expect(crossedSeam, isTrue);
            expect(damaged, isTrue);
            final result = runReplaySimulation(
              core: replayed,
              totalTicks: direct.tick,
              commandStream: frames,
              onCheckpoint: (tick) =>
                  expect(_signature(replayed), checkpoints[tick]),
            );
            expect(result.ticksExecuted, direct.tick);
            expect(_signature(replayed), _signature(direct));
            if (!direct.gameOver) {
              direct.giveUp();
              replayed.giveUp();
              directEnd = latestRunEndedEvent(direct.drainEvents());
            }
            final replayEnd =
                result.runEnded ?? latestRunEndedEvent(replayed.drainEvents());
            expect(directEnd!.stats.rescuedNpcs, 1);
            expect(directEnd.stats.rescuePoints, 250);
            expect(replayEnd!.stats.rescuedNpcs, directEnd.stats.rescuedNpcs);
            expect(replayEnd.stats.rescuePoints, directEnd.stats.rescuePoints);
            expect(
              replayEnd.stats.enemyKillCounts,
              directEnd.stats.enemyKillCounts,
            );
          },
        );
      }
    }
  }
}

List<Object?> _signature(GameCore core) => [
  core.tick,
  core.gameOver,
  core.distance,
  for (final e in core.buildSnapshot().entities)
    (
      e.id,
      e.kind,
      e.npcId,
      e.enemyId,
      e.pos.x,
      e.pos.y,
      e.vel?.x,
      e.vel?.y,
      e.anim,
      e.facing,
      e.npcHealth?.hp100,
      e.npcHealth?.protected,
    ),
];
