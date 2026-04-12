import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:runner_editor/src/app/pages/levelCreator/level_creator_page.dart';
import 'package:runner_editor/src/domain/authoring_plugin_registry.dart';
import 'package:runner_editor/src/domain/authoring_types.dart';
import 'package:runner_editor/src/levels/level_domain_models.dart';
import 'package:runner_editor/src/levels/level_domain_plugin.dart';
import 'package:runner_editor/src/session/editor_session_controller.dart';
import 'package:runner_editor/src/workspace/editor_workspace.dart';

void main() {
  testWidgets('level creator creates edits duplicates and updates status', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1800, 1200));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    final controller = EditorSessionController(
      pluginRegistry: AuthoringPluginRegistry(
        plugins: <AuthoringDomainPlugin>[
          _InMemoryLevelPlugin(_initialDocument),
        ],
      ),
      initialPluginId: LevelDomainPlugin.pluginId,
      initialWorkspacePath: '.',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: LevelCreatorPage(controller: controller)),
      ),
    );
    await _flush(tester);

    expect(controller.scene, isA<LevelScene>());
    expect((controller.scene as LevelScene).activeLevelId, 'forest');

    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await _flush(tester);
    await tester.tap(find.text('field').last);
    await _flush(tester);
    expect((controller.scene as LevelScene).activeLevelId, 'field');

    for (final label in const <String>['cameraCenterY', 'groundTopY']) {
      final field = tester.widget<TextField>(_textFieldByLabel(label));
      expect(field.readOnly, isTrue);
    }
    for (final label in const <String>[
      'earlyPatternChunks',
      'easyPatternChunks',
      'normalPatternChunks',
      'noEnemyChunks',
    ]) {
      final field = tester.widget<TextField>(_textFieldByLabel(label));
      expect(field.readOnly, isFalse);
    }

    await tester.enterText(_textFieldByLabel('New levelId'), 'cave');
    await tester.tap(find.text('Create'));
    await _flush(tester);

    var scene = controller.scene as LevelScene;
    expect(scene.activeLevelId, 'cave');
    expect(scene.levels.any((level) => level.levelId == 'cave'), isTrue);

    await tester.enterText(_textFieldByLabel('displayName'), 'Crystal Cave');
    await _selectDropdownByLabel(
      tester,
      label: 'visualThemeId (parallax + ground)',
      value: 'forest',
    );
    await tester.enterText(_textFieldByLabel('enumOrdinal'), '30');
    await tester.enterText(
      find.byKey(const ValueKey<String>('new_chunk_theme_group_id')),
      'forest',
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('add_chunk_theme_group_button')),
    );
    await _flush(tester);
    await tester.tap(find.text('Add Segment'));
    await _flush(tester);
    await tester.ensureVisible(_dropdownFieldByLabel('groupId'));
    await _flush(tester);
    await _selectDropdownByLabel(tester, label: 'groupId', value: 'forest');
    await tester.enterText(_textFieldByLabel('segmentId'), 'forest_run');
    await tester.drag(
      find.byKey(const ValueKey<String>('level_inspector_scroll')),
      const Offset(0, -600),
    );
    await _flush(tester);
    final applyLevel = find.byKey(const ValueKey<String>('apply_level_button'));
    await tester.tap(applyLevel);
    await _flush(tester);

    scene = controller.scene as LevelScene;
    final cave = scene.levels.firstWhere((level) => level.levelId == 'cave');
    expect(cave.displayName, 'Crystal Cave');
    expect(cave.visualThemeId, 'forest');
    expect(cave.cameraCenterY, 135);
    expect(cave.assembly?.segments.single.segmentId, 'forest_run');
    expect(cave.revision, 2);

    await tester.tap(find.text('Duplicate'));
    await _flush(tester);
    scene = controller.scene as LevelScene;
    expect(scene.levels.any((level) => level.levelId == 'cave_copy'), isTrue);

    await tester.tap(find.text('Deprecate'));
    await _flush(tester);
    scene = controller.scene as LevelScene;
    expect(scene.activeLevel?.status, levelStatusDeprecated);

    await tester.tap(find.text('Reactivate'));
    await _flush(tester);
    scene = controller.scene as LevelScene;
    expect(scene.activeLevel?.status, levelStatusActive);
    expect(controller.pendingChanges.hasChanges, isTrue);
  });

  testWidgets('level creator seeds new segments with the default group', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1800, 1200));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    final controller = EditorSessionController(
      pluginRegistry: AuthoringPluginRegistry(
        plugins: <AuthoringDomainPlugin>[
          _InMemoryLevelPlugin(_initialDocument),
        ],
      ),
      initialPluginId: LevelDomainPlugin.pluginId,
      initialWorkspacePath: '.',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: LevelCreatorPage(controller: controller)),
      ),
    );
    await _flush(tester);

    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await _flush(tester);
    await tester.tap(find.text('field').last);
    await _flush(tester);

    expect(
      find.text(
        'When disabled, runtime holds on the final authored segment after the ordered run list completes.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Add Segment'));
    await _flush(tester);

    expect(_dropdownFieldByLabel('groupId'), findsOneWidget);
    expect(_textFieldByLabel('segmentId'), findsOneWidget);
    final groupField = tester.widget<DropdownButtonFormField<String>>(
      _dropdownFieldByLabel('groupId'),
    );
    final segmentField = tester.widget<TextField>(
      _textFieldByLabel('segmentId'),
    );
    expect(groupField.initialValue, defaultAssemblyGroupId);
    expect(segmentField.controller?.text, defaultAssemblyGroupId);
  });
}

const LevelDefsDocument _initialDocument = LevelDefsDocument(
  workspaceRootPath: '.',
  levels: <LevelDef>[
    LevelDef(
      levelId: 'field',
      revision: 1,
      displayName: 'Field',
      visualThemeId: 'field',
      chunkThemeGroups: <String>['default', 'none'],
      cameraCenterY: 135,
      groundTopY: 224,
      earlyPatternChunks: 3,
      easyPatternChunks: 0,
      normalPatternChunks: 0,
      noEnemyChunks: 3,
      enumOrdinal: 20,
      status: levelStatusActive,
    ),
    LevelDef(
      levelId: 'forest',
      revision: 1,
      displayName: 'Forest',
      visualThemeId: 'forest',
      chunkThemeGroups: <String>['default', 'forest', 'none'],
      cameraCenterY: 135,
      groundTopY: 224,
      earlyPatternChunks: 3,
      easyPatternChunks: 0,
      normalPatternChunks: 0,
      noEnemyChunks: 3,
      enumOrdinal: 10,
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
      chunkThemeGroups: <String>['default', 'none'],
      cameraCenterY: 135,
      groundTopY: 224,
      earlyPatternChunks: 3,
      easyPatternChunks: 0,
      normalPatternChunks: 0,
      noEnemyChunks: 3,
      enumOrdinal: 20,
      status: levelStatusActive,
    ),
    LevelDef(
      levelId: 'forest',
      revision: 1,
      displayName: 'Forest',
      visualThemeId: 'forest',
      chunkThemeGroups: <String>['default', 'forest', 'none'],
      cameraCenterY: 135,
      groundTopY: 224,
      earlyPatternChunks: 3,
      easyPatternChunks: 0,
      normalPatternChunks: 0,
      noEnemyChunks: 3,
      enumOrdinal: 10,
      status: levelStatusActive,
    ),
  ],
  activeLevelId: 'forest',
  availableParallaxVisualThemeIds: <String>['field', 'forest'],
  parallaxThemeSourceAvailable: true,
  authoredChunkCountsByLevelId: <String, int>{'field': 1, 'forest': 1},
  authoredChunkAssemblyGroupCountsByLevelId: <String, Map<String, int>>{
    'field': <String, int>{'default': 1, 'none': 1},
    'forest': <String, int>{'forest': 1, 'default': 1, 'none': 1},
  },
  chunkCountSourceAvailable: true,
);

class _InMemoryLevelPlugin implements AuthoringDomainPlugin {
  _InMemoryLevelPlugin(this._initialDocument);

  final LevelDefsDocument _initialDocument;
  final LevelDomainPlugin _delegate = LevelDomainPlugin();

  @override
  String get id => LevelDomainPlugin.pluginId;

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
    final levelDocument = document as LevelDefsDocument;
    if (_sameLevels(levelDocument.levels, _initialDocument.levels)) {
      return PendingChanges.empty;
    }
    return PendingChanges(
      changedItemIds: levelDocument.levels
          .map((level) => level.levelId)
          .where(
            (levelId) =>
                !_initialDocument.levels.any(
                  (baseline) => baseline.levelId == levelId,
                ) ||
                !_sameLevel(
                  levelDocument.levels.firstWhere(
                    (level) => level.levelId == levelId,
                  ),
                  _initialDocument.levels.firstWhere(
                    (baseline) => baseline.levelId == levelId,
                    orElse: () => const LevelDef(
                      levelId: '',
                      revision: 0,
                      displayName: '',
                      visualThemeId: '',
                      cameraCenterY: 0,
                      groundTopY: 0,
                      earlyPatternChunks: 0,
                      easyPatternChunks: 0,
                      normalPatternChunks: 0,
                      noEnemyChunks: 0,
                      enumOrdinal: 0,
                      status: '',
                    ),
                  ),
                ),
          )
          .toList(growable: false),
      fileDiffs: const <PendingFileDiff>[
        PendingFileDiff(
          relativePath: levelDefsSourcePath,
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

bool _sameLevels(List<LevelDef> a, List<LevelDef> b) {
  if (a.length != b.length) {
    return false;
  }
  for (var i = 0; i < a.length; i += 1) {
    if (!_sameLevel(a[i], b[i])) {
      return false;
    }
  }
  return true;
}

bool _sameLevel(LevelDef a, LevelDef b) {
  return a.levelId == b.levelId &&
      a.revision == b.revision &&
      a.displayName == b.displayName &&
      a.visualThemeId == b.visualThemeId &&
      _stringListEquals(a.chunkThemeGroups, b.chunkThemeGroups) &&
      a.cameraCenterY == b.cameraCenterY &&
      a.groundTopY == b.groundTopY &&
      a.earlyPatternChunks == b.earlyPatternChunks &&
      a.easyPatternChunks == b.easyPatternChunks &&
      a.normalPatternChunks == b.normalPatternChunks &&
      a.noEnemyChunks == b.noEnemyChunks &&
      a.enumOrdinal == b.enumOrdinal &&
      a.status == b.status &&
      levelAssemblyEquals(a.assembly, b.assembly);
}

bool _stringListEquals(List<String> a, List<String> b) {
  if (a.length != b.length) {
    return false;
  }
  for (var i = 0; i < a.length; i += 1) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}

Finder _textFieldByLabel(String label) {
  return find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label,
  );
}

Finder _dropdownFieldByLabel(String label) {
  return find.byWidgetPredicate(
    (widget) =>
        widget is DropdownButtonFormField<String> &&
        widget.decoration.labelText == label,
  );
}

Future<void> _selectDropdownByLabel(
  WidgetTester tester, {
  required String label,
  required String value,
}) async {
  await tester.tap(_dropdownFieldByLabel(label));
  await _flush(tester);
  await tester.tap(find.text(value).last);
  await _flush(tester);
}

Future<void> _flush(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 150));
}
