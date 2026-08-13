import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:runner_editor/src/app/pages/levelCreator/level_creator_page.dart';
import 'package:runner_editor/src/domain/authoring_plugin_registry.dart';
import 'package:runner_editor/src/domain/authoring_types.dart';
import 'package:runner_editor/src/levels/level_domain_models.dart';
import 'package:runner_editor/src/levels/level_domain_plugin.dart';
import 'package:runner_editor/src/parallax/parallax_domain_models.dart';
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
    await tester.tap(find.text('Create Level'));
    await _flush(tester);

    var scene = controller.scene as LevelScene;
    expect(scene.activeLevelId, 'cave');
    expect(scene.levels.any((level) => level.levelId == 'cave'), isTrue);

    await tester.enterText(_textFieldByLabel('displayName'), 'Crystal Cave');
    await _selectDropdownByLabel(
      tester,
      label: 'Visual theme (Parallax)',
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

  testWidgets(
    'new-theme suggestion detaches after manual editing and undoes atomically',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1800, 1200));
      addTearDown(() async => tester.binding.setSurfaceSize(null));
      final controller = _buildController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: LevelCreatorPage(controller: controller)),
        ),
      );
      await _flush(tester);

      expect(find.text('Create new theme'), findsOneWidget);
      expect(_textFieldByLabel('New visual theme ID'), findsOneWidget);
      await tester.enterText(_textFieldByLabel('New levelId'), 'crystal');
      await _flush(tester);
      expect(
        tester
            .widget<TextField>(_textFieldByLabel('New visual theme ID'))
            .controller
            ?.text,
        'crystal',
      );
      await tester.enterText(
        _textFieldByLabel('New visual theme ID'),
        'violet_depths',
      );
      await tester.enterText(
        _textFieldByLabel('New levelId'),
        'crystal_depths',
      );
      await _flush(tester);
      expect(
        tester
            .widget<TextField>(_textFieldByLabel('New visual theme ID'))
            .controller
            ?.text,
        'violet_depths',
      );

      await tester.tap(find.text('Create Level'));
      await _flush(tester);
      var document = controller.document as LevelDefsDocument;
      expect(
        findLevelDefById(document.levels, 'crystal_depths')?.visualThemeId,
        'violet_depths',
      );
      expect(
        findParallaxThemeById(
          document.parallaxDocument!.themes,
          'violet_depths',
        ),
        isNotNull,
      );
      expect(controller.pendingChanges.fileDiffs, hasLength(2));

      controller.undo();
      await _flush(tester);
      document = controller.document as LevelDefsDocument;
      expect(findLevelDefById(document.levels, 'crystal_depths'), isNull);
      expect(
        findParallaxThemeById(
          document.parallaxDocument!.themes,
          'violet_depths',
        ),
        isNull,
      );
      controller.redo();
      await _flush(tester);
      document = controller.document as LevelDefsDocument;
      expect(findLevelDefById(document.levels, 'crystal_depths'), isNotNull);
      expect(
        findParallaxThemeById(
          document.parallaxDocument!.themes,
          'violet_depths',
        ),
        isNotNull,
      );
    },
  );

  testWidgets(
    'reuse mode requires an explicit authored theme and plans one file',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1800, 1200));
      addTearDown(() async => tester.binding.setSurfaceSize(null));
      final controller = _buildController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: LevelCreatorPage(controller: controller)),
        ),
      );
      await _flush(tester);

      await tester.tap(find.text('Use existing theme'));
      await _flush(tester);
      expect(
        find.text('Choose an existing visual theme explicitly.'),
        findsOneWidget,
      );
      final createButton = find.byKey(
        const ValueKey<String>('create_level_button'),
      );
      expect(tester.widget<FilledButton>(createButton).onPressed, isNull);

      await tester.tap(
        find.byKey(const ValueKey<String>('new_level_existing_theme')),
      );
      await _flush(tester);
      await tester.tap(find.text('field').last);
      await tester.enterText(_textFieldByLabel('New levelId'), 'shared_field');
      await _flush(tester);
      await tester.tap(createButton);
      await _flush(tester);

      final document = controller.document as LevelDefsDocument;
      expect(
        findLevelDefById(document.levels, 'shared_field')?.visualThemeId,
        'field',
      );
      expect(controller.pendingChanges.fileDiffs, hasLength(1));
      expect(
        controller.pendingChanges.fileDiffs.single.relativePath,
        levelDefsSourcePath,
      );
    },
  );

  testWidgets(
    'existing level can create and assign a theme from the inspector',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1800, 1200));
      addTearDown(() async => tester.binding.setSurfaceSize(null));
      final controller = _buildController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: LevelCreatorPage(controller: controller)),
        ),
      );
      await _flush(tester);

      final action = find.byKey(
        const ValueKey<String>('create_assign_visual_theme_button'),
      );
      await tester.ensureVisible(action);
      await tester.tap(action);
      await _flush(tester);
      await tester.enterText(
        find.byKey(const ValueKey<String>('create_assign_theme_id_field')),
        'forest_night',
      );
      await _flush(tester);
      await tester.tap(find.text('Create and assign').last);
      await _flush(tester);

      final document = controller.document as LevelDefsDocument;
      expect(
        document.levels
            .firstWhere((level) => level.levelId == 'forest')
            .revision,
        2,
      );
      expect(
        document.levels
            .firstWhere((level) => level.levelId == 'forest')
            .visualThemeId,
        'forest_night',
      );
      expect(
        findParallaxThemeById(
          document.parallaxDocument!.themes,
          'forest_night',
        ),
        isNotNull,
      );
    },
  );

  testWidgets(
    'successful apply exposes generation guidance and typed handoff',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1800, 1200));
      addTearDown(() async => tester.binding.setSurfaceSize(null));
      final controller = _buildController(applyExports: true);
      ParallaxLevelTarget? openedTarget;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LevelCreatorPage(
              controller: controller,
              onOpenInParallax: (target) => openedTarget = target,
            ),
          ),
        ),
      );
      await _flush(tester);

      await tester.enterText(_textFieldByLabel('New levelId'), 'crystal');
      await tester.tap(find.text('Create Level'));
      await _flush(tester);
      await tester.tap(
        find.byKey(const ValueKey<String>('apply_level_files_button')),
      );
      await _flush(tester);
      expect(find.textContaining(parallaxDefsSourcePath), findsOneWidget);
      await tester.tap(find.text('Apply').last);
      await _flush(tester);

      expect(find.text('Authoring sources saved'), findsOneWidget);
      expect(
        find.textContaining('dart run tool/generate_chunk_runtime_data.dart'),
        findsOneWidget,
      );
      final openButton = find.byKey(
        const ValueKey<String>('open_level_in_parallax_button'),
      );
      await tester.drag(
        find.byKey(const ValueKey<String>('level_inspector_scroll')),
        const Offset(0, -300),
      );
      await _flush(tester);
      await tester.tap(openButton);
      await _flush(tester);
      expect(openedTarget?.levelId, 'crystal');
      expect(openedTarget?.parallaxThemeId, 'crystal');
    },
  );

  testWidgets('missing reference is a repair state that can create its theme', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1800, 1200));
    addTearDown(() async => tester.binding.setSurfaceSize(null));
    final missingLevels = _initialDocument.levels
        .map(
          (level) => level.levelId == 'forest'
              ? level.copyWith(visualThemeId: 'missing_forest')
              : level,
        )
        .toList(growable: false);
    final missingDocument = _initialDocument.copyWith(
      levels: missingLevels,
      baselineLevels: missingLevels,
      parallaxDocument: _initialDocument.parallaxDocument!.copyWith(
        parallaxThemeIdByLevelId: const <String, String>{
          'field': 'field',
          'forest': 'missing_forest',
        },
      ),
    );
    final controller = EditorSessionController(
      pluginRegistry: AuthoringPluginRegistry(
        plugins: <AuthoringDomainPlugin>[_InMemoryLevelPlugin(missingDocument)],
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

    expect(
      find.byKey(const ValueKey<String>('missing_visual_theme_repair')),
      findsOneWidget,
    );
    final repair = find.byKey(
      const ValueKey<String>('create_missing_visual_theme_button'),
    );
    await tester.ensureVisible(repair);
    await tester.tap(repair);
    await _flush(tester);
    expect(
      find.byKey(const ValueKey<String>('create_assign_theme_id_field')),
      findsOneWidget,
    );
    await tester.tap(find.text('Create and assign').last);
    await _flush(tester);

    final document = controller.document as LevelDefsDocument;
    expect(
      findParallaxThemeById(
        document.parallaxDocument!.themes,
        'missing_forest',
      ),
      isNotNull,
    );
    expect(
      document.levels.firstWhere((level) => level.levelId == 'forest').revision,
      2,
    );
    expect(
      controller.issues.where(
        (issue) => issue.code == 'missing_parallax_theme',
      ),
      isEmpty,
    );
  });

  testWidgets('narrow layout keeps the full workflow scrollable', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(760, 900));
    addTearDown(() async => tester.binding.setSurfaceSize(null));
    final controller = _buildController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: LevelCreatorPage(controller: controller)),
      ),
    );
    await _flush(tester);

    expect(
      find.byKey(const ValueKey<String>('level_creator_narrow_layout')),
      findsOneWidget,
    );
    expect(find.text('Create new theme'), findsOneWidget);
    await tester.drag(
      find.byKey(const ValueKey<String>('level_creator_narrow_layout')),
      const Offset(0, -650),
    );
    await _flush(tester);
    expect(find.text('Inspector'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

EditorSessionController _buildController({bool applyExports = false}) {
  return EditorSessionController(
    pluginRegistry: AuthoringPluginRegistry(
      plugins: <AuthoringDomainPlugin>[
        _InMemoryLevelPlugin(_initialDocument, applyExports: applyExports),
      ],
    ),
    initialPluginId: LevelDomainPlugin.pluginId,
    initialWorkspacePath: '.',
  );
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
  parallaxDocument: ParallaxDefsDocument(
    workspaceRootPath: '.',
    themes: _initialThemes,
    baseline: ParallaxSourceBaseline(
      sourcePath: parallaxDefsSourcePath,
      fingerprint: 'test',
      sourceContent: '',
    ),
    baselineThemes: _initialThemes,
    availableLevelIds: <String>['field', 'forest'],
    activeLevelId: 'forest',
    levelOptionSource: 'test',
    parallaxThemeIdByLevelId: <String, String>{
      'field': 'field',
      'forest': 'forest',
    },
  ),
);

const List<ParallaxThemeDef> _initialThemes = <ParallaxThemeDef>[
  ParallaxThemeDef(
    parallaxThemeId: 'field',
    revision: 1,
    layers: <ParallaxLayerDef>[],
  ),
  ParallaxThemeDef(
    parallaxThemeId: 'forest',
    revision: 1,
    layers: <ParallaxLayerDef>[],
  ),
];

class _InMemoryLevelPlugin implements AuthoringDomainPlugin {
  _InMemoryLevelPlugin(
    LevelDefsDocument initialDocument, {
    this.applyExports = false,
  }) : _persistedDocument = initialDocument;

  LevelDefsDocument _persistedDocument;
  final bool applyExports;
  final LevelDomainPlugin _delegate = LevelDomainPlugin();

  @override
  String get id => LevelDomainPlugin.pluginId;

  @override
  Future<AuthoringDocument> loadFromRepo(EditorWorkspace workspace) async {
    return _persistedDocument.copyWith(workspaceRootPath: workspace.rootPath);
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
    final levelsChanged = !_sameLevels(
      levelDocument.levels,
      _persistedDocument.levels,
    );
    final themesChanged = !_sameThemes(
      levelDocument.parallaxDocument?.themes ?? const <ParallaxThemeDef>[],
      _persistedDocument.parallaxDocument?.themes ?? const <ParallaxThemeDef>[],
    );
    if (!levelsChanged && !themesChanged) {
      return PendingChanges.empty;
    }
    return PendingChanges(
      changedItemIds: <String>[
        if (levelsChanged)
          ...levelDocument.levels
              .map((level) => 'level:${level.levelId}')
              .where(
                (itemId) =>
                    !_persistedDocument.levels.any(
                      (baseline) => 'level:${baseline.levelId}' == itemId,
                    ) ||
                    !_sameLevel(
                      levelDocument.levels.firstWhere(
                        (level) => 'level:${level.levelId}' == itemId,
                      ),
                      _persistedDocument.levels.firstWhere(
                        (baseline) => 'level:${baseline.levelId}' == itemId,
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
              ),
        if (themesChanged)
          ...levelDocument.parallaxDocument!.themes
              .map((theme) => 'parallaxTheme:${theme.parallaxThemeId}')
              .where(
                (itemId) => !_persistedDocument.parallaxDocument!.themes.any(
                  (theme) => 'parallaxTheme:${theme.parallaxThemeId}' == itemId,
                ),
              ),
      ],
      fileDiffs: <PendingFileDiff>[
        if (levelsChanged)
          const PendingFileDiff(
            relativePath: levelDefsSourcePath,
            editCount: 1,
            unifiedDiff: '@@ level',
          ),
        if (themesChanged)
          const PendingFileDiff(
            relativePath: parallaxDefsSourcePath,
            editCount: 1,
            unifiedDiff: '@@ parallax',
          ),
      ],
    );
  }

  @override
  Future<ExportResult> exportToRepo(
    EditorWorkspace workspace, {
    required AuthoringDocument document,
  }) async {
    if (!applyExports) return ExportResult(applied: false);
    _persistedDocument = document as LevelDefsDocument;
    return LevelThemeExportResult(applied: true);
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

bool _sameThemes(List<ParallaxThemeDef> a, List<ParallaxThemeDef> b) {
  if (a.length != b.length) return false;
  for (var index = 0; index < a.length; index += 1) {
    if (!parallaxThemeEquals(a[index], b[index])) return false;
  }
  return true;
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
