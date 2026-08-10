import 'package:meta/meta.dart';
import 'package:runner_core/collision/terrain/terrain_authoring_scheduler.dart';
import 'package:runner_core/collision/terrain/terrain_authoring_seam_signature.dart';
import 'package:runner_core/collision/terrain/terrain_boundary_signature.dart';
import 'package:runner_core/collision/terrain/terrain_geometry.dart';
import 'package:runner_core/track/chunk_pattern_source.dart';

import '../domain/authoring_types.dart';
import '../levels/level_domain_models.dart';
import '../terrain_authoring/terrain_physics_text.dart';
import 'chunk_domain_models.dart';
import 'chunk_v2_collision_expansion.dart';
import 'chunk_v2_file_data.dart';

typedef ChunkV2BoundarySide = TerrainBoundarySide;
typedef ChunkV2BoundaryInterval = TerrainBoundaryInterval;
typedef ChunkV2BoundaryVertex = TerrainBoundaryVertex;
typedef ChunkV2BoundarySignature = TerrainBoundarySignature;
typedef ChunkV2BoundaryComparison = TerrainBoundaryComparison;
typedef ChunkV2ReachableTransition = TerrainAuthoringReachableTransition;

/// One scheduler-reachable seam and its compiled physical comparison.
@immutable
final class ChunkV2ReachableSeam {
  const ChunkV2ReachableSeam({
    required this.transition,
    required this.comparison,
  });

  final ChunkV2ReachableTransition transition;
  final ChunkV2BoundaryComparison comparison;
}

/// Immutable global scheduler/seam analysis shared by validation and UI.
@immutable
final class ChunkV2SeamAnalysis {
  ChunkV2SeamAnalysis({
    required Map<String, ChunkV2BoundarySignature> leftSignaturesByChunkKey,
    required Map<String, ChunkV2BoundarySignature> rightSignaturesByChunkKey,
    required Iterable<ChunkV2ReachableTransition> transitions,
    required Iterable<ChunkV2ReachableSeam> seams,
    required Iterable<ValidationIssue> issues,
  }) : leftSignaturesByChunkKey = Map.unmodifiable(leftSignaturesByChunkKey),
       rightSignaturesByChunkKey = Map.unmodifiable(rightSignaturesByChunkKey),
       transitions = List.unmodifiable(transitions),
       seams = List.unmodifiable(seams),
       issues = List.unmodifiable(issues) {
    final signature = TerrainAuthoringSeamSignature(
      this.transitions.map((transition) => transition.authoringTransition),
    );
    reachableAdjacencyRecord = signature.canonicalRecord;
    reachableAdjacencyDigest = signature.digest;
  }

  final Map<String, ChunkV2BoundarySignature> leftSignaturesByChunkKey;
  final Map<String, ChunkV2BoundarySignature> rightSignaturesByChunkKey;
  final List<ChunkV2ReachableTransition> transitions;
  final List<ChunkV2ReachableSeam> seams;
  final List<ValidationIssue> issues;
  late final String reachableAdjacencyRecord;
  late final String reachableAdjacencyDigest;

  List<ChunkV2ReachableSeam> seamsForChunk(String chunkKey) =>
      List<ChunkV2ReachableSeam>.unmodifiable(
        seams.where(
          (seam) =>
              seam.transition.leftChunkKey == chunkKey ||
              seam.transition.rightChunkKey == chunkKey,
        ),
      );
}

/// Builds one canonical signature directly from accepted Core geometry.
ChunkV2BoundarySignature buildChunkV2BoundarySignature({
  required String chunkKey,
  required int chunkWidth,
  required TerrainGeometry geometry,
  required ChunkV2BoundarySide side,
}) => buildTerrainBoundarySignature(
  chunkKey: chunkKey,
  chunkWidth: chunkWidth,
  geometry: geometry,
  side: side,
);

/// Compares the right side of [left] with the left side of [right].
ChunkV2BoundaryComparison compareChunkV2Boundaries({
  required ChunkV2BoundarySignature left,
  required ChunkV2BoundarySignature right,
}) => compareTerrainBoundaries(left: left, right: right);

/// Enumerates scheduler-reachable directed pairs and validates their seams.
ChunkV2SeamAnalysis analyzeChunkV2Seams({
  required Iterable<ChunkV2FileData> chunks,
  required Iterable<LevelDef> levels,
  required Map<String, ChunkV2CollisionExpansionResult>
  collisionExpansionByChunkKey,
  Map<String, String> sourcePathByChunkKey = const <String, String>{},
}) {
  final orderedChunks = List<ChunkV2FileData>.of(
    chunks.where((chunk) => chunk.status == chunkStatusActive),
  )..sort(_compareChunks);
  final orderedLevels = List<LevelDef>.of(levels)
    ..sort((left, right) => left.levelId.compareTo(right.levelId));
  final issues = <ValidationIssue>[];
  final leftSignatures = <String, ChunkV2BoundarySignature>{};
  final rightSignatures = <String, ChunkV2BoundarySignature>{};

  for (final chunk in orderedChunks) {
    final expansion = collisionExpansionByChunkKey[chunk.chunkKey]?.expansion;
    if (expansion == null) continue;
    leftSignatures[chunk.chunkKey] = buildChunkV2BoundarySignature(
      chunkKey: chunk.chunkKey,
      chunkWidth: chunk.width,
      geometry: expansion.geometry,
      side: ChunkV2BoundarySide.left,
    );
    rightSignatures[chunk.chunkKey] = buildChunkV2BoundarySignature(
      chunkKey: chunk.chunkKey,
      chunkWidth: chunk.width,
      geometry: expansion.geometry,
      side: ChunkV2BoundarySide.right,
    );
  }

  final schedulerChunks = <TerrainAuthoringSchedulerChunk>[];
  for (final chunk in orderedChunks) {
    final tier = _tierFromDifficulty(chunk.difficulty);
    if (tier == null) continue;
    schedulerChunks.add(
      TerrainAuthoringSchedulerChunk(
        chunkKey: chunk.chunkKey,
        levelId: chunk.levelId,
        tier: tier,
        assemblyGroupId: chunk.assemblyGroupId,
        isActive: true,
      ),
    );
  }
  final scheduler = enumerateTerrainAuthoringReachability(
    chunks: schedulerChunks,
    levels: orderedLevels.map(_schedulerLevel),
  );
  issues.addAll(
    scheduler.issues.map(
      (issue) => ValidationIssue(
        severity: ValidationSeverity.error,
        code: _editorSchedulerIssueCode(issue.code),
        message: issue.message,
      ),
    ),
  );
  final transitions = scheduler.transitions;

  final seams = <ChunkV2ReachableSeam>[];
  for (final transition in transitions) {
    final left = rightSignatures[transition.leftChunkKey];
    final right = leftSignatures[transition.rightChunkKey];
    if (left == null || right == null) continue;
    final comparison = compareChunkV2Boundaries(left: left, right: right);
    seams.add(
      ChunkV2ReachableSeam(transition: transition, comparison: comparison),
    );
    if (!comparison.isCompatible) {
      final coordinates = comparison.mismatchYTicks
          .map(TerrainPhysicsText.formatTicks)
          .join(', ');
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'chunk_v2_reachable_seam_mismatch',
          message:
              'Level ${transition.levelId} transition '
              '${transition.transitionId} (${transition.description}) emits '
              '${transition.leftChunkKey}[right] -> '
              '${transition.rightChunkKey}[left], but compiled boundary '
              'coverage/continuation differs at y=[$coordinates] px. '
              'Expected/right ${left.digest} ${left.physicalRecord}; '
              'actual/left ${right.digest} ${right.physicalRecord}.',
          sourcePath: sourcePathByChunkKey[transition.leftChunkKey],
        ),
      );
    }
  }

  issues.sort(_compareValidationIssues);
  return ChunkV2SeamAnalysis(
    leftSignaturesByChunkKey: leftSignatures,
    rightSignaturesByChunkKey: rightSignatures,
    transitions: transitions,
    seams: seams,
    issues: issues,
  );
}

TerrainAuthoringSchedulerLevel _schedulerLevel(LevelDef level) =>
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

String _editorSchedulerIssueCode(String code) => switch (code) {
  'terrain_authoring_scheduler_level_context_missing' =>
    'chunk_v2_seam_level_context_missing',
  'terrain_authoring_scheduler_analysis_capacity_exceeded' =>
    'chunk_v2_scheduler_analysis_capacity_exceeded',
  'terrain_authoring_scheduler_distinct_pool_too_small' =>
    'chunk_v2_scheduler_distinct_pool_too_small',
  'terrain_authoring_scheduler_pool_empty' => 'chunk_v2_scheduler_pool_empty',
  _ => code,
};

ChunkPatternTier? _tierFromDifficulty(String difficulty) =>
    switch (difficulty) {
      chunkDifficultyEarly => ChunkPatternTier.early,
      chunkDifficultyEasy => ChunkPatternTier.easy,
      chunkDifficultyNormal => ChunkPatternTier.normal,
      chunkDifficultyHard => ChunkPatternTier.hard,
      _ => null,
    };

int _compareChunks(ChunkV2FileData left, ChunkV2FileData right) {
  var order = left.levelId.compareTo(right.levelId);
  if (order != 0) return order;
  order = left.difficulty.compareTo(right.difficulty);
  if (order != 0) return order;
  order = left.assemblyGroupId.compareTo(right.assemblyGroupId);
  return order != 0 ? order : left.chunkKey.compareTo(right.chunkKey);
}

int _compareValidationIssues(ValidationIssue left, ValidationIssue right) {
  var order = (left.sourcePath ?? '').compareTo(right.sourcePath ?? '');
  if (order != 0) return order;
  order = left.code.compareTo(right.code);
  return order != 0 ? order : left.message.compareTo(right.message);
}
