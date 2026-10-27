import 'package:replay_validator/src/replay_benchmark_fixture.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/levels/level_registry.dart';
import 'package:runner_core/track/chunk_pattern_source.dart';
import 'package:test/test.dart';

void main() {
  for (final levelId in LevelRegistry.compiledLevelIds) {
    for (final seed in [7, 42, 2026, 4401]) {
      test('${levelId.name} fixture preserves 200 selections, seed=$seed', () {
        final registered = LevelRegistry.byId(levelId);
        final original = registered.chunkPatternSource;
        final fixture = replayBenchmarkLevel(levelId).chunkPatternSource;
        var originalBosses = 0;
        for (var index = 0; index < 200; index++) {
          final tier = chunkPatternTierForIndex(
            chunkIndex: index,
            earlyPatternChunks: registered.earlyPatternChunks,
            easyPatternChunks: registered.easyPatternChunks,
            normalPatternChunks: registered.normalPatternChunks,
          );
          final expected = original.selectionFor(
            seed: seed,
            chunkIndex: index,
            tier: tier,
          );
          final actual = fixture.selectionFor(
            seed: seed,
            chunkIndex: index,
            tier: tier,
          );
          expect(actual.pattern.chunkKey, expected.pattern.chunkKey);
          expect(actual.tier, expected.tier);
          expect(actual.assembly?.segmentId, expected.assembly?.segmentId);
          expect(actual.assembly?.runSequence, expected.assembly?.runSequence);
          expect(actual.assembly?.chunkCount, expected.assembly?.chunkCount);
          expect(
            actual.assembly?.repeatsFinalSegment,
            expected.assembly?.repeatsFinalSegment,
          );
          expect(
            actual.pattern.visualSprites,
            same(expected.pattern.visualSprites),
          );
          expect(actual.pattern.traps, same(expected.pattern.traps));
          expect(actual.pattern.spawnMarkers, isEmpty);
          expect(actual.pattern.encounters, isEmpty);
          expect(actual.pattern.bossArena, isNull);
          if (expected.pattern.bossArena != null) originalBosses++;
        }
        if (levelId == LevelId.forest) expect(originalBosses, greaterThan(0));
      });
    }
  }
}
