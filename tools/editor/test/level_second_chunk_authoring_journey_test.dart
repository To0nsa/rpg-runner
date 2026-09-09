import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:runner_editor/src/app/pages/chunkCreator/v2/chunk_scene_surface.dart';
import 'package:runner_editor/src/app/pages/home/editor_home_page.dart';
import 'package:runner_editor/src/app/pages/levelCreator/level_sample_preview.dart';
import 'package:runner_editor/src/chunks/chunk_domain_plugin.dart';
import 'package:runner_editor/src/chunks/chunk_level_target.dart';
import 'package:runner_editor/src/chunks/chunk_v2_file_data.dart';
import 'package:runner_editor/src/chunks/chunk_v2_models.dart';
import 'package:runner_editor/src/domain/authoring_plugin_registry.dart';
import 'package:runner_editor/src/domain/authoring_types.dart';
import 'package:runner_editor/src/levels/level_domain_models.dart';
import 'package:runner_editor/src/levels/level_domain_plugin.dart';
import 'package:runner_editor/src/parallax/parallax_domain_plugin.dart';
import 'package:runner_editor/src/prefabs/models/models.dart';
import 'package:runner_editor/src/prefabs/store/prefab_v3_file_codec.dart';
import 'package:runner_editor/src/session/editor_session_controller.dart';
import 'package:runner_editor/src/workspace/editor_workspace.dart';

import 'test_support/chunk_level_fixture.dart';

void main() {
  testWidgets(
    'second authored Chunk receives terrain Prefab enemy group and enters Level sample',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final workspace = (await tester.runAsync(_starterAndAssetFixture))!;
      final session = EditorSessionController(
        pluginRegistry: AuthoringPluginRegistry(
          plugins: [
            LevelDomainPlugin(),
            ChunkDomainPlugin(),
            ParallaxDomainPlugin(),
          ],
        ),
        initialPluginId: LevelDomainPlugin.pluginId,
        initialWorkspacePath: workspace.rootPath,
      );
      addTearDown(session.dispose);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        for (var i = 0; i < 20; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump();
        }
      });
      await tester.pumpWidget(
        MaterialApp(home: EditorHomePage(controller: session)),
      );
      await _drain(tester, () => find.text('Add chunk').evaluate().isNotEmpty);
      await tester.tap(find.text('Add chunk'));
      await _drain(
        tester,
        () => find
            .byKey(const ValueKey('chunk_v2_inline_create_id'))
            .evaluate()
            .isNotEmpty,
      );
      expect((session.document! as ChunkV2Document).chunks, hasLength(1));
      await tester.enterText(
        find.byKey(const ValueKey('chunk_v2_inline_create_id')),
        'forest_encounter',
      );
      await _tapKey(tester, 'chunk_v2_inline_create_apply');
      expect(_second(session).status, 'deprecated');
      expect(_second(session).collisionShapes, isEmpty);
      expect(_second(session).prefabs, isEmpty);
      expect(_second(session).markers, isEmpty);

      // The saved starter is merely a dimension template. All second-owner
      // composition below goes through visible tools and semantic UI commands.
      await _openSection(
        tester,
        'chunk_polygon_creation_panel_toggle',
        'chunk_polygon_creation_section',
      );
      final snap = find.byKey(
        const ValueKey('chunk_polygon_creation_snap_to_grid'),
      );
      if (tester.widget<SwitchListTile>(snap).value) {
        await _tapKey(tester, 'chunk_polygon_creation_snap_to_grid');
      }
      await _tapKey(tester, 'chunk_polygon_new_rectangle');
      final gesture = await tester.startGesture(_scenePoint(tester, 0, 224));
      await gesture.moveTo(_scenePoint(tester, 600, 270));
      await gesture.up();
      await tester.pump();
      await _tapKey(tester, 'chunk_polygon_save_draft');
      expect(_second(session).collisionShapes, hasLength(1));
      expect(_second(session).collisionShapes.single.materialKey, 'grass_dirt');

      await _tapText(tester, 'Prefabs');
      await _openSection(
        tester,
        'chunk_prefab_catalog_section_toggle',
        'chunk_prefab_catalog_grid',
      );
      await _tapKey(tester, 'chunk_prefab_catalog_card_journey_prop');
      await _openSection(
        tester,
        'chunk_prefab_creation_panel_toggle',
        'chunk_prefab_creation_form_forest_encounter',
      );
      await _enter(tester, 'chunk_v2_placement_creation_x_field', '200');
      await _enter(tester, 'chunk_v2_placement_creation_y_field', '224');
      await _tapKey(tester, 'chunk_v2_placement_add');
      expect(_second(session).prefabs.single.prefabKey, 'journey_prop');

      await _tapText(tester, 'Markers');
      await _openSection(
        tester,
        'chunk_enemy_catalog_section_toggle',
        'chunk_enemy_catalog_grid',
      );
      await _tapKey(tester, 'chunk_enemy_catalog_card_unocoDemon');
      await _openSection(
        tester,
        'chunk_marker_creation_panel_toggle',
        'chunk_marker_creation_form_forest_encounter',
      );
      await _enter(tester, 'chunk_v2_marker_creation_x_field', '350');
      await _enter(tester, 'chunk_v2_marker_creation_y_field', '80');
      await _tapKey(tester, 'chunk_v2_marker_add');
      expect(_second(session).markers.single.markerId, 'unocoDemon');

      await _openSection(
        tester,
        'chunk_owner_section_toggle',
        'chunk_polygon_owner_forest_encounter',
      );
      if (find
          .byKey(const ValueKey('chunk_v2_owner_status_deprecated'))
          .evaluate()
          .isEmpty) {
        await _tapKey(tester, 'chunk_v2_owner_edit_forest_encounter');
      }
      await _choose(tester, 'chunk_v2_owner_status_deprecated', 'active');
      await _choose(
        tester,
        'chunk_v2_owner_assembly_forest_default',
        'encounters',
      );
      await _choose(tester, 'chunk_v2_owner_difficulty_normal', 'early');
      await _tapKey(tester, 'chunk_v2_owner_inline_apply_forest_encounter');
      final authored = _second(session);
      expect(authored.status, 'active');
      expect(authored.assemblyGroupId, 'encounters');
      expect(session.pendingChanges.hasChanges, isTrue);
      await _tapText(tester, 'Save and return to level');
      await _drain(
        tester,
        () =>
            session.selectedPluginId == LevelDomainPlugin.pluginId &&
            find
                .byKey(const ValueKey('level_chunk_forest_encounter'))
                .evaluate()
                .isNotEmpty,
      );
      expect(session.pendingChanges.hasChanges, isFalse);
      expect((session.document! as LevelDefsDocument).activeLevelId, 'forest');
      expect(find.text('2 active chunks'), findsOneWidget);

      final saved = (await tester.runAsync(
        () => ChunkDomainPlugin().loadV2FromRepo(workspace),
      ))!;
      final persisted = saved.chunks.singleWhere(
        (chunk) => chunk.chunkKey == 'forest_encounter',
      );
      final savedContent = Map<String, Object>.of(persisted.toJson())
        ..remove('revision');
      final intendedContent = Map<String, Object>.of(authored.toJson())
        ..remove('revision');
      expect(savedContent, intendedContent);
      expect(persisted.assemblyGroupId, 'encounters');
      await _tapKey(tester, 'level_sample_button');
      await _drain(
        tester,
        () => find.byType(LevelSamplePreview).evaluate().isNotEmpty,
      );
      final sampled = tester
          .widget<LevelSamplePreview>(find.byType(LevelSamplePreview))
          .scenario;
      expect(
        sampled.sampleChunks().map((chunk) => chunk.chunkKey),
        contains('forest_encounter'),
      );
      expect(
        sampled.sampleChunks().map((chunk) => chunk.chunkKey),
        contains('forest_starter'),
      );
      expect(session.pendingChanges.hasChanges, isFalse);
      expect(tester.takeException(), isNull);
    },
  );
}

ChunkV2FileData _second(EditorSessionController session) =>
    (session.document! as ChunkV2Document).chunks.singleWhere(
      (chunk) => chunk.chunkKey == 'forest_encounter',
    );

Future<EditorWorkspace> _starterAndAssetFixture() async {
  final workspace = await createChunkLevelFixture(
    level: standardChunkFixtureLevel.copyWith(
      chunkThemeGroups: ['default', 'encounters'],
    ),
  );
  // A provisioned editor contains the runtime sprite sheets captured by Play
  // and Sample. Supply those assets, not any second-owner authored content.
  final sprites = Directory(
    p.normalize(p.absolute('..', '..', 'assets', 'images', 'entities')),
  );
  for (final source
      in sprites
          .listSync(recursive: true, followLinks: false)
          .whereType<File>()) {
    final destination = File(
      workspace.resolve(
        p.join(
          'assets/images/entities',
          p.relative(source.path, from: sprites.path),
        ),
      ),
    );
    destination.parent.createSync(recursive: true);
    source.copySync(destination.path);
  }
  final prefab = PrefabV3Def(
    prefabKey: 'journey_prop',
    id: 'prop',
    revision: 1,
    status: PrefabStatus.active,
    kind: PrefabKind.decoration,
    visualSource: const PrefabVisualSource.atlasSlice('prop_slice'),
    anchorXPx: 8,
    anchorYPx: 16,
    collisionShapes: [],
    tags: [],
  );
  File(workspace.resolve('assets/authoring/level/prefab_defs.json'))
      .writeAsStringSync(
        PrefabV3FileCodec.encode(
          PrefabV3FileData(
            slices: const [
              AtlasSliceDef(
                id: 'prop_slice',
                sourceImagePath: 'assets/images/level/atlases/test/ground.png',
                x: 0,
                y: 0,
                width: 16,
                height: 16,
              ),
            ],
            prefabs: [prefab],
          ),
        ),
      );
  final plugin = ChunkDomainPlugin();
  final empty = await plugin.loadForLevel(
    workspace,
    target: const ChunkLevelTarget('forest'),
  );
  final starter = plugin.applyEdit(
    empty,
    AuthoringCommand(
      kind: ChunkDomainPlugin.createFlatStarterCommandKind,
      payload: {
        'intent': plugin.flatStarterIntentForLevel(empty, levelId: 'forest'),
      },
    ),
  ) as ChunkV2Document;
  final result = await plugin.exportToRepo(workspace, document: starter);
  expect(result.applied, isTrue);
  return workspace;
}

Future<void> _enter(WidgetTester tester, String key, String text) async {
  final field = find.byKey(ValueKey(key));
  await tester.ensureVisible(field);
  await tester.enterText(field, text);
  await tester.pump();
}

Future<void> _tapKey(WidgetTester tester, String key) async {
  final target = find.byKey(ValueKey(key));
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _tapText(WidgetTester tester, String text) async {
  final target = find.text(text);
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _choose(WidgetTester tester, String key, String value) async {
  await _tapKey(tester, key);
  await tester.tap(find.text(value).last);
  await tester.pumpAndSettle();
}

Future<void> _openSection(
  WidgetTester tester,
  String toggleKey,
  String bodyKey,
) async {
  if (find.byKey(ValueKey(bodyKey)).evaluate().isNotEmpty) return;
  final toggle = find.byKey(ValueKey(toggleKey));
  await tester.ensureVisible(toggle);
  final bounds = tester.getRect(toggle);
  await tester.tapAt(Offset(bounds.right - 20, bounds.center.dy));
  await tester.pumpAndSettle();
  expect(find.byKey(ValueKey(bodyKey)), findsOneWidget);
}

Offset _scenePoint(WidgetTester tester, double x, double y) {
  final surfaceFinder = find.byKey(const ValueKey('chunk_scene_surface'));
  final surface = tester.widget<ChunkSceneSurface>(
    find.ancestor(of: surfaceFinder, matching: find.byType(ChunkSceneSurface)),
  );
  return tester.getTopLeft(surfaceFinder) +
      surface.transform.origin +
      Offset(x * surface.transform.zoom, y * surface.transform.zoom);
}

Future<void> _drain(WidgetTester tester, bool Function() complete) async {
  for (var i = 0; i < 1500; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 20));
    if (complete() &&
        find.byType(CircularProgressIndicator).evaluate().isEmpty) {
      return;
    }
  }
  final text = tester
      .widgetList<Text>(find.byType(Text))
      .map((widget) => widget.data)
      .join(' | ');
  fail('Second Chunk authoring did not reach its next step: $text');
}
