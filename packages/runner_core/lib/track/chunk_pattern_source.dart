/// Abstraction for deterministic chunk pattern selection.
library;

import '../levels/level_assembly.dart';
import '../util/deterministic_rng.dart' show mix32;
import 'chunk_pattern.dart';

/// Requested chunk pacing tier for a streamed chunk index.
enum ChunkPatternTier { early, easy, normal, hard }

/// Deterministic pattern + render-theme selection for a chunk index.
class ChunkPatternSelection {
  const ChunkPatternSelection({required this.pattern});

  final ChunkPattern pattern;
}

/// Resolves a [ChunkPattern] for a given chunk index and progression state.
abstract class ChunkPatternSource {
  const ChunkPatternSource();

  /// Returns the full deterministic chunk selection for [chunkIndex].
  ///
  /// [tier] is the requested authored pacing bucket for this chunk.
  ChunkPatternSelection selectionFor({
    required int seed,
    required int chunkIndex,
    required ChunkPatternTier tier,
  });

  /// Convenience accessor for just the selected [ChunkPattern].
  ChunkPattern patternFor({
    required int seed,
    required int chunkIndex,
    required ChunkPatternTier tier,
  }) {
    return selectionFor(
      seed: seed,
      chunkIndex: chunkIndex,
      tier: tier,
    ).pattern;
  }
}

/// Deterministic [ChunkPatternSource] backed by explicit authored lists.
class ChunkPatternListSource extends ChunkPatternSource {
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
  ChunkPatternSelection selectionFor({
    required int seed,
    required int chunkIndex,
    required ChunkPatternTier tier,
  }) {
    final patterns = resolvePatternsForTier(
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
    return ChunkPatternSelection(pattern: patterns[idx]);
  }
}

/// Deterministic [ChunkPatternSource] that applies authored level assembly
/// sequencing on top of explicit authored chunk lists.
class AssembledChunkPatternSource extends ChunkPatternSource {
  AssembledChunkPatternSource({
    required this.baseSource,
    required this.assembly,
  }) : assert(assembly.segments.isNotEmpty);

  final ChunkPatternListSource baseSource;
  final LevelAssemblyDefinition assembly;

  final List<_ResolvedAssemblyRun> _resolvedRuns = <_ResolvedAssemblyRun>[];
  int _nextRunStartChunkIndex = 0;
  int _nextRunSequence = 0;
  int? _resolvedSeed;

  @override
  ChunkPatternSelection selectionFor({
    required int seed,
    required int chunkIndex,
    required ChunkPatternTier tier,
  }) {
    final run = _resolvedRunFor(seed: seed, chunkIndex: chunkIndex);
    final eligiblePatterns = _eligiblePatternsForSegment(
      tier: tier,
      groupId: run.segment.groupId,
    );
    if (eligiblePatterns == null || eligiblePatterns.isEmpty) {
      throw StateError(
        'AssembledChunkPatternSource has no patterns available for '
        'groupId="${run.segment.groupId}", tier=${tier.name}, '
        'chunkIndex=$chunkIndex.',
      );
    }

    final offsetInRun = chunkIndex - run.startChunkIndex;
    final selectedPattern = run.segment.requireDistinctChunks
        ? _distinctPatternForRun(
            seed: seed,
            run: run,
            eligiblePatterns: eligiblePatterns,
            offsetInRun: offsetInRun,
          )
        : _patternForChunk(
            seed: seed,
            chunkIndex: chunkIndex,
            eligiblePatterns: eligiblePatterns,
          );

    return ChunkPatternSelection(pattern: selectedPattern);
  }

  _ResolvedAssemblyRun _resolvedRunFor({
    required int seed,
    required int chunkIndex,
  }) {
    if (_resolvedSeed != seed) {
      _resolvedSeed = seed;
      _resolvedRuns.clear();
      _nextRunStartChunkIndex = 0;
      _nextRunSequence = 0;
    }
    for (final run in _resolvedRuns) {
      if (chunkIndex >= run.startChunkIndex && chunkIndex < run.endChunkIndex) {
        return run;
      }
    }

    while (true) {
      final run = _createRun(seed: seed, runSequence: _nextRunSequence);
      _resolvedRuns.add(run);
      _nextRunSequence += 1;
      _nextRunStartChunkIndex = run.endChunkIndex;
      if (chunkIndex < run.endChunkIndex) {
        return run;
      }
    }
  }

  _ResolvedAssemblyRun _createRun({
    required int seed,
    required int runSequence,
  }) {
    final segmentState = _segmentStateForRunSequence(runSequence);
    final segment = segmentState.segment;
    final countRange = segment.maxChunkCount - segment.minChunkCount + 1;
    final countHash = mix32(
      seed ^
          (runSequence * 0x9e3779b9) ^
          (segmentState.segmentIndex * 0x85ebca6b) ^
          (segmentState.cycleIndex * 0xc2b2ae35) ^
          0x27d4eb2d,
    );
    final chunkCount = segment.minChunkCount + (countHash % countRange);
    return _ResolvedAssemblyRun(
      sequence: runSequence,
      cycleIndex: segmentState.cycleIndex,
      segmentIndex: segmentState.segmentIndex,
      segment: segment,
      startChunkIndex: _nextRunStartChunkIndex,
      endChunkIndex: _nextRunStartChunkIndex + chunkCount,
    );
  }

  _SegmentRunState _segmentStateForRunSequence(int runSequence) {
    final segments = assembly.segments;
    if (assembly.loopSegments) {
      return _SegmentRunState(
        segment: segments[runSequence % segments.length],
        segmentIndex: runSequence % segments.length,
        cycleIndex: runSequence ~/ segments.length,
      );
    }

    final lastIndex = segments.length - 1;
    if (runSequence <= lastIndex) {
      return _SegmentRunState(
        segment: segments[runSequence],
        segmentIndex: runSequence,
        cycleIndex: 0,
      );
    }

    return _SegmentRunState(
      segment: segments[lastIndex],
      segmentIndex: lastIndex,
      cycleIndex: runSequence - lastIndex,
    );
  }

  List<ChunkPattern>? _eligiblePatternsForSegment({
    required ChunkPatternTier tier,
    required String groupId,
  }) {
    for (final candidateTier in fallbackOrderForTier(tier)) {
      final patterns = switch (candidateTier) {
        ChunkPatternTier.early => baseSource.earlyPatterns,
        ChunkPatternTier.easy => baseSource.easyPatterns,
        ChunkPatternTier.normal => baseSource.normalPatterns,
        ChunkPatternTier.hard => baseSource.hardPatterns,
      };
      final eligible = patterns
          .where((pattern) => pattern.assemblyGroupId == groupId)
          .toList(growable: false);
      if (eligible.isNotEmpty) {
        return eligible;
      }
    }
    return null;
  }

  ChunkPattern _patternForChunk({
    required int seed,
    required int chunkIndex,
    required List<ChunkPattern> eligiblePatterns,
  }) {
    final h = mix32(seed ^ (chunkIndex * 0x9e3779b9) ^ 0x27d4eb2d);
    return eligiblePatterns[h % eligiblePatterns.length];
  }

  ChunkPattern _distinctPatternForRun({
    required int seed,
    required _ResolvedAssemblyRun run,
    required List<ChunkPattern> eligiblePatterns,
    required int offsetInRun,
  }) {
    if (eligiblePatterns.length < run.length) {
      throw StateError(
        'AssembledChunkPatternSource requires ${run.length} distinct chunks for '
        'segment "${run.segment.segmentId}" but only found '
        '${eligiblePatterns.length} eligible chunk(s).',
      );
    }

    final decorated = <_HashedChunkPattern>[];
    for (var i = 0; i < eligiblePatterns.length; i += 1) {
      final pattern = eligiblePatterns[i];
      decorated.add(
        _HashedChunkPattern(
          pattern: pattern,
          hash: mix32(
            seed ^
                (run.sequence * 0x9e3779b9) ^
                (run.segmentIndex * 0x85ebca6b) ^
                (run.cycleIndex * 0xc2b2ae35) ^
                (i * 0x27d4eb2d),
          ),
        ),
      );
    }
    decorated.sort((a, b) {
      final hashCompare = a.hash.compareTo(b.hash);
      if (hashCompare != 0) {
        return hashCompare;
      }
      final aId = a.pattern.chunkKey ?? a.pattern.name;
      final bId = b.pattern.chunkKey ?? b.pattern.name;
      final idCompare = aId.compareTo(bId);
      if (idCompare != 0) {
        return idCompare;
      }
      return a.pattern.name.compareTo(b.pattern.name);
    });
    return decorated[offsetInRun].pattern;
  }
}

List<ChunkPattern>? resolvePatternsForTier({
  required ChunkPatternTier tier,
  required List<ChunkPattern> earlyPatterns,
  required List<ChunkPattern> easyPatterns,
  required List<ChunkPattern> normalPatterns,
  required List<ChunkPattern> hardPatterns,
}) {
  for (final candidateTier in fallbackOrderForTier(tier)) {
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

List<ChunkPatternTier> fallbackOrderForTier(ChunkPatternTier tier) {
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

class _ResolvedAssemblyRun {
  const _ResolvedAssemblyRun({
    required this.sequence,
    required this.cycleIndex,
    required this.segmentIndex,
    required this.segment,
    required this.startChunkIndex,
    required this.endChunkIndex,
  });

  final int sequence;
  final int cycleIndex;
  final int segmentIndex;
  final LevelAssemblySegment segment;
  final int startChunkIndex;
  final int endChunkIndex;

  int get length => endChunkIndex - startChunkIndex;
}

class _SegmentRunState {
  const _SegmentRunState({
    required this.segment,
    required this.segmentIndex,
    required this.cycleIndex,
  });

  final LevelAssemblySegment segment;
  final int segmentIndex;
  final int cycleIndex;
}

class _HashedChunkPattern {
  const _HashedChunkPattern({required this.pattern, required this.hash});

  final ChunkPattern pattern;
  final int hash;
}
