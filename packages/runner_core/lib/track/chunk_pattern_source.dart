/// Abstraction for deterministic chunk pattern selection.
library;

import '../util/deterministic_rng.dart' show mix32;
import 'chunk_pattern.dart';
import 'chunk_pattern_pool.dart';

/// Resolves a [ChunkPattern] for a given chunk index and progression state.
abstract class ChunkPatternSource {
  /// Returns the pattern to use for [chunkIndex].
  ///
  /// [isEarlyChunk] controls whether the source should pull from an easier pool.
  ChunkPattern patternFor({
    required int seed,
    required int chunkIndex,
    required bool isEarlyChunk,
  });
}

/// Default [ChunkPatternSource] backed by [ChunkPatternPool].
class ChunkPatternPoolSource implements ChunkPatternSource {
  const ChunkPatternPoolSource(this.pool);

  final ChunkPatternPool pool;

  @override
  ChunkPattern patternFor({
    required int seed,
    required int chunkIndex,
    required bool isEarlyChunk,
  }) {
    final patterns = isEarlyChunk ? pool.easyPatterns : pool.allPatterns;
    if (patterns.isEmpty) {
      final poolName = isEarlyChunk ? 'easyPatterns' : 'allPatterns';
      throw StateError(
        'ChunkPatternPool.$poolName is empty for chunkIndex=$chunkIndex.',
      );
    }

    // MurmurHash-style mix for uniform deterministic distribution.
    final h = mix32(seed ^ (chunkIndex * 0x9e3779b9) ^ 0x27d4eb2d);
    final idx = h % patterns.length;
    return patterns[idx];
  }
}
