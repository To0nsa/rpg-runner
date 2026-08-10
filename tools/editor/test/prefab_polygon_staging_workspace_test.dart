import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runner_editor/src/app/pages/prefabCreator/prefab_creator_page.dart';
import 'package:runner_editor/src/app/pages/shared/editor_page_local_draft_state.dart';
import 'package:runner_editor/src/domain/authoring_plugin_registry.dart';
import 'package:runner_editor/src/domain/authoring_types.dart';
import 'package:runner_editor/src/prefabs/domain/prefab_domain_models.dart';
import 'package:runner_editor/src/prefabs/domain/prefab_domain_plugin.dart';
import 'package:runner_editor/src/prefabs/models/models.dart';
import 'package:runner_editor/src/prefabs/store/prefab_tile_file_codec.dart';
import 'package:runner_editor/src/prefabs/store/prefab_v3_file_codec.dart';
import 'package:runner_editor/src/session/editor_session_controller.dart';
import 'package:runner_editor/src/terrain_authoring/terrain_source_models.dart';
import 'package:runner_editor/src/workspace/editor_workspace.dart';

void main() {
  testWidgets('staging route honors a requested stable prefab owner', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = await _buildHarness();
    addTearDown(harness.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: PrefabCreatorPage(
            controller: harness.session,
            initialStagedPrefabKey: 'platform',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final requestedOwner = find.byKey(
      const ValueKey<String>('prefab_polygon_owner_platform'),
    );
    final requestedOwnerTile = find.descendant(
      of: requestedOwner,
      matching: find.byType(ListTile),
    );
    expect(tester.widget<ListTile>(requestedOwnerTile).selected, isTrue);
    expect(find.textContaining('platform_module:module_a'), findsOneWidget);
    expect(harness.session.pendingChanges.hasChanges, isFalse);
  });

  testWidgets(
    'explicit staging route isolates owners and commits half-pixel polygons',
    (tester) async {
      tester.view.physicalSize = const Size(1800, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final harness = await _buildHarness();
      addTearDown(harness.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(body: PrefabCreatorPage(controller: harness.session)),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('prefab_polygon_staging_workspace')),
        findsOneWidget,
      );
      expect(find.text('Save Definitions'), findsNothing);
      final applySource = tester.widget<FilledButton>(
        find.byKey(const ValueKey<String>('prefab_polygon_apply_source')),
      );
      expect(applySource.onPressed, isNull);

      final closeDraftFinder = find.byKey(
        const ValueKey<String>('prefab_polygon_close_draft'),
      );
      expect(tester.widget<OutlinedButton>(closeDraftFinder).onPressed, isNull);
      await tester.tap(
        find.byKey(const ValueKey<String>('prefab_polygon_new_shape')),
      );
      await tester.pump();
      expect(
        tester.widget<OutlinedButton>(closeDraftFinder).onPressed,
        isNotNull,
      );
      final routeState = tester.state(find.byType(PrefabCreatorPage));
      final localDraftState = routeState as EditorPageLocalDraftState;
      final shortcutHandler = routeState as EditorPageSessionShortcutHandler;
      expect(localDraftState.hasLocalDraftChanges, isTrue);
      expect(shortcutHandler.canHandleUndoSessionShortcut, isTrue);
      expect(shortcutHandler.handleUndoSessionShortcut(), isTrue);
      await tester.pump();
      expect(tester.widget<OutlinedButton>(closeDraftFinder).onPressed, isNull);
      expect(harness.session.canUndo, isFalse);

      await tester.tap(
        find.byKey(const ValueKey<String>('prefab_polygon_new_shape')),
      );
      await tester.pump();

      await tester.tap(
        find.byKey(const ValueKey<String>('prefab_polygon_owner_platform')),
      );
      await tester.pump();
      expect(tester.widget<OutlinedButton>(closeDraftFinder).onPressed, isNull);
      expect(find.textContaining('platform_module:module_a'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('prefab_polygon_owner_obstacle')),
      );
      await tester.pump();
      await tester.tap(find.text('0.5 px'));
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey<String>('prefab_polygon_new_shape')),
      );
      await tester.pump();

      final surface = find.byKey(
        const ValueKey<String>('prefab_polygon_scene_surface'),
      );
      final center = tester.getCenter(surface);
      await tester.tapAt(center + const Offset(22, 22));
      await tester.tapAt(center + const Offset(34, 22));
      await tester.tapAt(center + const Offset(22, 34));
      await tester.pump();
      await tester.tap(closeDraftFinder);
      await tester.pump();

      var obstacle = _prefab(harness.session, 'obstacle');
      expect(obstacle.revision, 2);
      expect(obstacle.collisionShapes, hasLength(2));
      expect(
        obstacle.collisionShapes
            .singleWhere((shape) => shape.shapeId == 'collision_002')
            .vertices
            .first
            .xHalfPixels,
        11,
      );
      final impactText = tester.widget<Text>(
        find.byKey(const ValueKey<String>('prefab_polygon_downstream_impact')),
      );
      expect(impactText.data, contains('3 placement(s) in 2 chunk(s)'));
      expect(impactText.data, contains('chunk revisions stay unchanged'));

      await tester.tap(
        find.byKey(const ValueKey<String>('prefab_polygon_undo_button')),
      );
      await tester.pump();
      obstacle = _prefab(harness.session, 'obstacle');
      expect(obstacle.revision, 1);
      expect(obstacle.collisionShapes, hasLength(1));

      await tester.tap(
        find.byKey(const ValueKey<String>('prefab_polygon_redo_button')),
      );
      await tester.pump();
      obstacle = _prefab(harness.session, 'obstacle');
      expect(obstacle.revision, 2);

      final editedShapeRow = find.byKey(
        const ValueKey<String>('prefab_polygon_shape_collision_002'),
      );
      await tester.ensureVisible(editedShapeRow);
      await tester.tap(editedShapeRow);
      await tester.pump();
      final vertexRow = find.byKey(
        const ValueKey<String>('prefab_polygon_vertex_collision_002_0'),
      );
      await tester.ensureVisible(vertexRow);
      await tester.tap(vertexRow);
      await tester.pump();
      final xField = find.byKey(
        const ValueKey<String>('prefab_polygon_vertex_x_field'),
      );
      final yField = find.byKey(
        const ValueKey<String>('prefab_polygon_vertex_y_field'),
      );
      await tester.ensureVisible(xField);
      await tester.enterText(xField, '5');
      await tester.enterText(yField, '5.5');
      await tester.tap(
        find.byKey(const ValueKey<String>('prefab_polygon_apply_vertex')),
      );
      await tester.pump();
      obstacle = _prefab(harness.session, 'obstacle');
      expect(obstacle.revision, 3);
      final editedVertex = obstacle.collisionShapes
          .singleWhere((shape) => shape.shapeId == 'collision_002')
          .vertices
          .first;
      expect(editedVertex.xHalfPixels, 10);
      expect(editedVertex.yHalfPixels, 11);

      final diagnostic = find.text(
        'prefab_collision_shape_outside_visual_bounds',
      );
      await tester.ensureVisible(diagnostic);
      await tester.tap(diagnostic);
      await tester.pump();
      final shapeTile = tester.widget<ListTile>(
        find.descendant(
          of: find.byKey(
            const ValueKey<String>('prefab_polygon_shape_collision_001'),
          ),
          matching: find.byType(ListTile),
        ),
      );
      expect(shapeTile.selected, isTrue);

      expect(harness.session.pendingChanges.changedItemIds, <String>[
        'obstacle',
      ]);
      expect(harness.session.exportError, isNull);
    },
  );

  testWidgets(
    'staging owner forms preserve polygons across metadata and lifecycle edits',
    (tester) async {
      tester.view.physicalSize = const Size(1800, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final harness = await _buildHarness();
      addTearDown(harness.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(body: PrefabCreatorPage(controller: harness.session)),
        ),
      );
      await tester.pumpAndSettle();

      final originalShapes = _prefab(
        harness.session,
        'obstacle',
      ).collisionShapes;
      await tester.tap(
        find.byKey(const ValueKey<String>('prefab_v3_owner_edit')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('prefab_v3_owner_status_field')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('deprecated').last);
      await tester.enterText(
        find.byKey(const ValueKey<String>('prefab_v3_owner_anchor_x_field')),
        '9',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('prefab_v3_owner_tags_field')),
        'test, boss, test',
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('prefab_v3_owner_dialog_apply')),
      );
      await tester.pumpAndSettle();

      var obstacle = _prefab(harness.session, 'obstacle');
      expect(obstacle.revision, 2);
      expect(obstacle.status, PrefabStatus.deprecated);
      expect(obstacle.anchorXPx, 9);
      expect(obstacle.tags, <String>['boss', 'test']);
      expect(obstacle.collisionShapes, originalShapes);

      await tester.tap(
        find.byKey(const ValueKey<String>('prefab_polygon_undo_button')),
      );
      await tester.pump();
      obstacle = _prefab(harness.session, 'obstacle');
      expect(obstacle.revision, 1);
      expect(obstacle.status, PrefabStatus.active);
      expect(obstacle.collisionShapes, originalShapes);
      await tester.tap(
        find.byKey(const ValueKey<String>('prefab_polygon_redo_button')),
      );
      await tester.pump();
      expect(_prefab(harness.session, 'obstacle').revision, 2);

      await tester.tap(
        find.byKey(const ValueKey<String>('prefab_v3_owner_rename')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey<String>('prefab_v3_rename_id_field')),
        'obstacle_renamed',
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('prefab_v3_rename_apply')),
      );
      await tester.pumpAndSettle();
      obstacle = _prefab(harness.session, 'obstacle');
      expect(obstacle.id, 'obstacle_renamed');
      expect(obstacle.revision, 3);
      expect(obstacle.collisionShapes, originalShapes);

      await tester.tap(
        find.byKey(const ValueKey<String>('prefab_v3_owner_duplicate')),
      );
      await tester.pump();
      final duplicate = _prefab(harness.session, 'obstacle_renamed_copy');
      expect(duplicate.id, 'obstacle_renamed_copy');
      expect(duplicate.revision, 1);
      expect(duplicate.status, PrefabStatus.active);
      expect(duplicate.collisionShapes, originalShapes);

      await tester.tap(
        find.byKey(const ValueKey<String>('prefab_v3_owner_delete')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('prefab_v3_owner_delete_confirm')),
      );
      await tester.pumpAndSettle();
      expect(
        (harness.session.document! as PrefabV3StagingDocument).data.prefabs.any(
          (prefab) => prefab.prefabKey == 'obstacle_renamed_copy',
        ),
        isFalse,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('prefab_v3_owner_create')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey<String>('prefab_v3_owner_id_field')),
        'flower',
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('prefab_v3_owner_kind_obstacle')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('decoration').last);
      await tester.enterText(
        find.byKey(const ValueKey<String>('prefab_v3_owner_tags_field')),
        'flora, art, flora',
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('prefab_v3_owner_dialog_apply')),
      );
      await tester.pumpAndSettle();

      final flower = _prefab(harness.session, 'flower');
      expect(flower.id, 'flower');
      expect(flower.revision, 1);
      expect(flower.kind, PrefabKind.decoration);
      expect(flower.sliceId, 'decoration_slice');
      expect(flower.anchorXPx, 6);
      expect(flower.anchorYPx, 6);
      expect(flower.tags, <String>['art', 'flora']);
      expect(flower.collisionShapes, isEmpty);
      expect(find.text('Save Definitions'), findsNothing);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey<String>('prefab_polygon_apply_source')),
            )
            .onPressed,
        isNotNull,
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('prefab_polygon_apply_source')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Apply Prefab-v3 Changes'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Cancel').last);
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'staging atlas form commits slices and protects local drafts and references',
    (tester) async {
      tester.view.physicalSize = const Size(1800, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final harness = await _buildHarness();
      addTearDown(harness.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(body: PrefabCreatorPage(controller: harness.session)),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('prefab_v3_view_atlas_slices')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('atlas_slice_row_decoration_slice')),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const ValueKey<String>('atlas_slice_id_field')),
        'bonus_slice',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('atlas_slice_tags_field')),
        'bonus, art, bonus',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('atlas_selection_x_field')),
        '1',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('atlas_selection_y_field')),
        '1',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('atlas_selection_w_field')),
        '6',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('atlas_selection_h_field')),
        '6',
      );
      final saveSlice = find.byKey(const ValueKey<String>('atlas_slice_save'));
      await tester.ensureVisible(saveSlice);
      await tester.pump();
      await tester.tap(saveSlice);
      await tester.pumpAndSettle();

      var bonus = _slice(harness.session, 'bonus_slice');
      expect(bonus.sourceImagePath, 'assets/decorations.png');
      expect((bonus.x, bonus.y, bonus.width, bonus.height), (1, 1, 6, 6));
      expect(bonus.tags, <String>['art', 'bonus']);

      await tester.tap(
        find.byKey(const ValueKey<String>('prefab_polygon_undo_button')),
      );
      await tester.pumpAndSettle();
      expect(
        (harness.session.document! as PrefabV3StagingDocument).data.slices.any(
          (slice) => slice.id == 'bonus_slice',
        ),
        isFalse,
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('prefab_polygon_redo_button')),
      );
      await tester.pumpAndSettle();
      expect(_slice(harness.session, 'bonus_slice').width, 6);

      await tester.tap(
        find.byKey(const ValueKey<String>('atlas_slice_row_bonus_slice')),
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey<String>('atlas_selection_w_field')),
        '7',
      );
      await tester.ensureVisible(saveSlice);
      await tester.pump();
      await tester.tap(saveSlice);
      await tester.pumpAndSettle();
      bonus = _slice(harness.session, 'bonus_slice');
      expect(bonus.width, 7);
      expect(bonus.tags, <String>['art', 'bonus']);

      final referencedRow = find.byKey(
        const ValueKey<String>('atlas_slice_row_decoration_slice'),
      );
      await tester.tap(
        find.descendant(of: referencedRow, matching: find.byTooltip('Delete')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Cannot delete decoration_slice'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey<String>('prefab_v3_slice_delete_blocked')),
      );
      await tester.pumpAndSettle();
      expect(
        _slice(harness.session, 'decoration_slice').id,
        'decoration_slice',
      );

      final bonusRow = find.byKey(
        const ValueKey<String>('atlas_slice_row_bonus_slice'),
      );
      await tester.tap(
        find.descendant(of: bonusRow, matching: find.byTooltip('Delete')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('prefab_v3_slice_delete_confirm')),
      );
      await tester.pumpAndSettle();
      expect(
        (harness.session.document! as PrefabV3StagingDocument).data.slices.any(
          (slice) => slice.id == 'bonus_slice',
        ),
        isFalse,
      );

      await tester.tap(find.byKey(const ValueKey<String>('slice_kind_prefab')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tile Slice').last);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('atlas_slice_row_tile_a')),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('atlas_slice_id_field')),
        'tile_bonus',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('atlas_selection_x_field')),
        '0',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('atlas_selection_y_field')),
        '0',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('atlas_selection_w_field')),
        '8',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('atlas_selection_h_field')),
        '8',
      );
      await tester.ensureVisible(saveSlice);
      await tester.pump();
      await tester.tap(saveSlice);
      await tester.pumpAndSettle();
      expect(
        _slice(harness.session, 'tile_bonus').sourceImagePath,
        'assets/tiles.png',
      );

      final tileBonusRow = find.byKey(
        const ValueKey<String>('atlas_slice_row_tile_bonus'),
      );
      await tester.tap(
        find.descendant(of: tileBonusRow, matching: find.byTooltip('Delete')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('prefab_v3_slice_delete_confirm')),
      );
      await tester.pumpAndSettle();
      expect(
        (harness.session.document! as PrefabV3StagingDocument)
            .tileData
            .tileSlices
            .any((slice) => slice.id == 'tile_bonus'),
        isFalse,
      );

      final routeState = tester.state(find.byType(PrefabCreatorPage));
      final localDraftState = routeState as EditorPageLocalDraftState;
      await tester.enterText(
        find.byKey(const ValueKey<String>('atlas_slice_tags_field')),
        'unsaved',
      );
      expect(localDraftState.hasLocalDraftChanges, isTrue);
      await tester.tap(
        find.byKey(const ValueKey<String>('prefab_v3_view_owners')),
      );
      await tester.pump();
      expect(
        find.byKey(const ValueKey<String>('atlas_slice_save')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('prefab_polygon_undo_button')),
      );
      await tester.pump();
      expect(localDraftState.hasLocalDraftChanges, isFalse);
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey<String>('atlas_slice_tags_field')),
            )
            .controller!
            .text,
        isNot('unsaved'),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('prefab_v3_view_owners')),
      );
      await tester.pump();
      expect(
        find.byKey(const ValueKey<String>('prefab_v3_owner_edit')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey<String>('prefab_polygon_apply_source')),
            )
            .onPressed,
        isNull,
      );
    },
  );

  testWidgets(
    'staging module form preserves references across retained module workflows',
    (tester) async {
      tester.view.physicalSize = const Size(1800, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final harness = await _buildHarness();
      addTearDown(harness.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(body: PrefabCreatorPage(controller: harness.session)),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('prefab_v3_view_platform_modules')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('platform_module_row_module_a')),
        findsOneWidget,
      );

      final moduleARow = find.byKey(
        const ValueKey<String>('platform_module_row_module_a'),
      );
      await tester.tap(
        find
            .descendant(of: moduleARow, matching: find.byTooltip('Delete'))
            .first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Cannot delete module_a'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey<String>('prefab_v3_module_delete_blocked')),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey<String>('platform_module_tile_size_field')),
        '20',
      );
      final upsert = find.byKey(
        const ValueKey<String>('platform_module_upsert_button'),
      );
      await tester.ensureVisible(upsert);
      await tester.pump();
      await tester.tap(upsert);
      await tester.pumpAndSettle();
      expect(_module(harness.session, 'module_a').revision, 2);
      expect(_module(harness.session, 'module_a').tileSize, 20);

      await tester.tap(
        find.byKey(const ValueKey<String>('prefab_polygon_undo_button')),
      );
      await tester.pumpAndSettle();
      expect(_module(harness.session, 'module_a').revision, 1);
      expect(_module(harness.session, 'module_a').tileSize, 16);
      await tester.tap(
        find.byKey(const ValueKey<String>('prefab_polygon_redo_button')),
      );
      await tester.pumpAndSettle();
      expect(_module(harness.session, 'module_a').revision, 2);

      final platformShapes = _prefab(
        harness.session,
        'platform',
      ).collisionShapes;
      await tester.enterText(
        find.byKey(const ValueKey<String>('platform_module_id_field')),
        'module_main',
      );
      final rename = find.byKey(
        const ValueKey<String>('platform_module_rename_button'),
      );
      await tester.ensureVisible(rename);
      await tester.pump();
      await tester.tap(rename);
      await tester.pumpAndSettle();
      expect(_module(harness.session, 'module_main').revision, 3);
      final platform = _prefab(harness.session, 'platform');
      expect(platform.moduleId, 'module_main');
      expect(platform.revision, 2);
      expect(platform.collisionShapes, platformShapes);

      final duplicate = find.byKey(
        const ValueKey<String>('platform_module_duplicate_button'),
      );
      await tester.ensureVisible(duplicate);
      await tester.pump();
      await tester.tap(duplicate);
      await tester.pumpAndSettle();
      expect(_module(harness.session, 'module_main_copy').revision, 1);
      expect(_module(harness.session, 'module_main_copy').cells, hasLength(1));

      final copyRow = find.byKey(
        const ValueKey<String>('platform_module_row_module_main_copy'),
      );
      await tester.tap(
        find.descendant(of: copyRow, matching: find.byTooltip('Delete')).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('prefab_v3_module_delete_confirm')),
      );
      await tester.pumpAndSettle();
      expect(
        (harness.session.document! as PrefabV3StagingDocument)
            .tileData
            .platformModules
            .any((module) => module.id == 'module_main_copy'),
        isFalse,
      );

      final newEmpty = find.byKey(
        const ValueKey<String>('platform_module_new_empty_button'),
      );
      await tester.ensureVisible(newEmpty);
      await tester.pump();
      await tester.tap(newEmpty);
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey<String>('platform_module_id_field')),
        'scratch_module',
      );
      await tester.ensureVisible(upsert);
      await tester.pump();
      await tester.tap(upsert);
      await tester.pumpAndSettle();
      var scratch = _module(harness.session, 'scratch_module');
      expect(scratch.status, TileModuleStatus.deprecated);
      expect(scratch.cells, isEmpty);

      final sceneCanvas = find.byKey(
        const ValueKey<String>('platform_module_scene_canvas'),
      );
      await tester.tap(find.byKey(const ValueKey<String>('module_tool_paint')));
      await tester.pump();
      await tester.tapAt(tester.getCenter(sceneCanvas));
      await tester.pumpAndSettle();
      scratch = _module(harness.session, 'scratch_module');
      expect(scratch.revision, 2);
      expect(scratch.cells, hasLength(1));

      final status = find.byKey(
        const ValueKey<String>('platform_module_status_button'),
      );
      await tester.ensureVisible(status);
      await tester.pump();
      await tester.tap(status);
      await tester.pumpAndSettle();
      scratch = _module(harness.session, 'scratch_module');
      expect(scratch.revision, 3);
      expect(scratch.status, TileModuleStatus.active);

      final scratchRow = find.byKey(
        const ValueKey<String>('platform_module_row_scratch_module'),
      );
      await tester.tap(
        find
            .descendant(of: scratchRow, matching: find.byTooltip('Delete'))
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('prefab_v3_module_delete_confirm')),
      );
      await tester.pumpAndSettle();
      expect(
        (harness.session.document! as PrefabV3StagingDocument)
            .tileData
            .platformModules
            .any((module) => module.id == 'scratch_module'),
        isFalse,
      );

      await tester.enterText(
        find.byKey(const ValueKey<String>('platform_module_tile_size_field')),
        '24',
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('prefab_v3_view_owners')),
      );
      await tester.pump();
      expect(sceneCanvas, findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey<String>('prefab_polygon_undo_button')),
      );
      await tester.pump();
      expect(
        tester
            .widget<TextField>(
              find.byKey(
                const ValueKey<String>('platform_module_tile_size_field'),
              ),
            )
            .controller!
            .text,
        '20',
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('prefab_v3_view_owners')),
      );
      await tester.pump();
      expect(
        find.byKey(const ValueKey<String>('prefab_v3_owner_edit')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey<String>('prefab_polygon_apply_source')),
            )
            .onPressed,
        isNotNull,
      );
    },
  );
}

Future<_Harness> _buildHarness() async {
  final root = Directory.systemTemp.createTempSync('prefab_stage_page_');
  final document = _stagingDocument();
  final session = EditorSessionController(
    pluginRegistry: AuthoringPluginRegistry(
      plugins: <AuthoringDomainPlugin>[_StagingPrefabPlugin(document)],
    ),
    initialPluginId: PrefabDomainPlugin.pluginId,
    initialWorkspacePath: root.path,
  );
  await session.loadWorkspace();
  return _Harness(root: root, session: session);
}

PrefabV3StagingDocument _stagingDocument() {
  final data = PrefabV3FileData(
    slices: const <AtlasSliceDef>[
      AtlasSliceDef(
        id: 'decoration_slice',
        sourceImagePath: 'assets/decorations.png',
        x: 0,
        y: 0,
        width: 12,
        height: 12,
      ),
      AtlasSliceDef(
        id: 'obstacle_slice',
        sourceImagePath: 'assets/obstacles.png',
        x: 0,
        y: 0,
        width: 20,
        height: 20,
      ),
    ],
    prefabs: <PrefabV3Def>[
      PrefabV3Def(
        prefabKey: 'decoration',
        id: 'decoration',
        revision: 1,
        status: PrefabStatus.active,
        kind: PrefabKind.decoration,
        visualSource: const PrefabVisualSource.atlasSlice('decoration_slice'),
        anchorXPx: 6,
        anchorYPx: 6,
        collisionShapes: const <TerrainSourceShapeDef>[],
        tags: const <String>[],
      ),
      PrefabV3Def(
        prefabKey: 'obstacle',
        id: 'obstacle',
        revision: 1,
        status: PrefabStatus.active,
        kind: PrefabKind.obstacle,
        visualSource: const PrefabVisualSource.atlasSlice('obstacle_slice'),
        anchorXPx: 10,
        anchorYPx: 10,
        collisionShapes: <TerrainSourceShapeDef>[_outsideRectangle()],
        tags: const <String>['test'],
      ),
      PrefabV3Def(
        prefabKey: 'platform',
        id: 'platform',
        revision: 1,
        status: PrefabStatus.active,
        kind: PrefabKind.platform,
        visualSource: const PrefabVisualSource.platformModule('module_a'),
        anchorXPx: 8,
        anchorYPx: 8,
        collisionShapes: <TerrainSourceShapeDef>[_smallRectangle()],
        tags: const <String>[],
      ),
    ],
  );
  final tileData = PrefabTileFileData(
    tileSlices: const <AtlasSliceDef>[
      AtlasSliceDef(
        id: 'tile_a',
        sourceImagePath: 'assets/tiles.png',
        x: 0,
        y: 0,
        width: 16,
        height: 16,
      ),
    ],
    platformModules: const <TileModuleDef>[
      TileModuleDef(
        id: 'module_a',
        tileSize: 16,
        cells: <TileModuleCellDef>[
          TileModuleCellDef(sliceId: 'tile_a', gridX: 0, gridY: 0),
        ],
      ),
    ],
  );
  return PrefabV3StagingDocument(
    data: data,
    tileData: tileData,
    visualBoundsByPrefabKey: const <String, PrefabV3VisualBounds>{
      'obstacle': PrefabV3VisualBounds(widthPx: 20, heightPx: 20),
      'platform': PrefabV3VisualBounds(widthPx: 16, heightPx: 16),
      'decoration': PrefabV3VisualBounds(widthPx: 12, heightPx: 12),
    },
    atlasImagePaths: const <String>[
      'assets/decorations.png',
      'assets/obstacles.png',
      'assets/tiles.png',
    ],
    atlasImageSizes: const <String, Size>{
      'assets/obstacles.png': Size(20, 20),
      'assets/decorations.png': Size(12, 12),
      'assets/tiles.png': Size(16, 16),
    },
    prefabBaselineContents: PrefabV3FileCodec.encode(data),
    tileBaselineContents: PrefabTileFileCodec.encode(tileData),
    downstreamImpacts: <PrefabV3DownstreamImpact>[
      PrefabV3DownstreamImpact(
        prefabKey: 'obstacle',
        referencingChunkKeys: const <String>['forest_a', 'forest_b'],
        placementCount: 3,
      ),
    ],
  );
}

PrefabV3Def _prefab(EditorSessionController session, String prefabKey) {
  final document = session.document! as PrefabV3StagingDocument;
  return document.data.prefabs.singleWhere(
    (prefab) => prefab.prefabKey == prefabKey,
  );
}

AtlasSliceDef _slice(EditorSessionController session, String sliceId) {
  final document = session.document! as PrefabV3StagingDocument;
  return <AtlasSliceDef>[
    ...document.data.slices,
    ...document.tileData.tileSlices,
  ].singleWhere((slice) => slice.id == sliceId);
}

TileModuleDef _module(EditorSessionController session, String moduleId) {
  final document = session.document! as PrefabV3StagingDocument;
  return document.tileData.platformModules.singleWhere(
    (module) => module.id == moduleId,
  );
}

TerrainSourceShapeDef _outsideRectangle() => TerrainSourceShapeDef(
  shapeId: 'collision_001',
  vertices: const <TerrainSourceVertexDef>[
    TerrainSourceVertexDef(xHalfPixels: -24, yHalfPixels: -8),
    TerrainSourceVertexDef(xHalfPixels: 8, yHalfPixels: -8),
    TerrainSourceVertexDef(xHalfPixels: 8, yHalfPixels: 8),
    TerrainSourceVertexDef(xHalfPixels: -24, yHalfPixels: 8),
  ],
);

TerrainSourceShapeDef _smallRectangle() => TerrainSourceShapeDef(
  shapeId: 'collision_001',
  vertices: const <TerrainSourceVertexDef>[
    TerrainSourceVertexDef(xHalfPixels: -8, yHalfPixels: -8),
    TerrainSourceVertexDef(xHalfPixels: 8, yHalfPixels: -8),
    TerrainSourceVertexDef(xHalfPixels: 8, yHalfPixels: 8),
    TerrainSourceVertexDef(xHalfPixels: -8, yHalfPixels: 8),
  ],
);

final class _Harness {
  const _Harness({required this.root, required this.session});

  final Directory root;
  final EditorSessionController session;

  void dispose() {
    session.dispose();
    if (root.existsSync()) root.deleteSync(recursive: true);
  }
}

final class _StagingPrefabPlugin implements AuthoringDomainPlugin {
  const _StagingPrefabPlugin(this.document);

  final PrefabV3StagingDocument document;
  static const PrefabDomainPlugin _delegate = PrefabDomainPlugin();

  @override
  String get id => PrefabDomainPlugin.pluginId;

  @override
  Future<AuthoringDocument> loadFromRepo(EditorWorkspace workspace) async =>
      document;

  @override
  List<ValidationIssue> validate(AuthoringDocument document) =>
      _delegate.validate(document);

  @override
  EditableScene buildEditableScene(AuthoringDocument document) =>
      _delegate.buildEditableScene(document);

  @override
  AuthoringDocument applyEdit(
    AuthoringDocument document,
    AuthoringCommand command,
  ) => _delegate.applyEdit(document, command);

  @override
  Future<ExportResult> exportToRepo(
    EditorWorkspace workspace, {
    required AuthoringDocument document,
  }) => _delegate.exportToRepo(workspace, document: document);

  @override
  PendingChanges describePendingChanges(
    EditorWorkspace workspace, {
    required AuthoringDocument document,
  }) => _delegate.describePendingChanges(workspace, document: document);
}
