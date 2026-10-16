import 'package:run_protocol/replay_blob.dart';
import 'package:runner_core/commands/command.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/events/game_event.dart';
import 'package:runner_core/game_core.dart';
import 'package:runner_core/levels/level_assembly.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/levels/level_registry.dart';
import 'package:runner_core/players/player_character_definition.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:test/test.dart';

import '../lib/src/replay_simulation.dart';

void main() {
  for (final hz in [30, 60, 90]) {
    for (final character in [
      PlayerCharacterRegistry.eloise,
      PlayerCharacterRegistry.eloiseWip,
    ]) {
      test('point-blank attack spam meets retaliation and replays, '
          '${character.id.name}, $hz Hz', () {
        final direct = _core(hz, character);
        final frames = <ReplayCommandFrameV1>[];
        var playerHitBoss = false;
        var closeSpin = false;
        var retaliated = false;
        AnimKey? previousAnim;
        for (var n = 0; n < hz * 30 && !direct.gameOver; n++) {
          final before = direct.buildSnapshot();
          final boss = before.entities
              .where((e) => e.enemyId == EnemyId.shoggoth)
              .firstOrNull;
          final dx = boss == null ? 0.0 : boss.pos.x - direct.playerPosX;
          final axis = dx.abs() > 10 ? dx.sign : 0.0;
          final aim = dx >= 0 ? 1.0 : -1.0;
          final tick = direct.tick + 1;
          frames.add(
            ReplayCommandFrameV1(
              tick: tick,
              moveAxis: axis,
              aimDirX: aim,
              aimDirY: 0,
              pressedMask: ReplayCommandFrameV1.pressedStrikeBit,
            ),
          );
          direct.applyCommands([
            MoveAxisCommand(tick: tick, axis: axis),
            AimDirCommand(tick: tick, x: aim, y: 0),
            StrikePressedCommand(tick: tick),
          ]);
          direct.stepOneTick();
          final actor = direct
              .buildSnapshot()
              .entities
              .where((e) => e.enemyId == EnemyId.shoggoth)
              .firstOrNull;
          if (actor?.anim == AnimKey.strike2 &&
              previousAnim != AnimKey.strike2 &&
              dx.abs() <= 35) {
            closeSpin = true;
          }
          previousAnim = actor?.anim;
          final events = direct.drainEvents();
          playerHitBoss |= events.any((e) => e is PlayerLandedHitFeedbackEvent);
          retaliated |=
              closeSpin &&
              playerHitBoss &&
              events.any((e) => e is PlayerImpactFeedbackEvent);
          if (retaliated) break;
        }
        expect(playerHitBoss, isTrue);
        expect(closeSpin, isTrue);
        expect(retaliated, isTrue);

        final replay = _core(hz, character);
        final result = runReplaySimulation(
          core: replay,
          totalTicks: direct.tick,
          commandStream: frames,
        );
        expect(result.ticksExecuted, direct.tick);
        final a = direct.buildSnapshot(), b = replay.buildSnapshot();
        expect(a.bossArena!.hp100, lessThan(30000));
        expect(b.hud.hp, a.hud.hp);
        expect(b.bossArena!.hp100, a.bossArena!.hp100);
        expect(
          b.entities.map((e) => [e.id, e.pos.x, e.pos.y, e.anim, e.animFrame]),
          a.entities.map((e) => [e.id, e.pos.x, e.pos.y, e.anim, e.animFrame]),
        );
      });
    }
  }
}

GameCore _core(int hz, PlayerCharacterDefinition character) {
  final forest = LevelRegistry.byId(LevelId.forest);
  final segments = forest.assembly!.segments;
  final start = segments.indexWhere((s) => s.groupId == 'boss_shoggoth');
  return GameCore(
    seed: 7,
    tickHz: hz,
    playerCharacter: character,
    levelDefinition: forest.copyWith(
      noEnemyChunks: 0,
      clearFirstChunkKey: true,
      assembly: LevelAssemblyDefinition(
        loopSegments: false,
        segments: segments.sublist(start, start + 2),
      ),
    ),
  );
}
