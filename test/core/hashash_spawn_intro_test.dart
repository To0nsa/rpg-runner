import 'package:flutter_test/flutter_test.dart';

import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/game_core.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/levels/level_registry.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:runner_core/snapshots/entity_render_snapshot.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/track/chunk_pattern.dart';
import 'package:runner_core/track/chunk_pattern_source.dart';

void main() {
  test(
    'hashash teleports in at the camera-right chunk edge during prewarm',
    () {
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
      const source = ChunkPatternListSource(
        easyPatterns: <ChunkPattern>[pattern],
        hardPatterns: <ChunkPattern>[pattern],
      );

      final level = LevelRegistry.byId(LevelId.field).copyWith(
        chunkPatternSource: source,
        earlyPatternChunks: 0,
        noEnemyChunks: 0,
      );

      final core = GameCore(
        seed: 42,
        levelDefinition: level,
        playerCharacter: PlayerCharacterRegistry.eloise,
      );

      final snapshot = core.buildSnapshot();
      final hashash = snapshot.entities
          .where((entity) => entity.enemyId == EnemyId.hashash)
          .toList();

      expect(snapshot.tick, 0);
      expect(hashash.length, 1);
      expect(hashash.single.pos.x, closeTo(600.0, 1e-9));
      expect(hashash.single.anim, AnimKey.spawn);
      expect(hashash.single.animFrame, 0);
      expect(hashash.single.statusVisualMask, EntityStatusVisualMask.none);
      expect(hashash.single.controlLockMask, isNonZero);
      expect(
        hashash.single.controlLockMask & EntityControlLockMask.move,
        EntityControlLockMask.move,
      );
      expect(
        hashash.single.controlLockMask & EntityControlLockMask.jump,
        EntityControlLockMask.jump,
      );
      expect(
        hashash.single.controlLockMask & EntityControlLockMask.dash,
        EntityControlLockMask.dash,
      );
      expect(
        hashash.single.controlLockMask & EntityControlLockMask.strike,
        EntityControlLockMask.strike,
      );
      expect(
        hashash.single.controlLockMask & EntityControlLockMask.ranged,
        EntityControlLockMask.ranged,
      );
      expect(
        hashash.single.controlLockMask & EntityControlLockMask.nav,
        EntityControlLockMask.nav,
      );
      expect(
        hashash.single.controlLockMask & EntityControlLockMask.cast,
        isZero,
      );
      expect(
        hashash.single.controlLockMask & EntityControlLockMask.stun,
        isZero,
      );
    },
  );
}
