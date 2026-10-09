import 'dart:math' as math;

import 'package:runner_core/commands/command.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/events/game_event.dart';
import 'package:runner_core/game_core.dart';
import 'package:runner_core/levels/level_assembly.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/levels/level_registry.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:runner_core/spell_impacts/spell_impact_id.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/util/vec2.dart';
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
          Vec2? origin;
          Vec2? previous;
          final castFrames = <int>{};
          var travelTicks = 0;
          var returned = false;
          for (var n = 0; n < hz * 30 && !core.gameOver; n++) {
            final before = core.buildSnapshot();
            final boss = before.entities
                .where((e) => e.enemyId == EnemyId.voidbornGoddess)
                .firstOrNull;
            final attack =
                before.bossArena != null &&
                before.bossArena!.hp100 > before.bossArena!.hpMax100 * .75;
            final dx = boss == null
                ? 0.0
                : boss.pos.x - before.playerEntity!.pos.x;
            final tick = core.tick + 1;
            core.applyCommands([
              MoveAxisCommand(
                tick: tick,
                axis: attack && dx.abs() > 20 ? dx.sign : 0,
              ),
              AimDirCommand(tick: tick, x: dx >= 0 ? 1 : -1, y: 0),
              if (attack && n % (hz / 3).ceil() == 0)
                StrikePressedCommand(tick: tick),
              if (attack && n % (hz * .75).ceil() == 0)
                ProjectilePressedCommand(tick: tick),
            ]);
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
            if (actor != null) {
              if (actor.anim == AnimKey.ranged) {
                expect(
                  core.buildSnapshot().bossArena!.hp100,
                  lessThanOrEqualTo(before.bossArena!.hpMax100 * .75),
                );
                origin ??= actor.pos;
                castFrames.add(actor.animFrame! ~/ (.1 * hz).round());
              }
              if (hands.length == 6 && previous != null) {
                final dx = actor.pos.x - previous.x;
                final dy = actor.pos.y - previous.y;
                expect(
                  math.sqrt(dx * dx + dy * dy),
                  lessThanOrEqualTo(180 / hz + .1),
                );
                if (dx.abs() > .01 || dy.abs() > .01) travelTicks++;
              }
              previous = actor.pos;
            }
            if (impacts.isNotEmpty) {
              hands.addAll(impacts);
              expect(actor, isNotNull);
              expect(actor!.pos.y, closeTo(ground - 150, .01));
              cornerX ??= actor.pos.x;
              expect(actor.pos.x, cornerX);
              expect(cornerX, anyOf(closeTo(88, .01), closeTo(512, .01)));
            }
            if (hands.length == 6 &&
                actor != null &&
                origin != null &&
                (actor.pos.x - origin.x).abs() < 1 &&
                (actor.pos.y - origin.y).abs() < 1) {
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
              expect(hands[i].tick - hands[i - 1].tick, (hz * .35).ceil());
            }
          }
          expect(returned, isTrue);
          expect(travelTicks, greaterThan(hz ~/ 2));
          expect(castFrames, containsAll(List.generate(36, (i) => i)));
        },
      );
    }
  }
}
