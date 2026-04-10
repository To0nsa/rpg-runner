import 'package:flutter_test/flutter_test.dart';

import 'package:runner_core/track/chunk_pattern.dart';
import 'package:runner_core/track/chunk_pattern_pool.dart';
import 'package:runner_core/track/chunk_pattern_source.dart';
import 'package:runner_core/track/track_streamer.dart';
import 'package:runner_core/tuning/track_tuning.dart';

void main() {
  test('passes chunkKey and gapId through streamed runtime metadata', () {
    const pattern = ChunkPattern(
      name: 'identity-pattern',
      chunkKey: 'chunk-field-001',
      groundGaps: <GapRel>[GapRel(x: 128.0, width: 80.0, gapId: 'gap-001')],
    );
    const source = ChunkPatternPoolSource(
      ChunkPatternPool(
        easyPatterns: <ChunkPattern>[pattern],
        hardPatterns: <ChunkPattern>[pattern],
      ),
    );

    final streamer = TrackStreamer(
      seed: 42,
      tuning: const TrackTuning(spawnAheadMargin: 0.0),
      groundTopY: 220.0,
      patternSource: source,
      earlyPatternChunks: 0,
      noEnemyChunks: 0,
    );

    final result = streamer.step(
      cameraLeft: 0.0,
      cameraRight: 0.0,
      spawnEnemy: (_) {},
    );

    expect(result.spawnedChunks, hasLength(1));
    expect(result.spawnedChunks.single.patternName, 'identity-pattern');
    expect(result.spawnedChunks.single.chunkKey, 'chunk-field-001');
    expect(streamer.dynamicGroundGaps, hasLength(1));
    expect(streamer.dynamicGroundGaps.single.gapId, 'gap-001');
  });
}
