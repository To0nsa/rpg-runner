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
        'Goddess finishes its fixed hand sweep, casts an orb and teleports at $hz Hz (authored=$authored)',
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
          Vec2? destination;
          final castFrames = <int>{};
          List<int>? supportedMarks;
          var exitCast = false;
          var vanishTicks = 0;
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
            final playerX = before.playerEntity!.pos.x;
            // The authored arena has a gap at 222..270. Jump when approaching
            // it or when a shove would carry the player off its edge.
            final crossGap =
                authored &&
                attack &&
                (dx > 0 && playerX > 170 && playerX < 222 ||
                    dx < 0 && playerX > 270 && playerX < 322);
            final knockedTowardGap =
                authored &&
                (playerX > 270 &&
                        playerX < 390 &&
                        (before.playerEntity!.vel?.x ?? 0) < -100 ||
                    playerX > 102 &&
                        playerX < 222 &&
                        (before.playerEntity!.vel?.x ?? 0) > 100 &&
                        dx < 0);
            core.applyCommands([
              MoveAxisCommand(
                tick: tick,
                axis: attack && dx.abs() > 20 ? dx.sign : 0,
              ),
              AimDirCommand(tick: tick, x: dx >= 0 ? 1 : -1, y: 0),
              if (crossGap || knockedTowardGap) JumpPressedCommand(tick: tick),
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
                supportedMarks ??= [
                  for (var mark = 0; mark < 6; mark++)
                    if (!authored ||
                        before.stagedTerrainRenderSnapshot!.edges.any(
                          (edge) =>
                              edge.start.yTicks == ground * 1024 &&
                              edge.end.yTicks == ground * 1024 &&
                              edge.bounds.minX <= (74 + mark * 90.4) * 1024 &&
                              edge.bounds.maxX >= (74 + mark * 90.4) * 1024,
                        ))
                      mark,
                ];
                castFrames.add(actor.animFrame! ~/ (.1 * hz).round());
              }
              if (supportedMarks != null &&
                  hands.length == supportedMarks.length &&
                  actor.anim == AnimKey.cast) {
                exitCast = true;
                expect(actor.pos.x, cornerX);
                expect(actor.pos.y, closeTo(ground - 150, .01));
              }
              if (supportedMarks != null &&
                  hands.length == supportedMarks.length &&
                  actor.teleportDestination != null) {
                expect(exitCast, isTrue);
                expect(actor.anim, AnimKey.teleportOut);
                destination ??= actor.teleportDestination;
                expect(actor.teleportDestination!.x, destination!.x);
                expect(actor.teleportDestination!.y, destination.y);
                vanishTicks++;
              }
            }
            if (impacts.isNotEmpty) {
              hands.addAll(impacts);
              expect(actor, isNotNull);
              expect(actor!.pos.y, closeTo(ground - 150, .01));
              cornerX ??= actor.pos.x;
              expect(actor.pos.x, cornerX);
              expect(cornerX, anyOf(closeTo(88, .01), closeTo(512, .01)));
            }
            if (supportedMarks != null &&
                hands.length == supportedMarks.length &&
                actor != null &&
                destination != null &&
                actor.anim == AnimKey.spawn) {
              expect(actor.pos.x, destination.x);
              expect(actor.pos.y, closeTo(destination.y, .1));
              expect(actor.teleportDestination, isNull);
              returned = true;
              break;
            }
          }
          expect(
            supportedMarks,
            isNotNull,
            reason:
                'HP=${core.buildSnapshot().hud.hp}, boss=${core.buildSnapshot().bossArena?.hp100}, player=${core.buildSnapshot().playerEntity?.pos}, tick=${core.tick}',
          );
          expect(supportedMarks, isNotEmpty);
          expect(hands, hasLength(supportedMarks!.length));
          final xs = hands.map((e) => e.pos.x).toList();
          expect(xs.toSet(), hasLength(supportedMarks.length));
          final orderedMarks = cornerX! < 300
              ? supportedMarks
              : supportedMarks.reversed.toList();
          for (var i = 0; i < orderedMarks.length; i++) {
            final index = orderedMarks[i];
            expect(xs[i], closeTo(74 + index * 90.4, .01));
            expect(hands[i].pos.y, closeTo(ground, .01));
            if (i > 0) {
              expect(
                hands[i].tick - hands[i - 1].tick,
                (orderedMarks[i] - orderedMarks[i - 1]).abs() *
                    (hz * .35).ceil(),
              );
            }
          }
          expect(returned, isTrue);
          expect(exitCast, isTrue);
          expect(vanishTicks, (.3 * hz).ceil());
          expect(castFrames, containsAll(List.generate(36, (i) => i)));
        },
      );
    }
  }
}
