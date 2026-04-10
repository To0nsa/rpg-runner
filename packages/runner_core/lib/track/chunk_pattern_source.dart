/// Abstraction for deterministic chunk pattern selection.
library;

import '../util/deterministic_rng.dart' show mix32;
import 'chunk_pattern.dart';
import 'chunk_pattern_pool.dart';

/// Requested chunk pacing tier for a streamed chunk index.
enum ChunkPatternTier { early, easy, normal, hard }

/// Resolves a [ChunkPattern] for a given chunk index and progression state.
abstract class ChunkPatternSource {
  /// Returns the pattern to use for [chunkIndex].
  ///
  /// [tier] is the requested authored pacing bucket for this chunk.
  ChunkPattern patternFor({
    required int seed,
    required int chunkIndex,
    required ChunkPatternTier tier,
  });
}

/// Deterministic [ChunkPatternSource] backed by explicit authored lists.
class ChunkPatternListSource implements ChunkPatternSource {
  const ChunkPatternListSource({
    this.earlyPatterns = const <ChunkPattern>[],
    required this.easyPatterns,
    this.normalPatterns = const <ChunkPattern>[],
    this.hardPatterns = const <ChunkPattern>[],
  });

  final List<ChunkPattern> earlyPatterns;
  final List<ChunkPattern> easyPatterns;
  final List<ChunkPattern> normalPatterns;
  final List<ChunkPattern> hardPatterns;

  @override
  ChunkPattern patternFor({
    required int seed,
    required int chunkIndex,
    required ChunkPatternTier tier,
  }) {
    final patterns = _resolvePatternsForTier(
      tier: tier,
      earlyPatterns: earlyPatterns,
      easyPatterns: easyPatterns,
      normalPatterns: normalPatterns,
      hardPatterns: hardPatterns,
    );
    if (patterns == null) {
      throw StateError(
        'ChunkPatternListSource has no patterns available for '
        'tier=${tier.name}, chunkIndex=$chunkIndex.',
      );
    }

    final h = mix32(seed ^ (chunkIndex * 0x9e3779b9) ^ 0x27d4eb2d);
    final idx = h % patterns.length;
    return patterns[idx];
  }
}

/// Default [ChunkPatternSource] backed by [ChunkPatternPool].
class ChunkPatternPoolSource implements ChunkPatternSource {
  const ChunkPatternPoolSource(this.pool);

  final ChunkPatternPool pool;

  @override
  ChunkPattern patternFor({
    required int seed,
    required int chunkIndex,
    required ChunkPatternTier tier,
  }) {
    final patterns = _resolvePatternsForTier(
      tier: tier,
      earlyPatterns: pool.earlyPatterns,
      easyPatterns: pool.easyPatterns,
      normalPatterns: pool.normalPatterns,
      hardPatterns: pool.hardPatterns,
    );
    if (patterns == null) {
      throw StateError(
        'ChunkPatternPool has no patterns available for '
        'tier=${tier.name}, chunkIndex=$chunkIndex.',
      );
    }

    // MurmurHash-style mix for uniform deterministic distribution.
    final h = mix32(seed ^ (chunkIndex * 0x9e3779b9) ^ 0x27d4eb2d);
    final idx = h % patterns.length;
    return patterns[idx];
  }
}

List<ChunkPattern>? _resolvePatternsForTier({
  required ChunkPatternTier tier,
  required List<ChunkPattern> earlyPatterns,
  required List<ChunkPattern> easyPatterns,
  required List<ChunkPattern> normalPatterns,
  required List<ChunkPattern> hardPatterns,
}) {
  for (final candidateTier in _fallbackOrderForTier(tier)) {
    final patterns = switch (candidateTier) {
      ChunkPatternTier.early => earlyPatterns,
      ChunkPatternTier.easy => easyPatterns,
      ChunkPatternTier.normal => normalPatterns,
      ChunkPatternTier.hard => hardPatterns,
    };
    if (patterns.isNotEmpty) {
      return patterns;
    }
  }
  return null;
}

List<ChunkPatternTier> _fallbackOrderForTier(ChunkPatternTier tier) {
  return switch (tier) {
    ChunkPatternTier.early => const <ChunkPatternTier>[
      ChunkPatternTier.early,
      ChunkPatternTier.easy,
      ChunkPatternTier.normal,
      ChunkPatternTier.hard,
    ],
    ChunkPatternTier.easy => const <ChunkPatternTier>[
      ChunkPatternTier.easy,
      ChunkPatternTier.early,
      ChunkPatternTier.normal,
      ChunkPatternTier.hard,
    ],
    ChunkPatternTier.normal => const <ChunkPatternTier>[
      ChunkPatternTier.normal,
      ChunkPatternTier.easy,
      ChunkPatternTier.hard,
      ChunkPatternTier.early,
    ],
    ChunkPatternTier.hard => const <ChunkPatternTier>[
      ChunkPatternTier.hard,
      ChunkPatternTier.normal,
      ChunkPatternTier.easy,
      ChunkPatternTier.early,
    ],
  };
}
