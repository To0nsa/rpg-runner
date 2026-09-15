import '../collision/terrain/terrain_authoring_scheduler.dart';
import '../collision/terrain/terrain_chunk_connections.dart';
import '../collision/terrain/terrain_connection_schedule.dart';
import '../levels/level_definition.dart';
import 'chunk_pattern.dart';
import 'chunk_pattern_source.dart';
import 'staged_terrain_catalog.dart';
import 'staged_terrain_world_geometry.dart';

/// Binds authored selection to admitted compiled terrain. Geometry remains in
/// the existing catalog; this source holds only the exact scheduling graph and
/// a constant-storage seeded cursor. Each preview/run creates fresh cursor state.
final class ConnectedChunkPatternSource extends ChunkPatternSource {
  ConnectedChunkPatternSource({
    required this.schedule,
    required Map<String, ChunkPattern> patterns,
  }) : patterns = Map.unmodifiable(patterns);

  factory ConnectedChunkPatternSource.forLevel({
    required LevelDefinition level,
    required StagedTerrainCatalog catalog,
  }) {
    final source = level.chunkPatternSource;
    final base = switch (source) {
      ChunkPatternListSource value => value,
      FirstChunkPatternSource value => value.baseSource,
      AssembledChunkPatternSource value => value.baseSource,
      _ => throw ArgumentError(
        'Connected terrain requires authored chunk lists.',
      ),
    };
    final chunks = <TerrainAuthoringSchedulerChunk>[];
    final patterns = <String, ChunkPattern>{};
    final connections = <String, TerrainChunkConnection>{};
    for (final (tier, pool) in [
      (ChunkPatternTier.early, base.earlyPatterns),
      (ChunkPatternTier.easy, base.easyPatterns),
      (ChunkPatternTier.normal, base.normalPatterns),
      (ChunkPatternTier.hard, base.hardPatterns),
    ]) {
      for (final pattern in pool) {
        final key = pattern.chunkKey;
        if (key == null || patterns.containsKey(key)) {
          throw ArgumentError('Connected chunks require unique authored keys.');
        }
        final terrain = catalog.requireChunk(key);
        if (terrain.levelId != level.identity.value ||
            terrain.status != 'active' ||
            terrain.difficulty != tier.name ||
            terrain.assemblyGroupId != pattern.assemblyGroupId ||
            terrain.width.toDouble() != level.tuning.track.chunkWidth) {
          throw ArgumentError(
            'Chunk $key does not match the level selection pool.',
          );
        }
        patterns[key] = pattern;
        chunks.add(
          TerrainAuthoringSchedulerChunk(
            chunkKey: key,
            levelId: level.identity.value,
            tier: tier,
            assemblyGroupId: pattern.assemblyGroupId,
            isActive: true,
          ),
        );
        final geometry = const StagedTerrainWorldGeometryBuilder().build(
          bindings: [
            catalog.bind(chunkKey: key, chunkIndex: 0, worldOriginXTicks: 0),
          ],
          geometryVersion: 0,
        );
        connections[key] = buildTerrainChunkConnection(
          chunkKey: key,
          chunkWidth: terrain.width,
          geometry: geometry,
          groundTopY: level.groundTopY,
          spawnX: level.tuning.track.playerStartX,
        );
      }
    }
    final assembly = level.assembly;
    return ConnectedChunkPatternSource(
      schedule: TerrainConnectionSchedule.build(
        level: TerrainAuthoringSchedulerLevel(
          levelId: level.identity.value,
          earlyPatternChunks: level.earlyPatternChunks,
          easyPatternChunks: level.easyPatternChunks,
          normalPatternChunks: level.normalPatternChunks,
          firstChunkKey: level.firstChunkKey,
          assembly: assembly == null
              ? null
              : TerrainAuthoringSchedulerAssembly(
                  loopSegments: assembly.loopSegments,
                  segments: assembly.segments.map(
                    (s) => TerrainAuthoringSchedulerSegment(
                      segmentId: s.segmentId,
                      groupId: s.groupId,
                      difficulty: s.difficulty,
                      minChunkCount: s.minChunkCount,
                      maxChunkCount: s.maxChunkCount,
                      requireDistinctChunks: s.requireDistinctChunks,
                    ),
                  ),
                ),
        ),
        chunks: chunks,
        connections: connections,
      ),
      patterns: patterns,
    );
  }

  final TerrainConnectionSchedule schedule;
  final Map<String, ChunkPattern> patterns;
  TerrainConnectionCursor? _cursor;

  TerrainConnectionSelection explainSelection({
    required int seed,
    required int chunkIndex,
  }) {
    if (_cursor?.seed != seed) _cursor = schedule.cursor(seed);
    return _cursor!.selectionFor(chunkIndex);
  }

  @override
  ChunkPatternSelection selectionFor({
    required int seed,
    required int chunkIndex,
    required ChunkPatternTier tier,
  }) {
    final selected = explainSelection(seed: seed, chunkIndex: chunkIndex);
    return ChunkPatternSelection(
      pattern: patterns[selected.chunk.chunkKey]!,
      assembly: selected.assembly,
    );
  }
}
