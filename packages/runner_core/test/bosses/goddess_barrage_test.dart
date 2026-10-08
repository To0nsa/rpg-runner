import 'package:runner_core/commands/command.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/events/game_event.dart';
import 'package:runner_core/game_core.dart';
import 'package:runner_core/levels/level_assembly.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/levels/level_registry.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:runner_core/spell_impacts/spell_impact_id.dart';
import 'package:test/test.dart';

import 'ancient_god_arena_test.dart' show ancientGodTestCore;

void main() {
  for (final hz in [30, 60, 90]) {
    for (final authored in [false, true]) {
      test(
        'Goddess hovers for six sequential hands then returns at $hz Hz (authored=$authored)',
        () {
          final forest = LevelRegistry.byId(LevelId.forest);
          final start = forest.assembly!.segments.indexWhere(
            (segment) => segment.groupId == 'boss_voidborn_goddess',
          );
          final core = authored
              ? GameCore(
                  seed: 7,
                  tickHz: hz,
                  playerCharacter: PlayerCharacterRegistry.eloise,
                  levelDefinition: forest.copyWith(
                    noEnemyChunks: 0,
                    clearFirstChunkKey: true,
                    assembly: LevelAssemblyDefinition(
                      loopSegments: false,
                      segments: forest.assembly!.segments.sublist(
                        start,
                        start + 2,
                      ),
                    ),
                  ),
                )
              : ancientGodTestCore(EnemyId.voidbornGoddess, hz: hz);
          final ground = authored ? 224.0 : 222.0;
          final hands = <SpellImpactEvent>[];
          double? cornerX;
          var returned = false;
          for (var n = 0; n < hz * 15 && !core.gameOver; n++) {
            core.applyCommands([MoveAxisCommand(tick: core.tick + 1, axis: 0)]);
            core.stepOneTick();
            final actor = core
                .buildSnapshot()
                .entities
                .where((e) => e.enemyId == EnemyId.voidbornGoddess)
                .firstOrNull;
            final impacts = core
                .drainEvents()
                .whereType<SpellImpactEvent>()
                .where((e) => e.impactId == SpellImpactId.goddessEruption)
                .toList();
            if (impacts.isNotEmpty) {
              hands.addAll(impacts);
              expect(actor, isNotNull);
              expect(actor!.pos.y, closeTo(ground - 150, .01));
              cornerX ??= actor.pos.x;
              expect(actor.pos.x, cornerX);
              expect(cornerX, anyOf(closeTo(88, .01), closeTo(512, .01)));
            }
            if (hands.length == 6 && actor != null && actor.pos.y > 150) {
              returned = true;
              break;
            }
          }
          expect(hands, hasLength(6));
          final xs = hands.map((e) => e.pos.x).toList();
          expect(xs.toSet(), hasLength(6));
          for (var i = 0; i < 6; i++) {
            final index = cornerX! < 300 ? i : 5 - i;
            expect(xs[i], closeTo(74 + index * 90.4, .01));
            expect(hands[i].pos.y, closeTo(ground, .01));
            if (i > 0) {
              expect(hands[i].tick - hands[i - 1].tick, (hz / 2).ceil());
            }
          }
          expect(returned, isTrue);
        },
      );
    }
  }
}
