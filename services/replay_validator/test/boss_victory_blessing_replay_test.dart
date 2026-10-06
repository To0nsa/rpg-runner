import 'package:run_protocol/replay_blob.dart';
import 'package:runner_core/commands/command.dart';
import 'package:runner_core/events/game_event.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:runner_core/snapshots/boss_arena_snapshot.dart';
import 'package:runner_core/spell_impacts/spell_impact_id.dart';
import 'package:test/test.dart';

import '../../../packages/runner_core/test/test_support/boss_victory_fixture.dart';
import '../lib/src/replay_simulation.dart';

void main() {
  for (final character in [
    PlayerCharacterRegistry.eloise,
    PlayerCharacterRegistry.eloiseWip,
  ]) {
    for (final hz in [30, 60, 90]) {
      test(
        '${character.id.name} Forest victory blessing replays at $hz Hz',
        () {
          final direct = bossVictoryCore(hz: hz, character: character);
          final replay = bossVictoryCore(hz: hz, character: character);
          final frames = <ReplayCommandFrameV1>[];
          var holyEvents = 0;
          for (var n = 0; n < hz * 90 && !direct.gameOver; n++) {
            final before = direct.buildSnapshot();
            final commands = bossVictoryCommands(direct);
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
            holyEvents += direct
                .drainEvents()
                .whereType<SpellImpactEvent>()
                .where((e) => e.impactId == SpellImpactId.holyBlessing)
                .length;
            if (direct.buildSnapshot().bossVictoryBlessing != null) {
              expect(before.bossArena?.phase, BossArenaPhase.defeated);
              break;
            }
          }
          final expected = direct.buildSnapshot();
          final blessing = expected.bossVictoryBlessing;
          expect(blessing, isNotNull);
          expect(holyEvents, 1);
          final result = runReplaySimulation(
            core: replay,
            totalTicks: direct.tick,
            commandStream: frames,
          );
          final actual = replay.buildSnapshot();
          expect(result.runEnded, isNull);
          expect(actual.bossArena, isNull);
          expect(actual.bossVictoryBlessing!.id, blessing!.id);
          expect(actual.bossVictoryBlessing!.startTick, blessing.startTick);
          expect(
            actual.bossVictoryBlessing!.durationTicks,
            blessing.durationTicks,
          );
          expect(actual.bossVictoryBlessing!.restorationBp, 6000);
          expect(actual.hud.hp, expected.hud.hp);
          expect(actual.hud.mana, expected.hud.mana);
          expect(actual.hud.stamina, expected.hud.stamina);
          expect(replay.playerPosX, direct.playerPosX);
          expect(replay.playerPosY, direct.playerPosY);
          expect(replay.distance, direct.distance);
        },
      );
    }
  }
}
