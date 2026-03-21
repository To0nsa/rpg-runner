import 'package:flutter_test/flutter_test.dart';

import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/game_core.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/levels/level_registry.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:runner_core/snapshots/entity_render_snapshot.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/track/chunk_pattern.dart';
import 'package:runner_core/track/chunk_pattern_pool.dart';

void main() {
  test('hashash teleports in at the camera-right chunk edge', () {
    const pattern = ChunkPattern(
      name: 'hashash-only',
      spawnMarkers: <SpawnMarker>[
        SpawnMarker(
          enemyId: EnemyId.hashash,
          x: 160.0,
          chancePercent: 100,
          salt: 0x1,
        ),
      ],
    );
    const pool = ChunkPatternPool(
      easyPatterns: <ChunkPattern>[pattern],
      allPatterns: <ChunkPattern>[pattern],
    );

    final level = LevelRegistry.byId(
      LevelId.field,
    ).copyWith(patternPool: pool, earlyPatternChunks: 0, noEnemyChunks: 0);

    final core = GameCore(
      seed: 42,
      levelDefinition: level,
      playerCharacter: PlayerCharacterRegistry.eloise,
    );

    core.stepOneTick();
    final snapshot = core.buildSnapshot();
    final hashash = snapshot.entities
        .where((entity) => entity.enemyId == EnemyId.hashash)
        .toList();

    expect(hashash.length, 1);
    expect(hashash.single.pos.x, closeTo(600.0, 1e-9));
    expect(hashash.single.anim, AnimKey.spawn);
    expect(hashash.single.animFrame, 0);
    expect(hashash.single.statusVisualMask, EntityStatusVisualMask.none);
  });
}
