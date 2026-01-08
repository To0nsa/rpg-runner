/// Groups pattern pools used for procedural track generation.
library;

import 'chunk_pattern.dart';

/// Default count of early chunks that draw from the "easy" pool.
const int defaultEarlyPatternChunks = 3;

/// Default count of early chunks that suppress enemy spawns.
const int defaultNoEnemyChunks = 3;

/// Pattern pools for early vs full difficulty.
class ChunkPatternPool {
  const ChunkPatternPool({
    required this.easyPatterns,
    required this.allPatterns,
  });

  /// Simpler patterns for early chunks.
  final List<ChunkPattern> easyPatterns;

  /// Full pattern pool used after early chunks.
  final List<ChunkPattern> allPatterns;
}
