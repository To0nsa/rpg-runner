import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:runner_editor/src/app/pages/prefabCreator/prefab_creator_page.dart';
import 'package:runner_editor/src/domain/authoring_plugin_registry.dart';
import 'package:runner_editor/src/domain/authoring_types.dart';
import 'package:runner_editor/src/session/editor_session_controller.dart';
import 'package:runner_editor/src/workspace/editor_workspace.dart';

void main() {
  testWidgets('tabs split obstacle and platform authoring', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1800, 1200));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    final fixtureRoot = _createPrefabAuthoringFixture();
    addTearDown(() {
      fixtureRoot.deleteSync(recursive: true);
    });

    await _pumpPrefabCreatorPage(tester, workspacePath: fixtureRoot.path);

    expect(_dropdownByLabel('Atlas Slice'), findsOneWidget);
    expect(find.text('Create/Update Platform Prefab'), findsNothing);

    await tester.tap(find.text('Platform Prefabs').first);
    await tester.pumpAndSettle();

    expect(find.text('Create/Update Platform Prefab'), findsOneWidget);
    expect(_dropdownByLabel('Atlas Slice'), findsNothing);

    await tester.tap(find.text('Obstacle Prefabs').first);
    await tester.pumpAndSettle();
    expect(_dropdownByLabel('Atlas Slice'), findsOneWidget);
    expect(find.text('Create/Update Platform Prefab'), findsNothing);
  });

  testWidgets('obstacle tab stays atlas-slice only', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1800, 1200));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    final fixtureRoot = _createPrefabAuthoringFixture();
    addTearDown(() {
      fixtureRoot.deleteSync(recursive: true);
    });

    await _pumpPrefabCreatorPage(tester, workspacePath: fixtureRoot.path);

    expect(_dropdownByLabel('Atlas Slice'), findsOneWidget);
    expect(find.text('crate_slice'), findsOneWidget);
    expect(find.text('ground_module'), findsNothing);
    expect(find.text('Create/Update Platform Prefab'), findsNothing);

    await tester.tap(find.text('Platform Prefabs').first);
    await tester.pumpAndSettle();
    expect(find.text('ground_module'), findsWidgets);
    expect(find.text('Create/Update Platform Prefab'), findsOneWidget);
  });

  testWidgets('obstacle create/edit flow is revision-safe', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1800, 1200));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    final fixtureRoot = _createPrefabAuthoringFixture();
    addTearDown(() {
      fixtureRoot.deleteSync(recursive: true);
    });

    await _pumpPrefabCreatorPage(tester, workspacePath: fixtureRoot.path);

    await tester.enterText(
      _textFieldByLabel('Prefab ID').first,
      'obstacle_box',
    );
    await tester.ensureVisible(find.text('Add/Update Prefab'));
    await tester.tap(find.text('Add/Update Prefab'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Upserted obstacle prefab "obstacle_box"'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Upserted obstacle prefab "obstacle_box" (rev=1'),
      findsOneWidget,
    );

    await tester.tap(find.text('Obstacle Prefabs').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Add/Update Prefab'));
    await tester.tap(find.text('Add/Update Prefab'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Upserted obstacle prefab "obstacle_box"'),
      findsOneWidget,
    );
    // No-payload-change update keeps revision stable.
    expect(
      find.textContaining('Upserted obstacle prefab "obstacle_box" (rev=1'),
      findsOneWidget,
    );
  });

  testWidgets('platform create/edit flow is revision-safe', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1800, 1200));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    final fixtureRoot = _createPrefabAuthoringFixture();
    addTearDown(() {
      fixtureRoot.deleteSync(recursive: true);
    });

    await _pumpPrefabCreatorPage(tester, workspacePath: fixtureRoot.path);

    await tester.tap(find.text('Platform Prefabs').first);
    await tester.pumpAndSettle();
    await tester.enterText(
      _textFieldByLabel('Platform Prefab ID').first,
      'platform_bridge',
    );
    await tester.ensureVisible(find.text('Create/Update Platform Prefab'));
    await tester.tap(find.text('Create/Update Platform Prefab'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Upserted platform prefab "platform_bridge"'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Upserted platform prefab "platform_bridge" (rev=1'),
      findsOneWidget,
    );

    await tester.tap(find.text('Create/Update Platform Prefab'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Upserted platform prefab "platform_bridge"'),
      findsOneWidget,
    );
    // No-payload-change update keeps revision stable.
    expect(
      find.textContaining('Upserted platform prefab "platform_bridge" (rev=1'),
      findsOneWidget,
    );
  });

  testWidgets('blocking validation surfaces coded errors on save', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1800, 1200));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    final fixtureRoot = _createPrefabAuthoringFixture();
    addTearDown(() {
      fixtureRoot.deleteSync(recursive: true);
    });

    await _pumpPrefabCreatorPage(tester, workspacePath: fixtureRoot.path);

    await tester.ensureVisible(find.text('Save Definitions'));
    await tester.tap(find.text('Save Definitions'));
    await tester.pumpAndSettle();

    expect(find.textContaining('[prefab_slice_atlas_missing]'), findsOneWidget);
  });

  testWidgets(
    'module rename cascades prefab refs and delete blocks referenced module',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1800, 1200));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });

      final fixtureRoot = _createPrefabAuthoringFixture();
      addTearDown(() {
        fixtureRoot.deleteSync(recursive: true);
      });

      await _pumpPrefabCreatorPage(tester, workspacePath: fixtureRoot.path);

      await tester.tap(find.text('Platform Prefabs').first);
      await tester.pumpAndSettle();
      await tester.enterText(
        _textFieldByLabel('Platform Prefab ID').first,
        'platform_ref',
      );
      await tester.ensureVisible(find.text('Create/Update Platform Prefab'));
      await tester.tap(find.text('Create/Update Platform Prefab'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('source=platform_module:ground_module'),
        findsOneWidget,
      );

      await tester.tap(find.text('Platform Prefabs').first);
      await tester.pumpAndSettle();
      await _openAdvancedModuleControls(tester);
      await tester.enterText(
        _textFieldByLabel('Platform Module ID').first,
        'ground_module_v2',
      );
      await tester.ensureVisible(find.text('Rename'));
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining(
          'Renamed module "ground_module" -> "ground_module_v2"',
        ),
        findsOneWidget,
      );

      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Cannot delete module "ground_module_v2"'),
        findsOneWidget,
      );
      expect(find.textContaining('ground_module_v2'), findsWidgets);
    },
  );

  testWidgets('platform module scene supports paint and erase workflows', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1800, 1200));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    final fixtureRoot = _createPrefabAuthoringFixture();
    addTearDown(() {
      fixtureRoot.deleteSync(recursive: true);
    });

    await _pumpPrefabCreatorPage(tester, workspacePath: fixtureRoot.path);

    await tester.tap(find.text('Platform Prefabs').first);
    await tester.pumpAndSettle();

    final sceneCanvas = find.byKey(
      const ValueKey<String>('platform_module_scene_canvas'),
    );
    expect(sceneCanvas, findsOneWidget);
    expect(find.textContaining('cells=1'), findsWidgets);

    final center = tester.getCenter(sceneCanvas);

    await tester.tap(find.byKey(const ValueKey<String>('module_tool_erase')));
    await tester.pumpAndSettle();

    for (final offset in <Offset>[
      Offset.zero,
      const Offset(10, 0),
      const Offset(-10, 0),
      const Offset(0, 10),
      const Offset(0, -10),
    ]) {
      await tester.tapAt(center + offset);
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(find.textContaining('cells=0'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey<String>('module_tool_paint')));
    await tester.pumpAndSettle();

    await tester.tapAt(center);
    await tester.pumpAndSettle();

    expect(find.textContaining('Painted cell ('), findsOneWidget);
    expect(find.textContaining('cells=1'), findsWidgets);
  });

  testWidgets('module tab can create a platform prefab for selected module', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1800, 1200));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    final fixtureRoot = _createPrefabAuthoringFixture();
    addTearDown(() {
      fixtureRoot.deleteSync(recursive: true);
    });

    await _pumpPrefabCreatorPage(tester, workspacePath: fixtureRoot.path);

    await tester.tap(find.text('Platform Prefabs').first);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Create/Update Platform Prefab'));
    await tester.tap(find.text('Create/Update Platform Prefab'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Upserted platform prefab'), findsOneWidget);
    expect(
      find.textContaining('source=platform_module:ground_module'),
      findsOneWidget,
    );
  });
}

Future<void> _pumpPrefabCreatorPage(
  WidgetTester tester, {
  required String workspacePath,
}) async {
  final controller = EditorSessionController(
    pluginRegistry: AuthoringPluginRegistry(
      plugins: const <AuthoringDomainPlugin>[_NoopPlugin()],
    ),
    initialPluginId: _NoopPlugin.pluginId,
    initialWorkspacePath: workspacePath,
  );
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: PrefabCreatorPage(controller: controller)),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pumpAndSettle();

  expect(
    find.textContaining('Loaded prefab/tile authoring data'),
    findsOneWidget,
  );
  await tester.tap(find.text('Obstacle Prefabs'));
  await tester.pumpAndSettle();
}

Directory _createPrefabAuthoringFixture() {
  final root = Directory.systemTemp.createTempSync('prefab_creator_fixture_');
  final authoringDir = Directory(
    p.join(root.path, 'assets', 'authoring', 'level'),
  );
  authoringDir.createSync(recursive: true);
  final levelAssetsDir = Directory(
    p.join(root.path, 'assets', 'images', 'level'),
  );
  levelAssetsDir.createSync(recursive: true);

  const encoder = JsonEncoder.withIndent('  ');

  final prefabDefs = <String, Object?>{
    'schemaVersion': 2,
    'slices': <Object?>[
      <String, Object?>{
        'id': 'crate_slice',
        'sourceImagePath': 'assets/images/level/props/missing_props.png',
        'x': 0,
        'y': 0,
        'width': 32,
        'height': 32,
      },
    ],
    'prefabs': <Object?>[],
  };
  final tileDefs = <String, Object?>{
    'schemaVersion': 2,
    'tileSlices': <Object?>[
      <String, Object?>{
        'id': 'ground_tile',
        'sourceImagePath': 'assets/images/level/tileset/missing_tiles.png',
        'x': 0,
        'y': 0,
        'width': 16,
        'height': 16,
      },
    ],
    'platformModules': <Object?>[
      <String, Object?>{
        'id': 'ground_module',
        'tileSize': 16,
        'cells': <Object?>[
          <String, Object?>{'sliceId': 'ground_tile', 'gridX': 0, 'gridY': 0},
        ],
      },
    ],
  };

  File(
    p.join(authoringDir.path, 'prefab_defs.json'),
  ).writeAsStringSync('${encoder.convert(prefabDefs)}\n');
  File(
    p.join(authoringDir.path, 'tile_defs.json'),
  ).writeAsStringSync('${encoder.convert(tileDefs)}\n');

  return root;
}

Future<void> _openAdvancedModuleControls(WidgetTester tester) async {
  if (_textFieldByLabel('Platform Module ID').evaluate().isNotEmpty) {
    return;
  }
  final tileFinder = find.byKey(
    const ValueKey<String>('platform_module_advanced_controls'),
  );
  expect(tileFinder, findsOneWidget);
  await tester.tap(
    find.descendant(
      of: tileFinder,
      matching: find.text('Advanced Module Controls'),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _textFieldByLabel(String label) {
  return find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label,
  );
}

Finder _dropdownByLabel(String label) {
  return find.byWidgetPredicate(
    (widget) =>
        widget is DropdownButtonFormField &&
        widget.decoration.labelText == label,
  );
}

class _NoopPlugin implements AuthoringDomainPlugin {
  const _NoopPlugin();

  static const String pluginId = 'noop';

  @override
  String get id => pluginId;

  @override
  String get displayName => 'Noop';

  @override
  Future<AuthoringDocument> loadFromRepo(EditorWorkspace workspace) async {
    return const _NoopDocument();
  }

  @override
  List<ValidationIssue> validate(AuthoringDocument document) {
    return const <ValidationIssue>[];
  }

  @override
  EditableScene buildEditableScene(AuthoringDocument document) {
    return const _NoopScene();
  }

  @override
  AuthoringDocument applyEdit(
    AuthoringDocument document,
    AuthoringCommand command,
  ) {
    return document;
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

class _NoopDocument extends AuthoringDocument {
  const _NoopDocument();
}

class _NoopScene extends EditableScene {
  const _NoopScene();
}
