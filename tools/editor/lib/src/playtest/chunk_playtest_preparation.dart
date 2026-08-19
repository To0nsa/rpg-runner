import 'dart:isolate';

import 'package:meta/meta.dart';
import 'package:rpg_runner/playtest.dart';
import 'package:runner_content_pipeline/runner_content_pipeline.dart';
import 'package:runner_core/ecs/stores/combat/equipped_loadout_store.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/levels/level_registry.dart';
import 'package:runner_core/players/player_character_registry.dart';

import '../chunks/chunk_v2_file_codec.dart';
import '../chunks/chunk_v2_models.dart';
import '../prefabs/store/prefab_store.dart';
import '../prefabs/store/prefab_tile_file_codec.dart';
import '../prefabs/store/prefab_v3_file_codec.dart';

/// Fixed Phase 5 seed used for reproducible authoring feedback.
///
/// Changing the seed is a future explicit scenario option, never a wall-clock
/// side effect of entering Play mode.
const int chunkPlaytestDefaultSeed = 4401;

/// Stable failure raised before an immutable preparation input can be built.
final class ChunkPlaytestPreparationException implements Exception {
  const ChunkPlaytestPreparationException({
    required this.code,
    required this.message,
  });

  final String code;
  final String message;

  @override
  String toString() => '$code: $message';
}

/// Sendable canonical source snapshot consumed by the background compiler.
///
/// Contents come from the accepted plugin document, including unapplied
/// session commands. Repository baselines and mutable editor controllers are
/// deliberately absent so background preparation cannot read or write files.
@immutable
final class ChunkPlaytestPreparationInput {
  const ChunkPlaytestPreparationInput({
    required this.selectedChunkKey,
    required this.levelId,
    required this.visualThemeId,
    required this.prefabSourcePath,
    required this.prefabContents,
    required this.tileSourcePath,
    required this.tileContents,
    required this.chunkSourcePath,
    required this.chunkContents,
    this.seed = chunkPlaytestDefaultSeed,
  });

  final String selectedChunkKey;
  final String levelId;
  final String visualThemeId;
  final String prefabSourcePath;
  final String prefabContents;
  final String tileSourcePath;
  final String tileContents;
  final String chunkSourcePath;
  final String chunkContents;
  final int seed;
}

/// One deterministic editor-facing preparation diagnostic.
@immutable
final class ChunkPlaytestPreparationIssue
    implements Comparable<ChunkPlaytestPreparationIssue> {
  const ChunkPlaytestPreparationIssue({
    required this.code,
    required this.message,
    this.sourcePath,
    this.ownerKey,
  });

  final String code;
  final String message;
  final String? sourcePath;
  final String? ownerKey;

  @override
  int compareTo(ChunkPlaytestPreparationIssue other) {
    var order = (sourcePath ?? '').compareTo(other.sourcePath ?? '');
    if (order != 0) return order;
    order = (ownerKey ?? '').compareTo(other.ownerKey ?? '');
    if (order != 0) return order;
    order = code.compareTo(other.code);
    return order != 0 ? order : message.compareTo(other.message);
  }
}

/// Fail-closed outcome from pure source compilation and scenario admission.
@immutable
final class ChunkPlaytestPreparationResult {
  ChunkPlaytestPreparationResult._({
    required this.scenario,
    required Iterable<ChunkPlaytestPreparationIssue> issues,
  }) : issues = List<ChunkPlaytestPreparationIssue>.unmodifiable(
         List<ChunkPlaytestPreparationIssue>.of(issues)..sort(),
       ) {
    if ((scenario == null) == this.issues.isEmpty) {
      throw ArgumentError(
        'Preparation requires either one scenario or one-or-more issues.',
      );
    }
  }

  /// Successful immutable scenario, absent whenever [issues] is non-empty.
  final ChunkPlaytestScenario? scenario;

  /// Canonically ordered blockers; no partial scenario accompanies them.
  final List<ChunkPlaytestPreparationIssue> issues;

  bool get isSuccess => scenario != null;

  factory ChunkPlaytestPreparationResult.success(
    ChunkPlaytestScenario scenario,
  ) => ChunkPlaytestPreparationResult._(
    scenario: scenario,
    issues: const <ChunkPlaytestPreparationIssue>[],
  );

  factory ChunkPlaytestPreparationResult.failure(
    Iterable<ChunkPlaytestPreparationIssue> issues,
  ) => ChunkPlaytestPreparationResult._(scenario: null, issues: issues);
}

/// Background preparation seam injectable by Chunk Creator widget tests.
typedef ChunkPlaytestPreparationRunner =
    Future<ChunkPlaytestPreparationResult> Function(
      ChunkPlaytestPreparationInput input,
    );

/// Captures canonical source strings from one accepted editor document.
///
/// The selected owner and its Level must exist in the same immutable document.
/// Encoding performs no filesystem access and fails before returning a partial
/// input if the accepted DTOs cannot satisfy their current-schema codecs.
ChunkPlaytestPreparationInput captureChunkPlaytestPreparationInput({
  required ChunkV2Document document,
  required String selectedChunkKey,
}) {
  final selectedChunk = document.chunks
      .where((chunk) => chunk.chunkKey == selectedChunkKey)
      .firstOrNull;
  if (selectedChunk == null) {
    throw ChunkPlaytestPreparationException(
      code: 'chunk_playtest_owner_missing',
      message: 'Selected chunk owner "$selectedChunkKey" no longer exists.',
    );
  }
  final level = document.levels
      .where((candidate) => candidate.levelId == selectedChunk.levelId)
      .firstOrNull;
  if (level == null) {
    throw ChunkPlaytestPreparationException(
      code: 'chunk_playtest_level_missing',
      message:
          'Selected chunk ${selectedChunk.chunkKey} has no Level definition '
          'for ${selectedChunk.levelId}.',
    );
  }
  if (level.visualThemeId.trim().isEmpty) {
    throw ChunkPlaytestPreparationException(
      code: 'chunk_playtest_visual_theme_missing',
      message: 'Level ${level.levelId} has no visual theme for Play mode.',
    );
  }
  final sourcePath = document.sourcePathByChunkKey[selectedChunkKey];
  if (sourcePath == null || sourcePath.trim().isEmpty) {
    throw ChunkPlaytestPreparationException(
      code: 'chunk_playtest_source_path_missing',
      message: 'Selected chunk $selectedChunkKey has no canonical source path.',
    );
  }

  try {
    return ChunkPlaytestPreparationInput(
      selectedChunkKey: selectedChunkKey,
      levelId: selectedChunk.levelId,
      visualThemeId: level.visualThemeId,
      prefabSourcePath: PrefabStore.prefabDefsPath,
      prefabContents: PrefabV3FileCodec.encode(document.prefabData),
      tileSourcePath: PrefabStore.tileDefsPath,
      tileContents: PrefabTileFileCodec.encode(document.tileData),
      chunkSourcePath: sourcePath,
      chunkContents: ChunkV2FileCodec.encode(selectedChunk),
    );
  } on FormatException catch (error) {
    throw ChunkPlaytestPreparationException(
      code: 'chunk_playtest_snapshot_invalid',
      message: error.message.toString(),
    );
  } on ArgumentError catch (error) {
    throw ChunkPlaytestPreparationException(
      code: 'chunk_playtest_snapshot_invalid',
      message: error.message?.toString() ?? error.toString(),
    );
  }
}

/// Compiles one captured snapshot on a background isolate.
///
/// Only the immutable input crosses the isolate boundary. Cancellation is
/// generation-based at the page owner: a completed stale result is ignored.
Future<ChunkPlaytestPreparationResult> prepareChunkPlaytestInBackground(
  ChunkPlaytestPreparationInput input,
) => Isolate.run(() => prepareChunkPlaytest(input));

/// Pure deterministic compiler/admission operation for one captured snapshot.
///
/// This function performs no filesystem, Flutter widget, Flame, replay, or
/// backend work and returns no scenario alongside a blocking issue.
ChunkPlaytestPreparationResult prepareChunkPlaytest(
  ChunkPlaytestPreparationInput input,
) {
  final levelId = LevelId.values
      .where((candidate) => candidate.name == input.levelId)
      .firstOrNull;
  if (levelId == null) {
    return ChunkPlaytestPreparationResult.failure(
      <ChunkPlaytestPreparationIssue>[
        ChunkPlaytestPreparationIssue(
          code: 'chunk_playtest_level_unsupported',
          message:
              'Level ${input.levelId} is not present in the generated Core '
              'level registry.',
          sourcePath: input.chunkSourcePath,
          ownerKey: input.selectedChunkKey,
        ),
      ],
    );
  }

  try {
    final runtimeResult = compilePolygonTerrainRuntimeChunkSource(
      prefabSourcePath: input.prefabSourcePath,
      prefabContents: input.prefabContents,
      tileSourcePath: input.tileSourcePath,
      tileContents: input.tileContents,
      chunkSourcePath: input.chunkSourcePath,
      chunkContents: input.chunkContents,
    );
    final runtimeChunk = runtimeResult.chunk;
    if (runtimeChunk == null) {
      return ChunkPlaytestPreparationResult.failure(
        runtimeResult.issues.map(
          (issue) => ChunkPlaytestPreparationIssue(
            code: issue.code,
            message: issue.message,
            sourcePath: issue.sourcePath,
            ownerKey: issue.ownerKey,
          ),
        ),
      );
    }

    final scenario = ChunkPlaytestScenario(
      levelDefinition: LevelRegistry.byId(levelId),
      visualThemeId: input.visualThemeId,
      seed: input.seed,
      draftPattern: runtimeChunk.pattern,
      draftTerrain: runtimeChunk.stagedTerrain,
      playerCharacter: PlayerCharacterRegistry.eloise,
      equippedLoadout: const EquippedLoadoutDef(),
    );
    return ChunkPlaytestPreparationResult.success(scenario);
  } on ChunkPlaytestScenarioException catch (error) {
    return ChunkPlaytestPreparationResult.failure(
      <ChunkPlaytestPreparationIssue>[
        ChunkPlaytestPreparationIssue(
          code: error.code,
          message: error.message,
          sourcePath: input.chunkSourcePath,
          ownerKey: input.selectedChunkKey,
        ),
      ],
    );
  } on FormatException catch (error) {
    return _unexpectedPreparationFailure(input, error.message.toString());
  } on ArgumentError catch (error) {
    return _unexpectedPreparationFailure(
      input,
      error.message?.toString() ?? error.toString(),
    );
  } on Object catch (error) {
    return _unexpectedPreparationFailure(input, error.toString());
  }
}

ChunkPlaytestPreparationResult _unexpectedPreparationFailure(
  ChunkPlaytestPreparationInput input,
  String message,
) => ChunkPlaytestPreparationResult.failure(<ChunkPlaytestPreparationIssue>[
  ChunkPlaytestPreparationIssue(
    code: 'chunk_playtest_preparation_failed',
    message: message,
    sourcePath: input.chunkSourcePath,
    ownerKey: input.selectedChunkKey,
  ),
]);
