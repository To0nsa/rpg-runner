import '../../track/chunk_pattern_source.dart';
import 'terrain_authoring_seam_signature.dart';
import 'terrain_connection_schedule.dart';

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
    this.firstChunkKey,
    this.assembly,
  });

  final String levelId;
  final int earlyPatternChunks;
  final int easyPatternChunks;
  final int normalPatternChunks;
  final String? firstChunkKey;
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
    this.difficulty,
    required this.minChunkCount,
    required this.maxChunkCount,
    required this.requireDistinctChunks,
  });

  final String segmentId;
  final String groupId;

  /// Exact section tier; null uses the level's progression and fallback.
  final ChunkPatternTier? difficulty;
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
    this.chunkKey,
    this.sectionId,
  });

  final String? chunkKey;
  final String? sectionId;
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
    Map<String, TerrainConnectionSchedule> schedules = const {},
  }) : transitions = List<TerrainAuthoringReachableTransition>.unmodifiable(
         List<TerrainAuthoringReachableTransition>.of(transitions)..sort(),
       ),
       issues = List<TerrainAuthoringSchedulerIssue>.unmodifiable(
         List<TerrainAuthoringSchedulerIssue>.of(issues)..sort(),
       ),
       schedules = Map.unmodifiable(schedules) {
    signature = TerrainAuthoringSeamSignature(
      this.transitions.map((transition) => transition.authoringTransition),
    );
  }

  final List<TerrainAuthoringReachableTransition> transitions;
  final List<TerrainAuthoringSchedulerIssue> issues;
  final Map<String, TerrainConnectionSchedule> schedules;
  late final TerrainAuthoringSeamSignature signature;
}

/// Proves complete schedules using compiled terrain profiles, without RNG.
/// Missing profiles fail admission; structural pool-only checks use
/// [validateTerrainAuthoringFirstChunk] separately.
TerrainAuthoringSchedulerResult enumerateTerrainAuthoringReachability({
  required Iterable<TerrainAuthoringSchedulerChunk> chunks,
  required Iterable<TerrainAuthoringSchedulerLevel> levels,
  Map<String, TerrainChunkConnection> connections = const {},
}) {
  final orderedChunks = chunks.toList()..sort(_compareChunks);
  final orderedLevels = levels.toList()
    ..sort((a, b) => a.levelId.compareTo(b.levelId));
  final issues = <TerrainAuthoringSchedulerIssue>[];
  final transitions = <TerrainAuthoringReachableTransition>[];
  final schedules = <String, TerrainConnectionSchedule>{};
  final levelIds = orderedLevels.map((level) => level.levelId).toSet();
  for (final chunk in orderedChunks) {
    if (chunk.isActive && !levelIds.contains(chunk.levelId)) {
      issues.add(
        TerrainAuthoringSchedulerIssue(
          code: 'terrain_authoring_scheduler_level_context_missing',
          message: 'Active chunk ${chunk.chunkKey} has no Level context.',
          levelId: chunk.levelId,
        ),
      );
    }
  }
  for (final level in orderedLevels) {
    final firstIssue = validateTerrainAuthoringFirstChunk(
      level: level,
      chunks: orderedChunks,
    );
    if (firstIssue != null) {
      issues.add(firstIssue);
      continue;
    }
    try {
      final schedule = TerrainConnectionSchedule.build(
        level: level,
        chunks: orderedChunks,
        connections: connections,
      );
      schedules[level.levelId] = schedule;
      transitions.addAll(schedule.transitions);
    } on TerrainConnectionException catch (error) {
      issues.add(
        TerrainAuthoringSchedulerIssue(
          code: error.code,
          message: error.message,
          levelId: level.levelId,
          chunkKey: error.chunkKey,
          sectionId: error.sectionId,
        ),
      );
    }
  }
  return TerrainAuthoringSchedulerResult(
    transitions: transitions,
    issues: issues,
    schedules: schedules,
  );
}

/// Validates that a configured first chunk belongs to the first runtime pool.
///
/// The eligible pool applies the same first-segment group, exact difficulty,
/// and tier-fallback rules as runtime selection.
TerrainAuthoringSchedulerIssue? validateTerrainAuthoringFirstChunk({
  required TerrainAuthoringSchedulerLevel level,
  required Iterable<TerrainAuthoringSchedulerChunk> chunks,
}) {
  final firstChunkKey = level.firstChunkKey;
  if (firstChunkKey == null) return null;
  final allMatches = chunks
      .where((chunk) => chunk.chunkKey == firstChunkKey)
      .toList(growable: false);
  final levelMatches = allMatches
      .where((chunk) => chunk.levelId == level.levelId)
      .toList(growable: false);
  if (levelMatches.isEmpty) {
    return TerrainAuthoringSchedulerIssue(
      code: allMatches.isEmpty
          ? 'terrain_authoring_first_chunk_missing'
          : 'terrain_authoring_first_chunk_wrong_level',
      message: allMatches.isEmpty
          ? 'Level ${level.levelId} firstChunkKey "$firstChunkKey" does not '
                'identify an authored chunk.'
          : 'Level ${level.levelId} firstChunkKey "$firstChunkKey" belongs '
                'to another level.',
      levelId: level.levelId,
    );
  }
  final candidate = levelMatches.first;
  if (!candidate.isActive) {
    return TerrainAuthoringSchedulerIssue(
      code: 'terrain_authoring_first_chunk_inactive',
      message:
          'Level ${level.levelId} firstChunkKey "$firstChunkKey" must identify an active chunk.',
      levelId: level.levelId,
    );
  }

  final firstTier = _tierForIndex(level, 0);
  final firstSegment = level.assembly?.segments.firstOrNull;
  final requestedTier = firstSegment?.difficulty ?? firstTier;
  final groupId = firstSegment?.groupId;
  final allowFallback = firstSegment?.difficulty == null;
  List<TerrainAuthoringSchedulerChunk> eligible = const [];
  for (final tier
      in allowFallback
          ? fallbackOrderForTier(requestedTier)
          : <ChunkPatternTier>[requestedTier]) {
    eligible = chunks
        .where(
          (chunk) =>
              chunk.isActive &&
              chunk.levelId == level.levelId &&
              chunk.tier == tier &&
              (groupId == null || chunk.assemblyGroupId == groupId),
        )
        .toList(growable: false);
    if (eligible.isNotEmpty) break;
  }
  if (!eligible.any((chunk) => chunk.chunkKey == firstChunkKey)) {
    return TerrainAuthoringSchedulerIssue(
      code: 'terrain_authoring_first_chunk_ineligible',
      message:
          'Level ${level.levelId} firstChunkKey "$firstChunkKey" is not eligible '
          'for the first scheduled slot${groupId == null ? '' : ' in group $groupId'}.',
      levelId: level.levelId,
    );
  }
  return null;
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
