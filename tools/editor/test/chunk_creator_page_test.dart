import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:runner_editor/src/app/pages/chunkCreator/chunk_creator_page.dart';
import 'package:runner_editor/src/chunks/chunk_domain_models.dart';
import 'package:runner_editor/src/chunks/chunk_domain_plugin.dart';
import 'package:runner_editor/src/domain/authoring_plugin_registry.dart';
import 'package:runner_editor/src/domain/authoring_types.dart';
import 'package:runner_editor/src/session/editor_session_controller.dart';
import 'package:runner_editor/src/workspace/editor_workspace.dart';

void main() {
  testWidgets(
    'chunk creator supports level switch, create/duplicate/rename/deprecate, and runtime-locked tileSize metadata',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1800, 1200));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });

      final controller = EditorSessionController(
        pluginRegistry: AuthoringPluginRegistry(
          plugins: <AuthoringDomainPlugin>[
            _InMemoryChunkPlugin(_initialChunkDocument),
          ],
        ),
        initialPluginId: ChunkDomainPlugin.pluginId,
        initialWorkspacePath: '.',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ChunkCreatorPage(controller: controller)),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(controller.scene, isA<ChunkScene>());

      await tester.tap(find.text('Chunk List').first);
      await tester.pumpAndSettle();
      expect(
        find.byKey(
          const ValueKey<String>('chunk_list_preview_chunk_field_001'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('forest').last);
      await tester.pumpAndSettle();
      final sceneAfterLevelSwitch = controller.scene as ChunkScene;
      expect(sceneAfterLevelSwitch.activeLevelId, 'forest');

      await tester.enterText(
        find.widgetWithText(TextField, 'New Chunk ID'),
        'chunk_new',
      );
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();
      final sceneAfterCreate = controller.scene as ChunkScene;
      expect(
        sceneAfterCreate.chunks.any((chunk) => chunk.id == 'chunk_new'),
        isTrue,
      );

      await tester.tap(find.text('chunk_new').first);
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Inspector:').first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Duplicate'));
      await tester.pumpAndSettle();
      final sceneAfterDuplicate = controller.scene as ChunkScene;
      expect(sceneAfterDuplicate.chunks.length, greaterThanOrEqualTo(2));

      await tester.enterText(
        find.widgetWithText(TextField, 'id'),
        'chunk_renamed',
      );
      await _selectDropdownByLabel(
        tester,
        label: 'chunkThemeGroupId',
        value: 'cemetery',
      );
      await tester.tap(find.text('Apply Changes'));
      await tester.pumpAndSettle();
      final sceneAfterRename = controller.scene as ChunkScene;
      expect(
        sceneAfterRename.chunks.any((chunk) => chunk.id == 'chunk_renamed'),
        isTrue,
      );

      await tester.tap(find.text('Deprecate'));
      await tester.pumpAndSettle();
      final sceneAfterDeprecate = controller.scene as ChunkScene;
      final deprecated = sceneAfterDeprecate.chunks.firstWhere(
        (chunk) => chunk.id == 'chunk_renamed',
      );
      expect(deprecated.status, chunkStatusDeprecated);

      final groundBandRaise = find.byKey(
        const ValueKey<String>('ground_band_layer_raise'),
      );
      await tester.tap(find.text('Ground Profile'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(groundBandRaise);
      await tester.pumpAndSettle();
      await tester.tap(groundBandRaise);
      await tester.pumpAndSettle();
      final sceneAfterGroundBandRaise = controller.scene as ChunkScene;
      final raisedGroundBandChunk = sceneAfterGroundBandRaise.chunks.firstWhere(
        (chunk) => chunk.id == 'chunk_renamed',
      );
      expect(raisedGroundBandChunk.groundBandZIndex, 1);

      await tester.tap(
        find.byKey(const ValueKey<String>('difficulty-$chunkDifficultyNormal')),
      );
      await tester.pumpAndSettle();
      expect(find.text(chunkDifficultyEarly).last, findsOneWidget);
      await tester.tap(find.text(chunkDifficultyEarly).last);
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'tileSize').first)
            .enabled,
        isFalse,
      );

      final applyChanges = find.text('Apply Changes', skipOffstage: false);
      expect(applyChanges, findsWidgets);
      await tester.ensureVisible(applyChanges.last);
      await tester.pumpAndSettle();
      await tester.tap(applyChanges.last);
      await tester.pumpAndSettle();

      final sceneAfterMetadataApply = controller.scene as ChunkScene;
      final updatedChunk = sceneAfterMetadataApply.chunks.firstWhere(
        (chunk) => chunk.id == 'chunk_renamed',
      );
      expect(updatedChunk.difficulty, chunkDifficultyEarly);
      expect(updatedChunk.assemblyGroupId, 'cemetery');
      expect(updatedChunk.tileSize, 16);
    },
  );

  testWidgets('chunk creator filters chunk list by chunkThemeGroupId', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1800, 1200));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    final controller = EditorSessionController(
      pluginRegistry: AuthoringPluginRegistry(
        plugins: <AuthoringDomainPlugin>[
          _InMemoryChunkPlugin(_initialChunkWithAssemblyGroupsDocument),
        ],
      ),
      initialPluginId: ChunkDomainPlugin.pluginId,
      initialWorkspacePath: '.',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ChunkCreatorPage(controller: controller)),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.text('Chunk List').first);
    await tester.pumpAndSettle();

    expect(find.text('chunk_cemetery'), findsOneWidget);
    expect(find.text('chunk_village'), findsOneWidget);

    await _selectDropdownByLabel(
      tester,
      label: 'chunkThemeGroupId filter',
      value: 'village',
    );
    await tester.pumpAndSettle();

    expect(find.text('chunk_cemetery'), findsNothing);
    expect(find.text('chunk_village'), findsOneWidget);
  });

  testWidgets('chunk creator deletes selected chunk from inspector', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1800, 1200));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    final controller = EditorSessionController(
      pluginRegistry: AuthoringPluginRegistry(
        plugins: <AuthoringDomainPlugin>[
          _InMemoryChunkPlugin(_initialChunkWithAssemblyGroupsDocument),
        ],
      ),
      initialPluginId: ChunkDomainPlugin.pluginId,
      initialWorkspacePath: '.',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ChunkCreatorPage(controller: controller)),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.text('Chunk List').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('chunk_cemetery').first);
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Inspector:').first);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('delete_chunk_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    final sceneAfterDelete = controller.scene as ChunkScene;
    expect(
      sceneAfterDelete.chunks.any((chunk) => chunk.id == 'chunk_cemetery'),
      isFalse,
    );
    expect(
      sceneAfterDelete.chunks.any((chunk) => chunk.id == 'chunk_village'),
      isTrue,
    );
  });

  testWidgets('chunk creator updates an existing ground gap from inspector', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1800, 1200));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    final controller = EditorSessionController(
      pluginRegistry: AuthoringPluginRegistry(
        plugins: <AuthoringDomainPlugin>[
          _InMemoryChunkPlugin(_initialChunkWithGapDocument),
        ],
      ),
      initialPluginId: ChunkDomainPlugin.pluginId,
      initialWorkspacePath: '.',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ChunkCreatorPage(controller: controller)),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.text('Chunk List').first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('chunk_gap').first);
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Inspector:').first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ground Gaps'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(
        const ValueKey<String>('ground_gap_x_chunk_field_gap_001_gap_1'),
      ),
      '48',
    );
    await tester.enterText(
      find.byKey(
        const ValueKey<String>('ground_gap_width_chunk_field_gap_001_gap_1'),
      ),
      '64',
    );
    final saveGap = find.byKey(
      const ValueKey<String>('ground_gap_save_chunk_field_gap_001_gap_1'),
    );
    await tester.ensureVisible(saveGap);
    await tester.pumpAndSettle();
    await tester.tap(saveGap);
    await tester.pumpAndSettle();

    final sceneAfterEdit = controller.scene as ChunkScene;
    final chunk = sceneAfterEdit.chunks.firstWhere(
      (entry) => entry.id == 'chunk_gap',
    );
    final gap = chunk.groundGaps.firstWhere((entry) => entry.gapId == 'gap_1');
    expect(gap.x, 48);
    expect(gap.width, 64);
  });

  testWidgets('chunk creator resets new gap draft fields after adding a gap', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1800, 1200));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    final controller = EditorSessionController(
      pluginRegistry: AuthoringPluginRegistry(
        plugins: <AuthoringDomainPlugin>[
          _InMemoryChunkPlugin(_initialChunkDocument),
        ],
      ),
      initialPluginId: ChunkDomainPlugin.pluginId,
      initialWorkspacePath: '.',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ChunkCreatorPage(controller: controller)),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.text('Chunk List').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('chunk_a').first);
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Inspector:').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ground Gaps'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey<String>('new_ground_gap_x')),
      '48',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('new_ground_gap_width')),
      '64',
    );
    final addGroundGap = find.byKey(const ValueKey<String>('add_ground_gap'));
    await tester.ensureVisible(addGroundGap);
    await tester.pumpAndSettle();
    await tester.tap(addGroundGap);
    await tester.pumpAndSettle();

    final sceneAfterAdd = controller.scene as ChunkScene;
    final chunk = sceneAfterAdd.chunks.firstWhere(
      (entry) => entry.id == 'chunk_a',
    );
    expect(chunk.groundGaps, hasLength(1));
    expect(chunk.groundGaps.single.x, 48);
    expect(chunk.groundGaps.single.width, 64);

    final xField = tester.widget<TextField>(
      find.byKey(const ValueKey<String>('new_ground_gap_x')),
    );
    final widthField = tester.widget<TextField>(
      find.byKey(const ValueKey<String>('new_ground_gap_width')),
    );
    expect(xField.controller?.text, '0');
    expect(widthField.controller?.text, '16');
  });

  testWidgets('chunk creator keeps existing gap field state scoped per chunk', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1800, 1200));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    final controller = EditorSessionController(
      pluginRegistry: AuthoringPluginRegistry(
        plugins: <AuthoringDomainPlugin>[
          _InMemoryChunkPlugin(_initialChunkWithSharedGapIdsDocument),
        ],
      ),
      initialPluginId: ChunkDomainPlugin.pluginId,
      initialWorkspacePath: '.',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ChunkCreatorPage(controller: controller)),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.text('Chunk List').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('chunk_gap_a').first);
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Inspector:').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ground Gaps'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(
        const ValueKey<String>('ground_gap_x_chunk_field_gap_a_001_gap_1'),
      ),
      '48',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('chunk_gap_b').first);
    await tester.pumpAndSettle();

    expect(
      _textFormFieldValue(
        tester,
        const ValueKey<String>('ground_gap_x_chunk_field_gap_b_001_gap_1'),
      ),
      '80',
    );
    expect(
      _textFormFieldValue(
        tester,
        const ValueKey<String>('ground_gap_width_chunk_field_gap_b_001_gap_1'),
      ),
      '96',
    );
  });

  testWidgets(
    'chunk creator flips selected prefab placements from composer controls',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1800, 1200));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });

      final controller = EditorSessionController(
        pluginRegistry: AuthoringPluginRegistry(
          plugins: <AuthoringDomainPlugin>[
            _InMemoryChunkPlugin(_initialChunkWithPlacedPrefabDocument),
          ],
        ),
        initialPluginId: ChunkDomainPlugin.pluginId,
        initialWorkspacePath: '.',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ChunkCreatorPage(controller: controller)),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      await tester.tap(find.text('Chunk List').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('chunk_prefab').first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Placed Prefabs'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('crate_a').first);
      await tester.pumpAndSettle();

      final flipXChip = find.byKey(
        const ValueKey<String>('selected_prefab_flip_x'),
      );
      final flipYChip = find.byKey(
        const ValueKey<String>('selected_prefab_flip_y'),
      );
      await tester.ensureVisible(flipXChip);
      await tester.pumpAndSettle();

      await tester.tap(flipXChip);
      await tester.pumpAndSettle();

      var sceneAfterFlip = controller.scene as ChunkScene;
      var placement = sceneAfterFlip.chunks.single.prefabs.single;
      expect(placement.flipX, isTrue);
      expect(placement.flipY, isFalse);

      await tester.tap(flipYChip);
      await tester.pumpAndSettle();

      sceneAfterFlip = controller.scene as ChunkScene;
      placement = sceneAfterFlip.chunks.single.prefabs.single;
      expect(placement.flipX, isTrue);
      expect(placement.flipY, isTrue);
    },
  );
}

const ChunkDocument _initialChunkDocument = ChunkDocument(
  chunks: <LevelChunkDef>[
    LevelChunkDef(
      chunkKey: 'chunk_field_001',
      id: 'chunk_a',
      revision: 1,
      schemaVersion: 1,
      levelId: 'field',
      tileSize: 16,
      width: 600,
      height: 270,
      difficulty: chunkDifficultyNormal,
      tags: <String>['base'],
      tileLayers: <TileLayerDef>[],
      prefabs: <PlacedPrefabDef>[],
      markers: <PlacedMarkerDef>[],
      groundProfile: GroundProfileDef(kind: groundProfileKindFlat, topY: 224),
      groundGaps: <GroundGapDef>[],
      status: chunkStatusActive,
    ),
  ],
  baselineByChunkKey: <String, ChunkSourceBaseline>{},
  availableLevelIds: <String>['field', 'forest'],
  assemblyGroupOptionsByLevelId: <String, List<String>>{
    'field': <String>['default', 'cemetery', 'village'],
    'forest': <String>['default', 'cemetery', 'village'],
  },
  activeLevelId: 'field',
  levelOptionSource: 'test',
  runtimeGridSnap: 16.0,
  runtimeChunkWidth: 600.0,
  runtimeGroundTopY: 224,
);

const ChunkDocument _initialChunkWithGapDocument = ChunkDocument(
  chunks: <LevelChunkDef>[
    LevelChunkDef(
      chunkKey: 'chunk_field_gap_001',
      id: 'chunk_gap',
      revision: 1,
      schemaVersion: 1,
      levelId: 'field',
      tileSize: 16,
      width: 600,
      height: 270,
      difficulty: chunkDifficultyNormal,
      tags: <String>['base'],
      tileLayers: <TileLayerDef>[],
      prefabs: <PlacedPrefabDef>[],
      markers: <PlacedMarkerDef>[],
      groundProfile: GroundProfileDef(kind: groundProfileKindFlat, topY: 224),
      groundGaps: <GroundGapDef>[
        GroundGapDef(gapId: 'gap_1', type: groundGapTypePit, x: 16, width: 32),
      ],
      status: chunkStatusActive,
    ),
  ],
  baselineByChunkKey: <String, ChunkSourceBaseline>{},
  availableLevelIds: <String>['field', 'forest'],
  assemblyGroupOptionsByLevelId: <String, List<String>>{
    'field': <String>['default', 'cemetery', 'village'],
    'forest': <String>['default', 'cemetery', 'village'],
  },
  activeLevelId: 'field',
  levelOptionSource: 'test',
  runtimeGridSnap: 16.0,
  runtimeChunkWidth: 600.0,
  runtimeGroundTopY: 224,
);

const ChunkDocument _initialChunkWithAssemblyGroupsDocument = ChunkDocument(
  chunks: <LevelChunkDef>[
    LevelChunkDef(
      chunkKey: 'chunk_field_cemetery_001',
      id: 'chunk_cemetery',
      revision: 1,
      schemaVersion: 1,
      levelId: 'field',
      tileSize: 16,
      width: 600,
      height: 270,
      difficulty: chunkDifficultyNormal,
      assemblyGroupId: 'cemetery',
      tileLayers: <TileLayerDef>[],
      prefabs: <PlacedPrefabDef>[],
      markers: <PlacedMarkerDef>[],
      groundProfile: GroundProfileDef(kind: groundProfileKindFlat, topY: 224),
      groundGaps: <GroundGapDef>[],
      status: chunkStatusActive,
    ),
    LevelChunkDef(
      chunkKey: 'chunk_field_village_001',
      id: 'chunk_village',
      revision: 1,
      schemaVersion: 1,
      levelId: 'field',
      tileSize: 16,
      width: 600,
      height: 270,
      difficulty: chunkDifficultyNormal,
      assemblyGroupId: 'village',
      tileLayers: <TileLayerDef>[],
      prefabs: <PlacedPrefabDef>[],
      markers: <PlacedMarkerDef>[],
      groundProfile: GroundProfileDef(kind: groundProfileKindFlat, topY: 224),
      groundGaps: <GroundGapDef>[],
      status: chunkStatusActive,
    ),
  ],
  baselineByChunkKey: <String, ChunkSourceBaseline>{},
  availableLevelIds: <String>['field', 'forest'],
  assemblyGroupOptionsByLevelId: <String, List<String>>{
    'field': <String>['default', 'cemetery', 'village'],
    'forest': <String>['default', 'cemetery', 'village'],
  },
  activeLevelId: 'field',
  levelOptionSource: 'test',
  runtimeGridSnap: 16.0,
  runtimeChunkWidth: 600.0,
  runtimeGroundTopY: 224,
);

const ChunkDocument _initialChunkWithSharedGapIdsDocument = ChunkDocument(
  chunks: <LevelChunkDef>[
    LevelChunkDef(
      chunkKey: 'chunk_field_gap_a_001',
      id: 'chunk_gap_a',
      revision: 1,
      schemaVersion: 1,
      levelId: 'field',
      tileSize: 16,
      width: 600,
      height: 270,
      difficulty: chunkDifficultyNormal,
      tags: <String>['base'],
      tileLayers: <TileLayerDef>[],
      prefabs: <PlacedPrefabDef>[],
      markers: <PlacedMarkerDef>[],
      groundProfile: GroundProfileDef(kind: groundProfileKindFlat, topY: 224),
      groundGaps: <GroundGapDef>[
        GroundGapDef(gapId: 'gap_1', type: groundGapTypePit, x: 16, width: 32),
      ],
      status: chunkStatusActive,
    ),
    LevelChunkDef(
      chunkKey: 'chunk_field_gap_b_001',
      id: 'chunk_gap_b',
      revision: 1,
      schemaVersion: 1,
      levelId: 'field',
      tileSize: 16,
      width: 600,
      height: 270,
      difficulty: chunkDifficultyNormal,
      tags: <String>['base'],
      tileLayers: <TileLayerDef>[],
      prefabs: <PlacedPrefabDef>[],
      markers: <PlacedMarkerDef>[],
      groundProfile: GroundProfileDef(kind: groundProfileKindFlat, topY: 224),
      groundGaps: <GroundGapDef>[
        GroundGapDef(gapId: 'gap_1', type: groundGapTypePit, x: 80, width: 96),
      ],
      status: chunkStatusActive,
    ),
  ],
  baselineByChunkKey: <String, ChunkSourceBaseline>{},
  availableLevelIds: <String>['field', 'forest'],
  assemblyGroupOptionsByLevelId: <String, List<String>>{
    'field': <String>['default', 'cemetery', 'village'],
    'forest': <String>['default', 'cemetery', 'village'],
  },
  activeLevelId: 'field',
  levelOptionSource: 'test',
  runtimeGridSnap: 16.0,
  runtimeChunkWidth: 600.0,
  runtimeGroundTopY: 224,
);

const ChunkDocument _initialChunkWithPlacedPrefabDocument = ChunkDocument(
  chunks: <LevelChunkDef>[
    LevelChunkDef(
      chunkKey: 'chunk_field_prefab_001',
      id: 'chunk_prefab',
      revision: 1,
      schemaVersion: 1,
      levelId: 'field',
      tileSize: 16,
      width: 600,
      height: 270,
      difficulty: chunkDifficultyNormal,
      tags: <String>['base'],
      tileLayers: <TileLayerDef>[],
      prefabs: <PlacedPrefabDef>[
        PlacedPrefabDef(
          prefabId: 'crate_a',
          prefabKey: 'crate_a',
          x: 48,
          y: 224,
        ),
      ],
      markers: <PlacedMarkerDef>[],
      groundProfile: GroundProfileDef(kind: groundProfileKindFlat, topY: 224),
      groundGaps: <GroundGapDef>[],
      status: chunkStatusActive,
    ),
  ],
  baselineByChunkKey: <String, ChunkSourceBaseline>{},
  availableLevelIds: <String>['field', 'forest'],
  assemblyGroupOptionsByLevelId: <String, List<String>>{
    'field': <String>['default', 'cemetery', 'village'],
    'forest': <String>['default', 'cemetery', 'village'],
  },
  activeLevelId: 'field',
  levelOptionSource: 'test',
  runtimeGridSnap: 16.0,
  runtimeChunkWidth: 600.0,
  runtimeGroundTopY: 224,
);

class _InMemoryChunkPlugin implements AuthoringDomainPlugin {
  _InMemoryChunkPlugin(this._initialDocument);

  final ChunkDocument _initialDocument;
  final ChunkDomainPlugin _delegate = ChunkDomainPlugin();

  @override
  String get id => ChunkDomainPlugin.pluginId;

  @override
  Future<AuthoringDocument> loadFromRepo(EditorWorkspace workspace) async {
    return _initialDocument;
  }

  @override
  List<ValidationIssue> validate(AuthoringDocument document) {
    return _delegate.validate(document);
  }

  @override
  EditableScene buildEditableScene(AuthoringDocument document) {
    return _delegate.buildEditableScene(document);
  }

  @override
  AuthoringDocument applyEdit(
    AuthoringDocument document,
    AuthoringCommand command,
  ) {
    return _delegate.applyEdit(document, command);
  }

  @override
  Future<ExportResult> exportToRepo(
    EditorWorkspace workspace, {
    required AuthoringDocument document,
  }) async {
    return ExportResult(applied: false);
  }

  @override
  PendingChanges describePendingChanges(
    EditorWorkspace workspace, {
    required AuthoringDocument document,
  }) {
    return PendingChanges.empty;
  }
}

Future<void> _selectDropdownByLabel(
  WidgetTester tester, {
  required String label,
  required String value,
}) async {
  await tester.tap(
    find.byWidgetPredicate(
      (widget) =>
          widget is DropdownButtonFormField<String> &&
          widget.decoration.labelText == label,
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text(value).last);
  await tester.pumpAndSettle();
}

String _textFormFieldValue(WidgetTester tester, Key key) {
  final editableText = find.descendant(
    of: find.byKey(key),
    matching: find.byType(EditableText),
  );
  expect(editableText, findsOneWidget);
  return tester.widget<EditableText>(editableText).controller.text;
}
