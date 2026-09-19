import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/playtest.dart';
import 'package:runner_core/commands/command.dart';
import 'package:runner_core/game_core.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:runner_editor/src/app/pages/chunkCreator/v2/chunk_connection_creation_dialog.dart';
import 'package:runner_editor/src/chunks/chunk_connection_creation.dart';
import 'package:runner_editor/src/chunks/chunk_domain_plugin.dart';
import 'package:runner_editor/src/chunks/chunk_level_target.dart';
import 'package:runner_editor/src/chunks/chunk_v2_file_codec.dart';
import 'package:runner_editor/src/chunks/chunk_v2_models.dart';
import 'package:runner_editor/src/domain/authoring_types.dart';
import 'package:runner_editor/src/domain/authoring_plugin_registry.dart';
import 'package:runner_editor/src/levels/level_domain_models.dart';
import 'package:runner_editor/src/levels/level_domain_plugin.dart';
import 'package:runner_editor/src/playtest/authored_playtest_preparation.dart';
import 'package:runner_editor/src/session/editor_session_controller.dart';
import 'package:runner_editor/src/terrain_authoring/terrain_source_models.dart';

import 'test_support/chunk_level_fixture.dart';

void main() {
  for (final step in [24, 32]) {
    test(
      'flat joined starters survive Undo, Save and both characters at step $step',
      () async {
        const groups = [
          'default',
          'grove',
          'path',
          'clearing',
          'ridge',
          'return',
        ];
        final workspace = await createChunkLevelFixture(
          level: standardChunkFixtureLevel.copyWith(
            terrainHeightStepPx: step,
            chunkThemeGroups: groups,
            noEnemyChunks: 9999,
            assembly: LevelAssemblyDef(
              loopSegments: true,
              segments: [
                for (final group in groups)
                  LevelAssemblySegmentDef(
                    segmentId: group,
                    groupId: group,
                    minChunkCount: 1,
                    maxChunkCount: 1,
                    requireDistinctChunks: true,
                  ),
              ],
            ),
          ),
        );
        final plugin = ChunkDomainPlugin();
        var document = await plugin.loadForLevel(
          workspace,
          target: const ChunkLevelTarget('forest'),
        );
        final starter = plugin.flatStarterIntentForLevel(
          document,
          levelId: 'forest',
        );
        document = plugin.applyEdit(
          document,
          AuthoringCommand(
            kind: 'create_flat_starter',
            payload: {'intent': starter},
          ),
        ) as ChunkV2Document;
        await plugin.exportToRepo(workspace, document: document);
        final controller = EditorSessionController(
          pluginRegistry: AuthoringPluginRegistry(plugins: [plugin]),
          initialPluginId: 'chunks',
          initialWorkspacePath: workspace.rootPath,
        );
        addTearDown(controller.dispose);
        await controller.loadWorkspace();
        var predecessor = starter.chunkKey;
        for (final group in groups.skip(1)) {
          final before = controller.document! as ChunkV2Document;
          final intent = _intent(before, predecessor, group, group: group);
          final sourceBytes = ChunkV2FileCodec.encode(
            before.chunks.firstWhere((chunk) => chunk.chunkKey == predecessor),
          );
          controller.applyCommand(
            AuthoringCommand(
              kind: 'create_connecting_chunk',
              payload: {'intent': intent},
            ),
          );
          final next = controller.document! as ChunkV2Document;
          expect(next.chunks.length, before.chunks.length + 1);
          expect(next.selectedChunkKey, group);
          final created = next.chunks.singleWhere(
            (chunk) => chunk.chunkKey == group,
          );
          expect(
            created.collisionShapes.single.vertices[0].yHalfPixels,
            created.collisionShapes.single.vertices[1].yHalfPixels,
          );
          expect(
            ChunkV2FileCodec.encode(
              next.chunks.firstWhere((chunk) => chunk.chunkKey == predecessor),
            ),
            sourceBytes,
          );
          controller.undo();
          expect(
            (controller.document! as ChunkV2Document).chunks.length,
            before.chunks.length,
          );
          controller.redo();
          expect(
            (controller.document! as ChunkV2Document).chunks.length,
            next.chunks.length,
          );
          predecessor = group;
        }
        document = controller.document! as ChunkV2Document;
        expect(plugin.validate(document), isEmpty);
        final scene = plugin.buildEditableScene(document) as ChunkV2Scene;
        expect(
          scene.seamAnalysis.seams.every(
            (seam) => seam.comparison.isCompatible,
          ),
          isTrue,
        );
        expect(
          (await plugin.exportToRepo(workspace, document: document)).applied,
          isTrue,
        );
        final reloaded = await plugin.loadForLevel(
          workspace,
          target: const ChunkLevelTarget('forest'),
        );
        expect(
          reloaded.chunks.map(ChunkV2FileCodec.encode).toSet(),
          document.chunks.map(ChunkV2FileCodec.encode).toSet(),
        );
        final levelDocument = await LevelDomainPlugin().loadFromRepo(
          workspace,
        ) as LevelDefsDocument;
        final prepared = preparePlaytest(
          await captureLevelPlaytestPreparationInput(
            document: levelDocument,
            levelId: 'forest',
            contentDocument: reloaded,
            workspaceRoot: workspace.rootPath,
          ),
        );
        expect(
          prepared.isSuccess,
          isTrue,
          reason: prepared.issues.map((issue) => issue.message).join('\n'),
        );
        final original = prepared.scenario! as LevelPlaytestScenario;
        expect(original.sampleChunks().map((chunk) => chunk.groupId), [
          ...groups,
          ...groups,
        ]);
        for (final character in PlayerCharacterRegistry.all) {
          final scenario = LevelPlaytestScenario(
            levelDefinition: original.levelDefinition,
            terrainChunks: original.terrainCatalog.chunksByKey.values,
            seed: original.seed,
            playerCharacter: character,
            equippedLoadout: original.equippedLoadout,
          );
          final core = GameCore.levelPlaytest(scenario: scenario);
          final replay = GameCore.levelPlaytest(scenario: scenario);
          for (var tick = 1; tick <= 1800; tick++) {
            final commands = <Command>[MoveAxisCommand(tick: tick, axis: 1)];
            core.applyCommands(commands);
            replay.applyCommands(commands);
            core.stepOneTick();
            replay.stepOneTick();
            expect(
              core.gameOver,
              isFalse,
              reason: '${character.id} at tick $tick',
            );
            expect(replay.playerPosX, core.playerPosX);
            expect(replay.playerPosY, core.playerPosY);
          }
          expect(core.distance, greaterThan(4000));
        }
      },
    );
  }

  test(
    'stale presets and reused identities fail without changing source',
    () async {
      final workspace = await createChunkLevelFixture();
      final plugin = ChunkDomainPlugin();
      var document = await plugin.loadForLevel(
        workspace,
        target: const ChunkLevelTarget('forest'),
      );
      final starter = plugin.flatStarterIntentForLevel(
        document,
        levelId: 'forest',
      );
      document = plugin.applyEdit(
        document,
        AuthoringCommand(
          kind: 'create_flat_starter',
          payload: {'intent': starter},
        ),
      ) as ChunkV2Document;
      final intent = _intent(document, starter.chunkKey, 'up');
      final changed = document.copyWith(
        levels: [document.levels.single.copyWith(terrainHeightStepPx: 25)],
      );
      expect(
        () => buildConnectingChunk(changed, intent),
        throwsA(
          isA<ChunkTargetException>().having(
            (e) => e.code,
            'code',
            'connecting_chunk_source_changed',
          ),
        ),
      );
      final next = plugin.applyEdit(
        document,
        AuthoringCommand(
          kind: 'create_connecting_chunk',
          payload: {'intent': intent},
        ),
      ) as ChunkV2Document;
      expect(
        () => plugin.applyEdit(
          next,
          AuthoringCommand(
            kind: 'create_connecting_chunk',
            payload: {'intent': intent},
          ),
        ),
        throwsA(
          isA<ChunkTargetException>().having(
            (e) => e.code,
            'code',
            'connecting_chunk_key_collision',
          ),
        ),
      );
      expect(document.chunks, hasLength(1));
      final unsupported = next.copyWith(
        chunks: [next.chunks.last.copyWith(collisionShapes: [])],
      );
      expect(
        () => inspectChunkConnectionTemplate(unsupported, 'up'),
        throwsA(isA<ChunkTargetException>()),
      );
    },
  );

  test('custom solid exit creates an exact-height successor', () async {
    final workspace = await createChunkLevelFixture();
    final plugin = ChunkDomainPlugin();
    var document = await plugin.loadForLevel(
      workspace,
      target: const ChunkLevelTarget('forest'),
    );
    final starter = plugin.flatStarterIntentForLevel(
      document,
      levelId: 'forest',
    );
    document = plugin.applyEdit(
      document,
      AuthoringCommand(
        kind: 'create_flat_starter',
        payload: {'intent': starter},
      ),
    ) as ChunkV2Document;
    document = _withCustomExit(document);
    final template = inspectChunkConnectionTemplate(document, starter.chunkKey);
    final intent = ChunkConnectionCreation(
      predecessorKey: starter.chunkKey,
      predecessorSignature: template.signature,
      heightStepPx: template.presets.stepPx,
      groundTopY: template.presets.groundTopY,
      chunkKey: 'custom_successor',
      groupId: 'default',
      difficulty: 'early',
    );
    final next = plugin.applyEdit(
      document,
      AuthoringCommand(
        kind: ChunkDomainPlugin.createConnectingChunkCommandKind,
        payload: {'intent': intent},
      ),
    ) as ChunkV2Document;
    final successor = next.chunks.singleWhere(
      (chunk) => chunk.chunkKey == 'custom_successor',
    );
    expect(successor.collisionShapes.single.vertices.first.yHalfPixels, 324);
    expect(successor.collisionShapes.single.vertices[1].yHalfPixels, 324);
    final scene = plugin.buildEditableScene(next) as ChunkV2Scene;
    expect(
      scene
          .seamAnalysis
          .rightSignaturesByChunkKey[starter.chunkKey]!
          .physicalRecord,
      scene
          .seamAnalysis
          .leftSignaturesByChunkKey[successor.chunkKey]!
          .physicalRecord,
    );
    expect(
      (await plugin.exportToRepo(workspace, document: next)).applied,
      isTrue,
    );
    final reloaded = await plugin.loadForLevel(
      workspace,
      target: const ChunkLevelTarget('forest'),
    );
    expect(
      reloaded.chunks
          .singleWhere((chunk) => chunk.chunkKey == successor.chunkKey)
          .collisionShapes
          .single
          .vertices
          .first
          .yHalfPixels,
      324,
    );
  });

  testWidgets(
    'creation dialog previews a flat match and cancel leaves no owner',
    (tester) async {
      final workspace = (await tester.runAsync(createChunkLevelFixture))!;
      final plugin = ChunkDomainPlugin();
      var document = (await tester.runAsync(
        () => plugin.loadForLevel(
          workspace,
          target: const ChunkLevelTarget('forest'),
        ),
      ))!;
      final starter = plugin.flatStarterIntentForLevel(
        document,
        levelId: 'forest',
      );
      document = plugin.applyEdit(
        document,
        AuthoringCommand(
          kind: 'create_flat_starter',
          payload: {'intent': starter},
        ),
      ) as ChunkV2Document;
      final scene = plugin.buildEditableScene(document) as ChunkV2Scene;
      ChunkConnectionCreation? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await showDialog<ChunkConnectionCreation>(
                    context: context,
                    builder: (_) => ChunkConnectionCreationDialog(
                      document: document,
                      scene: scene,
                      template: inspectChunkConnectionTemplate(
                        document,
                        starter.chunkKey,
                      ),
                      workspaceRootPath: workspace.rootPath,
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Flat ground: Normal'), findsOneWidget);
      expect(find.text('Exit elevation'), findsNothing);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(document.chunks, hasLength(1));
      expect(tester.takeException(), isNull);
      expect(
        Directory(workspace.resolve('assets/authoring/level/chunks'))
            .existsSync(),
        isFalse,
      );
    },
  );

  testWidgets('creation dialog fixes both edges at the custom exit height', (
    tester,
  ) async {
    final workspace = (await tester.runAsync(createChunkLevelFixture))!;
    final plugin = ChunkDomainPlugin();
    var document = (await tester.runAsync(
      () => plugin.loadForLevel(
        workspace,
        target: const ChunkLevelTarget('forest'),
      ),
    ))!;
    final starter = plugin.flatStarterIntentForLevel(
      document,
      levelId: 'forest',
    );
    document = plugin.applyEdit(
      document,
      AuthoringCommand(
        kind: 'create_flat_starter',
        payload: {'intent': starter},
      ),
    ) as ChunkV2Document;
    document = _withCustomExit(document);
    final scene = plugin.buildEditableScene(document) as ChunkV2Scene;
    ChunkConnectionCreation? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showDialog<ChunkConnectionCreation>(
                  context: context,
                  builder: (_) => ChunkConnectionCreationDialog(
                    document: document,
                    scene: scene,
                    template: inspectChunkConnectionTemplate(
                      document,
                      starter.chunkKey,
                    ),
                    workspaceRootPath: workspace.rootPath,
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Flat ground: Custom · Y 162'), findsOneWidget);
    expect(find.text('Exit elevation'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('connecting_chunk_create')));
    await tester.pumpAndSettle();
    expect(result, isNotNull);
    final created = buildConnectingChunk(document, result!);
    expect(created.collisionShapes.single.vertices[0].yHalfPixels, 324);
    expect(created.collisionShapes.single.vertices[1].yHalfPixels, 324);
  });
}

ChunkV2Document _withCustomExit(ChunkV2Document document) {
  final predecessor = document.chunks.single;
  final originalShape = predecessor.collisionShapes.single;
  const points = [
    (0, 224),
    (173, 190),
    (446, 190),
    (600, 162),
    (600, 270),
    (0, 270),
  ];
  return document.copyWith(
    chunks: [
      predecessor.copyWith(
        collisionShapes: [
          TerrainSourceShapeDef(
            shapeId: originalShape.shapeId,
            surfaceKind: originalShape.surfaceKind,
            materialKey: originalShape.materialKey,
            vertices: [
              for (final (x, y) in points)
                TerrainSourceVertexDef(xHalfPixels: x * 2, yHalfPixels: y * 2),
            ],
          ),
        ],
      ),
    ],
  );
}

ChunkConnectionCreation _intent(
  ChunkV2Document document,
  String predecessor,
  String key, {
  String group = 'default',
}) {
  final template = inspectChunkConnectionTemplate(document, predecessor);
  return ChunkConnectionCreation(
    predecessorKey: predecessor,
    predecessorSignature: template.signature,
    heightStepPx: template.presets.stepPx,
    groundTopY: template.presets.groundTopY,
    chunkKey: key,
    groupId: group,
    difficulty: 'early',
  );
}
