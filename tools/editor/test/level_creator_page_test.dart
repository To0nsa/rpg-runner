import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:runner_editor/src/app/pages/levelCreator/level_creator_page.dart';
import 'package:runner_editor/src/app/pages/levelCreator/level_creator_navigation.dart';
import 'package:runner_editor/src/app/pages/levelCreator/level_content_projection.dart';
import 'package:runner_editor/src/app/pages/levelCreator/level_view_preferences.dart';
import 'package:runner_editor/src/chunks/chunk_v2_models.dart';
import 'package:runner_editor/src/chunks/chunk_v2_file_data.dart';
import 'package:runner_editor/src/prefabs/models/models.dart';
import 'package:runner_editor/src/app/pages/shared/editor_page_local_draft_state.dart';
import 'package:runner_editor/src/domain/authoring_plugin_registry.dart';
import 'package:runner_editor/src/domain/authoring_types.dart';
import 'package:runner_editor/src/domain/authoring_session_semantics.dart';
import 'package:runner_editor/src/levels/level_domain_models.dart';
import 'package:runner_editor/src/levels/level_domain_plugin.dart';
import 'package:runner_editor/src/parallax/parallax_domain_models.dart';
import 'package:runner_editor/src/session/editor_session_controller.dart';
import 'package:runner_editor/src/workspace/editor_workspace.dart';

void main() {
  testWidgets(
    'section Advanced expands while a range edit commits on focus loss',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final document = _initialDocument.copyWith(
        levels: [
          for (final level in _initialDocument.levels)
            if (level.levelId == 'forest')
              level.copyWith(
                chunkThemeGroups: const ['default', 'rocky_grove'],
                assembly: const LevelAssemblyDef(
                  segments: [
                    LevelAssemblySegmentDef(
                      segmentId: 'rocky_grove',
                      groupId: 'rocky_grove',
                      minChunkCount: 1,
                      maxChunkCount: 1,
                      requireDistinctChunks: true,
                    ),
                    LevelAssemblySegmentDef(
                      segmentId: 'default',
                      groupId: 'default',
                      minChunkCount: 1,
                      maxChunkCount: 1,
                      requireDistinctChunks: false,
                    ),
                  ],
                ),
              )
            else
              level,
        ],
      );
      await _mountLevelPage(tester, plugin: _InMemoryLevelPlugin(document));
      await _showTab(tester, 'Flow');
      await tester.tap(
        find.byKey(const ValueKey<String>('level_section_rocky_grove')),
      );
      await _flush(tester);

      await tester.enterText(_textFieldByLabel('minChunkCount'), '3');
      await tester.enterText(_textFieldByLabel('maxChunkCount'), '3');
      await tester.tap(find.text('Advanced').last);
      await tester.pumpAndSettle();

      expect(_textFieldByLabel('segmentId'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'section diagnostic opens its exact field and reveals compact Settings',
    (tester) async {
      final document = _initialDocument.copyWith(
        levels: [
          for (final level in _initialDocument.levels)
            if (level.levelId == 'forest')
              level.copyWith(
                assembly: const LevelAssemblyDef(
                  segments: [
                    LevelAssemblySegmentDef(
                      segmentId: 'first',
                      groupId: 'default',
                      minChunkCount: 1,
                      maxChunkCount: 1,
                      requireDistinctChunks: false,
                    ),
                    LevelAssemblySegmentDef(
                      segmentId: 'second',
                      groupId: 'default',
                      minChunkCount: 1,
                      maxChunkCount: 1,
                      requireDistinctChunks: false,
                    ),
                  ],
                ),
              )
            else
              level,
        ],
      );
      final plugin = _InMemoryLevelPlugin(document)
        ..extraIssues = const [
          ValidationIssue(
            severity: ValidationSeverity.error,
            code: 'invalid_chunk_count_range',
            message: 'Review the second section range.',
            ownerKey: 'forest',
            elementId: 'second',
            fieldKey: 'maxChunkCount',
            sourcePath: levelDefsSourcePath,
          ),
        ];
      await _mountLevelPage(tester, plugin: plugin);
      await tester.binding.setSurfaceSize(const Size(980, 720));
      await _flush(tester);
      await tester.tap(find.byKey(const ValueKey('level_diagnostics_button')));
      await _flush(tester);
      await tester.tap(find.text('Open').last);
      await tester.pumpAndSettle();
      expect(find.text('Section settings'), findsOneWidget);
      expect(
        (tester.state(
          find.byType(LevelCreatorPage),
        ) as LevelCreatorNavigationState).returnContext.selectedSegmentId,
        'second',
      );
      expect(
        tester
            .widget<TextField>(_textFieldByLabel('maxChunkCount'))
            .focusNode!
            .hasFocus,
        isTrue,
      );
    },
  );
  testWidgets(
    'canonical source refresh reloads content while retaining invalid raw fields',
    (tester) async {
      var loads = 0;
      final controller = await _mountLevelPage(
        tester,
        contentLoader: (root) async {
          loads++;
          final projection = await _testContentLoader(root);
          if (loads == 1) return projection;
          return LevelContentProjection(
            document: projection.document.copyWith(
              chunks: [
                ...projection.document.chunks,
                projection.document.chunks
                    .firstWhere((chunk) => chunk.levelId == 'forest')
                    .copyWith(chunkKey: 'new-second-key', id: 'forest_second'),
              ],
            ),
          );
        },
      );
      expect(loads, 1);
      await tester.enterText(_textFieldByLabel('displayName'), 'Accepted edit');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await _flush(tester);
      expect(loads, 1);
      await _enterInspectorText(tester, 'earlyPatternChunks', '-');
      await controller.loadWorkspace();
      await _flush(tester);
      expect(loads, 2);
      expect(find.text('new-second-key'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(_textFieldByLabel('earlyPatternChunks'))
            .controller!
            .text,
        '-',
      );
    },
  );
  testWidgets(
    'normal reopen restores valid level and tab without source history',
    (tester) async {
      final store = _MemoryViewStore(
        const LevelCreatorReturnContext(
          levelId: 'field',
          tab: LevelCreatorTab.flow,
          groupFilter: 'missing-group',
        ),
      );
      final controller = await _mountLevelPage(tester, viewStore: store);
      expect((controller.scene as LevelScene).activeLevelId, 'field');
      expect(find.text('Difficulty coverage'), findsOneWidget);
      expect(store.saved!.groupFilter, isNull);
      expect(controller.canUndo, isFalse);
      expect(controller.pendingChanges.hasChanges, isFalse);
    },
  );

  testWidgets('missing restored level asks for an explicit current selection', (
    tester,
  ) async {
    final store = _MemoryViewStore(
      const LevelCreatorReturnContext(levelId: 'removed-level'),
    );
    final controller = await _mountLevelPage(tester, viewStore: store);
    expect(find.textContaining('Previously selected level'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('level_persistent_preview')),
      findsNothing,
    );
    expect(store.saved, isNull);
    await tester.tap(find.byKey(const ValueKey('level_library_forest')));
    await _flush(tester);
    expect(
      find.byKey(const ValueKey('level_persistent_preview')),
      findsOneWidget,
    );
    expect(find.textContaining('Previously selected level'), findsNothing);
    expect(controller.canUndo, isFalse);
  });
  testWidgets('build inclusion is explicit and does not change level status', (
    tester,
  ) async {
    final controller = await _mountLevelPage(tester);
    final before = (controller.scene as LevelScene).activeLevel!;
    expect(before.includeInBuild, isFalse);
    await tester.tap(
      find.byKey(const ValueKey<String>('level_include_in_build')),
    );
    await _flush(tester);
    final after = (controller.scene as LevelScene).activeLevel!;
    expect(after.includeInBuild, isTrue);
    expect(after.status, before.status);
    controller.undo();
    await _flush(tester);
    expect(
      (controller.scene as LevelScene).activeLevel!.includeInBuild,
      isFalse,
    );
  });

  testWidgets(
    'dependency repair retains raw invalid input and targets its source owner',
    (tester) async {
      String? repairTarget;
      final plugin = _InMemoryLevelPlugin(_initialDocument)
        ..extraIssues = const [
          ValidationIssue(
            severity: ValidationSeverity.error,
            code: 'test_background_source_invalid',
            message: 'The background source needs repair.',
            sourcePath: parallaxDefsSourcePath,
          ),
        ];
      await _mountLevelPage(
        tester,
        plugin: plugin,
        onRepairDependency: (id) async {
          repairTarget = id;
          return true;
        },
      );
      await _enterInspectorText(tester, 'earlyPatternChunks', '-');
      await tester.tap(
        find.byKey(const ValueKey<String>('level_diagnostics_button')),
      );
      await _flush(tester);
      await tester.tap(find.text('Repair background'));
      await _flush(tester);
      expect(repairTarget, 'parallax');
      expect(
        tester
            .widget<TextField>(_textFieldByLabel('earlyPatternChunks'))
            .controller!
            .text,
        '-',
      );
      expect(
        (tester.state(
          find.byType(LevelCreatorPage),
        ) as EditorPageLocalDraftState).hasLocalDraftChanges,
        isTrue,
      );
    },
  );
  testWidgets(
    'friendly creation allocates IDs and an independent background by default',
    (tester) async {
      final controller = await _mountLevelPage(tester);
      await _openCreate(tester);
      expect(find.text('Make an independent copy'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('new_level_name')),
        'Crystal Depths',
      );
      await _flush(tester);
      await tester.tap(find.byKey(const ValueKey('create_level_button')));
      await tester.pumpAndSettle();
      final document = controller.document as LevelDefsDocument;
      final created = document.levels.singleWhere(
        (level) => level.displayName == 'Crystal Depths',
      );
      expect(created.levelId, 'crystal_depths');
      expect(created.visualThemeId, isNot('forest'));
      expect(created.includeInBuild, isFalse);
      expect(created.assembly, isNull);
      expect(
        document.parallaxDocument!.themes.any(
          (theme) => theme.parallaxThemeId == created.visualThemeId,
        ),
        isTrue,
      );
      expect(controller.pendingChanges.fileDiffs, hasLength(2));
      expect(find.byKey(const ValueKey('level_creation_dialog')), findsNothing);
      controller.undo();
      await _flush(tester);
      expect(
        (controller.document as LevelDefsDocument).levels.any(
          (level) => level.levelId == created.levelId,
        ),
        isFalse,
      );
      controller.redo();
      await _flush(tester);
      expect(
        (controller.document as LevelDefsDocument).levels.any(
          (level) => level.levelId == created.levelId,
        ),
        isTrue,
      );
    },
  );

  testWidgets(
    'sharing is explicit and cancelling named creation leaves no draft',
    (tester) async {
      final controller = await _mountLevelPage(tester);
      await _openCreate(tester);
      await tester.enterText(
        find.byKey(const ValueKey('new_level_name')),
        'Cancelled',
      );
      await tester.tap(find.text('Cancel').last);
      await tester.pumpAndSettle();
      expect(
        (tester.state(
          find.byType(LevelCreatorPage),
        ) as EditorPageLocalDraftState).hasLocalDraftChanges,
        isFalse,
      );
      expect(controller.pendingChanges.hasChanges, isFalse);
      await _openCreate(tester);
      await tester.enterText(
        find.byKey(const ValueKey('new_level_name')),
        'Shared Field',
      );
      await tester.tap(find.text('Make an independent copy'));
      await _flush(tester);
      await tester.tap(find.text('Share an existing background').last);
      await _flush(tester);
      await _selectDropdownByLabel(
        tester,
        label: 'Source background',
        value: 'field',
      );
      await tester.tap(find.byKey(const ValueKey('create_level_button')));
      await tester.pumpAndSettle();
      expect(controller.pendingChanges.fileDiffs, hasLength(1));
      expect(
        (controller.scene as LevelScene).activeLevel!.visualThemeId,
        'field',
      );
    },
  );

  testWidgets(
    'copy settings defaults to Automatic and an independent background',
    (tester) async {
      final controller = await _mountLevelPage(tester);
      await _addSection(tester);
      await tester.tap(find.byTooltip('Level actions'));
      await _flush(tester);
      await tester.tap(find.text('Copy level settings').last);
      await _flush(tester);
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const ValueKey('copy_level_section_design')),
            )
            .value,
        isFalse,
      );
      await tester.tap(find.byKey(const ValueKey('create_level_button')));
      await tester.pumpAndSettle();
      final copied = (controller.scene as LevelScene).activeLevel!;
      expect(copied.levelId, isNot('forest'));
      expect(copied.assembly, isNull);
      expect(copied.visualThemeId, isNot('forest'));
      expect(copied.includeInBuild, isFalse);
    },
  );

  testWidgets(
    'workspace shows real chunks and preserves preview across tab changes and resize',
    (tester) async {
      final controller = await _mountLevelPage(tester);
      expect(find.text('forest-flat-key'), findsWidgets);
      expect(find.text('field-flat-key'), findsNothing);
      final preview = tester.element(
        find.byKey(const ValueKey<String>('level_persistent_preview')),
      );
      await _showTab(tester, 'Flow');
      expect(
        identical(
          preview,
          tester.element(
            find.byKey(const ValueKey<String>('level_persistent_preview')),
          ),
        ),
        isTrue,
      );
      await _showTab(tester, 'Appearance');
      await tester.binding.setSurfaceSize(const Size(800, 600));
      await _flush(tester);
      expect(
        identical(
          preview,
          tester.element(
            find.byKey(const ValueKey<String>('level_persistent_preview')),
          ),
        ),
        isTrue,
      );
      expect(controller.pendingChanges.hasChanges, isFalse);
      expect(controller.canUndo, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'section creation defaults to one unique chunk and automatic removal is undoable',
    (tester) async {
      final controller = await _mountLevelPage(tester);
      await _addSection(tester);
      var section = (controller.scene as LevelScene)
          .activeLevel!
          .assembly!
          .segments
          .single;
      expect(section.groupId, defaultAssemblyGroupId);
      expect(section.minChunkCount, 1);
      expect(section.maxChunkCount, 1);
      expect(section.requireDistinctChunks, isTrue);
      expect(section.difficulty?.name, 'early');
      await tester.tap(find.text('Automatic'));
      await _flush(tester);
      await tester.tap(find.text('Cancel').last);
      await _flush(tester);
      expect((controller.scene as LevelScene).activeLevel!.assembly, isNotNull);
      await tester.tap(find.text('Automatic'));
      await _flush(tester);
      await tester.tap(find.text('Use Automatic'));
      await _flush(tester);
      expect((controller.scene as LevelScene).activeLevel!.assembly, isNull);
      controller.undo();
      await _flush(tester);
      section = (controller.scene as LevelScene)
          .activeLevel!
          .assembly!
          .segments
          .single;
      expect(section.minChunkCount, 1);
    },
  );

  testWidgets('content handoff carries exact chunk group and return context', (
    tester,
  ) async {
    LevelCreatorChunkTarget? target;
    await _mountLevelPage(
      tester,
      onOpenChunk: (value) async {
        target = value;
        return true;
      },
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('level_chunk_forest-flat-key')),
    );
    await _flush(tester);
    await tester.tap(find.text('Edit chunk').last);
    await _flush(tester);
    expect(target?.levelId, 'forest');
    expect(target?.chunkKey, 'forest-flat-key');
    expect(target?.groupId, 'default');
    expect(target?.intent, LevelCreatorChunkIntent.edit);
    expect(target?.returnContext.tab, LevelCreatorTab.contents);
    expect(target?.returnContext.selectedChunkKey, 'forest-flat-key');
  });

  testWidgets(
    'appearance handoff delegates the accepted background without an implicit export',
    (tester) async {
      ParallaxLevelTarget? opened;
      final controller = await _mountLevelPage(
        tester,
        applyExports: true,
        onOpenInParallax: (target) => opened = target,
      );
      await _showTab(tester, 'Appearance');
      await tester.tap(find.text('Create empty background'));
      await _flush(tester);
      await tester.enterText(
        find.byKey(const ValueKey<String>('create_assign_theme_id_field')),
        'forest_night',
      );
      await _flush(tester);
      await tester.tap(find.text('Create and assign').last);
      await _flush(tester);
      await tester.tap(find.text('Add background layers'));
      await _flush(tester);
      expect(opened?.levelId, 'forest');
      expect(opened?.parallaxThemeId, 'forest_night');
      expect(controller.lastExportResult, isNull);
    },
  );

  testWidgets('switching levels accepts visible edits without losing them', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1800, 1200));
    addTearDown(() async => tester.binding.setSurfaceSize(null));
    final controller = _buildController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LevelCreatorPage(
            viewStore: null,
            controller: controller,
            contentLoader: _testContentLoader,
          ),
        ),
      ),
    );
    await _flush(tester);

    await tester.enterText(_textFieldByLabel('displayName'), 'Forest draft');
    await _selectDropdownByLabel(tester, label: 'Active Level', value: 'field');
    expect(
      findLevelDefById(
        (controller.document as LevelDefsDocument).levels,
        'forest',
      )?.displayName,
      'Forest draft',
    );
    await _selectDropdownByLabel(
      tester,
      label: 'Active Level',
      value: 'forest',
    );
    expect(
      tester
          .widget<TextField>(_textFieldByLabel('displayName'))
          .controller
          ?.text,
      'Forest draft',
    );
  });

  testWidgets('same-level undo refreshes visible fields from accepted state', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1800, 1200));
    addTearDown(() async => tester.binding.setSurfaceSize(null));
    final controller = _buildController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LevelCreatorPage(
            viewStore: null,
            controller: controller,
            contentLoader: _testContentLoader,
          ),
        ),
      ),
    );
    await _flush(tester);
    await tester.enterText(_textFieldByLabel('displayName'), 'Forest accepted');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await _flush(tester);
    controller.undo();
    await _flush(tester);
    expect(
      tester
          .widget<TextField>(_textFieldByLabel('displayName'))
          .controller
          ?.text,
      'Forest',
    );
  });

  testWidgets('invalid section input participates in dirty state', (
    tester,
  ) async {
    await _mountLevelPage(tester);
    await _addSection(tester);
    await _flush(tester);
    await _enterInspectorText(tester, 'minChunkCount', '-');
    final state = tester.state(
      find.byType(LevelCreatorPage),
    ) as EditorPageLocalDraftState;
    expect(state.hasLocalDraftChanges, isTrue);
  });

  testWidgets(
    'Save accepts a focused local-only edit and exports its visible value',
    (tester) async {
      final controller = await _mountLevelPage(tester, applyExports: true);
      await tester.enterText(
        _textFieldByLabel('displayName'),
        'Focused Forest',
      );
      expect(controller.pendingChanges.hasChanges, isFalse);
      final handler =
          tester.state(find.byType(LevelCreatorPage)) as EditorPageSaveHandler;
      expect(handler.canSaveEditorPage, isTrue);
      expect(await handler.saveEditorPage(), EditorPageSaveResult.saved);
      await _flush(tester);
      expect(
        findLevelDefById(
          (controller.document as LevelDefsDocument).levels,
          'forest',
        )?.displayName,
        'Focused Forest',
      );
      expect(
        (handler as EditorPageLocalDraftState).hasLocalDraftChanges,
        isFalse,
      );
      expect(controller.pendingChanges.hasChanges, isFalse);
    },
  );

  testWidgets('Save exports focused B after accepted A and reload retains B', (
    tester,
  ) async {
    final controller = await _mountLevelPage(tester, applyExports: true);
    await tester.enterText(_textFieldByLabel('displayName'), 'Accepted A');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await _flush(tester);
    expect(
      findLevelDefById(
        (controller.document as LevelDefsDocument).levels,
        'forest',
      )?.displayName,
      'Accepted A',
    );
    await tester.enterText(_textFieldByLabel('displayName'), 'Visible B');
    final handler =
        tester.state(find.byType(LevelCreatorPage)) as EditorPageSaveHandler;
    expect(await handler.saveEditorPage(), EditorPageSaveResult.saved);
    await _flush(tester);
    await (handler as EditorPageReloadHandler).reloadEditorPage();
    await _flush(tester);
    expect(
      tester
          .widget<TextField>(_textFieldByLabel('displayName'))
          .controller
          ?.text,
      'Visible B',
    );
  });

  for (final invalid in <String>['', '-', '1.5', '-1']) {
    testWidgets(
      'Save preserves invalid pacing text "$invalid" and writes nothing',
      (tester) async {
        final plugin = _InMemoryLevelPlugin(
          _initialDocument,
          applyExports: true,
        );
        final controller = await _mountLevelPage(tester, plugin: plugin);
        await _enterInspectorText(tester, 'earlyPatternChunks', invalid);
        final handler = tester.state(
          find.byType(LevelCreatorPage),
        ) as EditorPageSaveHandler;
        expect(await handler.saveEditorPage(), EditorPageSaveResult.blocked);
        await _flush(tester);
        expect(plugin.exportCount, 0);
        expect(
          tester
              .widget<TextField>(_textFieldByLabel('earlyPatternChunks'))
              .controller
              ?.text,
          invalid,
        );
        expect(
          findLevelDefById(
            (controller.document as LevelDefsDocument).levels,
            'forest',
          )?.earlyPatternChunks,
          3,
        );
        expect(
          (handler as EditorPageLocalDraftState).hasLocalDraftChanges,
          isTrue,
        );
      },
    );
  }

  testWidgets(
    'invalid section text survives selection cancellation and undo cancellation',
    (tester) async {
      final controller = await _mountLevelPage(tester);
      await _addSection(tester);
      await _flush(tester);
      await _enterInspectorText(tester, 'minChunkCount', '-');
      await _selectDropdownByLabel(
        tester,
        label: 'Active Level',
        value: 'field',
      );
      expect(
        find.byKey(const ValueKey<String>('level_invalid_input_dialog')),
        findsOneWidget,
      );
      await tester.tap(find.text('Keep editing'));
      await _flush(tester);
      expect((controller.scene as LevelScene).activeLevelId, 'forest');
      expect(
        tester
            .widget<TextField>(_textFieldByLabel('minChunkCount'))
            .controller
            ?.text,
        '-',
      );
      final handler = tester.state(
        find.byType(LevelCreatorPage),
      ) as EditorPageSessionShortcutHandler;
      expect(handler.handleUndoSessionShortcut(), isTrue);
      await _flush(tester);
      await tester.tap(find.text('Keep editing'));
      await _flush(tester);
      expect(
        tester
            .widget<TextField>(_textFieldByLabel('minChunkCount'))
            .controller
            ?.text,
        '-',
      );
      expect((controller.scene as LevelScene).activeLevel?.assembly, isNotNull);
    },
  );

  testWidgets(
    'discarding only invalid input preserves valid pending changes during selection',
    (tester) async {
      final controller = await _mountLevelPage(tester);
      await tester.enterText(
        _textFieldByLabel('displayName'),
        'Forest renamed',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await _flush(tester);
      await _enterInspectorText(tester, 'earlyPatternChunks', '-');
      await _selectDropdownByLabel(
        tester,
        label: 'Active Level',
        value: 'field',
      );
      await tester.tap(find.text('Discard this edit'));
      await _flush(tester);
      expect((controller.scene as LevelScene).activeLevelId, 'field');
      expect(
        findLevelDefById(
          (controller.document as LevelDefsDocument).levels,
          'forest',
        )?.displayName,
        'Forest renamed',
      );
      expect(controller.pendingChanges.hasChanges, isTrue);
    },
  );

  testWidgets(
    'same-ID reload clears discarded raw input and restores the persisted baseline',
    (tester) async {
      await _mountLevelPage(tester);
      await tester.enterText(_textFieldByLabel('displayName'), 'Pending name');
      await _enterInspectorText(tester, 'earlyPatternChunks', '-');
      final handler = tester.state(
        find.byType(LevelCreatorPage),
      ) as EditorPageReloadHandler;
      await handler.reloadEditorPage();
      await _flush(tester);
      expect(
        tester
            .widget<TextField>(_textFieldByLabel('displayName'))
            .controller
            ?.text,
        'Forest',
      );
      expect(
        tester
            .widget<TextField>(_textFieldByLabel('earlyPatternChunks'))
            .controller
            ?.text,
        '3',
      );
      expect(
        (handler as EditorPageLocalDraftState).hasLocalDraftChanges,
        isFalse,
      );
    },
  );

  testWidgets(
    'selection does not occupy undo and pending summary covers every changed level',
    (tester) async {
      var notifications = 0;
      final controller = await _mountLevelPage(
        tester,
        onShellStateChanged: () => notifications++,
      );
      await _selectDropdownByLabel(
        tester,
        label: 'Active Level',
        value: 'field',
      );
      expect(controller.canUndo, isFalse);
      await tester.enterText(_textFieldByLabel('displayName'), 'Field changed');
      await _selectDropdownByLabel(
        tester,
        label: 'Active Level',
        value: 'forest',
      );
      await tester.enterText(
        _textFieldByLabel('displayName'),
        'Forest changed',
      );
      await _flush(tester);
      final summary = tester.state(
        find.byType(LevelCreatorPage),
      ) as EditorPagePendingChangesSummary;
      expect(summary.pendingChangesSummary, '2 levels have changes');
      expect(
        summary.pendingChangeDescriptions,
        containsAll(<String>['Level: Field changed', 'Level: Forest changed']),
      );
      expect(notifications, greaterThan(0));
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await _flush(tester);
      controller.undo();
      await _flush(tester);
      expect((controller.scene as LevelScene).activeLevelId, 'forest');
      expect(
        tester
            .widget<TextField>(_textFieldByLabel('displayName'))
            .controller
            ?.text,
        'Forest',
      );
      controller.undo();
      await _flush(tester);
      expect(controller.canUndo, isFalse);
      expect(controller.pendingChanges.hasChanges, isFalse);
    },
  );

  testWidgets('failed save retains input and accepted changes for retry', (
    tester,
  ) async {
    final plugin = _InMemoryLevelPlugin(_initialDocument, applyExports: true)
      ..failExports = true;
    final controller = await _mountLevelPage(tester, plugin: plugin);
    await tester.enterText(
      _textFieldByLabel('displayName'),
      'Retain after failure',
    );
    final handler =
        tester.state(find.byType(LevelCreatorPage)) as EditorPageSaveHandler;
    expect(await handler.saveEditorPage(), EditorPageSaveResult.failed);
    await _flush(tester);
    expect(
      tester
          .widget<TextField>(_textFieldByLabel('displayName'))
          .controller
          ?.text,
      'Retain after failure',
    );
    expect(controller.pendingChanges.hasChanges, isTrue);
    plugin.failExports = false;
    expect(await handler.saveEditorPage(), EditorPageSaveResult.saved);
    await _flush(tester);
    expect(controller.pendingChanges.hasChanges, isFalse);
  });

  testWidgets('small windows and text scaling keep fields reachable', (
    tester,
  ) async {
    await _mountLevelPage(tester);
    await tester.binding.setSurfaceSize(const Size(800, 600));
    await _flush(tester);
    await tester.tap(find.text('Settings'));
    await _flush(tester);
    await _enterInspectorText(tester, 'displayName', 'Small window edit');
    expect(
      tester
          .widget<TextField>(_textFieldByLabel('displayName'))
          .controller
          ?.text,
      'Small window edit',
    );
    expect(tester.takeException(), isNull);
  });
}

Future<void> _openCreate(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey<String>('new_level_button')));
  await _flush(tester);
}

Future<void> _showTab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(
      of: find.byKey(const ValueKey<String>('level_workspace_tabs')),
      matching: find.text(label),
    ),
  );
  await _flush(tester);
}

Future<void> _addSection(WidgetTester tester) async {
  await _showTab(tester, 'Flow');
  await tester.tap(find.text('Ordered sections'));
  await _flush(tester);
}

Future<LevelContentProjection> _testContentLoader(String _) async =>
    LevelContentProjection(
      document: ChunkV2Document(
        chunks: [
          for (final level in ['field', 'forest'])
            ChunkV2FileData(
              chunkKey: '$level-flat-key',
              id: '${level}_flat',
              revision: 1,
              status: 'active',
              levelId: level,
              tileSize: 16,
              width: 600,
              height: 270,
              difficulty: 'early',
              assemblyGroupId: 'default',
              tags: const [],
              tileLayers: const [],
              prefabs: const [],
              markers: const [],
              groundBandZIndex: 0,
              collisionShapes: const [],
            ),
        ],
        sourcePathByChunkKey: const {},
        baselineContentsByChunkKey: const {},
        prefabData: PrefabV3FileData(slices: const [], prefabs: const []),
        tileData: PrefabTileFileData(
          tileSlices: const [],
          platformModules: const [],
        ),
        visualBoundsByPrefabKey: const {},
        levels: _initialDocument.levels,
        parallaxThemes: _initialThemes,
        availableLevelIds: const ['field', 'forest'],
        activeLevelId: 'forest',
      ),
    );

Future<EditorSessionController> _mountLevelPage(
  WidgetTester tester, {
  bool applyExports = false,
  _InMemoryLevelPlugin? plugin,
  VoidCallback? onShellStateChanged,
  Future<bool> Function(LevelCreatorChunkTarget)? onOpenChunk,
  ValueChanged<ParallaxLevelTarget>? onOpenInParallax,
  Future<bool> Function(String)? onRepairDependency,
  LevelCreatorViewStore? viewStore,
  LevelContentProjectionLoader contentLoader = _testContentLoader,
}) async {
  await tester.binding.setSurfaceSize(const Size(1800, 1600));
  addTearDown(() async => tester.binding.setSurfaceSize(null));
  final controller = EditorSessionController(
    pluginRegistry: AuthoringPluginRegistry(
      plugins: <AuthoringDomainPlugin>[
        plugin ??
            _InMemoryLevelPlugin(_initialDocument, applyExports: applyExports),
      ],
    ),
    initialPluginId: LevelDomainPlugin.pluginId,
    initialWorkspacePath: '.',
  );
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: LevelCreatorPage(
          viewStore: viewStore,
          controller: controller,
          onShellStateChanged: onShellStateChanged,
          onOpenChunk: onOpenChunk,
          onOpenInParallax: onOpenInParallax,
          onRepairDependency: onRepairDependency,
          contentLoader: contentLoader,
        ),
      ),
    ),
  );
  await _flush(tester);
  return controller;
}

Future<void> _enterInspectorText(
  WidgetTester tester,
  String label,
  String text,
) async {
  final finder = _textFieldByLabel(label);
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      220,
      scrollable: find
          .descendant(
            of: find.byKey(
              const PageStorageKey<String>('level_settings_scroll'),
            ),
            matching: find.byType(Scrollable),
          )
          .first,
    );
  }
  await tester.ensureVisible(finder);
  await tester.enterText(finder, text);
  await _flush(tester);
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

class _MemoryViewStore extends LevelCreatorViewStore {
  _MemoryViewStore(this.initial) : super.local();
  final LevelCreatorReturnContext initial;
  LevelCreatorReturnContext? saved;
  @override
  Future<LevelCreatorReturnContext?> read(String workspacePath) async =>
      initial;
  @override
  Future<void> write(
    String workspacePath,
    LevelCreatorReturnContext view,
  ) async {
    saved = view;
  }
}

class _InMemoryLevelPlugin
    implements AuthoringDomainPlugin, AuthoringSessionSemantics {
  _InMemoryLevelPlugin(
    LevelDefsDocument initialDocument, {
    this.applyExports = false,
  }) : _persistedDocument = initialDocument;

  LevelDefsDocument _persistedDocument;
  final bool applyExports;
  bool failExports = false;
  List<ValidationIssue> extraIssues = const [];
  int exportCount = 0;
  final LevelDomainPlugin _delegate = LevelDomainPlugin();

  @override
  bool isPresentationCommand(AuthoringCommand command) =>
      _delegate.isPresentationCommand(command);

  @override
  AuthoringDocument retainPresentation({
    required AuthoringDocument current,
    required AuthoringDocument restored,
  }) => _delegate.retainPresentation(current: current, restored: restored);

  @override
  String get id => LevelDomainPlugin.pluginId;

  @override
  Future<AuthoringDocument> loadFromRepo(EditorWorkspace workspace) async {
    return _persistedDocument.copyWith(workspaceRootPath: workspace.rootPath);
  }

  @override
  List<ValidationIssue> validate(AuthoringDocument document) {
    return [..._delegate.validate(document), ...extraIssues];
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
    exportCount += 1;
    if (failExports) {
      return ExportResult(
        applied: false,
        outcome: ExportOutcome.failed,
        message: 'Source is locked; retry when the lock is released.',
      );
    }
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
      a.includeInBuild == b.includeInBuild &&
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
  const keys = {
    'displayName',
    'cameraCenterY',
    'groundTopY',
    'earlyPatternChunks',
    'easyPatternChunks',
    'normalPatternChunks',
    'noEnemyChunks',
    'enumOrdinal',
    'segmentId',
    'minChunkCount',
    'maxChunkCount',
  };
  if (keys.contains(label)) {
    return find.byKey(ValueKey<String>('level_input_$label'));
  }
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
  if (label == 'Active Level') {
    await tester.tap(find.byKey(ValueKey<String>('level_library_$value')));
    await _flush(tester);
    return;
  }
  await tester.tap(_dropdownFieldByLabel(label));
  await _flush(tester);
  await tester.tap(find.text(value).last);
  await _flush(tester);
}

Future<void> _flush(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 150));
}
