import '../../track/chunk_pattern_source.dart';
import 'terrain_authoring_seam_signature.dart';

/// Largest finite pre-hard scheduling window enumerated exactly for authoring.
const int maxTerrainAuthoringFiniteWindowChunks = 256;

/// Minimal immutable chunk metadata needed to enumerate reachable seams.
final class TerrainAuthoringSchedulerChunk {
  const TerrainAuthoringSchedulerChunk({
    required this.chunkKey,
    required this.levelId,
    required this.tier,
    required this.assemblyGroupId,
    required this.isActive,
  });

  final String chunkKey;
  final String levelId;
  final ChunkPatternTier tier;
  final String assemblyGroupId;
  final bool isActive;
}

/// Minimal immutable level metadata needed to enumerate reachable seams.
final class TerrainAuthoringSchedulerLevel {
  TerrainAuthoringSchedulerLevel({
    required this.levelId,
    required this.earlyPatternChunks,
    required this.easyPatternChunks,
    required this.normalPatternChunks,
    this.assembly,
  });

  final String levelId;
  final int earlyPatternChunks;
  final int easyPatternChunks;
  final int normalPatternChunks;
  final TerrainAuthoringSchedulerAssembly? assembly;
}

/// Optional deterministic assembly schedule used by one authored level.
final class TerrainAuthoringSchedulerAssembly {
  TerrainAuthoringSchedulerAssembly({
    required this.loopSegments,
    required Iterable<TerrainAuthoringSchedulerSegment> segments,
  }) : segments = List<TerrainAuthoringSchedulerSegment>.unmodifiable(segments);

  final bool loopSegments;
  final List<TerrainAuthoringSchedulerSegment> segments;
}

/// One authored assembly run contract relevant to seam reachability.
final class TerrainAuthoringSchedulerSegment {
  const TerrainAuthoringSchedulerSegment({
    required this.segmentId,
    required this.groupId,
    required this.minChunkCount,
    required this.maxChunkCount,
    required this.requireDistinctChunks,
  });

  final String segmentId;
  final String groupId;
  final int minChunkCount;
  final int maxChunkCount;
  final bool requireDistinctChunks;
}

/// Structural scheduler provenance for one directed reachable chunk pair.
final class TerrainAuthoringReachableTransition
    implements Comparable<TerrainAuthoringReachableTransition> {
  const TerrainAuthoringReachableTransition({
    required this.levelId,
    required this.transitionId,
    required this.description,
    required this.leftChunkKey,
    required this.rightChunkKey,
  });

  final String levelId;
  final String transitionId;
  final String description;
  final String leftChunkKey;
  final String rightChunkKey;

  TerrainAuthoringSeamTransition get authoringTransition =>
      TerrainAuthoringSeamTransition(
        levelId: levelId,
        transitionId: transitionId,
        leftChunkKey: leftChunkKey,
        rightChunkKey: rightChunkKey,
      );

  String get canonicalRecord => authoringTransition.canonicalRecord;

  @override
  int compareTo(TerrainAuthoringReachableTransition other) {
    var order = levelId.compareTo(other.levelId);
    if (order != 0) return order;
    order = transitionId.compareTo(other.transitionId);
    if (order != 0) return order;
    order = leftChunkKey.compareTo(other.leftChunkKey);
    return order != 0 ? order : rightChunkKey.compareTo(other.rightChunkKey);
  }
}

/// Stable blocker found while proving finite scheduler reachability.
final class TerrainAuthoringSchedulerIssue
    implements Comparable<TerrainAuthoringSchedulerIssue> {
  const TerrainAuthoringSchedulerIssue({
    required this.code,
    required this.message,
    required this.levelId,
  });

  final String code;
  final String message;
  final String levelId;

  @override
  int compareTo(TerrainAuthoringSchedulerIssue other) {
    var order = levelId.compareTo(other.levelId);
    if (order != 0) return order;
    order = code.compareTo(other.code);
    return order != 0 ? order : message.compareTo(other.message);
  }
}

/// Canonical scheduler reachability result shared by editor and generation.
final class TerrainAuthoringSchedulerResult {
  TerrainAuthoringSchedulerResult({
    required Iterable<TerrainAuthoringReachableTransition> transitions,
    required Iterable<TerrainAuthoringSchedulerIssue> issues,
  }) : transitions = List<TerrainAuthoringReachableTransition>.unmodifiable(
         List<TerrainAuthoringReachableTransition>.of(transitions)..sort(),
       ),
       issues = List<TerrainAuthoringSchedulerIssue>.unmodifiable(
         List<TerrainAuthoringSchedulerIssue>.of(issues)..sort(),
       ) {
    signature = TerrainAuthoringSeamSignature(
      this.transitions.map((transition) => transition.authoringTransition),
    );
  }

  final List<TerrainAuthoringReachableTransition> transitions;
  final List<TerrainAuthoringSchedulerIssue> issues;
  late final TerrainAuthoringSeamSignature signature;
}

/// Enumerates every scheduler-reachable directed chunk pair without RNG.
///
/// Tier fallback, assembly runs, distinct selection, loop behavior, and the
/// steady hard tail mirror [ChunkPatternSource] construction. Invalid pools or
/// an excessive finite window fail closed and never require sampled seeds.
TerrainAuthoringSchedulerResult enumerateTerrainAuthoringReachability({
  required Iterable<TerrainAuthoringSchedulerChunk> chunks,
  required Iterable<TerrainAuthoringSchedulerLevel> levels,
}) {
  final orderedChunks = chunks.where((chunk) => chunk.isActive).toList()
    ..sort(_compareChunks);
  final orderedLevels = levels.toList()
    ..sort((left, right) => left.levelId.compareTo(right.levelId));
  final issues = <TerrainAuthoringSchedulerIssue>[];
  final levelById = <String, TerrainAuthoringSchedulerLevel>{
    for (final level in orderedLevels) level.levelId: level,
  };
  for (final levelId in orderedChunks.map((chunk) => chunk.levelId).toSet()) {
    if (levelById.containsKey(levelId)) continue;
    issues.add(
      TerrainAuthoringSchedulerIssue(
        code: 'terrain_authoring_scheduler_level_context_missing',
        message:
            'Active chunks for level $levelId cannot be seam-validated because '
            'its authored scheduler context is unavailable.',
        levelId: levelId,
      ),
    );
  }

  final transitions = <TerrainAuthoringReachableTransition>[];
  final issueKeys = <String>{};
  for (final level in orderedLevels) {
    final levelChunks = orderedChunks
        .where((chunk) => chunk.levelId == level.levelId)
        .toList(growable: false);
    if (levelChunks.isEmpty) continue;
    transitions.addAll(
      _SchedulerEnumerator(
        level: level,
        chunks: levelChunks,
        issues: issues,
        issueKeys: issueKeys,
      ).enumerate(),
    );
  }
  return TerrainAuthoringSchedulerResult(
    transitions: transitions,
    issues: issues,
  );
}

final class _SchedulerEnumerator {
  _SchedulerEnumerator({
    required this.level,
    required this.chunks,
    required this.issues,
    required this.issueKeys,
  });

  final TerrainAuthoringSchedulerLevel level;
  final List<TerrainAuthoringSchedulerChunk> chunks;
  final List<TerrainAuthoringSchedulerIssue> issues;
  final Set<String> issueKeys;

  List<TerrainAuthoringReachableTransition> enumerate() {
    final assembly = level.assembly;
    if (assembly == null || assembly.segments.isEmpty) {
      return _enumerateTierPools();
    }
    return _enumerateAssembly(assembly);
  }

  List<TerrainAuthoringReachableTransition> _enumerateTierPools() {
    final transitions = <TerrainAuthoringReachableTransition>[];
    final windows = <(ChunkPatternTier, int)>[
      (ChunkPatternTier.early, level.earlyPatternChunks),
      (ChunkPatternTier.easy, level.easyPatternChunks),
      (ChunkPatternTier.normal, level.normalPatternChunks),
    ].where((window) => window.$2 > 0).toList(growable: false);
    for (final window in windows) {
      if (window.$2 < 2) continue;
      _addPoolPairs(
        transitions,
        transitionId: 'tier=${window.$1.name}:within-window',
        description: 'within ${window.$1.name} tier pool',
        left: _resolvePool(tier: window.$1),
        right: _resolvePool(tier: window.$1),
        distinctWithinRun: false,
      );
    }
    final scheduledTiers = <ChunkPatternTier>[
      ...windows.map((window) => window.$1),
      ChunkPatternTier.hard,
    ];
    for (var index = 0; index < scheduledTiers.length - 1; index += 1) {
      final leftTier = scheduledTiers[index];
      final rightTier = scheduledTiers[index + 1];
      _addPoolPairs(
        transitions,
        transitionId: 'tier=${leftTier.name}>${rightTier.name}:boundary',
        description: 'tier boundary ${leftTier.name} -> ${rightTier.name}',
        left: _resolvePool(tier: leftTier),
        right: _resolvePool(tier: rightTier),
        distinctWithinRun: false,
      );
    }
    _addPoolPairs(
      transitions,
      transitionId: 'steady-hard:tier=hard>hard',
      description: 'steady hard tier pool',
      left: _resolvePool(tier: ChunkPatternTier.hard),
      right: _resolvePool(tier: ChunkPatternTier.hard),
      distinctWithinRun: false,
    );
    return _deduplicateTransitions(transitions);
  }

  List<TerrainAuthoringReachableTransition> _enumerateAssembly(
    TerrainAuthoringSchedulerAssembly assembly,
  ) {
    final transitions = <TerrainAuthoringReachableTransition>[];
    final hardStart = _hardStart(level);
    if (hardStart > maxTerrainAuthoringFiniteWindowChunks) {
      _addIssue(
        key: 'capacity|${level.levelId}',
        code: 'terrain_authoring_scheduler_analysis_capacity_exceeded',
        message:
            'Level ${level.levelId} has a $hardStart-chunk finite tier window '
            'with assembly enabled; exact seam analysis supports at most '
            '$maxTerrainAuthoringFiniteWindowChunks before the hard tail.',
      );
    } else {
      var states = <_AssemblyState>{
        for (final length in _boundedLengths(
          assembly.segments.first,
          remainingFiniteIndexes: hardStart + 1,
        ))
          _AssemblyState(segmentIndex: 0, offset: 0, runLength: length),
      };

      for (var index = 0; index < hardStart; index += 1) {
        final leftTier = _tierForIndex(level, index);
        final rightTier = _tierForIndex(level, index + 1);
        final nextStates = <_AssemblyState>{};
        final orderedStates = states.toList()..sort();
        for (final state in orderedStates) {
          final segment = assembly.segments[state.segmentIndex];
          if (state.offset + 1 < state.runLength) {
            nextStates.add(state.nextOffset());
            _validateDistinctCapacity(segment, leftTier);
            _validateDistinctCapacity(segment, rightTier);
            _addPoolPairs(
              transitions,
              transitionId:
                  'tier=${leftTier.name}>${rightTier.name}:'
                  'segment=${segment.segmentId}:within-run',
              description:
                  'within ${segment.segmentId} (${segment.groupId}) run',
              left: _resolvePool(tier: leftTier, groupId: segment.groupId),
              right: _resolvePool(tier: rightTier, groupId: segment.groupId),
              distinctWithinRun: segment.requireDistinctChunks,
            );
            continue;
          }

          final nextSegmentIndex = _nextSegmentIndex(
            assembly,
            state.segmentIndex,
          );
          final nextSegment = assembly.segments[nextSegmentIndex];
          _validateDistinctCapacity(segment, leftTier);
          _validateDistinctCapacity(nextSegment, rightTier);
          for (final length in _boundedLengths(
            nextSegment,
            remainingFiniteIndexes: hardStart - index,
          )) {
            nextStates.add(
              _AssemblyState(
                segmentIndex: nextSegmentIndex,
                offset: 0,
                runLength: length,
              ),
            );
          }
          _addPoolPairs(
            transitions,
            transitionId:
                'tier=${leftTier.name}>${rightTier.name}:'
                'segment=${segment.segmentId}>${nextSegment.segmentId}:'
                'between-runs',
            description:
                'between ${segment.segmentId} (${segment.groupId}) and '
                '${nextSegment.segmentId} (${nextSegment.groupId}) runs',
            left: _resolvePool(tier: leftTier, groupId: segment.groupId),
            right: _resolvePool(tier: rightTier, groupId: nextSegment.groupId),
            distinctWithinRun: false,
          );
        }
        states = nextStates;
      }
    }

    for (
      var segmentIndex = 0;
      segmentIndex < assembly.segments.length;
      segmentIndex += 1
    ) {
      final segment = assembly.segments[segmentIndex];
      _validateDistinctCapacity(segment, ChunkPatternTier.hard);
      if (segment.maxChunkCount >= 2) {
        _addPoolPairs(
          transitions,
          transitionId: 'steady-hard:segment=${segment.segmentId}:within-run',
          description:
              'within ${segment.segmentId} (${segment.groupId}) hard run',
          left: _resolvePool(
            tier: ChunkPatternTier.hard,
            groupId: segment.groupId,
          ),
          right: _resolvePool(
            tier: ChunkPatternTier.hard,
            groupId: segment.groupId,
          ),
          distinctWithinRun: segment.requireDistinctChunks,
        );
      }
      final nextIndex = _nextSegmentIndex(assembly, segmentIndex);
      final nextSegment = assembly.segments[nextIndex];
      _addPoolPairs(
        transitions,
        transitionId:
            'steady-hard:segment=${segment.segmentId}>'
            '${nextSegment.segmentId}:between-runs',
        description:
            'between ${segment.segmentId} (${segment.groupId}) and '
            '${nextSegment.segmentId} (${nextSegment.groupId}) hard runs',
        left: _resolvePool(
          tier: ChunkPatternTier.hard,
          groupId: segment.groupId,
        ),
        right: _resolvePool(
          tier: ChunkPatternTier.hard,
          groupId: nextSegment.groupId,
        ),
        distinctWithinRun: false,
      );
    }
    return _deduplicateTransitions(transitions);
  }

  void _validateDistinctCapacity(
    TerrainAuthoringSchedulerSegment segment,
    ChunkPatternTier tier,
  ) {
    if (!segment.requireDistinctChunks) return;
    final pool = _resolvePool(tier: tier, groupId: segment.groupId);
    if (pool == null || pool.chunks.length >= segment.maxChunkCount) return;
    _addIssue(
      key: 'distinct|${level.levelId}|${segment.segmentId}|${tier.name}',
      code: 'terrain_authoring_scheduler_distinct_pool_too_small',
      message:
          'Level ${level.levelId} segment ${segment.segmentId} may request '
          '${segment.maxChunkCount} distinct ${tier.name} chunks from '
          'resolved ${pool.resolvedTier.name}/${segment.groupId}, but only '
          '${pool.chunks.length} active chunk(s) are eligible.',
    );
  }

  _ResolvedPool? _resolvePool({
    required ChunkPatternTier tier,
    String? groupId,
  }) {
    for (final candidateTier in fallbackOrderForTier(tier)) {
      final eligible =
          chunks
              .where(
                (chunk) =>
                    chunk.tier == candidateTier &&
                    (groupId == null || chunk.assemblyGroupId == groupId),
              )
              .toList(growable: false)
            ..sort(_compareChunks);
      if (eligible.isNotEmpty) {
        return _ResolvedPool(
          resolvedTier: candidateTier,
          groupId: groupId,
          chunks: eligible,
        );
      }
    }
    _addIssue(
      key: 'empty|${level.levelId}|${tier.name}|${groupId ?? '*'}',
      code: 'terrain_authoring_scheduler_pool_empty',
      message:
          'Level ${level.levelId} has no active chunk in any fallback tier '
          'for requested ${tier.name}'
          '${groupId == null ? '' : ' and assembly group $groupId'}.',
    );
    return null;
  }

  void _addPoolPairs(
    List<TerrainAuthoringReachableTransition> target, {
    required String transitionId,
    required String description,
    required _ResolvedPool? left,
    required _ResolvedPool? right,
    required bool distinctWithinRun,
  }) {
    if (left == null || right == null) return;
    final sameResolvedPool =
        left.resolvedTier == right.resolvedTier &&
        left.groupId == right.groupId;
    for (final leftChunk in left.chunks) {
      for (final rightChunk in right.chunks) {
        if (distinctWithinRun &&
            sameResolvedPool &&
            leftChunk.chunkKey == rightChunk.chunkKey) {
          continue;
        }
        target.add(
          TerrainAuthoringReachableTransition(
            levelId: level.levelId,
            transitionId: transitionId,
            description:
                '$description; resolved ${left.resolvedTier.name}'
                '${left.groupId == null ? '' : '/${left.groupId}'} -> '
                '${right.resolvedTier.name}'
                '${right.groupId == null ? '' : '/${right.groupId}'}',
            leftChunkKey: leftChunk.chunkKey,
            rightChunkKey: rightChunk.chunkKey,
          ),
        );
      }
    }
  }

  void _addIssue({
    required String key,
    required String code,
    required String message,
  }) {
    if (!issueKeys.add(key)) return;
    issues.add(
      TerrainAuthoringSchedulerIssue(
        code: code,
        message: message,
        levelId: level.levelId,
      ),
    );
  }
}

final class _ResolvedPool {
  const _ResolvedPool({
    required this.resolvedTier,
    required this.groupId,
    required this.chunks,
  });

  final ChunkPatternTier resolvedTier;
  final String? groupId;
  final List<TerrainAuthoringSchedulerChunk> chunks;
}

final class _AssemblyState implements Comparable<_AssemblyState> {
  const _AssemblyState({
    required this.segmentIndex,
    required this.offset,
    required this.runLength,
  });

  final int segmentIndex;
  final int offset;
  final int runLength;

  _AssemblyState nextOffset() => _AssemblyState(
    segmentIndex: segmentIndex,
    offset: offset + 1,
    runLength: runLength,
  );

  @override
  int compareTo(_AssemblyState other) {
    var order = segmentIndex.compareTo(other.segmentIndex);
    if (order != 0) return order;
    order = offset.compareTo(other.offset);
    return order != 0 ? order : runLength.compareTo(other.runLength);
  }

  @override
  bool operator ==(Object other) =>
      other is _AssemblyState &&
      segmentIndex == other.segmentIndex &&
      offset == other.offset &&
      runLength == other.runLength;

  @override
  int get hashCode => Object.hash(segmentIndex, offset, runLength);
}

List<int> _boundedLengths(
  TerrainAuthoringSchedulerSegment segment, {
  required int remainingFiniteIndexes,
}) {
  final values = <int>[];
  final exactMaximum = segment.maxChunkCount < remainingFiniteIndexes + 1
      ? segment.maxChunkCount
      : remainingFiniteIndexes + 1;
  for (var value = segment.minChunkCount; value <= exactMaximum; value += 1) {
    values.add(value);
  }
  if (values.isEmpty) values.add(segment.minChunkCount);
  return values;
}

int _nextSegmentIndex(
  TerrainAuthoringSchedulerAssembly assembly,
  int currentIndex,
) {
  final lastIndex = assembly.segments.length - 1;
  if (currentIndex < lastIndex) return currentIndex + 1;
  return assembly.loopSegments ? 0 : lastIndex;
}

ChunkPatternTier _tierForIndex(
  TerrainAuthoringSchedulerLevel level,
  int index,
) {
  if (index < level.earlyPatternChunks) return ChunkPatternTier.early;
  final normalStart = level.earlyPatternChunks + level.easyPatternChunks;
  if (index < normalStart) return ChunkPatternTier.easy;
  final hardStart = normalStart + level.normalPatternChunks;
  return index < hardStart ? ChunkPatternTier.normal : ChunkPatternTier.hard;
}

int _hardStart(TerrainAuthoringSchedulerLevel level) =>
    level.earlyPatternChunks +
    level.easyPatternChunks +
    level.normalPatternChunks;

List<TerrainAuthoringReachableTransition> _deduplicateTransitions(
  Iterable<TerrainAuthoringReachableTransition> source,
) {
  final byRecord = <String, TerrainAuthoringReachableTransition>{};
  for (final transition in source) {
    byRecord[transition.canonicalRecord] = transition;
  }
  return byRecord.values.toList()..sort();
}

int _compareChunks(
  TerrainAuthoringSchedulerChunk left,
  TerrainAuthoringSchedulerChunk right,
) {
  var order = left.levelId.compareTo(right.levelId);
  if (order != 0) return order;
  order = left.tier.index.compareTo(right.tier.index);
  if (order != 0) return order;
  order = left.assemblyGroupId.compareTo(right.assemblyGroupId);
  return order != 0 ? order : left.chunkKey.compareTo(right.chunkKey);
}
