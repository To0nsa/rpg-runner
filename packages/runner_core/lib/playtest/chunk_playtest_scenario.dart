/// Immutable Core construction contract for an isolated authored-chunk test.
library;

import '../collision/terrain/terrain_authoring_scheduler.dart';
import '../collision/terrain/terrain_chunk_connections.dart';
import '../collision/terrain/terrain_connection_schedule.dart';
import '../track/staged_terrain_world_geometry.dart';
import '../ecs/stores/combat/equipped_loadout_store.dart';
import '../levels/level_definition.dart';
import '../players/player_character_definition.dart';
import '../players/player_tuning.dart' show defaultTickHz;
import '../track/chunk_pattern.dart';
import '../track/chunk_pattern_source.dart';
import '../track/staged_terrain_catalog.dart';
import '../track/staged_terrain_data.dart';
import 'playtest_scenario_validation.dart';
import 'playtest_scenario.dart';

export 'playtest_scenario_validation.dart' show PlaytestScenarioException;

/// Canonical scheduler-reachable chunk sequence with a deterministic loop.
///
/// [transitionRecords] has one entry per [chunkKeys] entry. Each record leads
/// to the following chunk, except the last record, which leads back to
/// [loopStartIndex]. This lasso representation lets track streaming continue
/// indefinitely without inventing an unvalidated boundary.
final class ChunkPlaytestScenarioPath {
  ChunkPlaytestScenarioPath._({
    required Iterable<String> chunkKeys,
    required Iterable<String> transitionRecords,
    required this.selectedChunkIndex,
    required this.loopStartIndex,
  }) : chunkKeys = List<String>.unmodifiable(chunkKeys),
       transitionRecords = List<String>.unmodifiable(transitionRecords) {
    if (this.chunkKeys.isEmpty ||
        this.transitionRecords.length != this.chunkKeys.length ||
        selectedChunkIndex < 0 ||
        selectedChunkIndex >= this.chunkKeys.length ||
        loopStartIndex < 0 ||
        loopStartIndex >= this.chunkKeys.length) {
      throw ArgumentError('Invalid chunk playtest path lasso.');
    }
  }

  final List<String> chunkKeys;
  final List<String> transitionRecords;
  final int selectedChunkIndex;
  final int loopStartIndex;

  /// Resolves the stable authored key for any streamed chunk index.
  String chunkKeyForIndex(int chunkIndex) {
    if (chunkIndex < 0) {
      throw ArgumentError.value(
        chunkIndex,
        'chunkIndex',
        'Must be non-negative.',
      );
    }
    if (chunkIndex < chunkKeys.length) return chunkKeys[chunkIndex];
    final loopLength = chunkKeys.length - loopStartIndex;
    return chunkKeys[loopStartIndex +
        ((chunkIndex - loopStartIndex) % loopLength)];
  }

  /// Materializes a finite diagnostic projection of the repeating path.
  List<String> previewChunkKeys(int count) {
    if (count < 0) {
      throw ArgumentError.value(count, 'count', 'Must be non-negative.');
    }
    return List<String>.unmodifiable(
      List<String>.generate(count, chunkKeyForIndex),
    );
  }
}

/// Complete deterministic inputs for one authored chunk playtest.
///
/// Construction validates scheduler reachability and exact Core boundaries
/// before a [GameCore] can consume this scenario. It owns no editor, Flutter,
/// Flame, replay, run-ticket, or backend state.
final class ChunkPlaytestScenario implements PlaytestScenario {
  factory ChunkPlaytestScenario({
    required LevelDefinition levelDefinition,
    required String visualThemeId,
    required int seed,
    int tickHz = defaultTickHz,
    required ChunkPattern draftPattern,
    required StagedTerrainChunkData draftTerrain,
    required Iterable<StagedTerrainChunkData> terrainChunks,
    required PlayerCharacterDefinition playerCharacter,
    required EquippedLoadoutDef equippedLoadout,
  }) {
    levelDefinition = immutablePlaytestLevelDefinition(levelDefinition);
    if (seed <= 0) {
      throw ArgumentError.value(seed, 'seed', 'Must be positive.');
    }
    if (tickHz <= 0) {
      throw ArgumentError.value(tickHz, 'tickHz', 'Must be positive.');
    }
    if (visualThemeId.trim().isEmpty) {
      throw ArgumentError.value(
        visualThemeId,
        'visualThemeId',
        'Must not be empty.',
      );
    }
    if (!levelDefinition.tuning.track.enabled) {
      throw const PlaytestScenarioException(
        code: 'chunk_playtest_track_disabled',
        message: 'Chunk playtest requires an enabled streamed level.',
      );
    }

    validatePlaytestLevelSettings(levelDefinition);
    final selectedKey = draftPattern.chunkKey;
    if (selectedKey == null || selectedKey.isEmpty) {
      throw const PlaytestScenarioException(
        code: 'chunk_playtest_selected_key_missing',
        message: 'The selected draft pattern requires a stable chunk key.',
      );
    }
    if (draftTerrain.chunkKey != selectedKey) {
      throw PlaytestScenarioException(
        code: 'chunk_playtest_selected_key_mismatch',
        message:
            'Draft pattern $selectedKey does not match staged terrain '
            '${draftTerrain.chunkKey}.',
      );
    }
    if (draftTerrain.levelId != levelDefinition.identity.value) {
      throw PlaytestScenarioException(
        code: 'chunk_playtest_selected_level_mismatch',
        message:
            'Selected chunk $selectedKey belongs to level '
            '${draftTerrain.levelId}, not ${levelDefinition.identity.value}.',
      );
    }
    if (draftTerrain.status != 'active') {
      throw PlaytestScenarioException(
        code: 'chunk_playtest_selected_chunk_inactive',
        message: 'Selected chunk $selectedKey must be active to playtest.',
      );
    }
    if (draftPattern.assemblyGroupId != draftTerrain.assemblyGroupId) {
      throw PlaytestScenarioException(
        code: 'chunk_playtest_selected_group_mismatch',
        message:
            'Draft pattern group ${draftPattern.assemblyGroupId} does not '
            'match staged terrain group ${draftTerrain.assemblyGroupId}.',
      );
    }
    if (levelDefinition.tuning.track.chunkWidth !=
        draftTerrain.width.toDouble()) {
      throw PlaytestScenarioException(
        code: 'chunk_playtest_selected_width_mismatch',
        message:
            'Selected chunk $selectedKey has width ${draftTerrain.width}, '
            'but level ${levelDefinition.identity.value} streams width '
            '${levelDefinition.tuning.track.chunkWidth}.',
      );
    }
    playtestTierForDifficulty(draftTerrain.difficulty);

    final captured = StagedTerrainChunkCatalog(chunks: terrainChunks);
    final overlayCatalog = StagedTerrainChunkCatalog(
      chunks: <StagedTerrainChunkData>[
        for (final chunk in captured.chunksByKey.values)
          if (chunk.chunkKey != selectedKey) chunk,
        draftTerrain,
      ],
    );
    final scheduler = _buildSchedulerResult(
      levelDefinition: levelDefinition,
      catalog: overlayCatalog,
    );
    if (scheduler.issues.isNotEmpty) {
      final issue = scheduler.issues.first;
      throw PlaytestScenarioException(code: issue.code, message: issue.message);
    }

    final path = _selectScenarioPath(
      levelId: levelDefinition.identity.value,
      selectedChunkKey: selectedKey,
      scheduler: scheduler,
    );
    final patternsByKey = _collectPatternsByKey(
      levelDefinition: levelDefinition,
      draftPattern: immutablePlaytestPattern(draftPattern),
    );
    for (final chunkKey in path.chunkKeys) {
      if (!patternsByKey.containsKey(chunkKey)) {
        throw PlaytestScenarioException(
          code: 'chunk_playtest_pattern_missing',
          message:
              'Scheduler path references chunk $chunkKey, but the selected '
              'level has no runtime pattern for it.',
        );
      }
    }
    _validateDraftReachableSeams(
      selectedChunkKey: selectedKey,
      scheduler: scheduler,
      catalog: overlayCatalog,
    );
    _validatePathSeams(path: path, catalog: overlayCatalog);

    return ChunkPlaytestScenario._(
      levelDefinition: levelDefinition,
      visualThemeId: visualThemeId,
      seed: seed,
      tickHz: tickHz,
      draftPattern: patternsByKey[selectedKey]!,
      draftTerrain: draftTerrain,
      playerCharacter: playerCharacter,
      equippedLoadout: equippedLoadout,
      path: path,
      terrainCatalog: overlayCatalog,
      patternsByKey: patternsByKey,
    );
  }

  /// Builds a deterministic loop that contains every chunk in an editor
  /// filter result and no chunks outside that result.
  ///
  /// Pool order is derived from stable chunk keys and exact compiled boundary
  /// compatibility. Repeated connector chunks from the same pool are allowed
  /// when needed to reach every owner and close the loop.
  factory ChunkPlaytestScenario.filteredPool({
    required LevelDefinition levelDefinition,
    required String visualThemeId,
    required int seed,
    int tickHz = defaultTickHz,
    required Iterable<ChunkPattern> patterns,
    required Iterable<StagedTerrainChunkData> terrainChunks,
    required PlayerCharacterDefinition playerCharacter,
    required EquippedLoadoutDef equippedLoadout,
  }) {
    levelDefinition = immutablePlaytestLevelDefinition(levelDefinition);
    if (seed <= 0) {
      throw ArgumentError.value(seed, 'seed', 'Must be positive.');
    }
    if (tickHz <= 0) {
      throw ArgumentError.value(tickHz, 'tickHz', 'Must be positive.');
    }
    if (visualThemeId.trim().isEmpty) {
      throw ArgumentError.value(
        visualThemeId,
        'visualThemeId',
        'Must not be empty.',
      );
    }
    validatePlaytestLevelSettings(levelDefinition);

    final terrainCatalog = StagedTerrainChunkCatalog(chunks: terrainChunks);
    final patternsByKey = <String, ChunkPattern>{};
    for (final source in patterns) {
      final pattern = immutablePlaytestPattern(source);
      final key = pattern.chunkKey;
      if (key == null || key.isEmpty || patternsByKey.containsKey(key)) {
        throw const PlaytestScenarioException(
          code: 'chunk_playtest_pattern_key_invalid',
          message: 'Filtered patterns require unique stable chunk keys.',
        );
      }
      patternsByKey[key] = pattern;
    }
    if (patternsByKey.isEmpty) {
      throw const PlaytestScenarioException(
        code: 'chunk_playtest_filtered_pool_empty',
        message: 'Filtered Chunk Play requires at least one active owner.',
      );
    }
    if (patternsByKey.length != terrainCatalog.chunksByKey.length ||
        !patternsByKey.keys.every(terrainCatalog.chunksByKey.containsKey)) {
      throw const PlaytestScenarioException(
        code: 'chunk_playtest_filtered_pool_mismatch',
        message: 'Filtered patterns and compiled terrain must have exact matching keys.',
      );
    }
    final levelId = levelDefinition.identity.value;
    for (final entry in patternsByKey.entries) {
      final terrain = terrainCatalog.requireChunk(entry.key);
      if (terrain.levelId != levelId ||
          terrain.status != 'active' ||
          terrain.width.toDouble() != levelDefinition.tuning.track.chunkWidth ||
          terrain.assemblyGroupId != entry.value.assemblyGroupId) {
        throw PlaytestScenarioException(
          code: 'chunk_playtest_filtered_pool_invalid',
          message:
              'Filtered chunk ${entry.key} must match level $levelId, active '
              'status, runtime width, and its authored group.',
        );
      }
      playtestTierForDifficulty(terrain.difficulty);
    }

    final connections = <String, TerrainChunkConnection>{
      for (final key in patternsByKey.keys)
        key: _buildChunkConnection(
          chunkKey: key,
          levelDefinition: levelDefinition,
          catalog: terrainCatalog,
        ),
    };
    final path = _selectFilteredPoolPath(
      levelId: levelId,
      connections: connections,
    );
    _validatePathSeams(path: path, catalog: terrainCatalog);
    final firstKey = path.chunkKeys.first;
    return ChunkPlaytestScenario._(
      levelDefinition: levelDefinition,
      visualThemeId: visualThemeId,
      seed: seed,
      tickHz: tickHz,
      draftPattern: patternsByKey[firstKey]!,
      draftTerrain: terrainCatalog.requireChunk(firstKey),
      playerCharacter: playerCharacter,
      equippedLoadout: equippedLoadout,
      path: path,
      terrainCatalog: terrainCatalog,
      patternsByKey: Map<String, ChunkPattern>.unmodifiable(patternsByKey),
    );
  }

  const ChunkPlaytestScenario._({
    required this.levelDefinition,
    required this.visualThemeId,
    required this.seed,
    required this.tickHz,
    required this.draftPattern,
    required this.draftTerrain,
    required this.playerCharacter,
    required this.equippedLoadout,
    required this.path,
    required this.terrainCatalog,
    required Map<String, ChunkPattern> patternsByKey,
  }) : _patternsByKey = patternsByKey;

  final LevelDefinition levelDefinition;
  final String visualThemeId;
  final int seed;
  @override
  final int tickHz;
  final ChunkPattern draftPattern;
  final StagedTerrainChunkData draftTerrain;
  @override
  final PlayerCharacterDefinition playerCharacter;
  final EquippedLoadoutDef equippedLoadout;
  final ChunkPlaytestScenarioPath path;
  final StagedTerrainChunkCatalog terrainCatalog;
  final Map<String, ChunkPattern> _patternsByKey;

  /// Builds a fresh level/source pair for one Core construction or restart.
  LevelDefinition buildRuntimeLevelDefinition() => levelDefinition.copyWith(
    chunkPatternSource: _ChunkPlaytestPatternSource(
      seed: seed,
      path: path,
      patternsByKey: _patternsByKey,
      terrainCatalog: terrainCatalog,
    ),
    groundTopY: levelDefinition.groundTopY,
    tuning: levelDefinition.tuning,
    cameraCenterY: levelDefinition.cameraCenterY,
    killPlaneY: levelDefinition.killPlaneY,
    earlyPatternChunks: levelDefinition.earlyPatternChunks,
    easyPatternChunks: levelDefinition.easyPatternChunks,
    normalPatternChunks: levelDefinition.normalPatternChunks,
    noEnemyChunks: 0,
    visualThemeId: visualThemeId,
    clearFirstChunkKey: true,
    clearAssembly: true,
  );
}

TerrainAuthoringSchedulerResult _buildSchedulerResult({
  required LevelDefinition levelDefinition,
  required StagedTerrainChunkCatalog catalog,
}) {
  final levelId = levelDefinition.identity.value;
  final chunks = <TerrainAuthoringSchedulerChunk>[];
  for (final chunk in catalog.chunksByKey.values) {
    if (chunk.levelId != levelId) {
      throw PlaytestScenarioException(
        code: 'chunk_playtest_level_mismatch',
        message:
            'Chunk ${chunk.chunkKey} belongs to ${chunk.levelId}, not $levelId.',
      );
    }
    if (chunk.width.toDouble() != levelDefinition.tuning.track.chunkWidth) {
      throw PlaytestScenarioException(
        code: 'chunk_playtest_width_mismatch',
        message: 'Chunk ${chunk.chunkKey} has an incompatible stream width.',
      );
    }
    chunks.add(
      TerrainAuthoringSchedulerChunk(
        chunkKey: chunk.chunkKey,
        levelId: chunk.levelId,
        tier: playtestTierForDifficulty(chunk.difficulty),
        assemblyGroupId: chunk.assemblyGroupId,
        isActive: chunk.status == 'active',
      ),
    );
  }
  return enumerateTerrainAuthoringReachability(
    chunks: chunks,
    connections: {
      for (final chunk in catalog.chunksByKey.values)
        chunk.chunkKey: _buildChunkConnection(
          chunkKey: chunk.chunkKey,
          levelDefinition: levelDefinition,
          catalog: catalog,
        ),
    },
    levels: <TerrainAuthoringSchedulerLevel>[
      TerrainAuthoringSchedulerLevel(
        levelId: levelId,
        earlyPatternChunks: levelDefinition.earlyPatternChunks,
        easyPatternChunks: levelDefinition.easyPatternChunks,
        normalPatternChunks: levelDefinition.normalPatternChunks,
        firstChunkKey: levelDefinition.firstChunkKey,
        assembly: playtestSchedulerAssembly(levelDefinition.assembly),
      ),
    ],
  );
}

TerrainChunkConnection _buildChunkConnection({
  required String chunkKey,
  required LevelDefinition levelDefinition,
  required StagedTerrainCatalog catalog,
}) => buildTerrainChunkConnection(
  chunkKey: chunkKey,
  chunkWidth: catalog.requireChunk(chunkKey).width,
  geometry: const StagedTerrainWorldGeometryBuilder().build(
    bindings: [
      catalog.bind(chunkKey: chunkKey, chunkIndex: 0, worldOriginXTicks: 0),
    ],
    geometryVersion: 0,
  ),
  groundTopY: levelDefinition.groundTopY,
  spawnX: levelDefinition.tuning.track.playerStartX,
);

ChunkPlaytestScenarioPath _selectFilteredPoolPath({
  required String levelId,
  required Map<String, TerrainChunkConnection> connections,
}) {
  final keys = connections.keys.toList()..sort();
  final start = keys.where((key) => connections[key]!.canStart).firstOrNull;
  if (start == null) {
    throw const PlaytestScenarioException(
      code: 'chunk_playtest_filtered_pool_no_opener',
      message: 'No filtered chunk supports the normal player opener.',
    );
  }
  List<String>? route(String from, String to) {
    if (from == to) return const <String>[];
    final parents = <String, String?>{from: null};
    final pending = <String>[from];
    for (var index = 0; index < pending.length; index += 1) {
      final current = pending[index];
      for (final candidate in keys) {
        if (parents.containsKey(candidate) ||
            connections[current]!.exit != connections[candidate]!.entrance) {
          continue;
        }
        parents[candidate] = current;
        if (candidate == to) {
          final reversed = <String>[candidate];
          var cursor = current;
          while (cursor != from) {
            reversed.add(cursor);
            cursor = parents[cursor]!;
          }
          return reversed.reversed.toList(growable: false);
        }
        pending.add(candidate);
      }
    }
    return null;
  }

  final path = <String>[start];
  final visited = <String>{start};
  var current = start;
  for (final target in keys) {
    if (visited.contains(target)) continue;
    final segment = route(current, target);
    if (segment == null) {
      throw PlaytestScenarioException(
        code: 'chunk_playtest_filtered_pool_disconnected',
        message:
            'Filtered chunk $target cannot be reached from $current using only the filtered pool.',
      );
    }
    path.addAll(segment);
    visited.addAll(segment);
    current = target;
  }
  final closing = route(current, start);
  if (closing == null) {
    throw PlaytestScenarioException(
      code: 'chunk_playtest_filtered_pool_disconnected',
      message:
          'Filtered chunk $current cannot loop back to opener $start using only the filtered pool.',
    );
  }
  if (closing.isNotEmpty) {
    path.addAll(closing.take(closing.length - 1));
  }
  return ChunkPlaytestScenarioPath._(
    chunkKeys: path,
    selectedChunkIndex: 0,
    loopStartIndex: 0,
    transitionRecords: [
      for (var index = 0; index < path.length; index += 1)
        '$levelId|connections:filtered|${path[index]}>${path[index + 1 < path.length ? index + 1 : 0]}',
    ],
  );
}

ChunkPlaytestScenarioPath _selectScenarioPath({
  required String levelId,
  required String selectedChunkKey,
  required TerrainAuthoringSchedulerResult scheduler,
}) {
  final witness = scheduler.schedules[levelId]?.witnessThrough(
    selectedChunkKey,
  );
  if (witness == null) {
    throw PlaytestScenarioException(
      code: 'chunk_playtest_selected_chunk_unreachable',
      message:
          'Chunk $selectedChunkKey has no valid opening and continuing schedule in $levelId.',
    );
  }
  return ChunkPlaytestScenarioPath._(
    chunkKeys: witness.chunkKeys,
    selectedChunkIndex: witness.selectedIndex,
    loopStartIndex: witness.loopStartIndex,
    transitionRecords: [
      for (var i = 0; i < witness.chunkKeys.length; i++)
        '$levelId|connections:focused|${witness.chunkKeys[i]}>${witness.chunkKeys[i + 1 < witness.chunkKeys.length ? i + 1 : witness.loopStartIndex]}',
    ],
  );
}

Map<String, ChunkPattern> _collectPatternsByKey({
  required LevelDefinition levelDefinition,
  required ChunkPattern draftPattern,
}) {
  final source = levelDefinition.chunkPatternSource;
  final listSource = switch (source) {
    ChunkPatternListSource value => value,
    FirstChunkPatternSource value => value.baseSource,
    AssembledChunkPatternSource value => value.baseSource,
    _ => throw PlaytestScenarioException(
      code: 'chunk_playtest_pattern_source_unsupported',
      message: 'Chunk playtest requires a list-backed authored pattern source.',
    ),
  };
  final patterns = <String, ChunkPattern>{};
  for (final pattern in <ChunkPattern>[
    ...listSource.earlyPatterns,
    ...listSource.easyPatterns,
    ...listSource.normalPatterns,
    ...listSource.hardPatterns,
  ]) {
    final key = pattern.chunkKey;
    if (key == null || key.isEmpty || patterns.containsKey(key)) {
      throw const PlaytestScenarioException(
        code: 'chunk_playtest_pattern_key_invalid',
        message: 'Captured patterns require unique stable chunk keys.',
      );
    }
    patterns[key] = pattern;
  }
  patterns[draftPattern.chunkKey!] = draftPattern;
  return Map<String, ChunkPattern>.unmodifiable(patterns);
}

void _validateDraftReachableSeams({
  required String selectedChunkKey,
  required TerrainAuthoringSchedulerResult scheduler,
  required StagedTerrainCatalog catalog,
}) {
  for (final transition in scheduler.transitions) {
    if (transition.leftChunkKey != selectedChunkKey &&
        transition.rightChunkKey != selectedChunkKey) {
      continue;
    }
    validatePlaytestSeam(
      transitionRecord: transition.canonicalRecord,
      leftChunkKey: transition.leftChunkKey,
      rightChunkKey: transition.rightChunkKey,
      catalog: catalog,
    );
  }
}

void _validatePathSeams({
  required ChunkPlaytestScenarioPath path,
  required StagedTerrainCatalog catalog,
}) {
  for (var index = 0; index < path.chunkKeys.length; index += 1) {
    final nextIndex = index + 1 < path.chunkKeys.length
        ? index + 1
        : path.loopStartIndex;
    validatePlaytestSeam(
      transitionRecord: path.transitionRecords[index],
      leftChunkKey: path.chunkKeys[index],
      rightChunkKey: path.chunkKeys[nextIndex],
      catalog: catalog,
    );
  }
}

final class _ChunkPlaytestPatternSource extends ChunkPatternSource {
  const _ChunkPlaytestPatternSource({
    required this.seed,
    required this.path,
    required this.patternsByKey,
    required this.terrainCatalog,
  });

  final int seed;
  final ChunkPlaytestScenarioPath path;
  final Map<String, ChunkPattern> patternsByKey;
  final StagedTerrainCatalog terrainCatalog;

  @override
  ChunkPatternSelection selectionFor({
    required int seed,
    required int chunkIndex,
    required ChunkPatternTier tier,
  }) {
    if (seed != this.seed) {
      throw StateError(
        'Chunk playtest path was built for seed ${this.seed}, not $seed.',
      );
    }
    final key = path.chunkKeyForIndex(chunkIndex);
    return ChunkPatternSelection(
      pattern: patternsByKey[key]!,
      tier: playtestTierForDifficulty(
        terrainCatalog.requireChunk(key).difficulty,
      ),
    );
  }
}
