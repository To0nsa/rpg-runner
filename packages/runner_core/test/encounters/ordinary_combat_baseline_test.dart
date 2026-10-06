import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:runner_core/commands/command.dart';
import 'package:runner_core/game_core.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/levels/level_registry.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/track/chunk_pattern.dart';
import 'package:runner_core/track/chunk_pattern_source.dart';
import 'package:test/test.dart';

void main() {
  test('ordinary field combat preserves the reviewed upright attack trace while enemies turn during committed strikes', () {
    final core = GameCore(
      seed: 42,
      levelDefinition: LevelRegistry.byId(LevelId.field).copyWith(
        noEnemyChunks: 0,
        earlyPatternChunks: 0,
        clearAssembly: true,
        clearFirstChunkKey: true,
        chunkPatternSource: const ChunkPatternListSource(
          easyPatterns: [],
          normalPatterns: [
            ChunkPattern(
              name: 'field_default_normal_001',
              chunkKey: 'field_default_normal_001',
              spawnMarkers: [
                SpawnMarker(
                  enemyId: EnemyId.grojib,
                  x: 380,
                  chancePercent: 100,
                  salt: 1,
                ),
                SpawnMarker(
                  enemyId: EnemyId.hashash,
                  x: 450,
                  chancePercent: 100,
                  salt: 2,
                ),
                SpawnMarker(
                  enemyId: EnemyId.unocoDemon,
                  x: 520,
                  chancePercent: 100,
                  salt: 3,
                ),
                SpawnMarker(
                  enemyId: EnemyId.derf,
                  x: 560,
                  chancePercent: 100,
                  salt: 4,
                ),
              ],
            ),
          ],
        ),
      ),
      playerCharacter: PlayerCharacterRegistry.eloise,
    );
    final trace = StringBuffer();
    final seenEnemies = <String>{};
    final strikeFacings = <int, Facing>{};
    var strikeTurns = 0;
    final transformedDerfs = <int>{};
    var sawDerfStrike = false;
    for (var tick = 1; tick <= 1800 && !core.gameOver; tick++) {
      core.applyCommands([
        MoveAxisCommand(tick: tick, axis: 1),
        if (tick % 75 == 0) JumpPressedCommand(tick: tick),
        if (tick % 25 == 0) StrikePressedCommand(tick: tick),
      ]);
      core.stepOneTick();
      final s = core.buildSnapshot();
      trace.writeln(
        jsonEncode([
          s.tick,
          s.distance,
          s.camera.centerX,
          s.camera.centerY,
          s.hud.hp,
          s.hud.mana,
          s.hud.stamina,
          s.hud.collectibleScore,
          s.gameOver,
          for (final e in s.entities)
            [
              e.id,
              e.kind.name,
              e.pos.x,
              e.pos.y,
              e.vel?.x,
              e.vel?.y,
              e.enemyId?.name,
              e.projectileId?.name,
              e.facing.name,
              e.anim.name,
              e.animFrame,
              e.grounded,
              e.statusVisualMask,
              e.controlLockMask,
            ],
        ]),
      );
      for (final e in s.entities) {
        if (e.enemyId == null) continue;
        seenEnemies.add(e.enemyId!.name);
        if (e.enemyId == EnemyId.derf) {
          if (e.anim == AnimKey.transform) {
            transformedDerfs.add(e.id);
          }
          sawDerfStrike |= e.anim == AnimKey.strike;
          if (transformedDerfs.contains(e.id)) {
            expect(e.anim, isNot(AnimKey.cast));
          }
        }
        expect(e.rotationRad, 0, reason: 'tick=$tick enemy=${e.enemyId}');
        if (e.anim == AnimKey.strike) {
          final previousFacing = strikeFacings[e.id];
          if (previousFacing != null && previousFacing != e.facing) {
            strikeTurns++;
          }
          strikeFacings[e.id] = e.facing;
        } else {
          strikeFacings.remove(e.id);
        }
      }
      core.drainEvents();
    }
    final digest = sha256.convert(utf8.encode(trace.toString())).toString();
    expect(seenEnemies, containsAll(EnemyId.values.map((id) => id.name)));
    expect(transformedDerfs, isNotEmpty);
    expect(sawDerfStrike, isTrue);
    expect(strikeTurns, greaterThan(0));
    expect(
      digest,
      '9669158bbd76a858fb347798510037d93db7f2c9f6ea3ca4eb4723b7e8d22ec2',
      reason: 'ticks=${core.tick}, enemies=$seenEnemies',
    );
  });
}
