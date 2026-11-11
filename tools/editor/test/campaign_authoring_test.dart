import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runner_content_pipeline/runner_content_pipeline.dart';
import 'package:runner_editor/src/app/pages/campaign/campaign_page.dart';
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
    await tester.pumpAndSettle();
    expect(find.text('Mission settings'), findsOneWidget);
    expect(find.text('Play mission (F5)'), findsOneWidget);
    await tester.tap(find.text('Mission settings'));
    await tester.pumpAndSettle();
    expect(find.text('Title (en)'), findsOneWidget);
    expect(find.text('Title (fr)'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
