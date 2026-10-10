import 'dart:convert';

import 'package:runner_core/bosses/boss_arena_definition.dart';
import 'package:runner_core/commands/command.dart';
import 'package:runner_core/ecs/world.dart';
import 'package:runner_core/ecs/stores/hitbox_store.dart';
import 'package:runner_core/ecs/stores/projectile_store.dart';
import 'package:runner_core/combat/damage_type.dart';
import 'package:runner_core/combat/faction.dart';
import 'package:runner_core/events/game_event.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/game_core.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/levels/level_registry.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:runner_core/players/player_character_definition.dart';
import 'package:runner_core/projectiles/projectile_id.dart';
import 'package:runner_core/snapshots/boss_arena_snapshot.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/track/chunk_pattern.dart';
import 'package:runner_core/track/chunk_pattern_source.dart';
import 'package:test/test.dart';

GameCore ancientGodTestCore(
  EnemyId boss, {
  int hz = 60,
  int seed = 7,
  double minX = 24,
  double maxX = 576,
  double spawnX = 440,
  double playerStartX = 300,
  PlayerCharacterDefinition? character,
}) => GameCore(
  seed: seed,
  tickHz: hz,
  playerCharacter: character ?? PlayerCharacterRegistry.eloise,
  levelDefinition: LevelRegistry.byId(LevelId.field).copyWith(
    tuning: LevelRegistry.byId(LevelId.field).tuning.copyWith(
      track: LevelRegistry.byId(LevelId.field).tuning.track
          .copyWith(playerStartX: playerStartX),
    ),
    noEnemyChunks: 0,
    earlyPatternChunks: 0,
    clearAssembly: true,
    clearFirstChunkKey: true,
    chunkPatternSource: ChunkPatternListSource(
      easyPatterns: const [],
      normalPatterns: [
        ChunkPattern(
          name: 'field_default_normal_001',
          chunkKey: 'field_default_normal_001',
          bossArena: BossArenaDefinition(
            id: 'test_ancient_god',
            enemyId: boss,
            spawnX: spawnX,
            minX: minX,
            maxX: maxX,
          ),
        ),
      ],
    ),
  ),
);

void main() {
  for (final boss in [
    EnemyId.voidbornGoddess,
    EnemyId.shoggoth,
    EnemyId.voidcaller,
  ]) {
    for (final hz in [30, 60, 90]) {
      test('${boss.name} enters, fights and stays confined at $hz Hz', () {
        final a = ancientGodTestCore(boss, hz: hz, playerStartX: 175);
        final b = ancientGodTestCore(boss, hz: hz, playerStartX: 175);
        final animations = <AnimKey>{};
        final observedSummons = <EnemyId>{};
        final tentacleX = <int, double>{};
        final summonBorn = <int, int>{};
        var combatTicks = 0;
        var teleported = false;
        double? previousX;
        for (var n = 0; n < hz * 28 && !a.gameOver; n++) {
          for (final core in [a, b]) {
            final t = core.tick + 1;
            core.applyCommands([MoveAxisCommand(tick: t, axis: 0)]);
            core.stepOneTick();
          }
          final sa = a.buildSnapshot(), sb = b.buildSnapshot();
          expect(sa.bossArena?.enemyId, boss);
          expect(sb.bossArena?.phase, sa.bossArena?.phase);
          expect(sb.hud.hp, sa.hud.hp);
          expect(
            jsonEncode(
              sb.entities
                  .map(
                    (e) => [
                      e.id,
                      e.enemyId?.index,
                      e.pos.x,
                      e.pos.y,
                      e.anim.index,
                      e.animFrame,
                    ],
                  )
                  .toList(),
            ),
            jsonEncode(
              sa.entities
                  .map(
                    (e) => [
                      e.id,
                      e.enemyId?.index,
                      e.pos.x,
                      e.pos.y,
                      e.anim.index,
                      e.animFrame,
                    ],
                  )
                  .toList(),
            ),
          );
          // Gameplay timers stop during the player's terminal death animation.
          if (sa.hud.hp <= 0) break;
          final actor = sa.entities.where((e) => e.enemyId == boss).firstOrNull;
          if (actor == null) continue;
          expect(actor.pos.x, inInclusiveRange(24, 576));
          animations.add(actor.anim);
          if (sa.bossArena?.phase == BossArenaPhase.combat) combatTicks++;
          if (previousX != null && (actor.pos.x - previousX).abs() > 80) {
            teleported = true;
          }
          previousX = actor.pos.x;
          for (final summon in sa.entities.where(
            (e) => e.enemyId?.isBossSummon ?? false,
          )) {
            observedSummons.add(summon.enemyId!);
            expect(summon.pos.x, inInclusiveRange(24, 576));
            summonBorn.putIfAbsent(summon.id, () => a.tick);
            expect(a.tick - summonBorn[summon.id]!, lessThan(hz * 12));
            if (summon.enemyId == EnemyId.voidTentacle) {
              tentacleX.putIfAbsent(summon.id, () => summon.pos.x);
              expect(summon.pos.x, closeTo(tentacleX[summon.id]!, .002));
            }
          }
          final alive = sa.entities
              .where((e) => e.enemyId?.isBossSummon ?? false)
              .map((e) => e.id)
              .toSet();
          expect(
            alive.length,
            lessThanOrEqualTo(boss == EnemyId.shoggoth ? 3 : 2),
          );
          summonBorn.removeWhere((id, tick) => !alive.contains(id));
          tentacleX.removeWhere((id, x) => !alive.contains(id));
        }
        expect(combatTicks, greaterThan(hz * 10));
        expect(animations, contains(AnimKey.spawn));
        expect(animations, contains(AnimKey.cast));
        if (boss == EnemyId.voidcaller) {
          expect(observedSummons, contains(EnemyId.voidTentacle));
          expect(animations, containsAll([AnimKey.ranged, AnimKey.strike2]));
        } else {
          if (boss == EnemyId.shoggoth) {
            expect(animations, contains(AnimKey.strike));
            // A reachable stationary target needs no relocation, and minions
            // belong to health thresholds rather than the ambient action clock.
            expect(observedSummons, isEmpty);
          } else {
            // No player attacks means no health threshold and no hand barrage.
            expect(teleported, isTrue);
            expect(animations, isNot(contains(AnimKey.ranged)));
            expect(animations, contains(AnimKey.teleportOut));
          }
        }
      });
    }
    for (final character in [
      PlayerCharacterRegistry.eloise,
      PlayerCharacterRegistry.eloiseWip,
    ]) {
      test(
        '${character.id.name} defeats ${boss.name} and releases its summons',
        () {
          final core = ancientGodTestCore(boss, character: character);
          var defeated = false, released = false;
          for (var n = 0; n < 6000 && !core.gameOver; n++) {
            final s = core.buildSnapshot();
            final actor = s.entities
                .where((e) => e.enemyId == boss)
                .firstOrNull;
            final dx = actor == null
                ? 0.0
                : actor.pos.x - s.playerEntity!.pos.x;
            final t = core.tick + 1;
            final evadeCombo =
                boss == EnemyId.voidbornGoddess &&
                (actor?.anim == AnimKey.strike ||
                    actor?.anim == AnimKey.teleportOut);
            final evadeOrb =
                boss == EnemyId.voidbornGoddess &&
                actor?.anim == AnimKey.cast &&
                // Release frame 8 is exposed as 48 animation ticks at 60 Hz;
                // jumping earlier lets the cast track the airborne player.
                (actor?.animFrame ?? 0) >= 48;
            final playerX = s.playerEntity!.pos.x;
            final avoidHands =
                boss == EnemyId.voidbornGoddess &&
                actor?.anim == AnimKey.ranged;
            // Stand between warning marks instead of letting the first slap
            // knock the player along the advancing hand sweep.
            final handGapX =
                119.2 + ((playerX - 119.2) / 90.4).round().clamp(0, 4) * 90.4;
            final escapeDirection = playerX < 70
                ? 1.0
                : playerX > 530
                ? -1.0
                : -dx.sign;
            core.applyCommands([
              MoveAxisCommand(
                tick: t,
                axis: avoidHands
                    ? ((handGapX - playerX).abs() > 2
                          ? (handGapX - playerX).sign
                          : 0)
                    : evadeCombo
                    ? escapeDirection
                    : dx.abs() > 20
                    ? dx.sign
                    : 0,
              ),
              AimDirCommand(tick: t, x: dx >= 0 ? 1 : -1, y: 0),
              // Tracking claws require an actual evasive input; walking through
              // the boss no longer leaves the entire combo facing away.
              if (boss == EnemyId.voidbornGoddess &&
                  actor?.anim == AnimKey.strike &&
                  dx.abs() < 90)
                JumpPressedCommand(tick: t),
              if (evadeCombo && dx.abs() < 55) DashPressedCommand(tick: t),
              if (evadeOrb) JumpPressedCommand(tick: t),
              if (!evadeCombo && !avoidHands && n % 20 == 0)
                StrikePressedCommand(tick: t),
              if (!evadeCombo && !avoidHands && n % 45 == 0)
                ProjectilePressedCommand(tick: t),
            ]);
            core.stepOneTick();
            final after = core.buildSnapshot();
            defeated |= after.bossArena?.phase == BossArenaPhase.defeated;
            if (defeated && after.bossArena == null) {
              expect(
                after.entities.where((e) => e.enemyId?.isBossSummon ?? false),
                isEmpty,
              );
              for (var k = 0; k < 10; k++) {
                final t = core.tick + 1;
                core.applyCommands([MoveAxisCommand(tick: t, axis: 1)]);
                core.stepOneTick();
              }
              expect(core.buildSnapshot().camera.centerX, greaterThan(300));
              released = true;
              break;
            }
          }
          expect(
            defeated,
            isTrue,
            reason: 'HP=${core.buildSnapshot().hud.hp}, tick=${core.tick}',
          );
          expect(released, isTrue);
          core.giveUp();
          final end = core.drainEvents().whereType<RunEndedEvent>().single;
          expect(end.stats.enemyKillCounts[boss.index], 1);
        },
      );
    }
  }
  test(
    'destroyed owner removes summons and their attacks before ID recycling',
    () {
      final world = EcsWorld(seed: 7);
      final boss = world.createEntity();
      world.bossCombat.addEntity(boss);
      final summon = world.createEntity();
      final si = world.bossSummon.addEntity(summon);
      world.bossSummon.owner[si] = boss;
      final projectile = world.createEntity();
      world.projectile.add(
        projectile,
        ProjectileEntityDef(
          projectileId: ProjectileId.shoggothOrb,
          faction: Faction.enemy,
          owner: summon,
          dirX: 1,
          dirY: 0,
          speedUnitsPerSecond: 100,
          damage100: 200,
          damageType: DamageType.dark,
        ),
      );
      final hitbox = world.createEntity();
      world.hitbox.add(
        hitbox,
        HitboxDef(
          owner: summon,
          faction: Faction.enemy,
          damage100: 200,
          damageType: DamageType.physical,
          dirX: 1,
          dirY: 0,
        ),
      );
      world.destroyEntity(boss);
      expect(world.isEntityAlive(summon), isFalse);
      expect(world.bossSummon.denseEntities, isEmpty);
      expect(world.isEntityAlive(projectile), isFalse);
      expect(world.isEntityAlive(hitbox), isFalse);
      expect(world.createEntity(), boss);
      expect(world.bossCombat.has(boss), isFalse);
    },
  );
}
