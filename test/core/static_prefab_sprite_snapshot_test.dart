import 'package:flutter_test/flutter_test.dart';

import 'package:runner_core/game_core.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/levels/level_registry.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:runner_core/track/chunk_pattern_source.dart';

void main() {
  test('forest emits static visuals from its authored chunk pools', () {
    final level = LevelRegistry.byId(LevelId.forest);
    final core = GameCore(
      seed: 42,
      levelDefinition: level,
      playerCharacter: PlayerCharacterRegistry.eloise,
    );

    final snapshot = core.buildSnapshot();
    final source = level.chunkPatternSource;
    final pools = source is AssembledChunkPatternSource
        ? source.baseSource
        : source as ChunkPatternListSource;
    final patterns = [
      ...pools.earlyPatterns,
      ...pools.easyPatterns,
      ...pools.normalPatterns,
      ...pools.hardPatterns,
    ];
    final authoredSprites = patterns
        .expand((pattern) => pattern.visualSprites)
        .map(
          (sprite) => (
            sprite.assetPath,
            sprite.srcX,
            sprite.srcY,
            sprite.srcWidth,
            sprite.srcHeight,
            sprite.width,
            sprite.height,
            sprite.zIndex,
            sprite.flipX,
            sprite.flipY,
          ),
        )
        .toSet();
    final renderedChunks = snapshot.stagedTerrainRenderSnapshot!.polygons
        .map(
          (polygon) => (polygon.sourceId.chunkIndex, polygon.sourceId.chunkKey),
        )
        .toSet();
    final expectedCount = renderedChunks.fold(
      0,
      (sum, chunk) =>
          sum +
          patterns
              .firstWhere((pattern) => pattern.chunkKey == chunk.$2)
              .visualSprites
              .length,
    );

    expect(snapshot.tick, 0);
    expect(snapshot.staticPrefabSprites, hasLength(expectedCount));
    for (final sprite in snapshot.staticPrefabSprites) {
      expect(
        authoredSprites,
        contains((
          sprite.assetPath,
          sprite.srcX,
          sprite.srcY,
          sprite.srcWidth,
          sprite.srcHeight,
          sprite.width,
          sprite.height,
          sprite.zIndex,
          sprite.flipX,
          sprite.flipY,
        )),
      );
    }
  });
}
