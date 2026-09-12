/// Shared admission primitives for the two explicit authored playtest scopes.
library;

import '../collision/terrain/terrain_authoring_scheduler.dart';
import '../collision/terrain/terrain_boundary_signature.dart';
import '../levels/level_assembly.dart';
import '../levels/level_definition.dart';
import '../track/chunk_pattern.dart';
import '../track/chunk_pattern_source.dart';
import '../track/staged_terrain_catalog.dart';
import '../track/staged_terrain_world_geometry.dart';

/// Stable preparation failure surfaced to an authoring host.
final class PlaytestScenarioException implements Exception {
  const PlaytestScenarioException({required this.code, required this.message});

  final String code;
  final String message;

  @override
  String toString() => '$code: $message';
}

TerrainAuthoringSchedulerAssembly? playtestSchedulerAssembly(
  LevelAssemblyDefinition? assembly,
) {
  if (assembly == null || assembly.segments.isEmpty) return null;
  return TerrainAuthoringSchedulerAssembly(
    loopSegments: assembly.loopSegments,
    segments: assembly.segments.map(
      (segment) => TerrainAuthoringSchedulerSegment(
        segmentId: segment.segmentId,
        groupId: segment.groupId,
        difficulty: segment.difficulty,
        minChunkCount: segment.minChunkCount,
        maxChunkCount: segment.maxChunkCount,
        requireDistinctChunks: segment.requireDistinctChunks,
      ),
    ),
  );
}

ChunkPatternTier playtestTierForDifficulty(String difficulty) =>
    switch (difficulty) {
      'early' => ChunkPatternTier.early,
      'easy' => ChunkPatternTier.easy,
      'normal' => ChunkPatternTier.normal,
      'hard' => ChunkPatternTier.hard,
      _ => throw PlaytestScenarioException(
        code: 'chunk_playtest_difficulty_invalid',
        message: 'Unsupported chunk difficulty "$difficulty".',
      ),
    };

ChunkPattern immutablePlaytestPattern(ChunkPattern source) => ChunkPattern(
  name: source.name,
  chunkKey: source.chunkKey,
  assemblyGroupId: source.assemblyGroupId,
  spawnMarkers: List<SpawnMarker>.unmodifiable(source.spawnMarkers),
  visualSprites: List<ChunkVisualSpriteRel>.unmodifiable(source.visualSprites),
);

void validatePlaytestSeam({
  required String transitionRecord,
  required String leftChunkKey,
  required String rightChunkKey,
  required StagedTerrainCatalog catalog,
}) {
  const geometryBuilder = StagedTerrainWorldGeometryBuilder();
  final leftChunk = catalog.requireChunk(leftChunkKey);
  final rightChunk = catalog.requireChunk(rightChunkKey);
  final leftGeometry = geometryBuilder.build(
    bindings: <StagedTerrainChunkBinding>[
      catalog.bind(chunkKey: leftChunkKey, chunkIndex: 0, worldOriginXTicks: 0),
    ],
    geometryVersion: 0,
  );
  final rightGeometry = geometryBuilder.build(
    bindings: <StagedTerrainChunkBinding>[
      catalog.bind(
        chunkKey: rightChunkKey,
        chunkIndex: 0,
        worldOriginXTicks: 0,
      ),
    ],
    geometryVersion: 0,
  );
  final leftBoundary = buildTerrainBoundarySignature(
    chunkKey: leftChunkKey,
    chunkWidth: leftChunk.width,
    geometry: leftGeometry,
    side: TerrainBoundarySide.right,
  );
  final rightBoundary = buildTerrainBoundarySignature(
    chunkKey: rightChunkKey,
    chunkWidth: rightChunk.width,
    geometry: rightGeometry,
    side: TerrainBoundarySide.left,
  );
  final comparison = compareTerrainBoundaries(
    left: leftBoundary,
    right: rightBoundary,
  );
  if (comparison.isCompatible) return;
  throw PlaytestScenarioException(
    code: 'staged_reachable_seam_mismatch',
    message:
        '$transitionRecord has incompatible compiled boundaries at physics '
        'ticks [${comparison.mismatchYTicks.join(', ')}]; right '
        '${leftBoundary.digest} ${leftBoundary.physicalRecord}; left '
        '${rightBoundary.digest} ${rightBoundary.physicalRecord}.',
  );
}

/// Captures mutable collection inputs before any scenario is admitted.
LevelDefinition immutablePlaytestLevelDefinition(LevelDefinition level) {
  final source = level.chunkPatternSource;
  final base = switch (source) {
    ChunkPatternListSource value => value,
    FirstChunkPatternSource value => value.baseSource,
    AssembledChunkPatternSource value => value.baseSource,
    _ => throw const PlaytestScenarioException(
      code: 'playtest_pattern_source_unsupported',
      message: 'Authored playtest requires a list-backed pattern source.',
    ),
  };
  List<ChunkPattern> freeze(List<ChunkPattern> patterns) =>
      List<ChunkPattern>.unmodifiable(patterns.map(immutablePlaytestPattern));
  final assembly = level.assembly;
  return level.copyWith(
    chunkPatternSource: ChunkPatternListSource(
      earlyPatterns: freeze(base.earlyPatterns),
      easyPatterns: freeze(base.easyPatterns),
      normalPatterns: freeze(base.normalPatterns),
      hardPatterns: freeze(base.hardPatterns),
    ),
    assembly: assembly == null
        ? null
        : LevelAssemblyDefinition(
            loopSegments: assembly.loopSegments,
            segments: List<LevelAssemblySegment>.unmodifiable(
              assembly.segments,
            ),
          ),
  );
}

/// Checks release-mode settings before any captured source reaches Core.
void validatePlaytestLevelSettings(LevelDefinition level) {
  if (!level.tuning.track.enabled ||
      !level.cameraCenterY.isFinite ||
      !level.tuning.track.chunkWidth.isFinite ||
      level.tuning.track.chunkWidth <= 0 ||
      level.earlyPatternChunks < 0 ||
      level.easyPatternChunks < 0 ||
      level.normalPatternChunks < 0 ||
      level.noEnemyChunks < 0) {
    throw const PlaytestScenarioException(
      code: 'playtest_level_settings_invalid',
      message: 'Playtest requires finite streamed-level settings and non-negative pacing.',
    );
  }
}
