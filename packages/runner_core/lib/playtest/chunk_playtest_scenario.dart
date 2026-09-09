/// Immutable Core construction contract for an isolated authored-chunk test.
library;

import '../collision/terrain/terrain_authoring_scheduler.dart';
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
      transitions: scheduler.transitions,
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
    levels: <TerrainAuthoringSchedulerLevel>[
      TerrainAuthoringSchedulerLevel(
        levelId: levelId,
        earlyPatternChunks: levelDefinition.earlyPatternChunks,
        easyPatternChunks: levelDefinition.easyPatternChunks,
        normalPatternChunks: levelDefinition.normalPatternChunks,
        assembly: playtestSchedulerAssembly(levelDefinition.assembly),
      ),
    ],
  );
}

ChunkPlaytestScenarioPath _selectScenarioPath({
  required String levelId,
  required String selectedChunkKey,
  required Iterable<TerrainAuthoringReachableTransition> transitions,
}) {
  final ordered =
      transitions.where((transition) => transition.levelId == levelId).toList()
        ..sort(
          (left, right) =>
              left.canonicalRecord.compareTo(right.canonicalRecord),
        );
  final touchingSelected = ordered.where(
    (transition) =>
        transition.leftChunkKey == selectedChunkKey ||
        transition.rightChunkKey == selectedChunkKey,
  );
  if (touchingSelected.isEmpty) {
    throw PlaytestScenarioException(
      code: 'chunk_playtest_selected_chunk_unreachable',
      message:
          'Active chunk $selectedChunkKey is not reachable in level $levelId.',
    );
  }

  final incoming = ordered
      .where(
        (transition) =>
            transition.rightChunkKey == selectedChunkKey &&
            transition.leftChunkKey != selectedChunkKey,
      )
      .toList(growable: false);
  final chunkKeys = <String>[];
  final transitionRecords = <String>[];
  if (incoming.isNotEmpty) {
    chunkKeys
      ..add(incoming.first.leftChunkKey)
      ..add(selectedChunkKey);
    transitionRecords.add(incoming.first.canonicalRecord);
  } else {
    chunkKeys.add(selectedChunkKey);
  }
  final selectedChunkIndex = chunkKeys.length - 1;
  final firstIndexByKey = <String, int>{
    for (var index = 0; index < chunkKeys.length; index += 1)
      chunkKeys[index]: index,
  };

  while (true) {
    final current = chunkKeys.last;
    final outgoing = ordered
        .where((transition) => transition.leftChunkKey == current)
        .toList(growable: false);
    if (outgoing.isEmpty) {
      throw PlaytestScenarioException(
        code: 'chunk_playtest_scenario_path_dead_end',
        message:
            'Scheduler-reachable path for $selectedChunkKey stops at '
            '$current before a deterministic loop can be formed.',
      );
    }
    final selectedTransition = outgoing.first;
    transitionRecords.add(selectedTransition.canonicalRecord);
    final next = selectedTransition.rightChunkKey;
    final loopStartIndex = firstIndexByKey[next];
    if (loopStartIndex != null) {
      return ChunkPlaytestScenarioPath._(
        chunkKeys: chunkKeys,
        transitionRecords: transitionRecords,
        selectedChunkIndex: selectedChunkIndex,
        loopStartIndex: loopStartIndex,
      );
    }
    firstIndexByKey[next] = chunkKeys.length;
    chunkKeys.add(next);
  }
}

Map<String, ChunkPattern> _collectPatternsByKey({
  required LevelDefinition levelDefinition,
  required ChunkPattern draftPattern,
}) {
  final source = levelDefinition.chunkPatternSource;
  final listSource = switch (source) {
    ChunkPatternListSource value => value,
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
  });

  final int seed;
  final ChunkPlaytestScenarioPath path;
  final Map<String, ChunkPattern> patternsByKey;

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
    final _ = tier;
    final key = path.chunkKeyForIndex(chunkIndex);
    return ChunkPatternSelection(pattern: patternsByKey[key]!);
  }
}
