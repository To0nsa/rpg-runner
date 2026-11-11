import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runner_content_pipeline/runner_content_pipeline.dart';
import 'package:runner_editor/src/app/pages/campaign/campaign_page.dart';
import 'package:runner_editor/src/app/pages/shared/editor_page_navigation_state.dart';
import 'package:runner_editor/src/campaign/campaign_domain_plugin.dart';
import 'package:runner_editor/src/chunks/chunk_domain_plugin.dart';
import 'package:runner_editor/src/chunks/chunk_store.dart';
import 'package:runner_editor/src/chunks/chunk_v2_file_codec.dart';
import 'package:runner_editor/src/chunks/chunk_v2_lifecycle_commit.dart';
import 'package:runner_editor/src/chunks/chunk_v2_models.dart';
import 'package:runner_editor/src/domain/authoring_plugin_registry.dart';
import 'package:runner_editor/src/domain/authoring_types.dart';
import 'package:runner_editor/src/playtest/authored_playtest_preparation.dart';
import 'package:runner_editor/src/session/editor_session_controller.dart';
import 'package:runner_editor/src/workspace/editor_workspace.dart';
import 'package:rpg_runner/playtest.dart';

void main() {
  final repo = Directory.current.parent.parent.path;
  late Directory fixture;
  late EditorWorkspace workspace;
  late CampaignDomainPlugin plugin;
  setUp(() async {
    fixture = await Directory.systemTemp.createTemp('campaign_editor_');
    final sources = Directory('$repo/assets/authoring');
    for (final file in sources.listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.json')) continue;
      final relative = file.path.substring(repo.length + 1);
      final target = File('${fixture.path}/$relative');
      target.parent.createSync(recursive: true);
      file.copySync(target.path);
    }
    final materials = File(
      '$repo/assets/authoring/level/terrain_material_defs.json',
    ).readAsStringSync();
    for (final path in RegExp(
      r'assets/images/[^\"]+\.png',
    ).allMatches(materials).map((m) => m.group(0)!).toSet()) {
      final target = File('${fixture.path}/$path');
      target.parent.createSync(recursive: true);
      File('$repo/$path').copySync(target.path);
    }
    final flat =
        (jsonDecode(
                      File('$repo/$trainingFieldSourcePath').readAsStringSync(),
                    )['chunks']
                    as List)
                .first
            as Map<String, dynamic>;
    flat.addAll({
      'chunkKey': 'forest_campaign_fixture',
      'id': 'forest_campaign_fixture',
      'levelId': 'forest',
      'usage': 'campaign',
    });
    File(
      '${fixture.path}/assets/authoring/level/chunks/forest/forest_campaign_fixture.json',
    ).writeAsStringSync(jsonEncode(flat));
    workspace = EditorWorkspace(rootPath: fixture.path);
    plugin = CampaignDomainPlugin();
  });
  tearDown(() async {
    expect(
      fixture.absolute.path,
      startsWith(Directory.systemTemp.absolute.path),
    );
    await fixture.delete(recursive: true);
  });
  AuthoringCommand edit(CampaignDocument d, Map<String, Object?> json) =>
      AuthoringCommand(
        kind: CampaignDomainPlugin.replaceMission,
        payload: {
          'id': d.selected.id,
          'expectedRevision': d.selected.revision,
          'mission': json,
        },
      );
  Map<String, Object?> layout(CampaignDocument d) => d.selected.toJson()
    ..['route'] = [
      for (final id in ['first', 'second'])
        {'id': id, 'levelId': 'forest', 'chunkKey': 'forest_campaign_fixture'},
    ]
    ..['start'] = {'occurrenceId': 'first', 'x': 60, 'y': 224}
    ..['exit'] = {
      'origin': {'occurrenceId': 'second', 'x': 500, 'y': 0},
      'width': 100,
      'height': 270,
    };

  AuthoringCommand chapterReward(CampaignDocument d, String? reward) =>
      AuthoringCommand(
        kind: CampaignDomainPlugin.setChapterReward,
        payload: {
          'id': d.catalog.chapters.first.id,
          'expectedRewardCharacterId':
              d.catalog.chapters.first.rewardCharacterId,
          'rewardCharacterId': reward,
        },
      );

  AuthoringCommand createChapter(String title) => AuthoringCommand(
    kind: CampaignDomainPlugin.createChapter,
    payload: {
      'details': {
        'title': {'en': title, 'fr': title},
        'description': {'en': 'A chapter draft.', 'fr': 'Un chapitre à créer.'},
        'mapX': 0.25,
        'mapY': 0.4,
      },
    },
  );

  test('chapter creation allocates fresh drafts and metadata edits preserve identities', () async {
    final original = await plugin.loadFromRepo(workspace) as CampaignDocument;
    var current = plugin.applyEdit(
      original,
      createChapter('North Pass'),
    ) as CampaignDocument;
    final chapter = current.catalog.chapters.last;
    expect(chapter.id, 'north_pass');
    expect(chapter.rewardCharacterId, isNull);
    expect(chapter.mapX, 0.25);
    expect(chapter.missions, hasLength(1));
    expect(current.selected.id, chapter.missions.single.id);
    expect(current.selected.includeInBuild, isFalse);
    expect(current.selected.route, isEmpty);
    expect(current.selected.start, isNull);
    expect(current.selected.exit, isNull);
    expect(current.selected.firstClearXp, 0);
    expect(current.selected.rewardAbilityId, isNull);
    expect(current.selected.levelId, original.selected.levelId);
    expect(current.selected.visualThemeId, original.selected.visualThemeId);
    expect(
      current.catalog.chapters.first.toJson(),
      original.catalog.chapters.first.toJson(),
    );
    current = plugin.applyEdit(
      current,
      createChapter('North Pass'),
    ) as CampaignDocument;
    expect(current.catalog.chapters.last.id, 'north_pass_2');
    final metadata = AuthoringCommand(
      kind: CampaignDomainPlugin.editChapter,
      payload: {
        'id': chapter.id,
        'expectedChapter': chapter.toJson(),
        'details': {
          'title': {'en': 'Renamed pass', 'fr': 'Col renommé'},
          'description': chapter.description,
          'mapX': 0.6,
          'mapY': 0.7,
        },
      },
    );
    current = plugin.applyEdit(current, metadata) as CampaignDocument;
    final renamed = current.catalog.chapters[1];
    expect(renamed.id, chapter.id);
    expect(renamed.title['en'], 'Renamed pass');
    expect(
      renamed.missions.map((m) => m.toJson()),
      chapter.missions.map((m) => m.toJson()),
    );
    expect(() => plugin.applyEdit(current, metadata), throwsStateError);
    final append = AuthoringCommand(
      kind: CampaignDomainPlugin.addMission,
      payload: {'id': chapter.id},
    );
    for (var i = 1; i < 16; i++) {
      current = plugin.applyEdit(current, append) as CampaignDocument;
    }
    expect(current.catalog.chapters[1].missions, hasLength(16));
    expect(current.selected.id, current.catalog.chapters[1].missions.last.id);
    expect(
      current.catalog.missions.map((m) => m.id).toSet().length,
      current.catalog.missions.length,
    );
    expect(() => plugin.applyEdit(current, append), throwsFormatException);
    final invalid = createChapter('Bad map');
    expect(
      () => plugin.applyEdit(
        original,
        AuthoringCommand(
          kind: invalid.kind,
          payload: {
            'details': {...invalid.payload['details'] as Map, 'mapX': 2},
          },
        ),
      ),
      throwsFormatException,
    );
  });

  test(
    'unsaved chapter creation is undoable and Save seals new identities',
    () async {
      final controller = EditorSessionController(
        pluginRegistry: AuthoringPluginRegistry(plugins: [plugin]),
        initialPluginId: plugin.id,
        initialWorkspacePath: fixture.path,
      );
      addTearDown(controller.dispose);
      await controller.loadWorkspace();
      controller.applyCommand(createChapter('North Pass'));
      final created = controller.document as CampaignDocument;
      final newChapter = created.catalog.chapters.last;
      controller.undo();
      var current = controller.document as CampaignDocument;
      expect(current.catalog.chapters, hasLength(1));
      expect(current.selected.id, 'reporting_for_duty');
      expect(controller.pendingChanges.hasChanges, isFalse);
      controller.redo();
      current = controller.document as CampaignDocument;
      expect(current.catalog.chapters.last.id, newChapter.id);
      controller.applyCommand(
        AuthoringCommand(
          kind: CampaignDomainPlugin.addMission,
          payload: {'id': newChapter.id},
        ),
      );
      expect(
        (controller.document as CampaignDocument)
            .catalog
            .chapters
            .last
            .missions,
        hasLength(2),
      );
      controller.undo();
      expect(
        (controller.document as CampaignDocument)
            .catalog
            .chapters
            .last
            .missions,
        hasLength(1),
      );
      controller.redo();
      await controller.exportDirectWrite();
      expect(controller.exportError, isNull);
      final reopened = await plugin.loadFromRepo(workspace) as CampaignDocument;
      expect(reopened.catalog.chapters.last.id, newChapter.id);
      expect(reopened.catalog.chapters.last.missions, hasLength(2));
      current = controller.document as CampaignDocument;
      final selection = current.selected.id;
      controller.applyCommand(
        edit(current, current.selected.toJson()..['firstClearXp'] = 9),
      );
      controller.undo();
      expect((controller.document as CampaignDocument).selected.id, selection);
      expect(controller.pendingChanges.hasChanges, isFalse);
      controller.undo();
      expect(
        (controller.document as CampaignDocument)
            .catalog
            .chapters
            .last
            .missions,
        hasLength(2),
      );
      expect(controller.canUndo, isFalse);
    },
  );

  test('reward edits reject unsupported IDs and stale chapter forms', () async {
    final original = await plugin.loadFromRepo(workspace) as CampaignDocument;
    expect(
      plugin.applyEdit(original, chapterReward(original, 'bountyHunter')),
      same(original),
    );
    expect(
      () => plugin.applyEdit(original, chapterReward(original, 'eloise')),
      throwsFormatException,
    );
    expect(
      () => plugin.applyEdit(
        original,
        edit(original, original.selected.toJson()..['rewardAbilityId'] = 'bad'),
      ),
      throwsFormatException,
    );
    final clear = chapterReward(original, null);
    final changed = plugin.applyEdit(original, clear) as CampaignDocument;
    expect(changed.catalog.chapters.first.rewardCharacterId, isNull);
    expect(
      changed.catalog.missions.map((m) => m.toJson()),
      original.catalog.missions.map((m) => m.toJson()),
    );
    expect(() => plugin.applyEdit(changed, clear), throwsStateError);
    expect(original.catalog.chapters.first.rewardCharacterId, 'bountyHunter');
    expect(
      () => plugin.applyEdit(
        original,
        AuthoringCommand(
          kind: CampaignDomainPlugin.setChapterReward,
          payload: {...clear.payload, 'id': 'missing'},
        ),
      ),
      throwsArgumentError,
    );
  });

  test('reward settings survive Save, reopen and Undo after Save', () async {
    final controller = EditorSessionController(
      pluginRegistry: AuthoringPluginRegistry(plugins: [plugin]),
      initialPluginId: plugin.id,
      initialWorkspacePath: fixture.path,
    );
    addTearDown(controller.dispose);
    await controller.loadWorkspace();
    final original = controller.document as CampaignDocument;
    controller.applyCommand(
      edit(
        original,
        original.selected.toJson()
          ..['firstClearXp'] = 55
          ..['rewardAbilityId'] = null,
      ),
    );
    controller.applyCommand(
      chapterReward(controller.document as CampaignDocument, null),
    );
    await controller.exportDirectWrite();
    expect(controller.exportError, isNull);
    expect(controller.pendingChanges.hasChanges, isFalse);
    final reopened = await plugin.loadFromRepo(workspace) as CampaignDocument;
    expect(reopened.selected.firstClearXp, 55);
    expect(reopened.selected.rewardAbilityId, isNull);
    expect(reopened.catalog.chapters.first.rewardCharacterId, isNull);
    expect(
      reopened.catalog.chapters.first.title,
      original.catalog.chapters.first.title,
    );
    expect(
      reopened.catalog.missions.skip(1).map((m) => m.toJson()),
      original.catalog.missions.skip(1).map((m) => m.toJson()),
    );
    controller.undo();
    var restored = controller.document as CampaignDocument;
    expect(restored.catalog.chapters.first.rewardCharacterId, 'bountyHunter');
    expect(restored.selected.rewardAbilityId, isNull);
    controller.undo();
    restored = controller.document as CampaignDocument;
    expect(restored.selected.rewardAbilityId, 'eloise.double_jump');
    expect(restored.selected.firstClearXp, 40);
    controller.redo();
    controller.redo();
    restored = controller.document as CampaignDocument;
    expect(restored.catalog.chapters.first.rewardCharacterId, isNull);
    expect(restored.selected.rewardAbilityId, isNull);
    expect(controller.pendingChanges.hasChanges, isFalse);
    controller.applyCommand(
      edit(restored, restored.selected.toJson()..['firstClearXp'] = 56),
    );
    // Reward-only edits retain the same drift protection as route edits.
    final source = File(workspace.resolve(campaignSourcePath));
    final external = '${source.readAsStringSync()}\n';
    source.writeAsStringSync(external);
    final rejected = await plugin.exportToRepo(
      workspace,
      document: controller.document!,
    );
    expect(rejected.outcome, ExportOutcome.sourceDrift);
    expect(source.readAsStringSync(), external);
  });

  test(
    'Save/reopen, Undo after Save, source drift and captured mission Play',
    () async {
      final controller = EditorSessionController(
        pluginRegistry: AuthoringPluginRegistry(plugins: [plugin]),
        initialPluginId: plugin.id,
        initialWorkspacePath: fixture.path,
      );
      addTearDown(controller.dispose);
      await controller.loadWorkspace();
      final original = controller.document as CampaignDocument;
      expect(controller.pendingChanges.hasChanges, isFalse);
      controller.applyCommand(edit(original, layout(original)));
      final authored = controller.document as CampaignDocument;
      final capture = await captureCampaignPlaytestPreparationInput(
        document: authored,
        workspaceRoot: fixture.path,
      );
      final prepared = preparePlaytest(capture);
      expect(prepared.issues, isEmpty);
      expect(prepared.scenario, isA<CampaignPlaytestScenario>());
      expect(
        (prepared.scenario as CampaignPlaytestScenario)
            .mission
            .route
            .occurrences
            .map((o) => o.id),
        ['first', 'second'],
      );
      await controller.exportDirectWrite();
      expect(controller.exportError, isNull);
      final saved = controller.document as CampaignDocument;
      expect(saved.selected.route, hasLength(2));
      expect(controller.pendingChanges.hasChanges, isFalse);
      controller.undo();
      expect((controller.document as CampaignDocument).selected.route, isEmpty);
      await controller.exportDirectWrite();
      expect(controller.exportError, isNull);
      expect((controller.document as CampaignDocument).catalog.revision, 3);
      expect(
        (prepared.scenario as CampaignPlaytestScenario).mission.route.length,
        2,
      );
      final current = controller.document as CampaignDocument;
      controller.applyCommand(edit(current, layout(current)));
      final source = File(
        workspace.resolve('assets/authoring/level/tile_defs.json'),
      );
      source.writeAsStringSync('${source.readAsStringSync()}\n');
      final rejected = await plugin.exportToRepo(
        workspace,
        document: controller.document!,
      );
      expect(rejected.outcome, ExportOutcome.sourceDrift);
    },
  );
  test('both copy directions preserve layout and encounters without activating a runner copy', () async {
    final chunkPlugin = ChunkDomainPlugin();
    final doc = await chunkPlugin.loadV2FromRepo(workspace);
    final original = doc.chunks.firstWhere(
      (c) => c.chunkKey == 'forest_rocky_grove_normal_001',
    );
    ChunkV2Document copy(ChunkV2Document d, String key, String usage) =>
        chunkPlugin.applyEdit(
          d,
          AuthoringCommand(
            kind: ChunkDomainPlugin.commitChunkLifecycleCommandKind,
            payload: {
              'commit': ChunkV2LifecycleCommit(
                before: ChunkV2LifecycleSnapshot.fromDocument(d),
                operation: ChunkV2DuplicateOperation(
                  sourceChunkKey: key,
                  targetUsage: usage,
                ),
              ),
            },
          ),
        ) as ChunkV2Document;
    final campaign = copy(doc, original.chunkKey, 'campaign');
    final duplicate = campaign.chunks.firstWhere(
      (c) => c.chunkKey == '${original.chunkKey}_copy',
    );
    expect(duplicate.usage, 'campaign');
    expect(duplicate.revision, 1);
    expect(duplicate.markers, original.markers);
    expect(duplicate.encounters, original.encounters);
    expect(
      ChunkV2FileCodec.encode(
        campaign.chunks.firstWhere((c) => c.chunkKey == original.chunkKey),
      ),
      ChunkV2FileCodec.encode(original),
    );
    final runner = copy(campaign, duplicate.chunkKey, 'runner');
    final back = runner.chunks.firstWhere(
      (c) => c.chunkKey == '${duplicate.chunkKey}_copy',
    );
    final expected = original.toJson()
      ..remove('chunkKey')
      ..remove('id')
      ..remove('revision')
      ..remove('status');
    final actual = back.toJson()
      ..remove('chunkKey')
      ..remove('id')
      ..remove('revision')
      ..remove('status');
    expect(actual, expected);
    expect(back.status, 'deprecated');
    expect(
      (await chunkPlugin.exportToRepo(workspace, document: runner)).applied,
      isTrue,
    );
    final reloaded = await chunkPlugin.loadV2FromRepo(workspace);
    expect(
      reloaded.chunks.firstWhere((c) => c.chunkKey == duplicate.chunkKey).usage,
      'campaign',
    );
  });
  test(
    'referenced chunks cannot be deleted until the mission is rebound',
    () async {
      final document = await plugin.loadFromRepo(workspace) as CampaignDocument;
      final authored = plugin.applyEdit(
        document,
        edit(document, layout(document)),
      );
      expect(
        (await plugin.exportToRepo(workspace, document: authored)).applied,
        isTrue,
      );
      final chunks = ChunkDomainPlugin();
      final source = await chunks.loadV2FromRepo(workspace);
      final deleted = chunks.applyEdit(
        source,
        AuthoringCommand(
          kind: ChunkDomainPlugin.commitChunkLifecycleCommandKind,
          payload: {
            'commit': ChunkV2LifecycleCommit(
              before: ChunkV2LifecycleSnapshot.fromDocument(source),
              operation: const ChunkV2DeleteOperation(
                chunkKey: 'forest_campaign_fixture',
              ),
            ),
          },
        ),
      );
      await expectLater(
        chunks.exportToRepo(workspace, document: deleted),
        throwsA(
          isA<ChunkV2SaveException>().having(
            (e) => e.code,
            'code',
            'chunk_v2_campaign_reference',
          ),
        ),
      );
      expect(
        File(
          workspace.resolve(
            'assets/authoring/level/chunks/forest/forest_campaign_fixture.json',
          ),
        ).existsSync(),
        isTrue,
      );
    },
  );
  testWidgets('campaign workspace exposes editable missions and route tools', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = EditorSessionController(
      pluginRegistry: AuthoringPluginRegistry(plugins: [plugin]),
      initialPluginId: plugin.id,
      initialWorkspacePath: fixture.path,
    );
    addTearDown(controller.dispose);
    await tester.runAsync(controller.loadWorkspace);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CampaignPage(controller: controller)),
      ),
    );
    await _pumpWorkspace(tester);
    expect(find.text('Mission settings'), findsOneWidget);
    expect(find.text('Play mission (F5)'), findsOneWidget);
    await tester.tap(find.text('Mission settings'));
    await _pumpWorkspace(tester);
    expect(find.text('Title (en)'), findsOneWidget);
    expect(find.text('Title (fr)'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await _pumpWorkspace(tester);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'campaign preserves view context across panels, resize and return',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = EditorSessionController(
        pluginRegistry: AuthoringPluginRegistry(plugins: [plugin]),
        initialPluginId: plugin.id,
        initialWorkspacePath: fixture.path,
      );
      addTearDown(controller.dispose);
      await tester.runAsync(controller.loadWorkspace);
      final original = controller.document as CampaignDocument;
      controller.applyCommand(edit(original, layout(original)));
      final pageKey = GlobalKey();
      String? openedChunk;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CampaignPage(
              key: pageKey,
              controller: controller,
              onOpenChunk: (target) async {
                openedChunk = target.chunkKey;
                return false;
              },
            ),
          ),
        ),
      );
      await _pumpWorkspace(tester);
      Future<void> tap(Finder target) async {
        await tester.ensureVisible(target);
        await _pumpWorkspace(tester);
        await tester.tap(target);
        await _pumpWorkspace(tester);
      }

      CampaignLocation location() =>
          (pageKey.currentState as EditorPageNavigationState)
                  .navigationLocation!
              as CampaignLocation;
      await tester.enterText(
        find.widgetWithText(TextField, 'Find chunk'),
        'forest_campaign_fixture',
      );
      await _pumpWorkspace(tester);
      final beforeView = controller.document;
      await tap(
        find.byKey(const ValueKey('campaign_chunk_forest_campaign_fixture')),
      );
      expect(location().selectedChunkKey, 'forest_campaign_fixture');
      final preview = tester.element(
        find.byKey(const ValueKey('campaign_persistent_preview')),
      );
      await tap(find.text('Route'));
      await tap(find.byKey(const ValueKey('campaign_occurrence_first')));
      expect(location().selectedOccurrenceId, 'first');
      expect(controller.document, same(beforeView));
      await tester.binding.setSurfaceSize(const Size(800, 700));
      await _pumpWorkspace(tester);
      expect(
        tester.element(
          find.byKey(const ValueKey('campaign_persistent_preview')),
        ),
        same(preview),
      );
      await tap(find.widgetWithText(Tab, 'Settings'));
      expect(find.text('Selected occurrence'), findsOneWidget);
      expect(find.text('first'), findsOneWidget);
      await tap(find.text('Edit chunk'));
      expect(openedChunk, 'forest_campaign_fixture');
      expect(location().selectedOccurrenceId, 'first');
      await tap(find.text('Mission settings'));
      await tap(find.text('Cancel'));
      await tap(find.widgetWithText(Tab, 'Chapters'));
      expect(find.text('Chapter 1'), findsOneWidget);
      await tap(find.widgetWithText(Tab, 'Workspace'));
      await tap(find.text('Markers'));
      await tap(find.text('Place start / exit / objective'));
      await tap(find.text('Cancel'));
      await tap(find.text('Contents'));
      expect(find.text('forest_campaign_fixture').first, findsOneWidget);
      expect(location().chunkSearch, 'forest_campaign_fixture');
      await tap(find.text('Route'));
      final saved = location();
      await tester.binding.setSurfaceSize(const Size(1600, 900));
      await _pumpWorkspace(tester);
      expect(
        tester.element(
          find.byKey(const ValueKey('campaign_persistent_preview')),
        ),
        same(preview),
      );
      expect(controller.document, same(beforeView));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CampaignPage(
              key: pageKey,
              controller: controller,
              initialLocation: saved,
            ),
          ),
        ),
      );
      await _pumpWorkspace(tester);
      expect(location().tab, CampaignTab.route);
      expect(location().selectedOccurrenceId, 'first');
      expect(location().chunkSearch, 'forest_campaign_fixture');
      // Route actions still act on stable occurrences, including reference guards.
      final first = find.byKey(const ValueKey('campaign_occurrence_first'));
      await tap(
        find.descendant(
          of: first,
          matching: find.byTooltip('Duplicate occurrence'),
        ),
      );
      expect(
        (controller.document as CampaignDocument).selected.route.map(
          (o) => o.id,
        ),
        ['first', 'occurrence_1', 'second'],
      );
      expect(location().selectedOccurrenceId, 'occurrence_1');
      final copy = find.byKey(
        const ValueKey('campaign_occurrence_occurrence_1'),
      );
      await tap(
        find.descendant(of: copy, matching: find.byTooltip('Move left')),
      );
      expect(
        (controller.document as CampaignDocument).selected.route.first.id,
        'occurrence_1',
      );
      await tap(
        find.descendant(
          of: copy,
          matching: find.byTooltip('Remove occurrence'),
        ),
      );
      expect(
        (controller.document as CampaignDocument).selected.route,
        hasLength(2),
      );
      expect(location().selectedOccurrenceId, isNull);
      await tap(
        find.descendant(
          of: first,
          matching: find.byTooltip('Remove occurrence'),
        ),
      );
      expect(
        (controller.document as CampaignDocument).selected.route,
        hasLength(2),
      );
      expect(
        find.text(
          'Remove or replace the mission markers on this occurrence first.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('chapters collapse, create and reveal selected missions', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = EditorSessionController(
      pluginRegistry: AuthoringPluginRegistry(plugins: [plugin]),
      initialPluginId: plugin.id,
      initialWorkspacePath: fixture.path,
    );
    addTearDown(controller.dispose);
    await tester.runAsync(controller.loadWorkspace);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CampaignPage(controller: controller)),
      ),
    );
    await _pumpWorkspace(tester);
    Future<void> tap(Finder finder) async {
      await tester.ensureVisible(finder);
      await _pumpWorkspace(tester);
      await tester.tap(finder);
      await _pumpWorkspace(tester);
    }

    Future<void> fill(String label, String value) async {
      final field = find.widgetWithText(TextFormField, label);
      await tester.ensureVisible(field);
      await _pumpWorkspace(tester);
      await tester.enterText(field, value);
    }

    await tap(find.text('Chapter 1'));
    expect(find.text('1. Reporting for Duty'), findsNothing);
    expect(controller.pendingChanges.hasChanges, isFalse);
    await tester.drag(
      find.byKey(const ValueKey('campaign_library')),
      const Offset(0, 500),
    );
    await _pumpWorkspace(tester);
    await tap(find.text('Create chapter'));
    await tap(find.text('Cancel'));
    expect(
      (controller.document as CampaignDocument).catalog.chapters,
      hasLength(1),
    );
    await tap(find.text('Create chapter'));
    await tap(find.text('Create'));
    expect(find.text('Required.'), findsWidgets);
    await fill('Chapter title (en)', 'North Pass');
    await fill('Chapter title (fr)', 'Col du Nord');
    await fill('Map X (left 0 → right 1)', '2');
    await tap(find.text('Create'));
    expect(find.text('Enter a position from 0 to 1.'), findsOneWidget);
    await fill('Map X (left 0 → right 1)', '0.3');
    await tap(find.text('Create'));
    var document = controller.document as CampaignDocument;
    expect(document.catalog.chapters, hasLength(2));
    expect(document.catalog.chapters.last.mapX, 0.3);
    expect(
      document.selected.id,
      document.catalog.chapters.last.missions.single.id,
    );
    final section = find.byKey(const ValueKey('north_pass'));
    expect(section, findsOneWidget);
    Finder inside(String text) =>
        find.descendant(of: section, matching: find.text(text));
    expect(inside('1. Mission 1'), findsOneWidget);
    await tap(inside('Add mission'));
    document = controller.document as CampaignDocument;
    expect(document.catalog.chapters.last.missions, hasLength(2));
    expect(
      document.selected.id,
      document.catalog.chapters.last.missions.last.id,
    );
    await tap(inside('Chapter settings'));
    await fill('Chapter title (en)', 'Northern Pass');
    await tap(find.text('Apply'));
    expect(inside('Northern Pass'), findsOneWidget);
    expect(
      (controller.document as CampaignDocument).catalog.chapters.last.id,
      'north_pass',
    );
    await tap(find.text('Chapter 2'));
    expect(inside('1. Mission 1'), findsNothing);
    controller.applyCommand(
      AuthoringCommand(
        kind: CampaignDomainPlugin.selectMission,
        payload: {'id': document.catalog.chapters.last.missions.first.id},
      ),
    );
    await _pumpWorkspace(tester);
    expect(inside('1. Mission 1'), findsOneWidget);
    await tester.drag(
      find.byKey(const ValueKey('campaign_library')),
      const Offset(0, 900),
    );
    await _pumpWorkspace(tester);
    expect(find.text('Chapter 1'), findsOneWidget);
    expect(find.text('1. Reporting for Duty'), findsNothing);
    controller.applyCommand(
      AuthoringCommand(
        kind: CampaignDomainPlugin.selectMission,
        payload: {'id': 'reporting_for_duty'},
      ),
    );
    await _pumpWorkspace(tester);
    expect(find.text('1. Reporting for Duty'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'reward selectors apply, clear and cancel through the workspace',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = EditorSessionController(
        pluginRegistry: AuthoringPluginRegistry(plugins: [plugin]),
        initialPluginId: plugin.id,
        initialWorkspacePath: fixture.path,
      );
      addTearDown(controller.dispose);
      await tester.runAsync(controller.loadWorkspace);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: CampaignPage(controller: controller)),
        ),
      );
      await _pumpWorkspace(tester);
      CampaignDocument document() => controller.document as CampaignDocument;

      Future<void> open(String button) async {
        await tester.tap(find.text(button));
        await _pumpWorkspace(tester);
      }

      Future<void> choose(String label, String choice) async {
        final field = find.ancestor(
          of: find.text(label),
          matching: find.byType(DropdownButtonFormField<String>),
        );
        await tester.ensureVisible(field);
        await tester.tap(field);
        await _pumpWorkspace(tester);
        await tester.tap(find.text(choice).last);
        await _pumpWorkspace(tester);
      }

      await open('Mission settings');
      await choose('First-clear ability', 'None');
      await open('Cancel');
      expect(document().selected.rewardAbilityId, 'eloise.double_jump');
      expect(controller.pendingChanges.hasChanges, isFalse);

      await open('Mission settings');
      await choose('First-clear ability', 'None');
      await open('Apply');
      expect(document().selected.rewardAbilityId, isNull);
      await open('Mission settings');
      await choose('First-clear ability', 'Éloïse — Double Jump');
      await open('Apply');
      expect(document().selected.rewardAbilityId, 'eloise.double_jump');

      final beforeCancel = document();
      await open('Chapter rewards');
      await choose('Completion character', 'None');
      await open('Cancel');
      expect(document(), same(beforeCancel));
      await open('Chapter rewards');
      await choose('Completion character', 'None');
      await open('Apply');
      expect(document().catalog.chapters.first.rewardCharacterId, isNull);
      expect(find.text('Chapter reward: None · 224 XP'), findsOneWidget);
      await open('Chapter rewards');
      await choose('Completion character', 'Willow');
      await open('Apply');
      expect(
        document().catalog.chapters.first.rewardCharacterId,
        'bountyHunter',
      );
      expect(find.text('Chapter reward: Willow · 224 XP'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

// Authored water previews animate continuously. Advance UI transitions without
// waiting for those independent preview tickers to settle.
Future<void> _pumpWorkspace(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pump();
}
