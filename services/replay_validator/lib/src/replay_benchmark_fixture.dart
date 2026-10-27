import 'package:runner_core/game_core.dart';
import 'package:runner_core/levels/level_definition.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/levels/level_registry.dart';
import 'package:runner_core/navigation/terrain_graph_materializer.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:runner_core/track/chunk_pattern.dart';
import 'package:runner_core/track/chunk_pattern_source.dart';
import 'package:runner_core/tuning/camera_tuning.dart';
import 'package:runner_core/tuning/core_tuning.dart';

/// Builds the no-combat throughput fixture with normal player/terrain physics.
///
/// Recording and replay must use the same seed, tick rate and level. Unused
/// enemy graphs may remain deferred; this cannot change terrain collision.
GameCore buildReplayBenchmarkCore({
  required LevelId levelId,
  required int seed,
  required int tickHz,
  TerrainGraphMaterializer graphMaterializer =
      const TerrainGraphMaterializer.onDemand(),
}) => GameCore(
  graphMaterializer: graphMaterializer,
  seed: seed,
  runId: 1,
  tickHz: tickHz,
  levelDefinition: replayBenchmarkLevel(levelId),
  playerCharacter: PlayerCharacterRegistry.eloise,
);

/// Preserves all chunk pools, ordering, assembly, terrain keys, sprites and traps.
///
/// Only this fixture removes ambient spawns, required encounters and boss
/// objectives. Mandatory arenas otherwise hold the player with auto-scroll
/// disabled, even when `noEnemyChunks` suppresses ordinary spawn markers.
LevelDefinition replayBenchmarkLevel(LevelId levelId) {
  final registered = LevelRegistry.byId(levelId);
  final base = registered.tuning;
  final source = switch (registered.chunkPatternSource) {
    AssembledChunkPatternSource(:final baseSource) => baseSource,
    FirstChunkPatternSource(:final baseSource) => baseSource,
    ChunkPatternListSource source => source,
    _ => throw StateError('Benchmark requires authored chunk lists.'),
  };
  List<ChunkPattern> withoutCombat(List<ChunkPattern> patterns) => [
    for (final pattern in patterns)
      ChunkPattern(
        name: pattern.name,
        chunkKey: pattern.chunkKey,
        assemblyGroupId: pattern.assemblyGroupId,
        visualSprites: pattern.visualSprites,
        traps: pattern.traps,
      ),
  ];
  return registered.copyWith(
    chunkPatternSource: ChunkPatternListSource(
      earlyPatterns: withoutCombat(source.earlyPatterns),
      easyPatterns: withoutCombat(source.easyPatterns),
      normalPatterns: withoutCombat(source.normalPatterns),
      hardPatterns: withoutCombat(source.hardPatterns),
    ),
    noEnemyChunks: 1 << 30,
    tuning: CoreTuning(
      physics: base.physics,
      unocoDemon: base.unocoDemon,
      groundEnemy: base.groundEnemy,
      navigation: base.navigation,
      spatialGrid: base.spatialGrid,
      camera: const CameraTuning(speedLagMulX: 0),
      track: base.track,
      collectible: base.collectible,
      restorationItem: base.restorationItem,
      score: base.score,
    ),
  );
}
