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

      await tester.enterText(
        find.widgetWithText(TextField, 'width').first,
        '590',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Apply Metadata'));
      await tester.pumpAndSettle();

      expect(controller.errorCount, greaterThan(0));
      expect(
        find.textContaining('must match runtime chunkWidth'),
        findsWidgets,
      );
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
      height: 160,
      entrySocket: 'in',
      exitSocket: 'out',
      difficulty: chunkDifficultyNormal,
      tags: <String>['base'],
      tileLayers: <TileLayerDef>[],
      prefabs: <PlacedPrefabDef>[],
      markers: <PlacedMarkerDef>[],
      groundProfile: GroundProfileDef(kind: groundProfileKindFlat, topY: 0),
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
);

class _InMemoryChunkPlugin implements AuthoringDomainPlugin {
  _InMemoryChunkPlugin(this._initialDocument);

  final ChunkDocument _initialDocument;
  final ChunkDomainPlugin _delegate = ChunkDomainPlugin();

  @override
  String get id => ChunkDomainPlugin.pluginId;

  @override
  String get displayName => 'Chunks';

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
    return const ExportResult(applied: false);
  }

  @override
  PendingChanges describePendingChanges(
    EditorWorkspace workspace, {
    required AuthoringDocument document,
  }) {
    return const PendingChanges();
  }
}
