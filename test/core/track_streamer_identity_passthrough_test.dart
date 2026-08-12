import 'package:flutter_test/flutter_test.dart';

import 'package:runner_core/track/chunk_pattern.dart';
import 'package:runner_core/track/chunk_pattern_source.dart';
import 'package:runner_core/track/track_streamer.dart';
import 'package:runner_core/tuning/track_tuning.dart';

void main() {
  test('passes chunk identity through streamed runtime metadata', () {
    const pattern = ChunkPattern(
      name: 'identity-pattern',
      chunkKey: 'chunk-field-001',
    );
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

    final result = streamer.step(
      cameraLeft: 0.0,
      cameraRight: 0.0,
      spawnEnemy: (_) {},
    );

    expect(result.spawnedChunks, hasLength(1));
    expect(result.spawnedChunks.single.patternName, 'identity-pattern');
    expect(result.spawnedChunks.single.chunkKey, 'chunk-field-001');
    expect(streamer.activeChunks, hasLength(1));
    expect(streamer.activeChunks.single.index, 0);
    expect(streamer.activeChunks.single.chunkKey, 'chunk-field-001');
  });
}
