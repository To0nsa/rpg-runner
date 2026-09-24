import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:runner_core/commands/command.dart';
import 'package:runner_core/game_core.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/levels/level_registry.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:runner_core/track/chunk_pattern.dart';
import 'package:runner_core/track/chunk_pattern_source.dart';
import 'package:test/test.dart';

void main() {
  test('ordinary field combat preserves the reviewed combat-hold tick trace', () {
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
              name: 'field_flat',
              chunkKey: 'field_flat',
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
        if (e.enemyId != null) seenEnemies.add(e.enemyId!.name);
      }
      core.drainEvents();
    }
    final digest = sha256.convert(utf8.encode(trace.toString())).toString();
    expect(seenEnemies, containsAll(['grojib', 'hashash', 'unocoDemon']));
    expect(
      digest,
      'ec0c409c2a88e46ff36af3adbf56777b1827610dfd745c599c60394a54533701',
      reason: 'ticks=${core.tick}, enemies=$seenEnemies',
    );
  });
}
