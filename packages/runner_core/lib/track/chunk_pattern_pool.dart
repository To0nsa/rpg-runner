/// Groups pattern pools used for procedural track generation.
library;

import 'chunk_pattern.dart';

/// Default count of opening chunks that request the `early` tier.
const int defaultEarlyPatternChunks = 3;

/// Default count of chunks after the opening window that request the `easy` tier.
const int defaultEasyPatternChunks = 0;

/// Default count of chunks after the easy window that request the `normal` tier.
const int defaultNormalPatternChunks = 0;

/// Default count of early chunks that suppress enemy spawns.
const int defaultNoEnemyChunks = 3;

/// Tiered pattern pools used for procedural track generation.
class ChunkPatternPool {
  const ChunkPatternPool({
    this.earlyPatterns = const <ChunkPattern>[],
    required this.easyPatterns,
    this.normalPatterns = const <ChunkPattern>[],
    this.hardPatterns = const <ChunkPattern>[],
  });

  /// Tutorial-like opening patterns.
  final List<ChunkPattern> earlyPatterns;

  /// Low-pressure patterns for early run pacing.
  final List<ChunkPattern> easyPatterns;

  /// Baseline gameplay patterns.
  final List<ChunkPattern> normalPatterns;

  /// Highest-pressure patterns.
  final List<ChunkPattern> hardPatterns;
}
