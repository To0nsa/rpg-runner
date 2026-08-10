import 'package:runner_core/collision/terrain/terrain_authoring_issue.dart';
import 'package:runner_core/collision/terrain/terrain_authoring_scheduler.dart';
import 'package:runner_core/track/chunk_pattern_source.dart';

import 'level_definition_generation.dart';
import 'polygon_terrain_compilation.dart';
import 'polygon_terrain_legacy_projection.dart';
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

/// One fully accepted Chunk and its temporary exact legacy projection.
final class PolygonTerrainRepositoryChunk {
  const PolygonTerrainRepositoryChunk({
    required this.sourcePath,
    required this.source,
    required this.compiled,
    required this.legacyProjection,
  });

  final String sourcePath;
  final PolygonTerrainChunkSource source;
  final PolygonTerrainCompiledChunk compiled;
  final PolygonTerrainLegacyProjection legacyProjection;
}

/// Fail-closed repository terrain generation result.
final class PolygonTerrainRepositoryGenerationResult {
  PolygonTerrainRepositoryGenerationResult({
    required Iterable<PolygonTerrainRepositoryChunk> chunks,
    required this.validatedBatch,
    required Iterable<TerrainAuthoringIssue> issues,
  }) : chunks = List<PolygonTerrainRepositoryChunk>.unmodifiable(chunks),
       issues = canonicalTerrainAuthoringIssues(issues);

  final List<PolygonTerrainRepositoryChunk> chunks;
  final PolygonTerrainValidatedBatch? validatedBatch;
  final List<TerrainAuthoringIssue> issues;
}

/// Builds the complete current-schema terrain products used by generation.
///
/// Source decoding, Core compilation, scheduler reachability, compiled seam
/// validation, staged rendering eligibility, and the bounded Phase 4 legacy
/// projection are one fail-closed operation. No partial product is returned
/// when any source, scheduler, geometry, seam, or projection blocker exists.
PolygonTerrainRepositoryGenerationResult buildPolygonTerrainRepository({
  required String prefabSourcePath,
  required String prefabContents,
  required Iterable<PolygonTerrainRepositoryChunkInput> chunkInputs,
  required Iterable<LevelDefinitionSource> levels,
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

  final scheduler = enumerateTerrainAuthoringReachability(
    chunks: parsed.map(
      (item) => TerrainAuthoringSchedulerChunk(
        chunkKey: item.source.chunkKey,
        levelId: item.source.levelId,
        tier: _tier(item.source.difficulty),
        assemblyGroupId: item.source.assemblyGroupId,
        isActive: item.source.status == 'active',
      ),
    ),
    levels: orderedLevels.map(_schedulerLevel),
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
    chunks: compiled,
    manifest: PolygonTerrainSeamManifest(
      signature: scheduler.signature,
      sourcePath: schedulerSourcePath,
    ),
  );
  issues.addAll(seamResult.issues);
  final batch = seamResult.batch;
  if (issues.isNotEmpty || batch == null) return _failure(issues);

  final levelById = <String, LevelDefinitionSource>{
    for (final level in orderedLevels) level.levelId: level,
  };
  final projectionByChunkKey = <String, PolygonTerrainLegacyProjection>{};
  final sourcePathByChunkKey = <String, String>{
    for (final item in parsed) item.source.chunkKey: item.sourcePath,
  };
  for (final item in batch.chunks) {
    final level = levelById[item.chunk.levelId];
    final sourcePath = sourcePathByChunkKey[item.chunk.chunkKey]!;
    if (level == null) {
      issues.add(
        _issue(
          code: 'terrain_authoring_level_missing',
          message:
              'Chunk ${item.chunk.chunkKey} references missing level '
              '${item.chunk.levelId}.',
          sourcePath: sourcePath,
          ownerKey: item.chunk.chunkKey,
        ),
      );
      continue;
    }
    if (!level.groundTopY.isFinite ||
        level.groundTopY != level.groundTopY.truncateToDouble()) {
      issues.add(
        _issue(
          code: 'legacy_ground_top_not_integer',
          message:
              'Level ${level.levelId} groundTopY must be an integer while the '
              'Phase 4 legacy projection remains active.',
          sourcePath: schedulerSourcePath,
          ownerKey: level.levelId,
        ),
      );
      continue;
    }
    final projection = projectPolygonTerrainToLegacy(
      compiled: item,
      legacyGroundTopY: level.groundTopY.toInt(),
    );
    for (final issue in projection.issues) {
      issues.add(
        _issue(
          code: issue.code,
          message: issue.message,
          sourcePath: sourcePath,
          ownerKey: issue.chunkKey,
          placementKey: issue.placementKey,
          shapeId: issue.shapeId.isEmpty ? null : issue.shapeId,
          elementIndex: issue.elementIndex,
        ),
      );
    }
    if (projection.projection case final accepted?) {
      projectionByChunkKey[item.chunk.chunkKey] = accepted;
    }
  }
  if (issues.isNotEmpty || projectionByChunkKey.length != batch.chunks.length) {
    return _failure(issues);
  }

  final parsedByKey =
      <String, ({String sourcePath, PolygonTerrainChunkSource source})>{
        for (final item in parsed) item.source.chunkKey: item,
      };
  return PolygonTerrainRepositoryGenerationResult(
    chunks: <PolygonTerrainRepositoryChunk>[
      for (final item in batch.chunks)
        PolygonTerrainRepositoryChunk(
          sourcePath: parsedByKey[item.chunk.chunkKey]!.sourcePath,
          source: parsedByKey[item.chunk.chunkKey]!.source,
          compiled: item,
          legacyProjection: projectionByChunkKey[item.chunk.chunkKey]!,
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

TerrainAuthoringSchedulerLevel _schedulerLevel(LevelDefinitionSource level) =>
    TerrainAuthoringSchedulerLevel(
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
