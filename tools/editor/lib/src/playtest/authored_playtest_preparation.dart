import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'dart:isolate';

import 'package:meta/meta.dart';
import 'package:rpg_runner/playtest.dart';
import 'package:runner_content_pipeline/runner_content_pipeline.dart';
import 'package:runner_core/ecs/stores/combat/equipped_loadout_store.dart';
import 'package:runner_core/levels/level_assembly.dart';
import 'package:runner_core/levels/level_definition.dart';
import 'package:runner_core/levels/level_identity.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:runner_core/track/chunk_pattern.dart';
import 'package:runner_core/track/chunk_pattern_source.dart';
import 'package:terrain_materials/terrain_materials.dart';

import '../chunks/chunk_domain_plugin.dart';
import '../chunks/chunk_v2_file_codec.dart';
import '../chunks/chunk_v2_models.dart';
import '../levels/level_domain_models.dart';
import '../parallax/parallax_domain_models.dart';
import '../prefabs/store/prefab_store.dart';
import '../prefabs/store/prefab_tile_file_codec.dart';
import '../prefabs/store/prefab_v3_file_codec.dart';
import '../terrain_materials/terrain_material_domain_models.dart';
import '../workspace/editor_workspace.dart';
import '../workspace/workspace_file_io.dart';
import 'playtest_asset_validation.dart';

const int playtestDefaultSeed = 4401;

/// Capture/compiler failure that preserves source location for editor recovery.
final class PlaytestPreparationException implements Exception {
  const PlaytestPreparationException({
    required this.code,
    required this.message,
  });
  final String code;
  final String message;
  @override
  String toString() => '$code: $message';
}

/// Sendable immutable accepted source generation; no controllers or write access.
@immutable
final class PlaytestPreparationInput {
  PlaytestPreparationInput({
    required this.workspaceRoot,
    required LevelDef level,
    required ParallaxThemeDef theme,
    required Map<String, String> chunkSources,
    required this.prefabContents,
    required this.tileContents,
    required this.terrainMaterialContents,
    required Map<String, String> sourceBaseline,
    required Iterable<String> repositoryChunkPaths,
    String? selectedChunkKey,
    Iterable<String>? selectedChunkKeys,
    this.seed = playtestDefaultSeed,
  }) : level = level.normalized(),
       theme = theme.normalized(),
       chunkSources = Map.unmodifiable(
         Map.fromEntries(
           chunkSources.entries.toList()
             ..sort((a, b) => a.key.compareTo(b.key)),
         ),
       ),
       sourceBaseline = Map.unmodifiable(sourceBaseline),
       repositoryChunkPaths = List.unmodifiable(repositoryChunkPaths),
       selectedChunkKeys = _normalizeSelectedChunkKeys(
         selectedChunkKey: selectedChunkKey,
         selectedChunkKeys: selectedChunkKeys,
       );

  final String workspaceRoot;
  final LevelDef level;
  final ParallaxThemeDef theme;
  final Map<String, String> chunkSources;
  final String prefabContents;
  final String tileContents;
  final String terrainMaterialContents;
  final Map<String, String> sourceBaseline;
  final List<String> repositoryChunkPaths;

  /// Null selects whole-Level scope; otherwise these are the filtered owners.
  final List<String>? selectedChunkKeys;

  /// Compatibility view for single-owner callers and focused diagnostics.
  String? get selectedChunkKey =>
      selectedChunkKeys?.length == 1 ? selectedChunkKeys!.single : null;
  final int seed;

  String get fingerprint => WorkspaceFileIo.fingerprint(
    jsonEncode({
      'level': renderCanonicalLevelDefsJson([level]),
      'theme': renderCanonicalParallaxDefsJson([theme]),
      'chunks': chunkSources,
      'prefabs': prefabContents,
      'tiles': tileContents,
      'materials': terrainMaterialContents,
      'seed': seed,
      'selectedChunkKeys': selectedChunkKeys,
    }),
  );
}

List<String>? _normalizeSelectedChunkKeys({
  required String? selectedChunkKey,
  required Iterable<String>? selectedChunkKeys,
}) {
  if (selectedChunkKey != null && selectedChunkKeys != null) {
    throw ArgumentError(
      'Provide selectedChunkKey or selectedChunkKeys, not both.',
    );
  }
  if (selectedChunkKey == null && selectedChunkKeys == null) return null;
  final keys = <String>{?selectedChunkKey, ...?selectedChunkKeys}.toList()
    ..sort();
  if (keys.isEmpty || keys.any((key) => key.trim().isEmpty)) {
    throw ArgumentError.value(
      selectedChunkKeys,
      'selectedChunkKeys',
      'Chunk Play requires at least one non-empty owner key.',
    );
  }
  return List<String>.unmodifiable(keys);
}

@immutable
final class PlaytestPreparationIssue
    implements Comparable<PlaytestPreparationIssue> {
  const PlaytestPreparationIssue({
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
  int compareTo(PlaytestPreparationIssue other) {
    var order = (sourcePath ?? '').compareTo(other.sourcePath ?? '');
    if (order != 0) return order;
    order = (ownerKey ?? '').compareTo(other.ownerKey ?? '');
    if (order != 0) return order;
    order = code.compareTo(other.code);
    return order != 0 ? order : message.compareTo(other.message);
  }
}

/// Pure compilation may succeed before the outer preparation captures images.
final class PlaytestPreparationResult {
  PlaytestPreparationResult._({
    required this.scenario,
    required this.appearance,
    required this.fingerprint,
    required Iterable<PlaytestPreparationIssue> issues,
    required Iterable<String> warnings,
    this.assetBundle,
  }) : issues = List.unmodifiable(issues.toList()..sort()),
       warnings = List.unmodifiable(warnings);

  factory PlaytestPreparationResult.success({
    required PlaytestScenario scenario,
    required RunnerPlaytestAppearance appearance,
    required String fingerprint,
    Iterable<String> warnings = const [],
    RunnerCapturedAssetBundle? assetBundle,
  }) => PlaytestPreparationResult._(
    scenario: scenario,
    appearance: appearance,
    fingerprint: fingerprint,
    issues: const [],
    warnings: warnings,
    assetBundle: assetBundle,
  );
  factory PlaytestPreparationResult.failure(
    Iterable<PlaytestPreparationIssue> issues,
  ) => PlaytestPreparationResult._(
    scenario: null,
    appearance: null,
    fingerprint: null,
    issues: issues,
    warnings: const [],
  );

  final PlaytestScenario? scenario;
  final RunnerPlaytestAppearance? appearance;
  final RunnerCapturedAssetBundle? assetBundle;
  final String? fingerprint;
  final List<PlaytestPreparationIssue> issues;
  final List<String> warnings;
  bool get isSuccess => scenario != null;
}

typedef PlaytestPreparationRunner = Future<PlaytestPreparationResult> Function(
  PlaytestPreparationInput input,
);

/// Captures accepted Chunk edits with their complete authored level dependencies.
Future<PlaytestPreparationInput> captureChunkPlaytestPreparationInput({
  required ChunkV2Document document,
  String? selectedChunkKey,
  Iterable<String>? selectedChunkKeys,
  required String workspaceRoot,
  int seed = playtestDefaultSeed,
}) async {
  final keys = _normalizeSelectedChunkKeys(
    selectedChunkKey: selectedChunkKey,
    selectedChunkKeys: selectedChunkKeys,
  );
  if (keys == null) {
    throw ArgumentError('Chunk Play requires selected owner keys.');
  }
  final selected = document.chunks
      .where((chunk) => keys.contains(chunk.chunkKey))
      .toList(growable: false);
  if (selected.length != keys.length) {
    throw const PlaytestPreparationException(
      code: 'chunk_playtest_owner_missing',
      message: 'A filtered chunk owner no longer exists.',
    );
  }
  final levelIds = selected.map((chunk) => chunk.levelId).toSet();
  if (levelIds.length != 1) {
    throw const PlaytestPreparationException(
      code: 'chunk_playtest_level_mismatch',
      message: 'Filtered chunk owners must belong to one authored level.',
    );
  }
  final level = document.levels
      .where((candidate) => candidate.levelId == levelIds.single)
      .firstOrNull;
  if (level == null) {
    throw const PlaytestPreparationException(
      code: 'chunk_playtest_level_missing',
      message: 'The selected chunk has no authored level definition.',
    );
  }
  final theme = document.parallaxThemes
      .where((t) => t.parallaxThemeId == level.visualThemeId)
      .firstOrNull;
  if (theme == null) {
    throw const PlaytestPreparationException(
      code: 'playtest_theme_missing',
      message: 'The assigned authored background is unavailable.',
    );
  }
  return _capture(
    workspaceRoot: workspaceRoot,
    level: level,
    theme: theme,
    content: document,
    selectedChunkKeys: keys,
    seed: seed,
    expectedLevels: renderCanonicalLevelDefsJson(document.levels),
    expectedThemes: renderCanonicalParallaxDefsJson(document.parallaxThemes),
  );
}

/// Captures a Level's accepted metadata/theme while dependency writes stay owned
/// by their domains. A route may reuse its current immutable content projection.
Future<PlaytestPreparationInput> captureLevelPlaytestPreparationInput({
  required LevelDefsDocument document,
  required String levelId,
  required String workspaceRoot,
  ChunkV2Document? contentDocument,
  int seed = playtestDefaultSeed,
}) async {
  final level = document.levels.where((l) => l.levelId == levelId).firstOrNull;
  final theme =
      (document.parallaxDocument?.themes ?? const <ParallaxThemeDef>[])
          .where((t) => t.parallaxThemeId == level?.visualThemeId)
          .firstOrNull;
  if (level == null || theme == null) {
    throw const PlaytestPreparationException(
      code: 'playtest_level_or_theme_missing',
      message: 'The selected level and assigned background must exist.',
    );
  }
  final content =
      contentDocument ??
      await ChunkDomainPlugin().loadV2FromRepo(
        EditorWorkspace(rootPath: workspaceRoot),
      );
  return _capture(
    workspaceRoot: workspaceRoot,
    level: level,
    theme: theme,
    content: content,
    seed: seed,
    expectedLevels: document.baseline?.sourceContent,
    expectedThemes: document.parallaxDocument?.baseline?.sourceContent,
  );
}

Future<PlaytestPreparationInput> _capture({
  required String workspaceRoot,
  required LevelDef level,
  required ParallaxThemeDef theme,
  required ChunkV2Document content,
  required int seed,
  required String? expectedLevels,
  required String? expectedThemes,
  String? selectedChunkKey,
  Iterable<String>? selectedChunkKeys,
}) async {
  final bundle = RunnerWorkspaceAssetBundle(workspaceRoot: workspaceRoot);
  final repositoryChunkPaths = await _chunkPaths(workspaceRoot);
  final sources = <String, String>{};
  Future<String> read(String path, {String? expected}) async {
    final raw = await bundle.loadString(path, cache: false);
    if (expected != null &&
        raw.replaceAll('\r\n', '\n') != expected.replaceAll('\r\n', '\n')) {
      throw PlaytestPreparationException(
        code: 'playtest_source_drift',
        message:
            '$path changed since it was loaded. Reload or resolve the source conflict.',
      );
    }
    sources[path] = raw;
    return raw;
  }

  await read(levelDefsSourcePath, expected: expectedLevels);
  await read(parallaxDefsSourcePath, expected: expectedThemes);
  final prefabs = PrefabV3FileCodec.encode(content.prefabData);
  final tiles = PrefabTileFileCodec.encode(content.tileData);
  await read(PrefabStore.prefabDefsPath, expected: prefabs);
  await read(PrefabStore.tileDefsPath, expected: tiles);
  final materials = await read(terrainMaterialDefsSourcePath);
  final chunks = <String, String>{};
  final selectedChunks =
      content.chunks.where((c) => c.levelId == level.levelId).toList()
        ..sort((a, b) => a.chunkKey.compareTo(b.chunkKey));
  for (final chunk in selectedChunks) {
    final sourcePath = content.sourcePathByChunkKey[chunk.chunkKey];
    if (sourcePath == null || sourcePath.isEmpty) {
      throw PlaytestPreparationException(
        code: 'chunk_playtest_source_path_missing',
        message: 'Chunk ${chunk.chunkKey} has no canonical source path.',
      );
    }
    final path = p
        .relative(
          p.isAbsolute(sourcePath)
              ? sourcePath
              : p.join(workspaceRoot, sourcePath),
          from: workspaceRoot,
        )
        .replaceAll('\\', '/');
    if (!path.startsWith('assets/authoring/level/chunks/${level.levelId}/') ||
        path.split('/').any((part) => part == '..' || part == '.')) {
      throw PlaytestPreparationException(
        code: 'chunk_playtest_source_path_invalid',
        message:
            'Chunk ${chunk.chunkKey} must belong to its canonical level folder.',
      );
    }
    final baseline = content.baselineContentsByChunkKey[chunk.chunkKey];
    if (baseline != null) {
      await read(path, expected: baseline);
    } else if (repositoryChunkPaths.contains(path)) {
      throw PlaytestPreparationException(
        code: 'playtest_source_drift',
        message:
            'A new chunk target already exists at $path. Resolve the source conflict.',
      );
    }
    chunks[path] = ChunkV2FileCodec.encode(chunk);
  }
  final input = PlaytestPreparationInput(
    workspaceRoot: workspaceRoot,
    level: level,
    theme: theme,
    chunkSources: chunks,
    prefabContents: prefabs,
    tileContents: tiles,
    terrainMaterialContents: materials,
    sourceBaseline: sources,
    selectedChunkKey: selectedChunkKey,
    selectedChunkKeys: selectedChunkKeys,
    seed: seed,
    repositoryChunkPaths: repositoryChunkPaths,
  );
  await _verifySourceGeneration(input);
  return input;
}

Future<List<String>> _chunkPaths(String workspaceRoot) async {
  final root = Directory(
    p.join(workspaceRoot, 'assets/authoring/level/chunks'),
  );
  if (!await root.exists()) return const [];
  final paths = <String>[];
  await for (final entry in root.list(recursive: true, followLinks: false)) {
    if (entry is File && entry.path.toLowerCase().endsWith('.json')) {
      paths.add(
        p.relative(entry.path, from: workspaceRoot).replaceAll('\\', '/'),
      );
    }
  }
  return paths..sort();
}

Future<void> _verifySourceGeneration(PlaytestPreparationInput input) async {
  final paths = await _chunkPaths(input.workspaceRoot);
  if (jsonEncode(paths) != jsonEncode(input.repositoryChunkPaths)) {
    throw const PlaytestPreparationException(
      code: 'playtest_source_drift',
      message: 'The chunk source set changed during preparation. Prepare Play again.',
    );
  }
  final bundle = RunnerWorkspaceAssetBundle(workspaceRoot: input.workspaceRoot);
  for (final entry in input.sourceBaseline.entries) {
    if (await bundle.loadString(entry.key, cache: false) != entry.value) {
      throw PlaytestPreparationException(
        code: 'playtest_source_drift',
        message: '${entry.key} changed during preparation. Prepare Play again.',
      );
    }
  }
}

/// Compiles off the UI isolate, freezes exact renderer images, then checks that
/// dependency sources still match the captured generation before returning.
Future<PlaytestPreparationResult> preparePlaytestInBackground(
  PlaytestPreparationInput input,
) async {
  try {
    final compiled = await Isolate.run(() => preparePlaytest(input));
    final scenario = compiled.scenario;
    final appearance = compiled.appearance;
    if (scenario == null || appearance == null) return compiled;
    final level = switch (scenario) {
      ChunkPlaytestScenario value => value.levelDefinition,
      LevelPlaytestScenario value => value.levelDefinition,
      _ => throw StateError('Unsupported playtest scope.'),
    };
    final source = level.chunkPatternSource;
    final base = switch (source) {
      ChunkPatternListSource value => value,
      FirstChunkPatternSource value => value.baseSource,
      AssembledChunkPatternSource value => value.baseSource,
      _ => throw StateError('Playtest requires a list-backed pattern source.'),
    };
    final assets =
        await RunnerWorkspaceAssetBundle(workspaceRoot: input.workspaceRoot)
            .capture(
              appearance.requiredAssetKeys(
                scenario: scenario,
                patterns: [
                  ...base.earlyPatterns,
                  ...base.easyPatterns,
                  ...base.normalPatterns,
                  ...base.hardPatterns,
                ],
              ),
            );
    final assetIssues = await Isolate.run(
      () => validateCapturedPlaytestAssets(
        assets: assets,
        materialContents: input.terrainMaterialContents,
        materialKeys: appearance.terrainMaterials.keys.toSet(),
        patterns: [
          ...base.earlyPatterns,
          ...base.easyPatterns,
          ...base.normalPatterns,
          ...base.hardPatterns,
        ],
      ),
    );
    if (assetIssues.isNotEmpty) {
      return PlaytestPreparationResult.failure(assetIssues);
    }
    await _verifySourceGeneration(input);
    return PlaytestPreparationResult.success(
      scenario: scenario,
      appearance: appearance,
      fingerprint: WorkspaceFileIo.fingerprint(
        '${input.fingerprint}:${assets.fingerprint}',
      ),
      warnings: compiled.warnings,
      assetBundle: assets,
    );
  } on Object catch (error) {
    return _failure(error);
  }
}

/// Pure current-schema compilation and canonical Core scenario admission.
PlaytestPreparationResult preparePlaytest(PlaytestPreparationInput input) {
  try {
    _validateTheme(input);
    final decodedMaterials = decodeTerrainMaterialCatalog(
      input.terrainMaterialContents,
      sourcePath: terrainMaterialDefsSourcePath,
    );
    final materials = decodedMaterials.catalog;
    if (materials == null) {
      return PlaytestPreparationResult.failure(
        decodedMaterials.issues.map(
          (issue) => PlaytestPreparationIssue(
            code: issue.code,
            message: issue.message,
            sourcePath: terrainMaterialDefsSourcePath,
          ),
        ),
      );
    }
    final runtimeChunks = <PolygonTerrainRuntimeChunk>[];
    for (final entry in input.chunkSources.entries) {
      final result = compilePolygonTerrainRuntimeChunkSource(
        prefabSourcePath: PrefabStore.prefabDefsPath,
        prefabContents: input.prefabContents,
        tileSourcePath: PrefabStore.tileDefsPath,
        tileContents: input.tileContents,
        chunkSourcePath: entry.key,
        chunkContents: entry.value,
      );
      if (result.chunk == null) {
        return PlaytestPreparationResult.failure(
          result.issues.map(
            (issue) => PlaytestPreparationIssue(
              code: issue.code,
              message: issue.message,
              sourcePath: issue.sourcePath,
              ownerKey: issue.ownerKey,
            ),
          ),
        );
      }
      runtimeChunks.add(result.chunk!);
    }
    runtimeChunks.sort(
      (a, b) => a.stagedTerrain.chunkKey.compareTo(b.stagedTerrain.chunkKey),
    );
    final active = runtimeChunks
        .where((c) => isRuntimeEligibleChunkStatus(c.stagedTerrain.status))
        .toList();
    List<ChunkPattern> tier(
      Iterable<PolygonTerrainRuntimeChunk> chunks,
      String name,
    ) => chunks
        .where((c) => c.stagedTerrain.difficulty == name)
        .map((c) => c.pattern)
        .toList(growable: false);
    final sourceLevel = input.level;
    for (final chunk in runtimeChunks) {
      if (!sourceLevel.chunkThemeGroups.contains(
        chunk.stagedTerrain.assemblyGroupId,
      )) {
        throw PlaytestPreparationException(
          code: 'unknown_chunk_group_id',
          message:
              'Chunk ${chunk.stagedTerrain.chunkKey} references an undeclared group.',
        );
      }
    }
    final assembly = sourceLevel.assembly;
    final level = LevelDefinition.authored(
      identity: AuthoredLevelIdentity(sourceLevel.levelId),
      chunkPatternSource: ChunkPatternListSource(
        earlyPatterns: tier(active, 'early'),
        easyPatterns: tier(active, 'easy'),
        normalPatterns: tier(active, 'normal'),
        hardPatterns: tier(active, 'hard'),
      ),
      groundTopY: sourceLevel.groundTopY,
      cameraCenterY: sourceLevel.cameraCenterY,
      earlyPatternChunks: sourceLevel.earlyPatternChunks,
      easyPatternChunks: sourceLevel.easyPatternChunks,
      normalPatternChunks: sourceLevel.normalPatternChunks,
      noEnemyChunks: sourceLevel.noEnemyChunks,
      visualThemeId: sourceLevel.visualThemeId,
      firstChunkKey: sourceLevel.firstChunkKey,
      assembly: assembly == null
          ? null
          : LevelAssemblyDefinition(
              loopSegments: assembly.loopSegments,
              segments: [
                for (final s in assembly.segments)
                  LevelAssemblySegment(
                    segmentId: s.segmentId,
                    groupId: s.groupId,
                    difficulty: s.difficulty,
                    minChunkCount: s.minChunkCount,
                    maxChunkCount: s.maxChunkCount,
                    requireDistinctChunks: s.requireDistinctChunks,
                  ),
              ],
            ),
    );
    final selectedKeys = input.selectedChunkKeys;
    final selectedChunks = selectedKeys == null
        ? null
        : <PolygonTerrainRuntimeChunk>[
            for (final key in selectedKeys)
              runtimeChunks
                      .where((c) => c.stagedTerrain.chunkKey == key)
                      .firstOrNull ??
                  (throw PlaytestPreparationException(
                    code: 'chunk_playtest_owner_missing',
                    message: 'Filtered chunk $key is missing from the capture.',
                  )),
          ];
    final inactiveSelected = selectedChunks
        ?.where(
          (chunk) => !isRuntimeEligibleChunkStatus(chunk.stagedTerrain.status),
        )
        .map((chunk) => chunk.stagedTerrain.chunkKey)
        .toList(growable: false);
    if (inactiveSelected != null && inactiveSelected.isNotEmpty) {
      throw PlaytestPreparationException(
        code: 'chunk_playtest_filtered_chunk_inactive',
        message:
            'Filtered Play requires active chunks. Activate or exclude: '
            '${inactiveSelected.join(', ')}.',
      );
    }
    final usesFilteredPool =
        selectedChunks != null && selectedChunks.length > 1;
    final focusedLevel = selectedChunks == null
        ? null
        : usesFilteredPool
        ? _buildFilteredChunkPlaytestLevel(
            level: level,
            chunks: selectedChunks,
            tier: tier,
          )
        : level;
    final PlaytestScenario scenario = selectedChunks == null
        ? LevelPlaytestScenario(
            levelDefinition: level,
            terrainChunks: runtimeChunks.map((c) => c.stagedTerrain),
            seed: input.seed,
            playerCharacter: PlayerCharacterRegistry.eloise,
            equippedLoadout: const EquippedLoadoutDef(),
          )
        : usesFilteredPool
        ? ChunkPlaytestScenario.filteredPool(
            levelDefinition: focusedLevel!,
            terrainChunks: selectedChunks.map((c) => c.stagedTerrain),
            patterns: selectedChunks.map((c) => c.pattern),
            visualThemeId: sourceLevel.visualThemeId,
            seed: input.seed,
            playerCharacter: PlayerCharacterRegistry.eloise,
            equippedLoadout: const EquippedLoadoutDef(),
          )
        : ChunkPlaytestScenario(
            levelDefinition: level,
            terrainChunks: runtimeChunks.map((c) => c.stagedTerrain),
            draftPattern: selectedChunks.first.pattern,
            draftTerrain: selectedChunks.first.stagedTerrain,
            visualThemeId: sourceLevel.visualThemeId,
            seed: input.seed,
            playerCharacter: PlayerCharacterRegistry.eloise,
            equippedLoadout: const EquippedLoadoutDef(),
          );
    final appearanceChunks = usesFilteredPool ? selectedChunks : active;
    final referencedMaterials = <String>{
      for (final chunk in appearanceChunks)
        for (final water in chunk.stagedTerrain.waterRegions) water.materialKey,
      for (final chunk in appearanceChunks)
        for (final polygon in chunk.stagedTerrain.polygons)
          if (polygon.materialKey != null) polygon.materialKey!,
    };
    for (final key in referencedMaterials) {
      if (!materials.byKey.containsKey(key)) {
        throw PlaytestPreparationException(
          code: 'playtest_material_missing',
          message: 'Captured terrain material "$key" is unavailable.',
        );
      }
    }
    final specs = terrainMaterialSpecsFromCatalog(materials);
    final theme = input.theme;
    final appearance = RunnerPlaytestAppearance(
      parallaxThemes: {
        theme.parallaxThemeId: ParallaxTheme(
          backgroundLayers: [
            for (final layer in theme.layers)
              if (layer.group == parallaxGroupBackground)
                PixelParallaxLayerSpec(
                  assetPath: layer.assetPath.substring('assets/images/'.length),
                  parallaxFactor: layer.parallaxFactor,
                  opacity: layer.opacity,
                  yOffset: layer.yOffset,
                ),
          ],
          foregroundLayers: const [],
        ),
      },
      terrainMaterials: {
        for (final key in referencedMaterials) key: specs[key]!,
      },
    );
    return PlaytestPreparationResult.success(
      scenario: scenario,
      appearance: appearance,
      fingerprint: input.fingerprint,
      warnings: [
        if (theme.layers.any((layer) => layer.group == parallaxGroupForeground)) 'Foreground background layers are authored but are not rendered by the game.',
      ],
    );
  } on Object catch (error) {
    return _failure(error);
  }
}

LevelDefinition _buildFilteredChunkPlaytestLevel({
  required LevelDefinition level,
  required List<PolygonTerrainRuntimeChunk> chunks,
  required List<ChunkPattern> Function(
    Iterable<PolygonTerrainRuntimeChunk> chunks,
    String difficulty,
  )
  tier,
}) {
  return level.copyWith(
    chunkPatternSource: ChunkPatternListSource(
      earlyPatterns: tier(chunks, 'early'),
      easyPatterns: tier(chunks, 'easy'),
      normalPatterns: tier(chunks, 'normal'),
      hardPatterns: tier(chunks, 'hard'),
    ),
    noEnemyChunks: 0,
    clearFirstChunkKey: true,
    clearAssembly: true,
  );
}

void _validateTheme(PlaytestPreparationInput input) {
  final theme = input.theme;
  final layerKeys = <String>{};
  final assetPattern = RegExp(
    r'^assets/images/parallax/[a-z0-9]+(?:_[a-z0-9]+)*/[a-z0-9]+(?:_[a-z0-9]+)*\.png$',
  );
  if (theme.parallaxThemeId != input.level.visualThemeId ||
      !stableLevelIdentifierPattern.hasMatch(theme.parallaxThemeId) ||
      theme.revision <= 0) {
    throw const PlaytestPreparationException(
      code: 'playtest_theme_invalid',
      message:
          'The captured background must match the assigned authored theme.',
    );
  }
  for (final layer in theme.layers) {
    if (!stableLevelIdentifierPattern.hasMatch(layer.layerKey) ||
        !layerKeys.add(layer.layerKey) ||
        !assetPattern.hasMatch(layer.assetPath) ||
        ![
          parallaxGroupBackground,
          parallaxGroupForeground,
        ].contains(layer.group) ||
        !layer.parallaxFactor.isFinite ||
        layer.parallaxFactor < minParallaxFactor ||
        layer.parallaxFactor > maxParallaxFactor ||
        !layer.opacity.isFinite ||
        layer.opacity < minOpacity ||
        layer.opacity > maxOpacity ||
        !layer.yOffset.isFinite ||
        layer.yOffset.abs() > maxAbsYOffset) {
      throw PlaytestPreparationException(
        code: 'playtest_theme_layer_invalid',
        message:
            'Background layer ${layer.layerKey} has invalid identity, image path, or render settings.',
      );
    }
  }
}

PlaytestPreparationResult _failure(Object error) {
  final (code, message) = switch (error) {
    PlaytestPreparationException value => (value.code, value.message),
    PlaytestScenarioException value => (value.code, value.message),
    RunnerWorkspaceAssetException value => (value.code, value.message),
    _ => ('playtest_preparation_failed', error.toString()),
  };
  return PlaytestPreparationResult.failure([
    PlaytestPreparationIssue(code: code, message: message),
  ]);
}
