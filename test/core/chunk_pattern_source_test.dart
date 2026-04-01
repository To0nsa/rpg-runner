import 'package:flutter_test/flutter_test.dart';

import 'package:runner_core/track/chunk_pattern.dart';
import 'package:runner_core/track/chunk_pattern_pool.dart';
import 'package:runner_core/track/chunk_pattern_source.dart';
import 'package:runner_core/util/deterministic_rng.dart' show mix32;

void main() {
  test('ChunkPatternPoolSource preserves deterministic selection behavior', () {
    const easy = <ChunkPattern>[
      ChunkPattern(name: 'easy-0'),
      ChunkPattern(name: 'easy-1'),
      ChunkPattern(name: 'easy-2'),
    ];
    const all = <ChunkPattern>[
      ChunkPattern(name: 'all-0'),
      ChunkPattern(name: 'all-1'),
      ChunkPattern(name: 'all-2'),
      ChunkPattern(name: 'all-3'),
    ];
    const source = ChunkPatternPoolSource(
      ChunkPatternPool(easyPatterns: easy, allPatterns: all),
    );
    const seed = 1337;
    const earlyPatternChunks = 3;

    for (var chunkIndex = 0; chunkIndex < 10; chunkIndex += 1) {
      final isEarlyChunk = chunkIndex < earlyPatternChunks;
      final selected = source.patternFor(
        seed: seed,
        chunkIndex: chunkIndex,
        isEarlyChunk: isEarlyChunk,
      );

      final pool = isEarlyChunk ? easy : all;
      final expectedIndex =
          mix32(seed ^ (chunkIndex * 0x9e3779b9) ^ 0x27d4eb2d) % pool.length;
      expect(selected.name, pool[expectedIndex].name);
    }
  });

  test('ChunkPatternPoolSource throws when requested pool is empty', () {
    const source = ChunkPatternPoolSource(
      ChunkPatternPool(
        easyPatterns: <ChunkPattern>[],
        allPatterns: <ChunkPattern>[ChunkPattern(name: 'all')],
      ),
    );

    expect(
      () => source.patternFor(seed: 1, chunkIndex: 0, isEarlyChunk: true),
      throwsA(
        isA<StateError>().having(
          (error) => error.toString(),
          'message',
          contains('easyPatterns is empty'),
        ),
      ),
    );
  });
}
