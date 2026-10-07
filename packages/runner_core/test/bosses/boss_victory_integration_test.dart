import 'dart:math';

import 'package:runner_core/commands/command.dart';

import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/events/game_event.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:runner_core/snapshots/boss_arena_snapshot.dart';
import 'package:runner_core/spell_impacts/spell_impact_id.dart';
import 'package:test/test.dart';

import '../test_support/boss_victory_fixture.dart';

void main() {
  for (final character in [
    PlayerCharacterRegistry.eloise,
    PlayerCharacterRegistry.eloiseWip,
  ]) {
    for (final hz in [30, 60, 90]) {
      test(
        '${character.id.name} real Forest victory grants blessing after corpse cleanup at $hz Hz',
        () {
          final core = bossVictoryCore(hz: hz, character: character);
          var granted = false;
          var holyEvents = 0;
          for (var i = 0; i < hz * 90 && !core.gameOver; i++) {
            final before = core.buildSnapshot();
            core.applyCommands(bossVictoryCommands(core));
            core.stepOneTick();
            final after = core.buildSnapshot();
            final events = core
                .drainEvents()
                .whereType<SpellImpactEvent>()
                .where((e) => e.impactId == SpellImpactId.holyBlessing)
                .toList();
            holyEvents += events.length;
            if (after.bossVictoryBlessing == null) continue;
            expect(before.bossArena?.phase, BossArenaPhase.defeated);
            expect(
              before.entities.where((e) => e.enemyId == EnemyId.bringerOfDeath),
              isEmpty,
            );
            expect(after.bossArena, isNull);
            expect(after.bossVictoryBlessing!.startTick, core.tick);
            expect(after.bossVictoryBlessing!.restorationBp, 2000);
            expect(events, hasLength(1));
            expect(events.single.followEntityId, after.playerEntity!.id);
            expect(
              after.hud.hp,
              greaterThanOrEqualTo(
                min(before.hud.hpMax, before.hud.hp + before.hud.hpMax * .2) -
                    .001,
              ),
            );
            expect(
              after.hud.mana,
              greaterThanOrEqualTo(
                min(
                      before.hud.manaMax,
                      before.hud.mana + before.hud.manaMax * .2,
                    ) -
                    .001,
              ),
            );
            expect(
              after.hud.stamina,
              greaterThanOrEqualTo(
                min(
                      before.hud.staminaMax,
                      before.hud.stamina + before.hud.staminaMax * .2,
                    ) -
                    .001,
              ),
            );
            expect(after.hud.hp, lessThanOrEqualTo(after.hud.hpMax));
            expect(after.hud.mana, lessThanOrEqualTo(after.hud.manaMax));
            expect(after.hud.stamina, lessThanOrEqualTo(after.hud.staminaMax));
            expect(after.playerEntity!.controlLockMask, 0);
            final notice = after.bossVictoryBlessing;
            core.paused = true;
            for (var n = 0; n < 10; n++) {
              core.stepOneTick();
            }
            expect(
              core.buildSnapshot().bossVictoryBlessing!.startTick,
              notice!.startTick,
            );
            core.paused = false;
            final startX = core.playerPosX;
            for (var n = 0; n < (hz * .3).ceil(); n++) {
              core.applyCommands([
                MoveAxisCommand(tick: core.tick + 1, axis: 1),
              ]);
              core.stepOneTick();
              holyEvents += core
                  .drainEvents()
                  .whereType<SpellImpactEvent>()
                  .where((e) => e.impactId == SpellImpactId.holyBlessing)
                  .length;
            }
            expect(core.playerPosX, greaterThan(startX));
            expect(holyEvents, 1);
            granted = true;
            break;
          }
          expect(granted, isTrue);
        },
      );
    }
  }
}
