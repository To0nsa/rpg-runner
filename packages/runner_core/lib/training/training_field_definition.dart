import '../levels/level_definition.dart';
import '../levels/level_identity.dart';
import '../track/chunk_pattern.dart';
import '../track/chunk_pattern_source.dart';
import '../track/staged_terrain_catalog.dart';
import '../track/staged_terrain_data.dart';
import '../tuning/camera_tuning.dart';
import '../tuning/core_tuning.dart';
import '../tuning/track_tuning.dart';

/// Authored geometry only. Training rules are owned by the local Core session.
final class TrainingFieldDefinition {
  TrainingFieldDefinition({
    required Iterable<ChunkPattern> chunks,
    required this.terrain,
    required this.playerStartX,
    required this.playerStartY,
    required this.enemyChunkIndex,
    required this.enemySpawnX,
    required this.enemySpawnY,
    required this.visualThemeId,
  }) : chunks = List.unmodifiable(chunks) {
    if (this.chunks.length != 2 ||
        enemyChunkIndex < 0 ||
        enemyChunkIndex > 1 ||
        !playerStartX.isFinite ||
        playerStartX <= 0 ||
        playerStartX >= 600 ||
        !playerStartY.isFinite ||
        playerStartY < 0 ||
        playerStartY > 270 ||
        !enemySpawnY.isFinite ||
        enemySpawnY < 0 ||
        enemySpawnY > 270 ||
        !enemySpawnX.isFinite ||
        enemySpawnX <= 0 ||
        enemySpawnX >= 600 ||
        visualThemeId.isEmpty) {
      throw ArgumentError(
        'Training Field needs two chunks and valid spawn positions.',
      );
    }
    final catalog = terrainCatalog;
    for (final chunk in this.chunks) {
      final data = catalog.requireChunk(chunk.chunkKey!);
      if (data.width != 600 ||
          data.height != 270 ||
          chunk.spawnMarkers.isNotEmpty ||
          chunk.traps.isNotEmpty ||
          chunk.encounters.isNotEmpty ||
          chunk.bossArena != null) {
        throw ArgumentError(
          'Training chunks contain only normal-size layout data.',
        );
      }
    }
  }

  final List<ChunkPattern> chunks;
  final StagedTerrainArtifactData terrain;
  final double playerStartX;
  final double playerStartY;
  final int enemyChunkIndex;
  final double enemySpawnX;
  final double enemySpawnY;
  final String visualThemeId;

  StagedTerrainCatalog get terrainCatalog =>
      StagedTerrainArtifactCatalog(artifact: terrain);

  /// Never registered as a ticket/leaderboard level.
  LevelDefinition buildLevel() => LevelDefinition.authored(
    identity: AuthoredLevelIdentity('training_field'),
    chunkPatternSource: _TrainingFieldPatternSource(chunks),
    groundTopY: playerStartY,
    visualThemeId: visualThemeId,
    noEnemyChunks: 0,
    tuning: CoreTuning(
      camera: const CameraTuning(speedLagMulX: 0),
      track: TrackTuning(playerStartX: playerStartX),
    ),
  );
}

final class _TrainingFieldPatternSource extends ChunkPatternSource {
  const _TrainingFieldPatternSource(this.chunks);
  final List<ChunkPattern> chunks;

  @override
  ChunkPatternSelection selectionFor({
    required int seed,
    required int chunkIndex,
    required ChunkPatternTier tier,
  }) => ChunkPatternSelection(
    pattern: chunks[chunkIndex % 2],
    tier: ChunkPatternTier.easy,
  );
}
