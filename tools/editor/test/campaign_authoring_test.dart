import 'dart:convert';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runner_content_pipeline/runner_content_pipeline.dart';
import 'package:runner_editor/src/app/pages/campaign/campaign_overview.dart';
import 'package:runner_editor/src/app/pages/campaign/campaign_marker_painter.dart';
import 'package:runner_editor/src/app/pages/chunkCreator/v2/chunk_actor_terrain_overlay_painter.dart';
import 'package:runner_editor/src/chunks/chunk_v2_actor_terrain_projection.dart';
import 'package:runner_editor/src/app/pages/shared/editor_zoom_controls.dart';
import 'package:runner_editor/src/app/pages/campaign/campaign_page.dart';
import 'package:runner_editor/src/app/pages/campaign/campaign_marker_palette.dart';
import 'package:runner_editor/src/app/pages/campaign/campaign_marker_editing.dart';
import 'package:runner_core/campaign/campaign_mission_definition.dart';
import 'package:runner_editor/src/app/pages/shared/editor_page_local_draft_state.dart';
import 'package:runner_editor/src/campaign/campaign_marker_edit.dart';
import 'package:runner_editor/src/app/pages/chunkCreator/v2/chunk_composition_preview.dart';
import 'package:runner_editor/src/app/pages/chunkCreator/v2/chunk_mode_copy_dialog.dart';
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
    // Preview image reads can still be closing on Windows after unmount.
    for (var attempt = 0; ; attempt++) {
      try {
        await fixture.delete(recursive: true);
        break;
      } on FileSystemException catch (error) {
        if (error.osError?.errorCode != 32 || attempt >= 9) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }
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
    ..remove('placements')
    ..['collectibles'] = []
    ..['requiredRegions'] = []
    ..['requiredEnemies'] = []
    ..['requiredRescues'] = []
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

  AuthoringCommand chapterReward(
    CampaignDocument d,
    String? reward, {
    int xp = 0,
    int gold = 0,
    List<Map<String, Object>> items = const [],
  }) => AuthoringCommand(
    kind: CampaignDomainPlugin.setChapterReward,
    payload: {
      'id': d.catalog.chapters.first.id,
      'expectedRewards': d.catalog.chapters.first.rewardsToJson(),
      'rewards': {
        ...d.catalog.chapters.first.rewardsToJson(),
        'rewardCharacterId': reward,
        'rewardXp': xp,
        'rewardGold': gold,
        'rewardItems': items,
      },
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
      chapterReward(
        controller.document as CampaignDocument,
        null,
        xp: 75,
        gold: 250,
        items: [
          {'kind': 'gear', 'slot': 'mainWeapon', 'itemId': 'cinderedge'},
        ],
      ),
    );
    await controller.exportDirectWrite();
    expect(controller.exportError, isNull);
    expect(controller.pendingChanges.hasChanges, isFalse);
    final reopened = await plugin.loadFromRepo(workspace) as CampaignDocument;
    expect(reopened.selected.firstClearXp, 55);
    expect(reopened.selected.rewardAbilityId, isNull);
    expect(reopened.catalog.chapters.first.rewardCharacterId, isNull);
    expect(reopened.catalog.chapters.first.rewardXp, 75);
    expect(reopened.catalog.chapters.first.rewardGold, 250);
    expect(
      reopened.catalog.chapters.first.rewardItems.single.item.itemId,
      'cinderedge',
    );
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
    expect(restored.catalog.chapters.first.rewardXp, 0);
    expect(restored.catalog.chapters.first.rewardItems, isEmpty);
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
      expect(
        (controller.document as CampaignDocument).selected.route,
        original.selected.route,
      );
      await controller.exportDirectWrite();
      expect(controller.exportError, isNull);
      expect(
        (controller.document as CampaignDocument).catalog.revision,
        original.catalog.revision + 2,
      );
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
  for (final usage in ['campaign', 'runner']) {
    test(
      'copy to $usage names a layout without combat content and preserves the source',
      () async {
        final chunkPlugin = ChunkDomainPlugin();
        var doc = await chunkPlugin.loadV2FromRepo(workspace);
        final sources = [
          doc.chunks.firstWhere(
            (c) => c.markers.isNotEmpty && c.waterRegions.isNotEmpty,
          ),
          doc.chunks.firstWhere((c) => c.encounters.isNotEmpty),
          doc.chunks.firstWhere((c) => c.bossArena != null),
          doc.chunks.firstWhere((c) => c.traps.isNotEmpty),
        ];
        if (usage == 'runner') {
          for (final source in sources) {
            File(workspace.resolve(doc.sourcePathByChunkKey[source.chunkKey]!))
                .writeAsStringSync(
                  ChunkV2FileCodec.encode(source.copyWith(usage: 'campaign')),
                );
          }
          doc = await chunkPlugin.loadV2FromRepo(workspace);
        }
        ChunkV2Document copy(
          ChunkV2Document d,
          String key,
          String name, {
          String? targetUsage,
        }) => chunkPlugin.applyEdit(
          d,
          AuthoringCommand(
            kind: ChunkDomainPlugin.commitChunkLifecycleCommandKind,
            payload: {
              'commit': ChunkV2LifecycleCommit(
                before: ChunkV2LifecycleSnapshot.fromDocument(d),
                operation: ChunkV2DuplicateOperation(
                  sourceChunkKey: key,
                  targetId: name,
                  targetUsage: targetUsage,
                ),
              ),
            },
          ),
        ) as ChunkV2Document;
        final expectedCopies = <String, String>{};
        for (final source in sources) {
          final original = doc.chunks.firstWhere(
            (c) => c.chunkKey == source.chunkKey,
          );
          final name = 'custom_${usage}_${source.chunkKey}';
          doc = copy(doc, original.chunkKey, name, targetUsage: usage);
          final duplicate = doc.chunks.firstWhere((c) => c.chunkKey == name);
          final expected = original.copyWith(
            chunkKey: name,
            id: name,
            revision: 1,
            usage: usage,
            status: usage == 'runner' ? 'deprecated' : 'active',
            markers: [],
            encounters: [],
            traps: [],
            clearBossArena: true,
          );
          expect(duplicate.markers, isEmpty);
          expect(duplicate.encounters, isEmpty);
          expect(duplicate.traps, isEmpty);
          expect(duplicate.bossArena, isNull);
          expect(duplicate.toJson(), expected.toJson());
          expectedCopies[name] = ChunkV2FileCodec.encode(expected);
          expect(
            ChunkV2FileCodec.encode(
              doc.chunks.firstWhere((c) => c.chunkKey == original.chunkKey),
            ),
            ChunkV2FileCodec.encode(original),
          );

          final ordinaryName = '${name}_full';
          doc = copy(doc, original.chunkKey, ordinaryName);
          final ordinary = doc.chunks.firstWhere(
            (c) => c.chunkKey == ordinaryName,
          );
          expect(ordinary.markers, original.markers);
          expect(ordinary.encounters, original.encounters);
          expect(ordinary.bossArena, original.bossArena);
          expect(ordinary.traps, original.traps);
        }
        expect(
          (await chunkPlugin.exportToRepo(workspace, document: doc)).applied,
          isTrue,
        );
        final reloaded = await chunkPlugin.loadV2FromRepo(workspace);
        for (final entry in expectedCopies.entries) {
          expect(
            ChunkV2FileCodec.encode(
              reloaded.chunks.firstWhere((c) => c.chunkKey == entry.key),
            ),
            entry.value,
          );
        }
      },
    );
  }

  testWidgets('mode copy dialog validates and submits an editable chunk name', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final doc = (await tester.runAsync(
      () => ChunkDomainPlugin().loadV2FromRepo(workspace),
    ))!;
    final source = doc.chunks.first;
    ChunkV2DuplicateOperation? result;
    for (final sourceUsage in ['runner', 'campaign']) {
      result = null;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await showDialog<ChunkV2DuplicateOperation>(
                    context: context,
                    builder: (_) => ChunkModeCopyDialog(
                      document: doc,
                      source: source.copyWith(usage: sourceUsage),
                    ),
                  );
                },
                child: const Text('Copy chunk'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Copy chunk'));
      await tester.pumpAndSettle();
      final nameField = find.byKey(const ValueKey('chunk_mode_copy_name'));
      expect(
        tester.widget<TextFormField>(nameField).controller!.text,
        const ChunkV2LifecycleCommitPolicy().suggestCopyKey(
          doc,
          source.chunkKey,
        ),
      );
      for (final invalidName in [
        '',
        'Invalid name',
        '1_invalid',
        source.chunkKey,
      ]) {
        await tester.enterText(nameField, invalidName);
        await tester.tap(find.text('Create editable copy'));
        await tester.pumpAndSettle();
        expect(find.byType(ChunkModeCopyDialog), findsOneWidget);
        expect(result, isNull);
      }
      await tester.enterText(nameField, 'custom_mission_chunk');
      await tester.tap(find.text('Create editable copy'));
      await tester.pumpAndSettle();
      expect(find.byType(ChunkModeCopyDialog), findsNothing);
      expect(result!.targetId, 'custom_mission_chunk');
      expect(
        result!.targetUsage,
        sourceUsage == 'runner' ? 'campaign' : 'runner',
      );
    }
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
  test('every palette brush persists locally with identity-safe moves, history and stale rejection', () async {
    final session = EditorSessionController(
      pluginRegistry: AuthoringPluginRegistry(plugins: [plugin]),
      initialPluginId: plugin.id,
      initialWorkspacePath: fixture.path,
    );
    addTearDown(session.dispose);
    await session.loadWorkspace();
    final original = session.document as CampaignDocument;
    final otherMission = original.catalog.missions.last.toJson();
    session.applyCommand(
      edit(original, layout(original)..['combatAllowed'] = true),
    );
    final initial = session.document as CampaignDocument;
    final chunks = {
      for (final c in initial.compile(initial.selected).chunks)
        c.pattern.chunkKey!: c,
    };
    final editing = CampaignMarkerEditing(session);
    void bind() => editing.bind(session.document as CampaignDocument, chunks);
    bind();
    session.addListener(bind);
    addTearDown(() {
      session.removeListener(bind);
      editing.dispose();
    });
    for (final (brush, x, y) in [
      (CampaignMarkerBrush.gold, 120.0, 208.0),
      (CampaignMarkerBrush.health, 160.0, 208.0),
      (CampaignMarkerBrush.mana, 200.0, 208.0),
      (CampaignMarkerBrush.stamina, 240.0, 208.0),
      (CampaignMarkerBrush.shrine, 280.0, 224.0),
      (CampaignMarkerBrush.enemy, 320.0, 224.0),
      (CampaignMarkerBrush.trap, 500.0, 224.0),
      (CampaignMarkerBrush.rescue, 360.0, 144.0),
    ]) {
      editing.choose(brush);
      final candidate = editing.create(
        CampaignPoint(occurrenceId: 'first', x: x, y: y),
      );
      expect(editing.commit(null, candidate), isNull, reason: brush.name);
    }
    expect(editing.mission.placements, hasLength(8));
    expect(
      () => editing.document.compile(editing.mission),
      throwsFormatException,
    );
    editing.addRescueMember(npc: true);
    editing.addRescueMember(npc: false);
    expect(
      editing.document
          .compile(editing.mission)
          .definition
          .route
          .occurrences
          .first
          .pattern
          .encounters,
      hasLength(1),
    );
    final coin = editing.entries.firstWhere(
      (e) => e.placement is CampaignPickupSource,
    );
    final stale = editing.mission;
    final moved = editing.move(
      coin,
      CampaignPoint(occurrenceId: 'second', x: 120, y: 208),
    );
    expect(editing.commit(coin, moved), isNull);
    expect(editing.commit(moved, coin, expected: stale), contains('changed'));
    editing.select(coin.key);
    editing.duplicate();
    expect(editing.mission.placements, hasLength(9));
    editing.delete();
    expect(editing.mission.placements, hasLength(8));
    session.undo();
    expect(editing.mission.placements, hasLength(9));
    session.redo();
    expect(editing.mission.placements, hasLength(8));
    await session.exportDirectWrite();
    expect(session.exportError, isNull);
    final reopened = await plugin.loadFromRepo(workspace) as CampaignDocument;
    expect(
      reopened.selected.placements.map((p) => p.toJson()),
      editing.mission.placements.map((p) => p.toJson()),
    );
    expect(reopened.catalog.missions.last.toJson(), otherMission);
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets(
    'visual coins and attached fires support drag, draft Save, undo and reopen',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 1000));
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
      final chunkBytes = File(
        '${fixture.path}/assets/authoring/level/chunks/forest/forest_campaign_fixture.json',
      ).readAsStringSync();
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CampaignPage(
              key: key,
              controller: controller,
              initialLocation: CampaignLocation(
                original.selected.id,
                tab: CampaignTab.markers,
              ),
            ),
          ),
        ),
      );
      await _pumpWorkspace(tester);
      final palette = tester.widget<CampaignMarkerPalette>(
        find.byType(CampaignMarkerPalette),
      );
      final scene = find.byKey(const ValueKey('campaign_preview_first'));
      Offset point(double x, double y) =>
          tester.getTopLeft(scene) +
          Offset(x, y) * (tester.getSize(scene).height / 270);
      Future<void> brush(String id) async {
        final finder = find.byKey(ValueKey('campaign_brush_$id'));
        await tester.ensureVisible(finder);
        await tester.tap(finder);
        await _pumpWorkspace(tester);
      }

      CampaignMissionSource mission() =>
          (controller.document as CampaignDocument).selected;
      await brush('gold');
      await tester.tapAt(point(160, 200));
      await _pumpWorkspace(tester);
      expect(mission().placements.single, isA<CampaignPickupSource>());
      final coinId = mission().placements.single.id;
      palette.editing.select('placement:$coinId');
      await _pumpWorkspace(tester);
      await tester.dragFrom(
        point(160, 200),
        Offset(32, 0) * (tester.getSize(scene).height / 270),
      );
      await _pumpWorkspace(tester);
      expect(mission().placements.single.position.x, 192);
      final shortcuts = key.currentState as EditorPageSessionShortcutHandler;
      shortcuts.handleUndoSessionShortcut();
      await _pumpWorkspace(tester);
      expect(mission().placements.single.position.x, 160);
      shortcuts.handleRedoSessionShortcut();
      await _pumpWorkspace(tester);
      expect(mission().placements.single.position.x, 192);
      final beforeCancelledDrag = controller.document;
      final gesture = await tester.startGesture(point(192, 200));
      await gesture.moveBy(const Offset(30, 0));
      await tester.pump();
      expect(
        (key.currentState as EditorPageLocalDraftState).hasLocalDraftChanges,
        isTrue,
      );
      expect(
        await (key.currentState as EditorPageSaveHandler).saveEditorPage(),
        EditorPageSaveResult.blocked,
      );
      (key.currentState as EditorPagePlaytestHandler).handlePlaytestShortcut(
        LogicalKeyboardKey.escape,
      );
      await gesture.up();
      await _pumpWorkspace(tester);
      expect(controller.document, same(beforeCancelledDrag));
      await tester.enterText(
        find.byKey(const ValueKey('campaign_marker_x')),
        'not a number',
      );
      await _pumpWorkspace(tester);
      expect(
        (key.currentState as EditorPageLocalDraftState).hasLocalDraftChanges,
        isTrue,
      );
      expect(
        await (key.currentState as EditorPageSaveHandler).saveEditorPage(),
        EditorPageSaveResult.blocked,
      );
      await _pumpWorkspace(tester);
      expect(mission().placements.single.position.x, 192);
      await tester.enterText(
        find.byKey(const ValueKey('campaign_marker_x')),
        '208',
      );
      await _pumpWorkspace(tester);
      await brush('shrine'); // Changing tools resolves valid field input.
      expect(mission().placements.single.position.x, 208);
      await tester.tapAt(point(320, 224));
      await _pumpWorkspace(tester);
      final shrine = mission().placements
          .whereType<CampaignShrineSource>()
          .single;
      expect(shrine.position.y, 224);
      expect(shrine.prefabKey, isNull);
      expect(
        (controller.document as CampaignDocument)
            .compile(mission())
            .definition
            .interactions,
        hasLength(1),
      );
      await tester.tapAt(point(400, 100));
      await _pumpWorkspace(tester);
      expect(mission().placements, hasLength(2));
      expect(palette.editing.error, contains('flat'));
      palette.editing.cancel();
      final save = await tester.runAsync(
        () => (key.currentState as EditorPageSaveHandler).saveEditorPage(),
      );
      await _pumpWorkspace(tester);
      expect(save, EditorPageSaveResult.saved);
      final reopened = await tester.runAsync(
        () => plugin.loadFromRepo(workspace),
      );
      expect(
        (reopened as CampaignDocument).selected.placements.map(
          (p) => p.toJson(),
        ),
        mission().placements.map((p) => p.toJson()),
      );
      expect(
        File(
          '${fixture.path}/assets/authoring/level/chunks/forest/forest_campaign_fixture.json',
        ).readAsStringSync(),
        chunkBytes,
      );
      final duplicated = CampaignMissionSource.decode(
        duplicateCampaignOccurrence(mission(), 0),
      );
      expect(duplicated.placements, hasLength(4));
      expect(duplicated.placements.map((p) => p.id).toSet(), hasLength(4));
      expect(duplicated.placements.last.occurrenceId, 'occurrence_1');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      // Let real image I/O close after the Save-triggered preview remount.
      for (var i = 0; i < 8; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
      }
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
      final runner = original.chunks.chunks.firstWhere(
        (chunk) => chunk.usage == 'runner',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Find chunk'),
        runner.chunkKey,
      );
      await _pumpWorkspace(tester);
      expect(
        find.byKey(ValueKey('campaign_chunk_${runner.chunkKey}')),
        findsNothing,
      );
      expect(
        find.text('No campaign chunks match this search.'),
        findsOneWidget,
      );
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
      await tap(find.widgetWithText(Tab, 'Authoring'));
      await tap(find.text('Shared chunk objectives'));
      await tester.scrollUntilVisible(
        find.text('Link a shared enemy / rescue objective'),
        250,
        scrollable: find
            .descendant(
              of: find.byKey(const PageStorageKey('campaign_markers_scroll')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tap(find.text('Link a shared enemy / rescue objective'));
      await tap(find.text('Cancel'));
      await tap(find.widgetWithText(Tab, 'Workspace'));
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

  testWidgets(
    'marker scene shares tools, preserves view state and gates visual preview',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 1000));
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
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CampaignPage(
              key: key,
              controller: controller,
              initialLocation: CampaignLocation(
                original.selected.id,
                tab: CampaignTab.markers,
              ),
            ),
          ),
        ),
      );
      await _pumpWorkspace(tester);
      Future<void> tap(Finder target) async {
        await tester.ensureVisible(target);
        await tester.tap(target);
        await _pumpWorkspace(tester);
      }

      final overview = find.byType(CampaignOverview);
      final overviewState = tester.state(overview);
      final canvas = find.byKey(const ValueKey('campaign_route_canvas'));
      final palette = tester.widget<CampaignMarkerPalette>(
        find.byType(CampaignMarkerPalette),
      );
      final canvasRect = tester.getRect(canvas);
      expect(canvasRect.height, greaterThan(450));
      expect(
        tester.getRect(find.byType(CampaignMarkerPalette)).left,
        greaterThan(canvasRect.right),
      );
      expect(
        tester
            .getRect(find.byKey(const ValueKey('campaign_marker_tool_place')))
            .bottom,
        lessThan(canvasRect.top),
      );
      final beforeView = controller.document;
      final scrollbar = find.descendant(
        of: overview,
        matching: find.byType(Scrollbar),
      );
      final horizontal = tester.widget<Scrollbar>(scrollbar).controller!;
      final first = find.byKey(const ValueKey('campaign_preview_first'));
      CampaignMarkerPainter markers() =>
          tester.widget<CustomPaint>(first).foregroundPainter!
              as CampaignMarkerPainter;
      final grid = find.byKey(const ValueKey('campaign_show_grid_toggle'));
      expect(markers().showGrid, isFalse);
      await tap(grid);
      expect(markers().showGrid, isTrue);
      expect(palette.editing.snap, isTrue);
      await tap(find.text('Snap 8 px'));
      expect(palette.editing.snap, isFalse);
      expect(markers().showGrid, isTrue);

      await tap(find.byKey(const ValueKey('campaign_actor_terrain_toggle')));
      final overlay = find.byKey(
        const ValueKey('campaign_actor_terrain_overlay'),
      );
      ChunkActorTerrainOverlayPainter terrain() =>
          tester.widget<CustomPaint>(overlay.first).painter!
              as ChunkActorTerrainOverlayPainter;
      expect(terrain().actor, ChunkV2TerrainActor.eloise);
      expect(
        terrain().projection
            .groundedView(ChunkV2TerrainActor.eloise)!
            .eligibleSurfaces,
        isNotEmpty,
      );
      final projection = terrain().projection;
      await tap(find.byKey(const ValueKey('campaign_actor_terrain_selector')));
      await tap(find.text('Grojib').last);
      expect(terrain().actor, ChunkV2TerrainActor.grojib);
      expect(terrain().projection, same(projection));

      final zoom = find.byType(EditorZoomControls);
      final zoomField = find.descendant(
        of: zoom,
        matching: find.byType(TextField),
      );
      await tester.enterText(zoomField, '150');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await _pumpWorkspace(tester);
      horizontal.jumpTo(100);
      await _pumpWorkspace(tester);
      await tap(find.byKey(const ValueKey('campaign_marker_tool_move')));
      expect(horizontal.offset, 100);
      expect(tester.widget<EditorZoomControls>(zoom).value, 1.5);
      await tap(find.byKey(const ValueKey('campaign_visual_preview_toggle')));
      expect(tester.widget<CustomPaint>(first).foregroundPainter, isNull);
      expect(overlay, findsNothing);
      await tester.tapAt(tester.getCenter(canvas));
      (key.currentState as EditorPagePlaytestHandler).handlePlaytestShortcut(
        LogicalKeyboardKey.delete,
      );
      await _pumpWorkspace(tester);
      expect(controller.document, same(beforeView));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.dragFrom(
        tester.getCenter(canvas),
        const Offset(-70, 0),
        kind: PointerDeviceKind.mouse,
      );
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await _pumpWorkspace(tester);
      expect(horizontal.offset, greaterThan(100));
      await tap(find.byKey(const ValueKey('campaign_visual_preview_toggle')));
      expect(markers().showGrid, isTrue);
      expect(terrain().actor, ChunkV2TerrainActor.grojib);
      expect(palette.editing.tool, CampaignMarkerTool.move);
      await tap(find.text('Route'));
      await tap(find.text('Contents'));
      await tap(find.text('Markers'));
      expect(tester.state(overview), same(overviewState));
      expect(tester.widget<EditorZoomControls>(zoom).value, 1.5);
      expect(palette.editing.tool, CampaignMarkerTool.move);
      expect(terrain().actor, ChunkV2TerrainActor.grojib);
      expect(controller.document, same(beforeView));

      palette.editing.select('start');
      await _pumpWorkspace(tester);
      final x = find.byKey(const ValueKey('campaign_marker_x'));
      await tester.ensureVisible(x);
      await tester.enterText(x, 'invalid');
      await tap(find.byKey(const ValueKey('campaign_visual_preview_toggle')));
      expect(tester.widget<CampaignOverview>(overview).visualPreview, isFalse);
      await tap(find.byKey(const ValueKey('campaign_marker_tool_place')));
      expect(palette.editing.tool, CampaignMarkerTool.select);
      await tester.binding.setSurfaceSize(const Size(800, 700));
      await _pumpWorkspace(tester);
      await tap(find.widgetWithText(Tab, 'Authoring'));
      expect(tester.widget<TextFormField>(x).controller!.text, 'invalid');
      await tester.enterText(x, '72');
      await tap(find.widgetWithText(Tab, 'Workspace'));
      await tap(find.byKey(const ValueKey('campaign_visual_preview_toggle')));
      expect(tester.widget<CampaignOverview>(overview).visualPreview, isTrue);
      expect((controller.document as CampaignDocument).selected.start!.x, 72);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'route preview fills its height and scrolls through all 16 occurrences',
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
      final mission = layout(original)
        ..['route'] = [
          for (var i = 0; i < 16; i++)
            {
              'id': 'route_$i',
              'levelId': 'forest',
              'chunkKey': 'forest_campaign_fixture',
            },
        ]
        ..['start'] = {'occurrenceId': 'route_0', 'x': 60, 'y': 224}
        ..['exit'] = {
          'origin': {'occurrenceId': 'route_15', 'x': 500, 'y': 0},
          'width': 100,
          'height': 270,
        };
      controller.applyCommand(edit(original, mission));
      final beforeView = controller.document;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CampaignPage(
              controller: controller,
              initialLocation: CampaignLocation(
                original.selected.id,
                tab: CampaignTab.route,
              ),
            ),
          ),
        ),
      );
      await _pumpWorkspace(tester);
      final overview = find.byType(CampaignOverview);
      final scrollbar = find.descendant(
        of: overview,
        matching: find.byType(Scrollbar),
      );
      final scrollController = tester.widget<Scrollbar>(scrollbar).controller!;
      Finder occurrence(int index) =>
          find.byKey(ValueKey('campaign_preview_route_$index'));
      final firstSize = tester.getSize(occurrence(0));
      expect(firstSize.height, greaterThan(200));
      expect(firstSize.width / firstSize.height, closeTo(600 / 270, .001));
      final art = find.descendant(
        of: occurrence(0),
        matching: find.byType(ChunkCompositionPreview),
      );
      expect(tester.getSize(art), firstSize);
      final firstOverlay = tester
          .widget<CustomPaint>(occurrence(0))
          .foregroundPainter!;
      expect(
        (Canvas canvas) => firstOverlay.paint(canvas, firstSize),
        paints
          ..scale(x: firstSize.height / 270)
          ..circle(x: 60, y: 224, color: Colors.lightBlueAccent),
      );
      expect(occurrence(15), findsNothing);

      // Use the visible scrollbar, proving that desktop users can reach the end.
      final barRect = tester.getRect(scrollbar);
      await tester.dragFrom(
        Offset(barRect.left + 10, barRect.bottom - 3),
        Offset(barRect.width - 20, 0),
        kind: PointerDeviceKind.mouse,
      );
      await _pumpWorkspace(tester);
      expect(occurrence(15).hitTestable(), findsOneWidget);
      expect(
        scrollController.offset,
        closeTo(scrollController.position.maxScrollExtent, 1),
      );
      final lastSize = tester.getSize(occurrence(15));
      final lastOverlay = tester
          .widget<CustomPaint>(occurrence(15))
          .foregroundPainter!;
      expect(
        (Canvas canvas) => lastOverlay.paint(canvas, lastSize),
        paints..rect(rect: const Rect.fromLTWH(500, 0, 100, 270)),
      );
      expect(
        (Canvas canvas) => lastOverlay.paint(canvas, lastSize),
        paintsExactlyCountTimes(#drawCircle, 0),
      );

      final offset = scrollController.offset;
      await tester.tap(find.text('Markers'));
      await _pumpWorkspace(tester);
      expect(scrollController.offset, offset);
      await tester.binding.setSurfaceSize(const Size(800, 700));
      await _pumpWorkspace(tester);
      scrollController.jumpTo(scrollController.position.maxScrollExtent);
      await _pumpWorkspace(tester);
      expect(occurrence(15).hitTestable(), findsOneWidget);
      final resized = tester.getSize(occurrence(15));
      expect(resized.height, greaterThan(0));
      expect(
        tester
            .getBottomRight(find.byKey(const ValueKey('campaign_route_canvas')))
            .dy,
        lessThanOrEqualTo(700),
      );
      expect(resized.width / resized.height, closeTo(600 / 270, .001));
      expect(controller.document, same(beforeView));
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
    final firstId = document.catalog.chapters.last.missions.first.id;
    final lastId = document.catalog.chapters.last.missions.last.id;
    Finder reorder(String id, IconData icon) => find.descendant(
      of: find.byKey(ValueKey('campaign_mission_$id')),
      matching: find.widgetWithIcon(IconButton, icon),
    );
    expect(
      tester.widget<IconButton>(reorder(firstId, Icons.arrow_upward)).onPressed,
      isNull,
    );
    expect(
      tester
          .widget<IconButton>(reorder(lastId, Icons.arrow_downward))
          .onPressed,
      isNull,
    );
    await tap(reorder(firstId, Icons.arrow_downward));
    final reordered = controller.document as CampaignDocument;
    expect(reordered.catalog.chapters.last.missions.map((m) => m.id), [
      lastId,
      firstId,
    ]);
    expect(reordered.selected.id, lastId);
    expect(
      tester
          .widget<IconButton>(reorder(firstId, Icons.arrow_downward))
          .onPressed,
      isNull,
    );
    await tap(reorder(firstId, Icons.arrow_upward));
    expect(
      (controller.document as CampaignDocument).catalog.chapters.last.missions
          .map((m) => m.id),
      [firstId, lastId],
    );
    controller.undo();
    await _pumpWorkspace(tester);
    expect(
      (controller.document as CampaignDocument).catalog.chapters.last.missions
          .map((m) => m.id),
      [lastId, firstId],
    );
    controller.redo();
    await _pumpWorkspace(tester);
    expect(
      (controller.document as CampaignDocument).catalog.chapters.last.missions
          .map((m) => m.id),
      [firstId, lastId],
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
      expect(
        find.text('Chapter rewards: 0 XP · 0 gold · 0 items · No character'),
        findsOneWidget,
      );
      await open('Chapter rewards');
      await choose('Completion character', 'Willow');
      await open('Apply');
      expect(
        document().catalog.chapters.first.rewardCharacterId,
        'bountyHunter',
      );
      expect(
        find.text('Chapter rewards: 0 XP · 0 gold · 0 items · Willow'),
        findsOneWidget,
      );
      await open('Chapter rewards');
      Future<void> amount(String label, String value) async {
        final field = find.widgetWithText(TextFormField, label);
        await tester.ensureVisible(field);
        await tester.enterText(field, value);
      }

      await amount('Completion XP', '-1');
      await open('Apply');
      expect(
        find.text('Enter a whole number from 0 to 100000.'),
        findsOneWidget,
      );
      await amount('Completion XP', '75');
      await amount('Completion gold', '250');
      final search = find.byKey(const Key('catalog-search'));
      await tester.ensureVisible(search);
      await tester.enterText(search, 'cinderedge');
      await _pumpWorkspace(tester);
      final card = find.byKey(const ValueKey('gear/mainWeapon/cinderedge/'));
      await tester.ensureVisible(card);
      await tester.tap(card);
      await _pumpWorkspace(tester);
      await open('Apply');
      final rewards = document().catalog.chapters.first;
      expect(rewards.rewardXp, 75);
      expect(rewards.rewardGold, 250);
      expect(rewards.rewardItems.single.item.itemId, 'cinderedge');
      controller.undo();
      expect(document().catalog.chapters.first.rewardItems, isEmpty);
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
