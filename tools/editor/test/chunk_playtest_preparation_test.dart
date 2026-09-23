import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rpg_runner/playtest.dart';
import 'package:runner_core/game_core.dart';
import 'package:runner_core/levels/level_identity.dart';
import 'package:runner_editor/src/chunks/chunk_domain_plugin.dart';
import 'package:runner_editor/src/chunks/chunk_v2_file_codec.dart';
import 'package:runner_editor/src/chunks/chunk_v2_models.dart';
import 'package:runner_editor/src/terrain_authoring/terrain_source_models.dart';
import 'package:runner_editor/src/levels/level_domain_models.dart';
import 'package:runner_editor/src/levels/level_domain_plugin.dart';
import 'package:runner_editor/src/parallax/parallax_domain_models.dart';
import 'package:runner_editor/src/playtest/authored_playtest_preparation.dart';
import 'package:runner_editor/src/workspace/editor_workspace.dart';

void main() {
  late String workspaceRoot;
  late ChunkV2Document repositoryDocument;
  late PlaytestPreparationInput captured;

  setUpAll(() async {
    workspaceRoot = p.normalize(
      p.absolute(p.join(Directory.current.path, '..', '..')),
    );
    repositoryDocument = await ChunkDomainPlugin().loadV2FromRepo(
      EditorWorkspace(rootPath: workspaceRoot),
    );
    captured = await captureChunkPlaytestPreparationInput(
      document: repositoryDocument,
      selectedChunkKey: repositoryDocument.chunks
          .singleWhere((c) => c.chunkKey == 'forest_rocky_grove_easy_001')
          .chunkKey,
      workspaceRoot: workspaceRoot,
    );
  });

  test(
    'repository snapshot produces authored identity and captured appearance',
    () {
      final result = preparePlaytest(captured);
      expect(result.issues, isEmpty);
      final scenario = result.scenario! as ChunkPlaytestScenario;
      expect(scenario.seed, playtestDefaultSeed);
      expect(scenario.draftPattern.chunkKey, captured.selectedChunkKey);
      expect(scenario.path.chunkKeys, [captured.selectedChunkKey]);
      expect(scenario.path.previewChunkKeys(3), [
        captured.selectedChunkKey,
        captured.selectedChunkKey,
        captured.selectedChunkKey,
      ]);
      expect(
        scenario.levelDefinition.identity,
        AuthoredLevelIdentity('forest'),
      );
      expect(result.appearance!.parallaxThemes.keys, ['forest']);
      expect(result.appearance!.terrainMaterials, isNotEmpty);
      expect(result.assetBundle, isNull);
    },
  );

  test(
    'filtered owner pool becomes the complete repeating Chunk path',
    () async {
      final keys = <String>[
        'forest_rocky_grove_easy_003',
        'forest_rocky_grove_easy_001',
        'forest_rocky_grove_easy_002',
      ];
      final input = await captureChunkPlaytestPreparationInput(
        document: repositoryDocument,
        selectedChunkKeys: keys,
        workspaceRoot: workspaceRoot,
      );
      final result = preparePlaytest(input);

      expect(
        result.issues,
        isEmpty,
        reason: result.issues.map((issue) => issue.toString()).join('\n'),
      );
      expect(input.selectedChunkKeys, <String>[...keys]..sort());
      final scenario = result.scenario! as ChunkPlaytestScenario;
      expect(scenario.path.chunkKeys, everyElement(isIn(keys)));
      expect(scenario.path.chunkKeys.toSet(), keys.toSet());
      expect(scenario.levelDefinition.noEnemyChunks, 0);
      expect(scenario.levelDefinition.assembly, isNull);
      expect(
        scenario.path.previewChunkKeys(scenario.path.chunkKeys.length * 2),
        <String>[...scenario.path.chunkKeys, ...scenario.path.chunkKeys],
      );
    },
  );

  test('unfiltered owner catalog remains a bounded exact Chunk pool', () async {
    final keys =
        repositoryDocument.chunks
            .where(
              (chunk) => chunk.levelId == 'forest' && chunk.status == 'active',
            )
            .map((chunk) => chunk.chunkKey)
            .toList()
          ..sort();
    final input = await captureChunkPlaytestPreparationInput(
      document: repositoryDocument,
      selectedChunkKeys: keys,
      workspaceRoot: workspaceRoot,
    );
    final watch = Stopwatch()..start();
    final result = preparePlaytest(input);
    watch.stop();

    expect(
      result.issues,
      isEmpty,
      reason: result.issues.map((issue) => issue.message).join('\n'),
    );
    final scenario = result.scenario! as ChunkPlaytestScenario;
    expect(scenario.path.chunkKeys.toSet(), keys.toSet());
    expect(scenario.path.chunkKeys, everyElement(isIn(keys)));
    expect(watch.elapsed, lessThan(const Duration(seconds: 5)));
  });

  test(
    'accepted Chunk edits compile without changing persisted baseline',
    () async {
      final source = repositoryDocument.chunks.singleWhere(
        (c) => c.chunkKey == 'forest_rocky_grove_easy_001',
      );
      final edited = source.copyWith(revision: source.revision + 1);
      final input = await captureChunkPlaytestPreparationInput(
        document: repositoryDocument.copyWith(
          chunks: [
            for (final chunk in repositoryDocument.chunks)
              if (chunk.chunkKey == edited.chunkKey) edited else chunk,
          ],
          changedChunkKeys: [edited.chunkKey],
        ),
        selectedChunkKey: edited.chunkKey,
        workspaceRoot: workspaceRoot,
      );
      final result = preparePlaytest(input);
      expect(result.issues, isEmpty);
      expect(
        (result.scenario! as ChunkPlaytestScenario).draftTerrain.revision,
        source.revision + 1,
      );
      expect(input.fingerprint, isNot(captured.fingerprint));
      expect(
        repositoryDocument.baselineContentsByChunkKey[source.chunkKey],
        isNot(contains('"revision": ${source.revision + 1}')),
      );
    },
  );

  test(
    'captured water and all animation frames survive background Play',
    () async {
      final example = ChunkV2FileCodec.decode(
        File(p.join(workspaceRoot, 'docs/examples/water_pool_chunk.json'))
            .readAsStringSync(),
      ).copyWith(levelId: 'forest');
      final input = _copy(
        captured,
        selectedChunkKey: example.chunkKey,
        chunks: {
          'water_pool_example.json': ChunkV2FileCodec.encode(example),
          'water_opener.json': ChunkV2FileCodec.encode(
            example.copyWith(
              chunkKey: 'water_opener',
              id: 'water_opener',
              waterRegions: [],
              collisionShapes: [_flatGround(222)],
            ),
          ),
        },
        level: captured.level.copyWith(
          groundTopY: 222,
          clearAssembly: true,
          clearFirstChunkKey: true,
        ),
      );
      final direct = preparePlaytest(input);
      final background = await preparePlaytestInBackground(input);
      expect(
        direct.issues,
        isEmpty,
        reason: direct.issues.map((e) => "${e.code}: ${e.message}").join("\n"),
      );
      expect(
        background.issues,
        isEmpty,
        reason: background.issues
            .map((e) => "${e.code}: ${e.message}")
            .join("\n"),
      );
      final scenario = background.scenario! as ChunkPlaytestScenario;
      expect(
        scenario.draftTerrain.waterSignature,
        (direct.scenario! as ChunkPlaytestScenario).draftTerrain.waterSignature,
      );
      expect(scenario.draftTerrain.waterRegions, example.waterRegions);
      final material = background.appearance!.terrainMaterials['biome_water']!;
      expect(material.top.base.additionalFrames, hasLength(2));
      for (final region in material.regions) {
        final key = 'assets/images/${region.assetPath}';
        expect(
          (await background.assetBundle!.load(key)).lengthInBytes,
          greaterThan(0),
        );
      }
      final core = GameCore.chunkPlaytest(scenario: scenario);
      core.setPlayerPosXYUnsafeForTest(
        scenario.path.selectedChunkIndex * 600 + 220,
        245,
      );
      core.stepOneTick();
      expect(core.buildSnapshot().playerEntity!.isSwimming, isTrue);
      expect(
        core.buildSnapshot().stagedTerrainRenderSnapshot!.waterRegions,
        isNotEmpty,
      );
    },
  );

  test('new level, first chunk, and theme need no generated identities', () {
    final chunk = repositoryDocument.chunks
        .singleWhere((c) => c.chunkKey == 'forest_rocky_grove_easy_001')
        .copyWith(
          chunkKey: 'prototype_first',
          id: 'first',
          levelId: 'prototype',
          prefabs: [],
          markers: [],
          collisionShapes: [_flatGround(210)],
        );
    final chunks = {
      'assets/authoring/level/chunks/prototype/prototype_first.json':
          ChunkV2FileCodec.encode(chunk),
    };
    final level = captured.level.copyWith(
      levelId: 'prototype',
      visualThemeId: 'prototype_background',
      noEnemyChunks: 4,
      cameraCenterY: 123,
      groundTopY: 210,
      clearAssembly: true,
      clearFirstChunkKey: true,
    );
    final theme = captured.theme.copyWith(
      parallaxThemeId: 'prototype_background',
    );
    final chunkResult = preparePlaytest(
      _copy(
        captured,
        level: level,
        theme: theme,
        chunks: chunks,
        selectedChunkKey: chunk.chunkKey,
      ),
    );
    final levelResult = preparePlaytest(
      _copy(
        captured,
        level: level,
        theme: theme,
        chunks: chunks,
        wholeLevel: true,
      ),
    );
    expect(chunkResult.issues, isEmpty);
    expect(levelResult.issues, isEmpty);
    final focused = chunkResult.scenario! as ChunkPlaytestScenario;
    final full = levelResult.scenario! as LevelPlaytestScenario;
    expect(focused.path.chunkKeys, ['prototype_first']);
    expect(
      GameCore.chunkPlaytest(scenario: focused).buildSnapshot().levelIdentity,
      AuthoredLevelIdentity('prototype'),
    );
    expect(
      GameCore.levelPlaytest(scenario: full).buildSnapshot().levelIdentity,
      AuthoredLevelIdentity('prototype'),
    );
    expect(full.buildRuntimeLevelDefinition().noEnemyChunks, 4);
    expect(focused.buildRuntimeLevelDefinition().noEnemyChunks, 0);
    expect(full.levelDefinition.cameraCenterY, 123);
    expect(full.levelDefinition.groundTopY, 210);
    expect(levelResult.appearance!.parallaxThemes.keys, [
      'prototype_background',
    ]);
  });

  test(
    'whole-Level capture includes accepted metadata and dependency projection',
    () async {
      final loaded = await LevelDomainPlugin().loadFromRepo(
        EditorWorkspace(rootPath: workspaceRoot),
      ) as LevelDefsDocument;
      final input = await captureLevelPlaytestPreparationInput(
        document: loaded.copyWith(
          levels: [
            for (final level in loaded.levels)
              if (level.levelId == 'forest')
                level.copyWith(cameraCenterY: 119)
              else
                level,
          ],
        ),
        levelId: 'forest',
        workspaceRoot: workspaceRoot,
        contentDocument: repositoryDocument,
      );
      final result = preparePlaytest(input);
      expect(result.issues, isEmpty);
      expect(
        (result.scenario! as LevelPlaytestScenario)
            .levelDefinition
            .cameraCenterY,
        119,
      );
      expect(input.sourceBaseline, isNotEmpty);
    },
  );

  test(
    'new material keys bind captured source instead of generated lookup',
    () {
      final result = preparePlaytest(
        _copy(
          captured,
          chunks: {
            for (final entry in captured.chunkSources.entries)
              entry.key: entry.value.replaceAll(
                '"grass_dirt"',
                '"prototype_material"',
              ),
          },
          materialContents: captured.terrainMaterialContents.replaceAll(
            '"grass_dirt"',
            '"prototype_material"',
          ),
        ),
      );
      expect(result.issues, isEmpty);
      expect(
        result.appearance!.terrainMaterials.keys,
        contains('prototype_material'),
      );
      expect(
        result.appearance!.terrainMaterials.keys,
        isNot(contains('grass_dirt')),
      );
    },
  );

  test('capture rejects missing owner, level, and canonical path', () async {
    for (final entry in [
      (repositoryDocument, 'missing', 'chunk_playtest_owner_missing'),
      (
        repositoryDocument.copyWith(levels: const []),
        captured.selectedChunkKey!,
        'chunk_playtest_level_missing',
      ),
      (
        repositoryDocument.copyWith(sourcePathByChunkKey: {}),
        captured.selectedChunkKey!,
        'chunk_playtest_source_path_missing',
      ),
    ]) {
      await expectLater(
        captureChunkPlaytestPreparationInput(
          document: entry.$1,
          selectedChunkKey: entry.$2,
          workspaceRoot: workspaceRoot,
        ),
        throwsA(
          isA<PlaytestPreparationException>().having(
            (e) => e.code,
            'code',
            entry.$3,
          ),
        ),
      );
    }
  });

  test(
    'malformed source and missing captured materials yield no partial runtime',
    () {
      final malformed = preparePlaytest(
        _copy(captured, chunks: {captured.chunkSources.keys.first: '{}'}),
      );
      expect(malformed.scenario, isNull);
      expect(malformed.issues, isNotEmpty);
      final missingMaterial = preparePlaytest(
        _copy(
          captured,
          materialContents: captured.terrainMaterialContents.replaceAll(
            '"grass_dirt"',
            '"unreferenced_material"',
          ),
        ),
      );
      expect(missingMaterial.scenario, isNull);
      expect(missingMaterial.issues, isNotEmpty);
    },
  );

  test('background preparation captures every required image and detects source drift', () async {
    final result = await preparePlaytestInBackground(captured);
    expect(
      result.issues,
      isEmpty,
      reason: result.issues
          .map((e) => '${e.code}: ${e.sourcePath}: ${e.message}')
          .join('\n'),
    );
    expect(result.assetBundle, isNotNull);
    final full = result.scenario! as ChunkPlaytestScenario;
    final keys = result.appearance!.requiredAssetKeys(
      scenario: full,
      patterns: [full.draftPattern],
    );
    for (final key in keys) {
      expect(
        (await result.assetBundle!.load(key)).lengthInBytes,
        greaterThan(0),
      );
    }
    final drift = await preparePlaytestInBackground(
      _copy(
        captured,
        baseline: {
          ...captured.sourceBaseline,
          captured.sourceBaseline.keys.first: 'changed source generation',
        },
      ),
    );
    expect(drift.scenario, isNull);
    expect(drift.issues.single.code, 'playtest_source_drift');
  });
}

PlaytestPreparationInput _copy(
  PlaytestPreparationInput input, {
  LevelDef? level,
  ParallaxThemeDef? theme,
  Map<String, String>? chunks,
  Map<String, String>? baseline,
  String? materialContents,
  String? selectedChunkKey,
  bool wholeLevel = false,
}) => PlaytestPreparationInput(
  workspaceRoot: input.workspaceRoot,
  level: level ?? input.level,
  theme: theme ?? input.theme,
  chunkSources: chunks ?? input.chunkSources,
  prefabContents: input.prefabContents,
  tileContents: input.tileContents,
  terrainMaterialContents: materialContents ?? input.terrainMaterialContents,
  sourceBaseline: baseline ?? input.sourceBaseline,
  repositoryChunkPaths: input.repositoryChunkPaths,
  selectedChunkKey: wholeLevel ? null : selectedChunkKey,
  selectedChunkKeys: wholeLevel || selectedChunkKey != null
      ? null
      : input.selectedChunkKeys,
  seed: input.seed,
);

TerrainSourceShapeDef _flatGround(int y) => TerrainSourceShapeDef(
  shapeId: 'flat_ground',
  surfaceKind: 'ground',
  materialKey: 'grass_dirt',
  vertices: [
    for (final point in [(0, y), (600, y), (600, 270), (0, 270)])
      TerrainSourceVertexDef(
        xHalfPixels: point.$1 * 2,
        yHalfPixels: point.$2 * 2,
      ),
  ],
);
