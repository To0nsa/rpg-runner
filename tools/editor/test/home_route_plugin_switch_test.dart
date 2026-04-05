import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:runner_editor/src/app/pages/home/editor_home_page.dart';
import 'package:runner_editor/src/chunks/chunk_domain_models.dart';
import 'package:runner_editor/src/chunks/chunk_domain_plugin.dart';
import 'package:runner_editor/src/domain/authoring_plugin_registry.dart';
import 'package:runner_editor/src/domain/authoring_types.dart';
import 'package:runner_editor/src/entities/entity_domain_plugin.dart';
import 'package:runner_editor/src/prefabs/prefab_domain_models.dart';
import 'package:runner_editor/src/prefabs/prefab_domain_plugin.dart';
import 'package:runner_editor/src/prefabs/prefab_models.dart';
import 'package:runner_editor/src/session/editor_session_controller.dart';
import 'package:runner_editor/src/workspace/editor_workspace.dart';

void main() {
  testWidgets('route switching keeps plugin/session selection coherent', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1800, 1200));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    final controller = EditorSessionController(
      pluginRegistry: AuthoringPluginRegistry(
        plugins: <AuthoringDomainPlugin>[
          _FakeEntitiesPlugin(),
          _FakePrefabPlugin(),
          _FakeChunkPlugin(),
        ],
      ),
      initialPluginId: EntityDomainPlugin.pluginId,
      initialWorkspacePath: '.',
    );

    await tester.pumpWidget(
      MaterialApp(home: EditorHomePage(controller: controller)),
    );
    await tester.pumpAndSettle();

    expect(controller.selectedPluginId, EntityDomainPlugin.pluginId);

    await tester.tap(find.byType(DropdownButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('PREFAB CREATOR').last);
    await tester.pumpAndSettle();
    expect(controller.selectedPluginId, PrefabDomainPlugin.pluginId);

    await tester.tap(find.byType(DropdownButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('CHUNK CREATOR').last);
    await tester.pumpAndSettle();
    expect(controller.selectedPluginId, ChunkDomainPlugin.pluginId);

    await tester.tap(find.byType(DropdownButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('ENTITIES').last);
    await tester.pumpAndSettle();
    expect(controller.selectedPluginId, EntityDomainPlugin.pluginId);
  });

  testWidgets('route switching with pending changes can be cancelled', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1800, 1200));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    final controller = EditorSessionController(
      pluginRegistry: AuthoringPluginRegistry(
        plugins: <AuthoringDomainPlugin>[
          _FakeDirtyEntitiesPlugin(),
          _FakePrefabPlugin(),
          _FakeChunkPlugin(),
        ],
      ),
      initialPluginId: EntityDomainPlugin.pluginId,
      initialWorkspacePath: '.',
    );

    await tester.pumpWidget(
      MaterialApp(home: EditorHomePage(controller: controller)),
    );
    await tester.pumpAndSettle();
    expect(controller.pendingChanges.hasChanges, isTrue);

    await tester.tap(find.byType(DropdownButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('PREFAB CREATOR').last);
    await tester.pumpAndSettle();

    expect(find.text('Discard unsaved changes?'), findsOneWidget);

    await tester.tap(find.text('Stay'));
    await tester.pumpAndSettle();

    expect(controller.selectedPluginId, EntityDomainPlugin.pluginId);
    expect(find.text('Discard unsaved changes?'), findsNothing);
  });

  testWidgets('route switching with pending changes can be confirmed', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1800, 1200));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    final controller = EditorSessionController(
      pluginRegistry: AuthoringPluginRegistry(
        plugins: <AuthoringDomainPlugin>[
          _FakeDirtyEntitiesPlugin(),
          _FakePrefabPlugin(),
          _FakeChunkPlugin(),
        ],
      ),
      initialPluginId: EntityDomainPlugin.pluginId,
      initialWorkspacePath: '.',
    );

    await tester.pumpWidget(
      MaterialApp(home: EditorHomePage(controller: controller)),
    );
    await tester.pumpAndSettle();
    expect(controller.pendingChanges.hasChanges, isTrue);

    await tester.tap(find.byType(DropdownButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('PREFAB CREATOR').last);
    await tester.pumpAndSettle();

    expect(find.text('Discard unsaved changes?'), findsOneWidget);

    await tester.tap(find.text('Discard and leave'));
    await tester.pumpAndSettle();

    expect(controller.selectedPluginId, PrefabDomainPlugin.pluginId);
    expect(find.text('Discard unsaved changes?'), findsNothing);
  });

  testWidgets('route switching prompts for page-local prefab drafts', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1800, 1200));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    final controller = EditorSessionController(
      pluginRegistry: AuthoringPluginRegistry(
        plugins: <AuthoringDomainPlugin>[
          _FakeEntitiesPlugin(),
          _FakePrefabEditorPlugin(),
          _FakeChunkPlugin(),
        ],
      ),
      initialPluginId: EntityDomainPlugin.pluginId,
      initialWorkspacePath: '.',
    );

    await tester.pumpWidget(
      MaterialApp(home: EditorHomePage(controller: controller)),
    );
    await tester.pumpAndSettle();

    await _selectRoute(tester, 'PREFAB CREATOR');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Obstacle Prefabs').first);
    await tester.pumpAndSettle();

    expect(controller.pendingChanges.hasChanges, isFalse);

    await tester.enterText(_textFieldByLabel('Prefab ID').first, 'draft_box');
    await tester.pump();

    await _selectRoute(tester, 'CHUNK CREATOR');
    await tester.pumpAndSettle();

    expect(find.text('Discard unsaved changes?'), findsOneWidget);
    expect(
      find.textContaining('unsaved draft form/input changes'),
      findsOneWidget,
    );
    expect(controller.selectedPluginId, PrefabDomainPlugin.pluginId);

    await tester.tap(find.text('Stay'));
    await tester.pumpAndSettle();

    expect(controller.selectedPluginId, PrefabDomainPlugin.pluginId);
    expect(find.text('Discard unsaved changes?'), findsNothing);
  });
}

class _FakeEntitiesPlugin implements AuthoringDomainPlugin {
  @override
  String get id => EntityDomainPlugin.pluginId;

  @override
  AuthoringDocument applyEdit(
    AuthoringDocument document,
    AuthoringCommand command,
  ) {
    return document;
  }

  @override
  EditableScene buildEditableScene(AuthoringDocument document) {
    return const _FakeScene();
  }

  @override
  PendingChanges describePendingChanges(
    EditorWorkspace workspace, {
    required AuthoringDocument document,
  }) {
    return PendingChanges.empty;
  }

  @override
  Future<ExportResult> exportToRepo(
    EditorWorkspace workspace, {
    required AuthoringDocument document,
  }) async {
    return ExportResult(applied: false);
  }

  @override
  Future<AuthoringDocument> loadFromRepo(EditorWorkspace workspace) async {
    return const _FakeDocument();
  }

  @override
  List<ValidationIssue> validate(AuthoringDocument document) {
    return const <ValidationIssue>[];
  }
}

class _FakeDirtyEntitiesPlugin implements AuthoringDomainPlugin {
  @override
  String get id => EntityDomainPlugin.pluginId;

  @override
  AuthoringDocument applyEdit(
    AuthoringDocument document,
    AuthoringCommand command,
  ) {
    final dirtyDocument = document as _FakeDirtyDocument;
    if (command.kind != 'mark_dirty') {
      return dirtyDocument;
    }
    if (dirtyDocument.isDirty) {
      return dirtyDocument;
    }
    return const _FakeDirtyDocument(isDirty: true);
  }

  @override
  EditableScene buildEditableScene(AuthoringDocument document) {
    return const _FakeScene();
  }

  @override
  PendingChanges describePendingChanges(
    EditorWorkspace workspace, {
    required AuthoringDocument document,
  }) {
    final dirtyDocument = document as _FakeDirtyDocument;
    if (!dirtyDocument.isDirty) {
      return PendingChanges.empty;
    }
    return PendingChanges(
      changedItemIds: const <String>['entity_1'],
      fileDiffs: const <PendingFileDiff>[
        PendingFileDiff(
          relativePath: 'lib/src/entities.dart',
          editCount: 1,
          unifiedDiff: '@@',
        ),
      ],
    );
  }

  @override
  Future<ExportResult> exportToRepo(
    EditorWorkspace workspace, {
    required AuthoringDocument document,
  }) async {
    return ExportResult(applied: false);
  }

  @override
  Future<AuthoringDocument> loadFromRepo(EditorWorkspace workspace) async {
    return const _FakeDirtyDocument(isDirty: true);
  }

  @override
  List<ValidationIssue> validate(AuthoringDocument document) {
    return const <ValidationIssue>[];
  }
}

class _FakeChunkPlugin implements AuthoringDomainPlugin {
  final ChunkDomainPlugin _delegate = ChunkDomainPlugin();

  @override
  String get id => ChunkDomainPlugin.pluginId;

  @override
  AuthoringDocument applyEdit(
    AuthoringDocument document,
    AuthoringCommand command,
  ) {
    return _delegate.applyEdit(document, command);
  }

  @override
  EditableScene buildEditableScene(AuthoringDocument document) {
    return _delegate.buildEditableScene(document);
  }

  @override
  PendingChanges describePendingChanges(
    EditorWorkspace workspace, {
    required AuthoringDocument document,
  }) {
    return PendingChanges.empty;
  }

  @override
  Future<ExportResult> exportToRepo(
    EditorWorkspace workspace, {
    required AuthoringDocument document,
  }) async {
    return ExportResult(applied: false);
  }

  @override
  Future<AuthoringDocument> loadFromRepo(EditorWorkspace workspace) async {
    return const ChunkDocument(
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
          groundProfile: GroundProfileDef(kind: groundProfileKindFlat, topY: 0),
        ),
      ],
      baselineByChunkKey: <String, ChunkSourceBaseline>{},
      availableLevelIds: <String>['field'],
      activeLevelId: 'field',
      levelOptionSource: 'test',
      runtimeGridSnap: 16.0,
      runtimeChunkWidth: 600.0,
    );
  }

  @override
  List<ValidationIssue> validate(AuthoringDocument document) {
    return _delegate.validate(document);
  }
}

class _FakePrefabPlugin implements AuthoringDomainPlugin {
  @override
  String get id => PrefabDomainPlugin.pluginId;

  @override
  AuthoringDocument applyEdit(
    AuthoringDocument document,
    AuthoringCommand command,
  ) {
    return document;
  }

  @override
  EditableScene buildEditableScene(AuthoringDocument document) {
    return const _FakeScene();
  }

  @override
  PendingChanges describePendingChanges(
    EditorWorkspace workspace, {
    required AuthoringDocument document,
  }) {
    return PendingChanges.empty;
  }

  @override
  Future<ExportResult> exportToRepo(
    EditorWorkspace workspace, {
    required AuthoringDocument document,
  }) async {
    return ExportResult(applied: false);
  }

  @override
  Future<AuthoringDocument> loadFromRepo(EditorWorkspace workspace) async {
    return const _FakeDocument();
  }

  @override
  List<ValidationIssue> validate(AuthoringDocument document) {
    return const <ValidationIssue>[];
  }
}

class _FakePrefabEditorPlugin implements AuthoringDomainPlugin {
  @override
  String get id => PrefabDomainPlugin.pluginId;

  @override
  AuthoringDocument applyEdit(
    AuthoringDocument document,
    AuthoringCommand command,
  ) {
    return document;
  }

  @override
  EditableScene buildEditableScene(AuthoringDocument document) {
    final prefabDocument = document as PrefabDocument;
    return PrefabScene(
      data: prefabDocument.data,
      atlasImagePaths: prefabDocument.atlasImagePaths,
      atlasImageSizes: prefabDocument.atlasImageSizes,
      migrationHints: prefabDocument.migrationHints,
    );
  }

  @override
  PendingChanges describePendingChanges(
    EditorWorkspace workspace, {
    required AuthoringDocument document,
  }) {
    return PendingChanges.empty;
  }

  @override
  Future<ExportResult> exportToRepo(
    EditorWorkspace workspace, {
    required AuthoringDocument document,
  }) async {
    return ExportResult(applied: false);
  }

  @override
  Future<AuthoringDocument> loadFromRepo(EditorWorkspace workspace) async {
    return const PrefabDocument(
      data: PrefabData(
        prefabSlices: <AtlasSliceDef>[
          AtlasSliceDef(
            id: 'crate_slice',
            sourceImagePath: 'assets/images/level/props/crate.png',
            x: 0,
            y: 0,
            width: 32,
            height: 32,
          ),
        ],
        tileSlices: <AtlasSliceDef>[
          AtlasSliceDef(
            id: 'ground_tile',
            sourceImagePath: 'assets/images/level/tiles/ground.png',
            x: 0,
            y: 0,
            width: 16,
            height: 16,
          ),
        ],
        platformModules: <TileModuleDef>[
          TileModuleDef(
            id: 'ground_module',
            tileSize: 16,
            cells: <TileModuleCellDef>[
              TileModuleCellDef(sliceId: 'ground_tile', gridX: 0, gridY: 0),
            ],
          ),
        ],
      ),
      atlasImagePaths: <String>[],
      atlasImageSizes: <String, Size>{},
    );
  }

  @override
  List<ValidationIssue> validate(AuthoringDocument document) {
    return const <ValidationIssue>[];
  }
}

class _FakeDocument extends AuthoringDocument {
  const _FakeDocument();
}

class _FakeDirtyDocument extends AuthoringDocument {
  const _FakeDirtyDocument({required this.isDirty});

  final bool isDirty;
}

class _FakeScene extends EditableScene {
  const _FakeScene();
}

Future<void> _selectRoute(WidgetTester tester, String label) async {
  await tester.tap(find.byType(DropdownButton<String>).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
}

Finder _textFieldByLabel(String label) {
  return find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label,
  );
}
