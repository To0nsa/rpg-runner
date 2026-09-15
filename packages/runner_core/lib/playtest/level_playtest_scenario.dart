/// Immutable whole-level construction through the explicit tooling boundary.
library;

import '../ecs/stores/combat/equipped_loadout_store.dart';
import '../levels/level_definition.dart';
import '../players/player_character_definition.dart';
import '../players/player_tuning.dart' show defaultTickHz;
import '../track/chunk_pattern_source.dart';
import '../track/connected_chunk_pattern_source.dart';
import '../collision/terrain/terrain_connection_schedule.dart';
import '../track/staged_terrain_catalog.dart';
import '../track/staged_terrain_data.dart';
import 'playtest_scenario_validation.dart';
import 'playtest_scenario.dart';

export 'playtest_scenario_validation.dart' show PlaytestScenarioException;

/// Validated captured content for the real seeded level stream.
///
/// Unlike focused Chunk Play, this preserves all authored progression, assembly,
/// and enemy suppression. Compilation remains in the content pipeline; this
/// boundary verifies the complete runtime pool and every reachable seam.
final class LevelPlaytestScenario implements PlaytestScenario {
  factory LevelPlaytestScenario({
    required LevelDefinition levelDefinition,
    required Iterable<StagedTerrainChunkData> terrainChunks,
    required int seed,
    int tickHz = defaultTickHz,
    required PlayerCharacterDefinition playerCharacter,
    required EquippedLoadoutDef equippedLoadout,
  }) {
    if (seed <= 0 || tickHz <= 0) {
      throw ArgumentError('Playtest seed and tickHz must be positive.');
    }
    final level = immutablePlaytestLevelDefinition(levelDefinition);
    validatePlaytestLevelSettings(level);
    final catalog = StagedTerrainChunkCatalog(chunks: terrainChunks);
    final source = level.chunkPatternSource;
    final base = switch (source) {
      ChunkPatternListSource value => value,
      FirstChunkPatternSource value => value.baseSource,
      AssembledChunkPatternSource value => value.baseSource,
      _ => throw const PlaytestScenarioException(
        code: 'level_playtest_pattern_source_unsupported',
        message: 'Level playtest requires a list-backed pattern source.',
      ),
    };
    final seen = <String>{};
    final pools = [
      (ChunkPatternTier.early, base.earlyPatterns),
      (ChunkPatternTier.easy, base.easyPatterns),
      (ChunkPatternTier.normal, base.normalPatterns),
      (ChunkPatternTier.hard, base.hardPatterns),
    ];
    for (final (tier, patterns) in pools) {
      for (final pattern in patterns) {
        final key = pattern.chunkKey;
        if (key == null || key.isEmpty || !seen.add(key)) {
          throw const PlaytestScenarioException(
            code: 'level_playtest_chunk_key_invalid',
            message: 'Every pool entry requires a unique stable chunk key.',
          );
        }
        final terrain = catalog.chunksByKey[key];
        if (terrain == null) {
          throw PlaytestScenarioException(
            code: 'level_playtest_terrain_missing',
            message: 'Pattern $key has no captured compiled terrain.',
          );
        }
        if (terrain.levelId != level.identity.value ||
            terrain.status != 'active' ||
            terrain.width.toDouble() != level.tuning.track.chunkWidth ||
            terrain.assemblyGroupId != pattern.assemblyGroupId ||
            playtestTierForDifficulty(terrain.difficulty) != tier) {
          throw PlaytestScenarioException(
            code: 'level_playtest_pool_mismatch',
            message:
                'Chunk $key must match level ${level.identity.value}, active '
                'status, runtime width, group, and authored tier.',
          );
        }
      }
    }
    if (seen.isEmpty) {
      throw const PlaytestScenarioException(
        code: 'level_playtest_empty_pool',
        message: 'The level needs at least one active playable chunk.',
      );
    }
    for (final terrain in catalog.chunksByKey.values) {
      if (terrain.levelId != level.identity.value ||
          (terrain.status == 'active' && !seen.contains(terrain.chunkKey))) {
        throw PlaytestScenarioException(
          code: 'level_playtest_unmatched_terrain',
          message:
              'Captured terrain ${terrain.chunkKey} does not belong to the '
              'complete selected level pool.',
        );
      }
    }
    try {
      ConnectedChunkPatternSource.forLevel(level: level, catalog: catalog);
    } on TerrainConnectionException catch (error) {
      throw PlaytestScenarioException(code: error.code, message: error.message);
    }
    return LevelPlaytestScenario._(
      levelDefinition: level,
      terrainCatalog: catalog,
      seed: seed,
      tickHz: tickHz,
      playerCharacter: playerCharacter,
      equippedLoadout: equippedLoadout,
    );
  }

  const LevelPlaytestScenario._({
    required this.levelDefinition,
    required this.terrainCatalog,
    required this.seed,
    required this.tickHz,
    required this.playerCharacter,
    required this.equippedLoadout,
  });

  final LevelDefinition levelDefinition;
  final StagedTerrainChunkCatalog terrainCatalog;
  final int seed;
  @override
  final int tickHz;
  @override
  final PlayerCharacterDefinition playerCharacter;
  final EquippedLoadoutDef equippedLoadout;

  /// Returns fresh scheduler state with the captured level's original rules.
  LevelDefinition buildRuntimeLevelDefinition() => levelDefinition.copyWith();

  /// Projects a bounded opening sequence from the real seeded scheduler.
  ///
  /// Fresh source state keeps inspection independent from any running playtest.
  /// Enemy suppression reports the opening rule, not a promise that a chunk has
  /// enemy markers or that their individual spawn rolls succeed.
  List<LevelPlaytestChunkSample> sampleChunks({int count = 12}) {
    RangeError.checkValueInInterval(count, 1, 128, 'count');
    final level = buildRuntimeLevelDefinition();
    final source = ConnectedChunkPatternSource.forLevel(
      level: level,
      catalog: terrainCatalog,
    );
    return List.unmodifiable(
      List.generate(count, (index) {
        final tier = chunkPatternTierForIndex(
          chunkIndex: index,
          earlyPatternChunks: level.earlyPatternChunks,
          easyPatternChunks: level.easyPatternChunks,
          normalPatternChunks: level.normalPatternChunks,
        );
        final selected = source.selectionFor(
          seed: seed,
          chunkIndex: index,
          tier: tier,
        );
        final terrain = terrainCatalog.chunksByKey[selected.pattern.chunkKey]!;
        return LevelPlaytestChunkSample(
          chunkIndex: index,
          chunkKey: terrain.chunkKey,
          groupId: terrain.assemblyGroupId,
          requestedTier: selected.assembly?.difficulty ?? tier,
          resolvedTier: playtestTierForDifficulty(terrain.difficulty),
          enemiesSuppressed: index < level.noEnemyChunks,
          assembly: selected.assembly,
          availableChunkKeys: source
              .explainSelection(seed: seed, chunkIndex: index)
              .availableChunkKeys,
        );
      }),
    );
  }
}

/// Read-only evidence of one selected chunk in a captured level preview.
final class LevelPlaytestChunkSample {
  const LevelPlaytestChunkSample({
    required this.chunkIndex,
    required this.chunkKey,
    required this.groupId,
    required this.requestedTier,
    required this.resolvedTier,
    required this.enemiesSuppressed,
    required this.assembly,
    this.availableChunkKeys = const [],
  });

  final int chunkIndex;
  final String chunkKey;
  final String groupId;
  final ChunkPatternTier requestedTier;
  final ChunkPatternTier resolvedTier;
  final bool enemiesSuppressed;
  final ChunkAssemblySelection? assembly;

  /// Exact choices admitted at this occurrence, before seeded selection.
  final List<String> availableChunkKeys;
  bool get startsSection => assembly?.startChunkIndex == chunkIndex;
}
