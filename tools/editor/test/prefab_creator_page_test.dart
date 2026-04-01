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
  testWidgets('prefab kind switch flow updates source picker', (tester) async {
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
    expect(_dropdownByLabel('Platform Module'), findsNothing);

    await _selectPrefabKind(tester, 'Platform');
    expect(_dropdownByLabel('Platform Module'), findsOneWidget);
    expect(_dropdownByLabel('Atlas Slice'), findsNothing);

    await _selectPrefabKind(tester, 'Obstacle');
    expect(_dropdownByLabel('Atlas Slice'), findsOneWidget);
    expect(_dropdownByLabel('Platform Module'), findsNothing);
  });

  testWidgets('source picker filtering stays kind-specific', (tester) async {
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

    await _selectPrefabKind(tester, 'Platform');
    expect(_dropdownByLabel('Platform Module'), findsOneWidget);
    expect(find.text('ground_module'), findsOneWidget);
    expect(_dropdownByLabel('Atlas Slice'), findsNothing);
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
    expect(find.textContaining('rev=1'), findsOneWidget);

    await tester.tap(find.text('Prefabs').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Add/Update Prefab'));
    await tester.tap(find.text('Add/Update Prefab'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Upserted obstacle prefab "obstacle_box"'),
      findsOneWidget,
    );
    // No-payload-change update keeps revision stable.
    expect(find.textContaining('rev=1'), findsOneWidget);
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

    await _selectPrefabKind(tester, 'Platform');
    await tester.enterText(
      _textFieldByLabel('Prefab ID').first,
      'platform_bridge',
    );
    await tester.ensureVisible(find.text('Add/Update Prefab'));
    await tester.tap(find.text('Add/Update Prefab'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Upserted platform prefab "platform_bridge"'),
      findsOneWidget,
    );
    expect(find.textContaining('rev=1'), findsOneWidget);

    await tester.tap(find.text('Prefabs').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Add/Update Prefab'));
    await tester.tap(find.text('Add/Update Prefab'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Upserted platform prefab "platform_bridge"'),
      findsOneWidget,
    );
    // No-payload-change update keeps revision stable.
    expect(find.textContaining('rev=1'), findsOneWidget);
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
  await tester.tap(find.text('Prefabs'));
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

Future<void> _selectPrefabKind(WidgetTester tester, String kindLabel) async {
  await tester.tap(_dropdownByLabel('Kind'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(kindLabel).last);
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
