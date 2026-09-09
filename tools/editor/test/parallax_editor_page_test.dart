import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:runner_editor/src/app/pages/parallaxEditor/parallax_editor_page.dart';
import 'package:runner_editor/src/app/pages/shared/editor_page_local_draft_state.dart';
import 'test_support/level_parallax_fixture.dart';
import 'package:runner_editor/src/domain/authoring_plugin_registry.dart';
import 'package:runner_editor/src/domain/authoring_types.dart';
import 'package:runner_editor/src/domain/authoring_session_semantics.dart';
import 'package:runner_editor/src/parallax/parallax_domain_models.dart';
import 'package:runner_editor/src/parallax/parallax_domain_plugin.dart';
import 'package:runner_editor/src/session/editor_session_controller.dart';
import 'package:runner_editor/src/workspace/editor_workspace.dart';

void main() {
  testWidgets('Save includes focused Parallax input and invalid text blocks history and writes', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = (await tester.runAsync(() => createLevelParallaxTestSession(ParallaxDomainPlugin())))!;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      // Complete already-started file reads in both the real I/O zone and the
      // widget fake-async zone before the fixture removes its source images.
      for (var frame = 0; frame < 6; frame++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
        await tester.pump();
      }
    });
    final pageKey = GlobalKey();
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: ParallaxEditorPage(
      key: pageKey, controller: controller,
      previewBuilder: ({required workspaceRootPath, required theme}) => const SizedBox(),
    ))));
    await tester.pumpAndSettle();
    final opacity = _textFieldByLabel('opacity');
    await tester.enterText(opacity, '0.6');
    final save = pageKey.currentState! as EditorPageSaveHandler;
    expect(save.canSaveEditorPage, isTrue);
    expect(await tester.runAsync(save.saveEditorPage), EditorPageSaveResult.saved);
    await tester.pumpAndSettle();
    expect((controller.document! as ParallaxDefsDocument).themes.first.layers.single.opacity, 0.6);
    final savedWrites = controller.sourceWriteCount;
    await tester.enterText(opacity, '0.8');
    expect(await tester.runAsync(save.saveEditorPage), EditorPageSaveResult.saved);
    await tester.pumpAndSettle();
    expect((controller.document! as ParallaxDefsDocument).themes.first.layers.single.opacity, 0.8);
    expect(controller.sourceWriteCount, savedWrites + 1);
    final accepted = controller.document;
    await tester.enterText(opacity, 'not a number');
    expect(await tester.runAsync(save.saveEditorPage), EditorPageSaveResult.blocked);
    expect(controller.document, same(accepted));
    final shortcuts = pageKey.currentState! as EditorPageSessionShortcutHandler;
    expect(shortcuts.handleUndoSessionShortcut(), isTrue);
    await tester.pump();
    expect(controller.document, same(accepted));
    expect(tester.widget<TextField>(opacity).controller!.text, 'not a number');
    expect(controller.sourceWriteCount, savedWrites + 1);
  });

  testWidgets('parallax editor switches levels and edits layers', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1800, 1200));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });
    final workspaceRootPath = p.normalize(
      p.absolute(Directory.current.path, '..', '..'),
    );
    final outsideDirectory = Directory.systemTemp.createTempSync(
      'parallax_asset_picker_test_',
    );
    final outsideAsset = File(p.join(outsideDirectory.path, 'outside.png'))
      ..writeAsBytesSync(const <int>[0]);
    addTearDown(() {
      outsideDirectory.deleteSync(recursive: true);
    });
    final selectedAssetPath = p.join(
      workspaceRootPath,
      'assets',
      'images',
      'parallax',
      'forest',
      'layer_01.png',
    );
    final pickerSelections = <String>[outsideAsset.path, selectedAssetPath];
    final pickerInitialDirectories = <String>[];

    final controller = EditorSessionController(
      pluginRegistry: AuthoringPluginRegistry(
        plugins: <AuthoringDomainPlugin>[
          _InMemoryParallaxPlugin(_initialDocument),
        ],
      ),
      initialPluginId: ParallaxDomainPlugin.pluginId,
      initialWorkspacePath: workspaceRootPath,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ParallaxEditorPage(
            controller: controller,
            assetFilePicker: ({required initialDirectory}) async {
              pickerInitialDirectories.add(initialDirectory);
              return pickerSelections.removeAt(0);
            },
          ),
        ),
      ),
    );
    await _flush(tester);

    expect(controller.scene, isA<ParallaxScene>());
    expect((controller.scene as ParallaxScene).activeLevelId, 'field');
    expect(
      find.byKey(
        const ValueKey<String>('parallax_layer_asset_preview_field_bg_10'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await _flush(tester);
    await tester.tap(find.text('forest').last);
    await _flush(tester);
    expect((controller.scene as ParallaxScene).activeLevelId, 'forest');
    expect(
      find.byKey(
        const ValueKey<String>('parallax_layer_asset_preview_forest_bg_10'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Create'));
    await _flush(tester);
    var scene = controller.scene as ParallaxScene;
    expect(scene.activeTheme?.layers.length, 2);
    for (final layer in scene.activeTheme!.layers) {
      expect(
        find.byKey(
          ValueKey<String>('parallax_layer_asset_preview_${layer.layerKey}'),
        ),
        findsOneWidget,
      );
    }

    final assetPathField = _textFieldByLabel('assetPath').first;
    final assetPickerButton = find.byKey(
      const ValueKey<String>('parallax_asset_path_picker'),
    );
    await tester.tap(assetPickerButton);
    await _flush(tester);
    expect(
      find.text('Choose an image inside the current workspace.'),
      findsOneWidget,
    );
    expect(tester.widget<TextField>(assetPathField).controller?.text, isEmpty);

    await tester.tap(assetPickerButton);
    await _flush(tester);
    expect(
      tester.widget<TextField>(assetPathField).controller?.text,
      'assets/images/parallax/forest/layer_01.png',
    );
    expect(
      pickerInitialDirectories,
      everyElement(p.join(workspaceRootPath, 'assets', 'images', 'parallax')),
    );
    await tester.enterText(_textFieldByLabel('parallaxFactor').first, '1.1');
    await tester.enterText(_textFieldByLabel('zOrder').first, '20');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await _flush(tester);

    scene = controller.scene as ParallaxScene;
    expect(
      scene.activeTheme?.layers.any(
        (layer) =>
            layer.assetPath == 'assets/images/parallax/forest/layer_01.png' &&
            layer.parallaxFactor == 1.1,
      ),
      isTrue,
    );

    await tester.tap(find.text('Duplicate'));
    await _flush(tester);
    scene = controller.scene as ParallaxScene;
    expect(scene.activeTheme?.layers.length, 3);

    await tester.tap(find.text('Delete'));
    await _flush(tester);
    scene = controller.scene as ParallaxScene;
    expect(scene.activeTheme?.layers.length, 2);

    await tester.enterText(
      find.byKey(const ValueKey<String>('parallax_preview_y_offset')),
      '64',
    );
    await _flush(tester);
    await tester.tap(find.text('Set Y Offset on All Layers'));
    await _flush(tester);

    scene = controller.scene as ParallaxScene;
    expect(scene.activeTheme?.layers.map((layer) => layer.yOffset), <double>[
      64,
      64,
    ]);
    expect(
      tester
          .widget<TextField>(_textFieldByLabel('yOffset').first)
          .controller
          ?.text,
      '64',
    );

    expect(controller.pendingChanges.hasChanges, isTrue);
  });
}

const ParallaxDefsDocument _initialDocument = ParallaxDefsDocument(
  workspaceRootPath: '.',
  themes: <ParallaxThemeDef>[
    ParallaxThemeDef(
      parallaxThemeId: 'field',
      revision: 1,
      layers: <ParallaxLayerDef>[
        ParallaxLayerDef(
          layerKey: 'field_bg_10',
          assetPath: 'assets/images/parallax/field/bg_10.png',
          group: parallaxGroupBackground,
          parallaxFactor: 0.2,
          zOrder: 10,
          opacity: 1.0,
          yOffset: 0.0,
        ),
      ],
    ),
    ParallaxThemeDef(
      parallaxThemeId: 'forest',
      revision: 1,
      layers: <ParallaxLayerDef>[
        ParallaxLayerDef(
          layerKey: 'forest_bg_10',
          assetPath: 'assets/images/parallax/forest/bg_10.png',
          group: parallaxGroupBackground,
          parallaxFactor: 0.3,
          zOrder: 10,
          opacity: 1.0,
          yOffset: 0.0,
        ),
      ],
    ),
  ],
  baseline: null,
  availableLevelIds: <String>['field', 'forest'],
  activeLevelId: 'field',
  levelOptionSource: 'test',
  parallaxThemeIdByLevelId: <String, String>{
    'field': 'field',
    'forest': 'forest',
  },
);

class _InMemoryParallaxPlugin
    implements AuthoringDomainPlugin, AuthoringSessionSemantics {
  @override
  bool isPresentationCommand(AuthoringCommand command) =>
      command.kind == 'set_active_level';
  @override
  AuthoringDocument retainPresentation({
    required AuthoringDocument current,
    required AuthoringDocument restored,
  }) => restored;
  _InMemoryParallaxPlugin(this._initialDocument);

  final ParallaxDefsDocument _initialDocument;
  final ParallaxDomainPlugin _delegate = ParallaxDomainPlugin();

  @override
  String get id => ParallaxDomainPlugin.pluginId;

  @override
  Future<AuthoringDocument> loadFromRepo(EditorWorkspace workspace) async {
    return _initialDocument.copyWith(workspaceRootPath: workspace.rootPath);
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
  PendingChanges describePendingChanges(
    EditorWorkspace workspace, {
    required AuthoringDocument document,
  }) {
    final parallaxDocument = document as ParallaxDefsDocument;
    if (parallaxDocument.themes.length == _initialDocument.themes.length &&
        parallaxDocument.themes
            .map((theme) => theme.revision)
            .every((revision) => revision == 1)) {
      return PendingChanges.empty;
    }
    return PendingChanges(
      changedItemIds: parallaxDocument.themes
          .map((theme) => theme.parallaxThemeId)
          .toList(growable: false),
      fileDiffs: const <PendingFileDiff>[
        PendingFileDiff(
          relativePath: 'assets/authoring/level/parallax_defs.json',
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
}

Finder _textFieldByLabel(String label) {
  return find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label,
  );
}

Future<void> _flush(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 150));
}
