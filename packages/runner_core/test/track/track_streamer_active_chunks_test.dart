import 'package:runner_core/track/chunk_pattern.dart';
import 'package:runner_core/track/chunk_pattern_source.dart';
import 'package:runner_core/track/track_streamer.dart';
import 'package:runner_core/tuning/track_tuning.dart';
import 'package:test/test.dart';

void main() {
  test(
    'publishes current selected chunk identities with geometry rebuilds',
    () {
      const first = ChunkPattern(name: 'first', chunkKey: 'field_flat');
      const source = ChunkPatternListSource(
        earlyPatterns: <ChunkPattern>[first],
        easyPatterns: <ChunkPattern>[first],
        normalPatterns: <ChunkPattern>[first],
        hardPatterns: <ChunkPattern>[first],
      );
      final streamer = TrackStreamer(
        seed: 42,
        tuning: const TrackTuning(spawnAheadMargin: 0.0, cullBehindMargin: 0.0),
        groundTopY: 220.0,
        patternSource: source,
        earlyPatternChunks: 1,
        easyPatternChunks: 1,
        normalPatternChunks: 1,
        noEnemyChunks: 0,
      );

      streamer.step(cameraLeft: 0.0, cameraRight: 1800.0, spawnEnemy: (_) {});

      expect(streamer.activeChunks, hasLength(4));
      expect(streamer.activeChunks.map((chunk) => chunk.index), <int>[
        0,
        1,
        2,
        3,
      ]);
      expect(streamer.activeChunks.map((chunk) => chunk.startX), <double>[
        0.0,
        600.0,
        1200.0,
        1800.0,
      ]);
      expect(streamer.activeChunks.map((chunk) => chunk.chunkKey), <String?>[
        'field_flat',
        'field_flat',
        'field_flat',
        'field_flat',
      ]);
      expect(streamer.difficultyAtWorldX(599.999), ChunkPatternTier.early);
      expect(streamer.difficultyAtWorldX(600.0), ChunkPatternTier.easy);
      expect(streamer.difficultyAtWorldX(1200.0), ChunkPatternTier.normal);
      expect(streamer.difficultyAtWorldX(1800.0), ChunkPatternTier.hard);
      expect(() => streamer.activeChunks.clear(), throwsUnsupportedError);

      streamer.step(
        cameraLeft: 2401.0,
        cameraRight: 2400.0,
        spawnEnemy: (_) {},
      );

      expect(streamer.activeChunks.map((chunk) => chunk.index), <int>[4]);
      expect(streamer.activeChunks.single.startX, 2400.0);
    },
  );

  test('retains an explicit missing-key state for legacy selections', () {
    const pattern = ChunkPattern(name: 'legacy');
    const source = ChunkPatternListSource(
      easyPatterns: <ChunkPattern>[pattern],
      hardPatterns: <ChunkPattern>[pattern],
    );
    final streamer = TrackStreamer(
      seed: 42,
      tuning: const TrackTuning(spawnAheadMargin: 0.0),
      groundTopY: 220.0,
      patternSource: source,
      earlyPatternChunks: 0,
      noEnemyChunks: 0,
    );

    streamer.step(cameraLeft: 0.0, cameraRight: 0.0, spawnEnemy: (_) {});

    expect(streamer.activeChunks.single.chunkKey, isNull);
    expect(streamer.difficultyAtWorldX(0.0), ChunkPatternTier.hard);
  });
}
