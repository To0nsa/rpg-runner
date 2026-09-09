import 'package:runner_core/collision/terrain/terrain_authoring_issue.dart';
import 'package:runner_core/collision/terrain/terrain_authoring_scheduler.dart';
import 'package:runner_core/collision/terrain/terrain_authoring_seam_signature.dart';
import 'package:runner_core/track/chunk_pattern_source.dart';

import 'polygon_terrain_compilation.dart';
import 'polygon_terrain_seam_manifest.dart';
import 'polygon_terrain_seam_validation.dart';
import 'polygon_terrain_source.dart';

/// One canonical current-schema Chunk input in the repository generation set.
final class PolygonTerrainRepositoryChunkInput {
  const PolygonTerrainRepositoryChunkInput({
    required this.sourcePath,
    required this.contents,
  });

  final String sourcePath;
  final String contents;
}

/// Level reachability fields required by repository terrain generation.
final class PolygonTerrainSchedulerLevelSource {
  const PolygonTerrainSchedulerLevelSource({
    required this.levelId,
    required this.earlyPatternChunks,
    required this.easyPatternChunks,
    required this.normalPatternChunks,
    this.includeInBuild = true,
    this.assembly,
  });

  final String levelId;
  final int earlyPatternChunks;
  final int easyPatternChunks;
  final int normalPatternChunks;

  /// Exclusion skips whole-level readiness, never source or geometry validation.
  final bool includeInBuild;
  final PolygonTerrainSchedulerAssemblySource? assembly;
}

/// Optional ordered assembly rules used for one level's reachability.
final class PolygonTerrainSchedulerAssemblySource {
  PolygonTerrainSchedulerAssemblySource({
    required this.loopSegments,
    required Iterable<PolygonTerrainSchedulerSegmentSource> segments,
  }) : segments = List<PolygonTerrainSchedulerSegmentSource>.unmodifiable(
         segments,
       );

  final bool loopSegments;
  final List<PolygonTerrainSchedulerSegmentSource> segments;
}

/// One scheduler assembly segment used for terrain reachability.
final class PolygonTerrainSchedulerSegmentSource {
  const PolygonTerrainSchedulerSegmentSource({
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

/// One fully accepted Chunk and its compiled polygon terrain.
final class PolygonTerrainRepositoryChunk {
  const PolygonTerrainRepositoryChunk({
    required this.sourcePath,
    required this.source,
    required this.compiled,
  });

  final String sourcePath;
  final PolygonTerrainChunkSource source;
  final PolygonTerrainCompiledChunk compiled;
}

/// Fail-closed repository terrain generation result.
final class PolygonTerrainRepositoryGenerationResult {
  PolygonTerrainRepositoryGenerationResult({
    required Iterable<PolygonTerrainRepositoryChunk> chunks,
    required this.validatedBatch,
    required Iterable<TerrainAuthoringIssue> issues,
  }) : chunks = List<PolygonTerrainRepositoryChunk>.unmodifiable(chunks),
       issues = canonicalTerrainAuthoringIssues(issues);

  /// All structurally compiled source chunks, including excluded/deprecated ones.
  final List<PolygonTerrainRepositoryChunk> chunks;

  /// Only eligible chunks of included levels with proven reachable seams.
  final PolygonTerrainValidatedBatch? validatedBatch;
  final List<TerrainAuthoringIssue> issues;
}

/// Builds the complete current-schema terrain products used by generation.
///
/// Every source is decoded and compiled. Only included levels and active chunks
/// enter scheduler/seam readiness and the runtime render batch.
/// No partial product is returned when any source, scheduler, geometry, or seam
/// blocker exists.
PolygonTerrainRepositoryGenerationResult buildPolygonTerrainRepository({
  required String prefabSourcePath,
  required String prefabContents,
  required Iterable<PolygonTerrainRepositoryChunkInput> chunkInputs,
  required Iterable<PolygonTerrainSchedulerLevelSource> levels,
  required String schedulerSourcePath,
}) {
  prefabSourcePath = canonicalPolygonTerrainSourcePath(prefabSourcePath);
  schedulerSourcePath = canonicalPolygonTerrainSourcePath(schedulerSourcePath);
  final issues = <TerrainAuthoringIssue>[];
  final orderedInputs = chunkInputs.toList()
    ..sort((left, right) => left.sourcePath.compareTo(right.sourcePath));
  final orderedLevels = levels.toList()
    ..sort((left, right) => left.levelId.compareTo(right.levelId));

  final PolygonTerrainPrefabSourceSet prefabs;
  try {
    prefabs = decodePolygonTerrainPrefabs(
      prefabContents,
      sourcePath: prefabSourcePath,
    );
  } on FormatException catch (error) {
    return _failure(<TerrainAuthoringIssue>[
      _issue(
        code: 'prefab_source_invalid',
        message: error.message.toString(),
        sourcePath: prefabSourcePath,
        ownerKey: prefabSourcePath,
      ),
    ]);
  }

  final parsed = <({String sourcePath, PolygonTerrainChunkSource source})>[];
  final compiled = <PolygonTerrainCompiledChunk>[];
  for (final input in orderedInputs) {
    final sourcePath = canonicalPolygonTerrainSourcePath(input.sourcePath);
    final PolygonTerrainChunkSource source;
    try {
      source = decodePolygonTerrainChunk(
        input.contents,
        sourcePath: sourcePath,
      );
    } on FormatException catch (error) {
      issues.add(
        _issue(
          code: 'chunk_source_invalid',
          message: error.message.toString(),
          sourcePath: sourcePath,
          ownerKey: sourcePath,
        ),
      );
      continue;
    }
    parsed.add((sourcePath: sourcePath, source: source));
    final result = compilePolygonTerrainChunk(
      chunk: source,
      prefabSources: prefabs,
      sourcePath: sourcePath,
    );
    issues.addAll(result.issues);
    if (result.compiled case final accepted?) compiled.add(accepted);
  }

  final allLevelIds = orderedLevels.map((level) => level.levelId).toSet();
  final includedLevels = orderedLevels
      .where((level) => level.includeInBuild)
      .toList();
  final includedLevelIds = includedLevels.map((level) => level.levelId).toSet();
  for (final item in parsed) {
    if (!allLevelIds.contains(item.source.levelId)) {
      issues.add(
        _issue(
          code: 'terrain_authoring_scheduler_level_context_missing',
          message:
              'Chunk ${item.source.chunkKey} references unauthored Level ${item.source.levelId}.',
          sourcePath: item.sourcePath,
          ownerKey: item.source.chunkKey,
        ),
      );
    }
  }
  // Reuse the seam input validator for global identity uniqueness before any
  // exclusion. An empty manifest asks it to check identities, not reachability.
  final structuralBatch = validatePolygonTerrainSeams(
    chunks: compiled,
    manifest: PolygonTerrainSeamManifest(
      signature: TerrainAuthoringSeamSignature(const []),
      sourcePath: schedulerSourcePath,
    ),
  );
  issues.addAll(structuralBatch.issues);
  final runtimeSources = parsed
      .where(
        (item) =>
            includedLevelIds.contains(item.source.levelId) &&
            isRuntimeEligibleChunkStatus(item.source.status),
      )
      .toList();
  final scheduler = enumerateTerrainAuthoringReachability(
    chunks: runtimeSources.map(
      (item) => TerrainAuthoringSchedulerChunk(
        chunkKey: item.source.chunkKey,
        levelId: item.source.levelId,
        tier: _tier(item.source.difficulty),
        assemblyGroupId: item.source.assemblyGroupId,
        isActive: isRuntimeEligibleChunkStatus(item.source.status),
      ),
    ),
    levels: includedLevels.map(_schedulerLevel),
  );
  issues.addAll(
    scheduler.issues.map(
      (issue) => _issue(
        code: issue.code,
        message: issue.message,
        sourcePath: schedulerSourcePath,
        ownerKey: issue.levelId,
      ),
    ),
  );
  if (issues.isNotEmpty || compiled.length != parsed.length) {
    return _failure(issues);
  }

  final seamResult = validatePolygonTerrainSeams(
    chunks: compiled.where(
      (item) =>
          includedLevelIds.contains(item.chunk.levelId) &&
          isRuntimeEligibleChunkStatus(item.chunk.status),
    ),
    manifest: PolygonTerrainSeamManifest(
      signature: scheduler.signature,
      sourcePath: schedulerSourcePath,
    ),
  );
  issues.addAll(seamResult.issues);
  final batch = seamResult.batch;
  if (issues.isNotEmpty || batch == null) return _failure(issues);

  final parsedByKey =
      <String, ({String sourcePath, PolygonTerrainChunkSource source})>{
        for (final item in parsed) item.source.chunkKey: item,
      };
  return PolygonTerrainRepositoryGenerationResult(
    chunks: <PolygonTerrainRepositoryChunk>[
      for (final item in structuralBatch.batch!.chunks)
        PolygonTerrainRepositoryChunk(
          sourcePath: parsedByKey[item.chunk.chunkKey]!.sourcePath,
          source: parsedByKey[item.chunk.chunkKey]!.source,
          compiled: item,
        ),
    ],
    validatedBatch: batch,
    issues: const <TerrainAuthoringIssue>[],
  );
}

PolygonTerrainRepositoryGenerationResult _failure(
  Iterable<TerrainAuthoringIssue> issues,
) => PolygonTerrainRepositoryGenerationResult(
  chunks: const <PolygonTerrainRepositoryChunk>[],
  validatedBatch: null,
  issues: issues,
);

TerrainAuthoringSchedulerLevel _schedulerLevel(
  PolygonTerrainSchedulerLevelSource level,
) => TerrainAuthoringSchedulerLevel(
  levelId: level.levelId,
  earlyPatternChunks: level.earlyPatternChunks,
  easyPatternChunks: level.easyPatternChunks,
  normalPatternChunks: level.normalPatternChunks,
  assembly: level.assembly == null
      ? null
      : TerrainAuthoringSchedulerAssembly(
          loopSegments: level.assembly!.loopSegments,
          segments: level.assembly!.segments.map(
            (segment) => TerrainAuthoringSchedulerSegment(
              segmentId: segment.segmentId,
              groupId: segment.groupId,
              minChunkCount: segment.minChunkCount,
              maxChunkCount: segment.maxChunkCount,
              requireDistinctChunks: segment.requireDistinctChunks,
            ),
          ),
        ),
);

ChunkPatternTier _tier(String difficulty) => switch (difficulty) {
  'early' => ChunkPatternTier.early,
  'easy' => ChunkPatternTier.easy,
  'normal' => ChunkPatternTier.normal,
  'hard' => ChunkPatternTier.hard,
  _ => throw ArgumentError.value(difficulty, 'difficulty'),
};

TerrainAuthoringIssue _issue({
  required String code,
  required String message,
  required String sourcePath,
  required String ownerKey,
  String? placementKey,
  String? shapeId,
  int? elementIndex,
}) => TerrainAuthoringIssue(
  severity: TerrainAuthoringIssueSeverity.error,
  code: code,
  message: message,
  sourcePath: sourcePath,
  ownerKey: ownerKey,
  placementKey: placementKey,
  shapeId: shapeId,
  elementIndex: elementIndex,
);
