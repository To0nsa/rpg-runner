import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:runner_editor/src/app/pages/parallaxEditor/parallax_editor_page.dart';
import 'package:runner_editor/src/domain/authoring_plugin_registry.dart';
import 'package:runner_editor/src/domain/authoring_types.dart';
import 'package:runner_editor/src/parallax/parallax_domain_models.dart';
import 'package:runner_editor/src/parallax/parallax_domain_plugin.dart';
import 'package:runner_editor/src/session/editor_session_controller.dart';
import 'package:runner_editor/src/workspace/editor_workspace.dart';

void main() {
  testWidgets('parallax editor switches levels and edits layers', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1800, 1200));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    final controller = EditorSessionController(
      pluginRegistry: AuthoringPluginRegistry(
        plugins: <AuthoringDomainPlugin>[
          _InMemoryParallaxPlugin(_initialDocument),
        ],
      ),
      initialPluginId: ParallaxDomainPlugin.pluginId,
      initialWorkspacePath: '.',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ParallaxEditorPage(
            controller: controller,
            previewBuilder: ({required workspaceRootPath, required theme}) {
              return const SizedBox.expand();
            },
          ),
        ),
      ),
    );
    await _flush(tester);

    expect(controller.scene, isA<ParallaxScene>());
    expect((controller.scene as ParallaxScene).activeLevelId, 'field');

    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await _flush(tester);
    await tester.tap(find.text('forest').last);
    await _flush(tester);
    expect((controller.scene as ParallaxScene).activeLevelId, 'forest');

    await tester.tap(find.text('Create'));
    await _flush(tester);
    var scene = controller.scene as ParallaxScene;
    expect(scene.activeTheme?.layers.length, 2);

    await tester.enterText(
      _textFieldByLabel('assetPath').first,
      'assets/images/parallax/forest/fg_20.png',
    );
    await tester.enterText(_textFieldByLabel('parallaxFactor').first, '1.1');
    await tester.enterText(_textFieldByLabel('zOrder').first, '20');
    await tester.tap(find.text('Apply Layer'));
    await _flush(tester);

    scene = controller.scene as ParallaxScene;
    expect(
      scene.activeTheme?.layers.any(
        (layer) =>
            layer.assetPath == 'assets/images/parallax/forest/fg_20.png' &&
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
      _textFieldByLabel('groundMaterialAssetPath').first,
      'assets/images/parallax/forest/ground_alt.png',
    );
    await tester.tap(find.text('Apply Ground'));
    await _flush(tester);

    scene = controller.scene as ParallaxScene;
    expect(
      scene.activeTheme?.groundMaterialAssetPath,
      'assets/images/parallax/forest/ground_alt.png',
    );
    expect(controller.pendingChanges.hasChanges, isTrue);
  });
}

const ParallaxDefsDocument _initialDocument = ParallaxDefsDocument(
  workspaceRootPath: '.',
  themes: <ParallaxThemeDef>[
    ParallaxThemeDef(
      themeId: 'field',
      revision: 1,
      groundMaterialAssetPath: 'assets/images/parallax/field/ground.png',
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
      themeId: 'forest',
      revision: 1,
      groundMaterialAssetPath: 'assets/images/parallax/forest/ground.png',
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
  themeIdByLevelId: <String, String>{'field': 'field', 'forest': 'forest'},
);

class _InMemoryParallaxPlugin implements AuthoringDomainPlugin {
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
          .map((theme) => theme.themeId)
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
