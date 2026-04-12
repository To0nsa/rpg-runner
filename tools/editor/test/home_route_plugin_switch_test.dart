import 'dart:async';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:runner_editor/src/app/pages/home/editor_home_page.dart';
import 'package:runner_editor/src/app/pages/prefabCreator/obstacle_prefabs/widgets/prefab_scene_view.dart';
import 'package:runner_editor/src/app/pages/prefabCreator/platform_modules/widgets/platform_module_scene_view.dart';
import 'package:runner_editor/src/chunks/chunk_domain_models.dart';
import 'package:runner_editor/src/chunks/chunk_domain_plugin.dart';
import 'package:runner_editor/src/domain/authoring_plugin_registry.dart';
import 'package:runner_editor/src/domain/authoring_types.dart';
import 'package:runner_editor/src/entities/entity_domain_plugin.dart';
import 'package:runner_editor/src/levels/level_domain_models.dart';
import 'package:runner_editor/src/levels/level_domain_plugin.dart';
import 'package:runner_editor/src/parallax/parallax_domain_models.dart';
import 'package:runner_editor/src/parallax/parallax_domain_plugin.dart';
import 'package:runner_editor/src/prefabs/domain/prefab_domain_models.dart';
import 'package:runner_editor/src/prefabs/domain/prefab_domain_plugin.dart';
import 'package:runner_editor/src/prefabs/models/models.dart';
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
          _FakeLevelPlugin(),
          _FakeParallaxPlugin(),
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
    await tester.tap(find.text('LEVEL CREATOR').last);
    await tester.pumpAndSettle();
    expect(controller.selectedPluginId, LevelDomainPlugin.pluginId);

    await tester.tap(find.byType(DropdownButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('PARALLAX').last);
    await tester.pumpAndSettle();
    expect(controller.selectedPluginId, ParallaxDomainPlugin.pluginId);

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

  testWidgets('typing in workspace field does not change session context', (
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
    expect(controller.workspacePath, '.');

    await tester.enterText(
      _textFieldByLabel('Workspace Path'),
      'C:\\temp\\next',
    );
    await tester.pumpAndSettle();

    expect(controller.workspacePath, '.');
    expect(controller.pendingChanges.hasChanges, isTrue);
    expect(find.text('Discard unsaved changes?'), findsNothing);
  });

  testWidgets('workspace apply with pending changes can be cancelled', (
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

    await tester.enterText(
      _textFieldByLabel('Workspace Path'),
      'C:\\temp\\next',
    );
    await tester.pumpAndSettle();
    await tester.tap(_workspaceApplyButton());
    await tester.pumpAndSettle();

    expect(find.text('Discard unsaved changes?'), findsOneWidget);

    await tester.tap(find.text('Stay'));
    await tester.pumpAndSettle();

    expect(controller.workspacePath, '.');
    expect(controller.pendingChanges.hasChanges, isTrue);
    expect(_workspaceTextField(tester).controller?.text, 'C:\\temp\\next');
  });

  testWidgets('workspace apply with pending changes can be confirmed', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1800, 1200));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    final entitiesPlugin = _FakeDirtyEntitiesPlugin();
    final controller = EditorSessionController(
      pluginRegistry: AuthoringPluginRegistry(
        plugins: <AuthoringDomainPlugin>[
          entitiesPlugin,
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

    await tester.enterText(
      _textFieldByLabel('Workspace Path'),
      '  C:\\temp\\next  ',
    );
    await tester.pumpAndSettle();
    await tester.tap(_workspaceApplyButton());
    await tester.pumpAndSettle();

    expect(find.text('Discard unsaved changes?'), findsOneWidget);

    await tester.tap(find.text('Discard and switch'));
    await tester.pumpAndSettle();

    expect(controller.workspacePath, 'C:\\temp\\next');
    expect(entitiesPlugin.loadCallCount, 2);
    expect(find.text('Discard unsaved changes?'), findsNothing);
    expect(_workspaceTextField(tester).controller?.text, 'C:\\temp\\next');
  });

  testWidgets('shell reload uses discard guard and reloads current route', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1800, 1200));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    final entitiesPlugin = _FakeDirtyEntitiesPlugin();
    final controller = EditorSessionController(
      pluginRegistry: AuthoringPluginRegistry(
        plugins: <AuthoringDomainPlugin>[
          entitiesPlugin,
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

    expect(entitiesPlugin.loadCallCount, 1);
    expect(controller.pendingChanges.hasChanges, isTrue);

    await tester.tap(_workspaceReloadButton());
    await tester.pumpAndSettle();

    expect(find.text('Discard unsaved changes?'), findsOneWidget);

    await tester.tap(find.text('Discard and reload'));
    await tester.pumpAndSettle();

    expect(entitiesPlugin.loadCallCount, 2);
    expect(find.text('Discard unsaved changes?'), findsNothing);
  });

  testWidgets('workspace browse uses picker result and guarded apply flow', (
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
      MaterialApp(
        home: EditorHomePage(
          controller: controller,
          workspaceDirectoryPicker: () async => 'C:\\picked\\workspace',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(_workspaceBrowseButton());
    await tester.pumpAndSettle();

    expect(find.text('Discard unsaved changes?'), findsOneWidget);
    expect(
      _workspaceTextField(tester).controller?.text,
      'C:\\picked\\workspace',
    );

    await tester.tap(find.text('Discard and switch'));
    await tester.pumpAndSettle();

    expect(controller.workspacePath, 'C:\\picked\\workspace');
    expect(find.text('Discard unsaved changes?'), findsNothing);
  });

  testWidgets('shell reload delegates through prefab page reload flow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1800, 1200));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    final prefabPlugin = _ReloadableFakePrefabEditorPlugin();
    final controller = EditorSessionController(
      pluginRegistry: AuthoringPluginRegistry(
        plugins: <AuthoringDomainPlugin>[
          _FakeEntitiesPlugin(),
          prefabPlugin,
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

    expect(prefabPlugin.loadCallCount, 1);
    expect(find.text('reloaded_prefab'), findsNothing);

    await tester.tap(_workspaceReloadButton());
    await tester.pumpAndSettle();

    expect(prefabPlugin.loadCallCount, 2);
    expect(find.text('reloaded_prefab'), findsWidgets);
  });

  testWidgets('route selection fails fast when required plugin is missing', (
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

    Object? exception;
    await runZonedGuarded(
      () async {
        await tester.tap(find.byType(DropdownButton<String>).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('PREFAB CREATOR').last);
        await tester.pump();
      },
      (error, _) {
        exception = error;
      },
    );

    expect(exception, isA<StateError>());
    expect(
      '$exception',
      contains(
        'Editor home route "prefab_creator" requires plugin '
        '"${PrefabDomainPlugin.pluginId}"',
      ),
    );
  });

  testWidgets('app exit with pending changes can be cancelled', (tester) async {
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

    final exitRequest = tester.binding.handleRequestAppExit();
    await tester.pumpAndSettle();

    expect(find.text('Discard unsaved changes?'), findsOneWidget);
    expect(
      find.textContaining('Close the editor without saving?'),
      findsOneWidget,
    );

    await tester.tap(find.text('Stay'));
    await tester.pumpAndSettle();

    expect(await exitRequest, AppExitResponse.cancel);
    expect(controller.pendingChanges.hasChanges, isTrue);
  });

  testWidgets('app exit with pending changes can be confirmed', (tester) async {
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

    final exitRequest = tester.binding.handleRequestAppExit();
    await tester.pumpAndSettle();

    expect(find.text('Discard unsaved changes?'), findsOneWidget);

    await tester.tap(find.text('Discard and exit'));
    await tester.pumpAndSettle();

    expect(await exitRequest, AppExitResponse.exit);
  });

  testWidgets('ctrl+z does not mutate session while discard dialog is open', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1800, 1200));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    final controller = EditorSessionController(
      pluginRegistry: AuthoringPluginRegistry(
        plugins: <AuthoringDomainPlugin>[
          _FakeDirtyEntitiesPlugin(initialDirty: false),
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

    controller.applyCommand(AuthoringCommand(kind: 'mark_dirty'));
    await tester.pumpAndSettle();

    expect(controller.pendingChanges.hasChanges, isTrue);
    expect(controller.canUndo, isTrue);

    await _selectRoute(tester, 'PREFAB CREATOR');
    await tester.pumpAndSettle();

    expect(find.text('Discard unsaved changes?'), findsOneWidget);

    await _pressCtrlShortcut(tester, LogicalKeyboardKey.keyZ);

    expect(find.text('Discard unsaved changes?'), findsOneWidget);
    expect(controller.pendingChanges.hasChanges, isTrue);
    expect(controller.canUndo, isTrue);
    expect(controller.selectedPluginId, EntityDomainPlugin.pluginId);
  });

  testWidgets('ctrl+z and ctrl+y drive session undo and redo', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1800, 1200));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    final controller = EditorSessionController(
      pluginRegistry: AuthoringPluginRegistry(
        plugins: <AuthoringDomainPlugin>[
          _FakeDirtyEntitiesPlugin(initialDirty: false),
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

    controller.applyCommand(AuthoringCommand(kind: 'mark_dirty'));
    await tester.pumpAndSettle();

    expect(controller.pendingChanges.hasChanges, isTrue);
    expect(controller.canUndo, isTrue);

    await _pressCtrlShortcut(tester, LogicalKeyboardKey.keyZ);

    expect(controller.pendingChanges.hasChanges, isFalse);
    expect(controller.canRedo, isTrue);

    await _pressCtrlShortcut(tester, LogicalKeyboardKey.keyY);

    expect(controller.pendingChanges.hasChanges, isTrue);
    expect(controller.canUndo, isTrue);
  });

  testWidgets('ctrl+z and ctrl+y work on prefab obstacle tab committed edits', (
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

    expect(find.text('No obstacle prefabs yet.'), findsOneWidget);

    await tester.enterText(_textFieldByLabel('Prefab ID').first, 'crate_box');
    await tester.tap(
      find.byKey(const ValueKey<String>('obstacle_prefab_upsert_button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('No obstacle prefabs yet.'), findsNothing);
    expect(find.text('crate_box'), findsWidgets);

    await _pressCtrlShortcut(tester, LogicalKeyboardKey.keyZ);

    expect(find.text('No obstacle prefabs yet.'), findsOneWidget);

    await _pressCtrlShortcut(tester, LogicalKeyboardKey.keyY);

    expect(find.text('No obstacle prefabs yet.'), findsNothing);
    expect(find.text('crate_box'), findsWidgets);
  });

  testWidgets('ctrl+z and ctrl+y undo prefab obstacle anchor draft edits', (
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

    expect(_activePrefabSceneView(tester).values.anchorX, 0);

    await tester.enterText(_textFieldByLabel('Anchor X (px)').first, '11');
    await tester.pumpAndSettle();
    expect(_activePrefabSceneView(tester).values.anchorX, 11);

    await _pressCtrlShortcut(tester, LogicalKeyboardKey.keyZ);
    expect(_activePrefabSceneView(tester).values.anchorX, 0);

    await _pressCtrlShortcut(tester, LogicalKeyboardKey.keyY);
    expect(_activePrefabSceneView(tester).values.anchorX, 11);
  });

  testWidgets('ctrl+z and ctrl+y undo prefab platform collider draft edits', (
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
    await tester.tap(find.text('Platform Prefabs').first);
    await tester.pumpAndSettle();

    expect(
      _activePlatformModuleSceneView(tester).overlayValues?.colliderWidth,
      16,
    );

    await tester.enterText(_textFieldByLabel('Collider Width').first, '24');
    await tester.pumpAndSettle();
    expect(
      _activePlatformModuleSceneView(tester).overlayValues?.colliderWidth,
      24,
    );

    await _pressCtrlShortcut(tester, LogicalKeyboardKey.keyZ);
    expect(
      _activePlatformModuleSceneView(tester).overlayValues?.colliderWidth,
      16,
    );

    await _pressCtrlShortcut(tester, LogicalKeyboardKey.keyY);
    expect(
      _activePlatformModuleSceneView(tester).overlayValues?.colliderWidth,
      24,
    );
  });

  testWidgets(
    'ctrl+z does not trigger session undo while typing in a text field',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1800, 1200));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });

      final controller = EditorSessionController(
        pluginRegistry: AuthoringPluginRegistry(
          plugins: <AuthoringDomainPlugin>[
            _FakeDirtyEntitiesPlugin(initialDirty: false),
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

      controller.applyCommand(AuthoringCommand(kind: 'mark_dirty'));
      await tester.pumpAndSettle();

      await tester.tap(_textFieldByLabel('Workspace Path'));
      await tester.pumpAndSettle();

      await _pressCtrlShortcut(tester, LogicalKeyboardKey.keyZ);

      expect(controller.pendingChanges.hasChanges, isTrue);
      expect(controller.canUndo, isTrue);
    },
  );
}

class _FakeEntitiesPlugin implements AuthoringDomainPlugin {
  int loadCallCount = 0;

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
    loadCallCount += 1;
    return const _FakeDocument();
  }

  @override
  List<ValidationIssue> validate(AuthoringDocument document) {
    return const <ValidationIssue>[];
  }
}

class _FakeDirtyEntitiesPlugin implements AuthoringDomainPlugin {
  _FakeDirtyEntitiesPlugin({this.initialDirty = true});

  final bool initialDirty;
  int loadCallCount = 0;

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
    loadCallCount += 1;
    return _FakeDirtyDocument(isDirty: initialDirty);
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
          height: 270,
          difficulty: chunkDifficultyNormal,
          groundProfile: GroundProfileDef(
            kind: groundProfileKindFlat,
            topY: 224,
          ),
        ),
      ],
      baselineByChunkKey: <String, ChunkSourceBaseline>{},
      availableLevelIds: <String>['field'],
      assemblyGroupOptionsByLevelId: <String, List<String>>{
        'field': <String>['default'],
      },
      activeLevelId: 'field',
      levelOptionSource: 'test',
      runtimeGridSnap: 16.0,
      runtimeChunkWidth: 600.0,
      runtimeGroundTopY: 224,
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

class _FakeParallaxPlugin implements AuthoringDomainPlugin {
  final ParallaxDomainPlugin _delegate = ParallaxDomainPlugin();

  @override
  String get id => ParallaxDomainPlugin.pluginId;

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
    return ParallaxDefsDocument(
      workspaceRootPath: workspace.rootPath,
      themes: const <ParallaxThemeDef>[
        ParallaxThemeDef(
          parallaxThemeId: 'field',
          revision: 1,
          groundMaterialAssetPath: 'assets/images/parallax/field/ground.png',
          layers: <ParallaxLayerDef>[
            ParallaxLayerDef(
              layerKey: 'field_bg_10',
              assetPath: 'assets/images/parallax/field/bg_10.png',
              group: parallaxGroupBackground,
              parallaxFactor: 0.25,
              zOrder: 10,
              opacity: 1.0,
              yOffset: 0.0,
            ),
          ],
        ),
      ],
      baseline: null,
      availableLevelIds: const <String>['field'],
      activeLevelId: 'field',
      levelOptionSource: 'test',
      parallaxThemeIdByLevelId: const <String, String>{'field': 'field'},
    );
  }

  @override
  List<ValidationIssue> validate(AuthoringDocument document) {
    return _delegate.validate(document);
  }
}

class _FakeLevelPlugin implements AuthoringDomainPlugin {
  final LevelDomainPlugin _delegate = LevelDomainPlugin();

  @override
  String get id => LevelDomainPlugin.pluginId;

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
    return const LevelDefsDocument(
      workspaceRootPath: '.',
      levels: <LevelDef>[
        LevelDef(
          levelId: 'field',
          revision: 1,
          displayName: 'Field',
          visualThemeId: 'field',
          cameraCenterY: 135,
          groundTopY: 224,
          earlyPatternChunks: 3,
          easyPatternChunks: 0,
          normalPatternChunks: 0,
          noEnemyChunks: 3,
          enumOrdinal: 20,
          status: levelStatusActive,
        ),
      ],
      baseline: null,
      baselineLevels: <LevelDef>[
        LevelDef(
          levelId: 'field',
          revision: 1,
          displayName: 'Field',
          visualThemeId: 'field',
          cameraCenterY: 135,
          groundTopY: 224,
          earlyPatternChunks: 3,
          easyPatternChunks: 0,
          normalPatternChunks: 0,
          noEnemyChunks: 3,
          enumOrdinal: 20,
          status: levelStatusActive,
        ),
      ],
      activeLevelId: 'field',
      availableParallaxVisualThemeIds: <String>['field'],
      parallaxThemeSourceAvailable: true,
      authoredChunkCountsByLevelId: <String, int>{'field': 1},
      authoredChunkAssemblyGroupCountsByLevelId: <String, Map<String, int>>{
        'field': <String, int>{'default': 1},
      },
      chunkCountSourceAvailable: true,
    );
  }

  @override
  List<ValidationIssue> validate(AuthoringDocument document) {
    return _delegate.validate(document);
  }
}

class _FakePrefabEditorPlugin implements AuthoringDomainPlugin {
  int loadCallCount = 0;

  @override
  String get id => PrefabDomainPlugin.pluginId;

  @override
  AuthoringDocument applyEdit(
    AuthoringDocument document,
    AuthoringCommand command,
  ) {
    final prefabDocument = document as PrefabDocument;
    if (command.kind != PrefabDomainPlugin.replacePrefabDataCommandKind) {
      return prefabDocument;
    }
    final nextData = command.payload['data'];
    if (nextData is! PrefabData) {
      return prefabDocument;
    }
    return PrefabDocument(
      data: nextData,
      atlasImagePaths: prefabDocument.atlasImagePaths,
      atlasImageSizes: prefabDocument.atlasImageSizes,
      migrationHints: const <String>[],
    );
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
    loadCallCount += 1;
    return PrefabDocument(
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

class _ReloadableFakePrefabEditorPlugin implements AuthoringDomainPlugin {
  int loadCallCount = 0;

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
    loadCallCount += 1;
    final prefabs = loadCallCount >= 2
        ? <PrefabDef>[
            PrefabDef(
              prefabKey: 'reloaded_prefab',
              id: 'reloaded_prefab',
              revision: 1,
              kind: PrefabKind.obstacle,
              visualSource: const PrefabVisualSource.atlasSlice('crate_slice'),
              anchorXPx: 0,
              anchorYPx: 0,
              colliders: const <PrefabColliderDef>[
                PrefabColliderDef(
                  offsetX: 0,
                  offsetY: 0,
                  width: 16,
                  height: 16,
                ),
              ],
            ),
          ]
        : const <PrefabDef>[];
    return PrefabDocument(
      data: PrefabData(
        prefabSlices: const <AtlasSliceDef>[
          AtlasSliceDef(
            id: 'crate_slice',
            sourceImagePath: 'assets/images/level/props/crate.png',
            x: 0,
            y: 0,
            width: 32,
            height: 32,
          ),
        ],
        prefabs: prefabs,
      ),
      atlasImagePaths: const <String>[],
      atlasImageSizes: const <String, Size>{},
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

Future<void> _pressCtrlShortcut(
  WidgetTester tester,
  LogicalKeyboardKey key,
) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyDownEvent(key);
  await tester.sendKeyUpEvent(key);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pumpAndSettle();
}

Finder _textFieldByLabel(String label) {
  return find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label,
  );
}

Finder _workspaceApplyButton() {
  return find.byKey(const ValueKey<String>('apply_workspace_path_button'));
}

Finder _workspaceReloadButton() {
  return find.byKey(const ValueKey<String>('reload_editor_page_button'));
}

Finder _workspaceBrowseButton() {
  return find.byKey(const ValueKey<String>('browse_workspace_path_button'));
}

TextField _workspaceTextField(WidgetTester tester) {
  return tester.widget<TextField>(_textFieldByLabel('Workspace Path'));
}

PrefabSceneView _activePrefabSceneView(WidgetTester tester) {
  return tester.widget<PrefabSceneView>(find.byType(PrefabSceneView).first);
}

PlatformModuleSceneView _activePlatformModuleSceneView(WidgetTester tester) {
  return tester.widget<PlatformModuleSceneView>(
    find.byType(PlatformModuleSceneView).first,
  );
}
