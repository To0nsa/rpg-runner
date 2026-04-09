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
    'chunk creator supports level switch, create/duplicate/rename/deprecate, and blocking validation surfacing',
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
        find.widgetWithText(TextField, 'Rename ID'),
        'chunk_renamed',
      );
      await tester.tap(find.text('Rename'));
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

      await tester.tap(find.text('Metadata'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'tileSize').first,
        '15',
      );
      final applyMetadata = find.text('Apply Metadata', skipOffstage: false);
      expect(applyMetadata, findsWidgets);
      await tester.ensureVisible(applyMetadata.last);
      await tester.pumpAndSettle();
      await tester.tap(applyMetadata.last);
      await tester.pumpAndSettle();

      expect(controller.errorCount, greaterThan(0));
      await tester.tap(find.text('Validation'));
      await tester.pumpAndSettle();
      expect(find.textContaining('tileSize must be snapped'), findsWidgets);
    },
  );

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
      MaterialApp(home: Scaffold(body: ChunkCreatorPage(controller: controller))),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.text('chunk_gap').first);
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Inspector:').first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ground Gaps'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.edit_outlined).first);
    await tester.pumpAndSettle();

    final dialog = find.byType(AlertDialog);
    expect(dialog, findsOneWidget);

    await tester.enterText(
      find.descendant(
        of: dialog,
        matching: find.widgetWithText(TextFormField, 'x'),
      ),
      '48',
    );
    await tester.enterText(
      find.descendant(
        of: dialog,
        matching: find.widgetWithText(TextFormField, 'width'),
      ),
      '64',
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    final sceneAfterEdit = controller.scene as ChunkScene;
    final chunk = sceneAfterEdit.chunks.firstWhere((entry) => entry.id == 'chunk_gap');
    final gap = chunk.groundGaps.firstWhere((entry) => entry.gapId == 'gap_1');
    expect(gap.x, 48);
    expect(gap.width, 64);
  });
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
        GroundGapDef(
          gapId: 'gap_1',
          type: groundGapTypePit,
          x: 16,
          width: 32,
        ),
      ],
      status: chunkStatusActive,
    ),
  ],
  baselineByChunkKey: <String, ChunkSourceBaseline>{},
  availableLevelIds: <String>['field', 'forest'],
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
