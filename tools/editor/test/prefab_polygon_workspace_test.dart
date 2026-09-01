import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runner_editor/src/app/pages/prefabCreator/prefab_creator_page.dart';
import 'package:runner_editor/src/app/pages/shared/editor_list_card.dart';
import 'package:runner_editor/src/app/pages/shared/editor_page_local_draft_state.dart';
import 'package:runner_editor/src/domain/authoring_plugin_registry.dart';
import 'package:runner_editor/src/domain/authoring_types.dart';
import 'package:runner_editor/src/prefabs/domain/prefab_domain_models.dart';
import 'package:runner_editor/src/prefabs/domain/prefab_domain_plugin.dart';
import 'package:runner_editor/src/prefabs/domain/prefab_v3_metadata_commit.dart';
import 'package:runner_editor/src/prefabs/models/models.dart';
import 'package:runner_editor/src/prefabs/store/prefab_tile_file_codec.dart';
import 'package:runner_editor/src/prefabs/store/prefab_v3_file_codec.dart';
import 'package:runner_editor/src/session/editor_session_controller.dart';
import 'package:runner_editor/src/terrain_authoring/terrain_source_models.dart';
import 'package:runner_editor/src/workspace/editor_workspace.dart';

void main() {
  testWidgets('current route honors a requested stable prefab owner', (
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
            initialPrefabKey: 'platform',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _openOwnerLibrary(tester);

    final requestedOwner = find.byKey(
      const ValueKey<String>('prefab_polygon_owner_platform'),
    );
    final requestedOwnerTile = find.descendant(
      of: requestedOwner,
      matching: find.byType(ListTile),
    );
    expect(tester.widget<ListTile>(requestedOwnerTile).selected, isTrue);
    expect(find.textContaining('platform_module:module_a'), findsWidgets);
    expect(
      tester
          .widget<DropdownButton<String>>(
            find.byKey(const ValueKey<String>('prefab_v3_owner_selector')),
          )
          .value,
      'platform',
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('prefab_scene_owner_context')),
        matching: find.textContaining('platform'),
      ),
      findsOneWidget,
    );
    expect(harness.session.pendingChanges.hasChanges, isFalse);
  });

  testWidgets('current prefab workspace remains usable at a narrow width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 900);
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
      find.byKey(const ValueKey<String>('editor_three_panel_narrow')),
      findsOneWidget,
    );
    expect(find.byType(TabBar), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('prefab_scene_owner_context')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('prefab_owner_catalog_search')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('prefab_polygon_new_shape')),
      findsNothing,
    );

    await _openPrefabSection(
      tester,
      toggleKey: 'prefab_polygon_creation_panel_toggle',
      bodyKey: 'prefab_polygon_creation_name_0',
    );

    expect(
      find.byKey(const ValueKey<String>('prefab_polygon_new_shape')),
      findsOneWidget,
    );
    final newRectangle = find.byKey(
      const ValueKey<String>('prefab_polygon_new_rectangle'),
    );
    expect(newRectangle, findsOneWidget);
    expect(tester.widget<FilledButton>(newRectangle).onPressed, isNotNull);
    final saveDraft = find.byKey(
      const ValueKey<String>('prefab_polygon_save_draft'),
    );
    expect(tester.widget<OutlinedButton>(saveDraft).onPressed, isNull);
    expect(
      find.byKey(const ValueKey<String>('prefab_polygon_tool_createRectangle')),
      findsNothing,
    );
    for (final tool in const <String>['createPolygon']) {
      expect(
        tester
            .widget<ChoiceChip>(
              find.byKey(ValueKey<String>('prefab_polygon_tool_$tool')),
            )
            .onSelected,
        isNull,
      );
    }
    final sceneElement = tester.element(
      find.byKey(const ValueKey<String>('prefab_scene_owner_context')),
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('prefab_polygon_new_shape')),
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('prefab_polygon_new_shape')),
    );
    await tester.pump();
    expect(
      find.byKey(
        const ValueKey<String>('prefab_polygon_creation_panel_toggle'),
      ),
      findsNothing,
    );
    expect(tester.widget<OutlinedButton>(saveDraft).onPressed, isNull);
    expect(tester.widget<FilledButton>(newRectangle).onPressed, isNull);
    expect(
      tester
          .widget<ChoiceChip>(
            find.byKey(const ValueKey<String>('prefab_polygon_tool_select')),
          )
          .onSelected,
      isNull,
    );
    expect(
      tester
          .widget<ChoiceChip>(
            find.byKey(
              const ValueKey<String>('prefab_polygon_tool_createPolygon'),
            ),
          )
          .onSelected,
      isNotNull,
    );
    expect(find.text('Place vertex'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('prefab_polygon_tool_createRectangle')),
      findsNothing,
    );
    expect(
      tester
          .widget<ChoiceChip>(
            find.byKey(
              const ValueKey<String>('prefab_polygon_tool_translateShape'),
            ),
          )
          .onSelected,
      isNull,
    );
    expect(
      tester
          .widget<ChoiceChip>(
            find.byKey(
              const ValueKey<String>('prefab_polygon_tool_moveVertex'),
            ),
          )
          .onSelected,
      isNotNull,
    );
    expect(
      tester
          .widget<ChoiceChip>(
            find.byKey(
              const ValueKey<String>('prefab_polygon_tool_insertVertex'),
            ),
          )
          .onSelected,
      isNotNull,
    );

    tester.view.physicalSize = const Size(1400, 900);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('editor_three_panel_wide')),
      findsOneWidget,
    );
    expect(
      identical(
        sceneElement,
        tester.element(
          find.byKey(const ValueKey<String>('prefab_scene_owner_context')),
        ),
      ),
      isTrue,
    );
    expect(
      find.byKey(const ValueKey<String>('prefab_polygon_creation_name_0')),
      findsOneWidget,
    );
    expect(find.text('Place vertex'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'diagnostics project all owners and focus a non-selected shape safely',
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
          home: Scaffold(
            body: PrefabCreatorPage(
              controller: harness.session,
              initialPrefabKey: 'platform',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final issues = harness.session.issues;
      final errors = issues
          .where((issue) => issue.severity == ValidationSeverity.error)
          .length;
      final warnings = issues
          .where((issue) => issue.severity == ValidationSeverity.warning)
          .length;
      final infos = issues.length - errors - warnings;
      expect(issues, isNotEmpty);
      expect(
        find.text('$errors error(s) · $warnings warning(s) · $infos info'),
        findsOneWidget,
      );
      expect(
        find.text('prefab_collision_shape_outside_visual_bounds'),
        findsNothing,
      );

      await tester.tap(
        find.byKey(
          const ValueKey<String>('prefab_polygon_diagnostics_panel_toggle'),
        ),
      );
      await tester.pumpAndSettle();
      final diagnostic = find.text(
        'prefab_collision_shape_outside_visual_bounds',
      );
      expect(diagnostic, findsOneWidget);
      expect(find.textContaining('obstacle ·'), findsOneWidget);
      await tester.ensureVisible(diagnostic);
      await tester.tap(diagnostic);
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<DropdownButton<String>>(
              find.byKey(const ValueKey<String>('prefab_v3_owner_selector')),
            )
            .value,
        'obstacle',
      );
      expect(
        find.byKey(
          const ValueKey<String>('prefab_polygon_shape_collision_001'),
        ),
        findsOneWidget,
      );
      expect(diagnostic, findsOneWidget);
      expect(harness.session.pendingChanges.hasChanges, isFalse);
      expect(harness.session.canUndo, isFalse);
    },
  );

  testWidgets(
    'atlas and module scenes remain mounted above collapsed narrow sidebars',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1000);
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
        find.byKey(const ValueKey<String>('editor_three_panel_narrow')),
        findsOneWidget,
      );
      expect(find.byType(TabBar), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('atlas_scene_card')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('atlas_slice_setup_section_toggle')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey<String>('atlas_slice_library_section_toggle'),
        ),
        findsOneWidget,
      );
      final atlasScene = tester.element(
        find.byKey(const ValueKey<String>('atlas_scene_card')),
      );

      tester.view.physicalSize = const Size(1400, 1000);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('editor_three_panel_wide')),
        findsOneWidget,
      );
      expect(
        identical(
          atlasScene,
          tester.element(
            find.byKey(const ValueKey<String>('atlas_scene_card')),
          ),
        ),
        isTrue,
      );

      tester.view.physicalSize = const Size(900, 1000);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('prefab_v3_view_platform_modules')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('platform_module_scene_canvas')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey<String>('platform_module_advanced_controls_toggle'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey<String>('platform_module_library_section_toggle'),
        ),
        findsOneWidget,
      );
      final moduleScene = tester.element(
        find.byKey(const ValueKey<String>('platform_module_scene_canvas')),
      );

      tester.view.physicalSize = const Size(1400, 1000);
      await tester.pumpAndSettle();
      expect(
        identical(
          moduleScene,
          tester.element(
            find.byKey(const ValueKey<String>('platform_module_scene_canvas')),
          ),
        ),
        isTrue,
      );
      expect(harness.session.pendingChanges.hasChanges, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'collider-free editable prefabs disable committed-shape scene tools',
    (tester) async {
      tester.view.physicalSize = const Size(1800, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final harness = await _buildHarness(
        document: _currentDocumentWithColliderFreeObstacle(),
      );
      addTearDown(harness.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: PrefabCreatorPage(
              controller: harness.session,
              initialPrefabKey: 'obstacle',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _openPrefabSection(
        tester,
        toggleKey: 'prefab_polygon_creation_panel_toggle',
        bodyKey: 'prefab_polygon_creation_name_0',
      );

      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey<String>('prefab_polygon_new_shape')),
            )
            .onPressed,
        isNotNull,
      );
      for (final tool in const <String>[
        'moveVertex',
        'translateShape',
        'insertVertex',
      ]) {
        expect(
          tester
              .widget<ChoiceChip>(
                find.byKey(ValueKey<String>('prefab_polygon_tool_$tool')),
              )
              .onSelected,
          isNull,
        );
      }
    },
  );

  testWidgets(
    'collision sections edit rectangle identity and metadata below its row',
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
        find.byKey(
          const ValueKey<String>('prefab_polygon_creation_panel_toggle'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey<String>('prefab_polygon_shapes_panel_toggle'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey<String>('prefab_polygon_diagnostics_panel_toggle'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('prefab_polygon_new_shape')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('prefab_polygon_metadata_dialog')),
        findsNothing,
      );

      await _openPrefabSection(
        tester,
        toggleKey: 'prefab_polygon_shapes_panel_toggle',
        bodyKey: 'prefab_shape_list',
      );
      final shapeRow = find.byKey(
        const ValueKey<String>('prefab_polygon_shape_collision_001'),
      );
      await tester.tap(shapeRow);
      await tester.pump();
      expect(
        find.byKey(
          const ValueKey<String>(
            'prefab_polygon_selected_shape_editor_collision_001',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey<String>('prefab_polygon_rectangle_width_field'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('prefab_polygon_duplicate_shape')),
        findsOneWidget,
      );

      final nameField = find.byKey(
        const ValueKey<String>('prefab_polygon_shape_name_collision_001'),
      );
      await tester.ensureVisible(nameField);
      await tester.enterText(nameField, 'collision_pending');
      expect(_prefabApplyHandler(tester).canApplyEditorPage, isFalse);
      tester.widget<EditorListCard>(shapeRow).onTap!();
      await tester.pumpAndSettle();
      expect(
        find.byKey(
          const ValueKey<String>('prefab_polygon_unsaved_edit_dialog'),
        ),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(
          const ValueKey<String>('prefab_polygon_unsaved_edit_cancel'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('collision_pending'), findsOneWidget);

      tester.widget<EditorListCard>(shapeRow).onTap!();
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          const ValueKey<String>('prefab_polygon_unsaved_edit_discard'),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(
          const ValueKey<String>(
            'prefab_polygon_selected_shape_editor_collision_001',
          ),
        ),
        findsNothing,
      );
      expect(_prefab(harness.session, 'obstacle').revision, 1);

      await tester.tap(shapeRow);
      await tester.pump();
      await tester.enterText(nameField, 'collision_main');
      await tester.enterText(
        find.byKey(const ValueKey<String>('prefab_polygon_rectangle_x_field')),
        '-4',
      );
      await tester.enterText(
        find.byKey(
          const ValueKey<String>('prefab_polygon_rectangle_bottom_field'),
        ),
        '4',
      );
      await tester.enterText(
        find.byKey(
          const ValueKey<String>('prefab_polygon_rectangle_width_field'),
        ),
        '8',
      );
      await tester.enterText(
        find.byKey(
          const ValueKey<String>('prefab_polygon_rectangle_height_field'),
        ),
        '8',
      );
      final saveEdit = find.byKey(
        const ValueKey<String>('prefab_polygon_save_edit'),
      );
      await tester.ensureVisible(saveEdit);
      await tester.tap(saveEdit);
      await tester.pumpAndSettle();

      var obstacle = _prefab(harness.session, 'obstacle');
      expect(obstacle.revision, 2);
      expect(obstacle.collisionShapes.single.shapeId, 'collision_main');
      expect(
        obstacle.collisionShapes.single.vertices.first,
        const TerrainSourceVertexDef(xHalfPixels: -8, yHalfPixels: -8),
      );

      final modeSelector = find.byKey(
        const ValueKey<String>('prefab_polygon_metadata_mode'),
      );
      await tester.ensureVisible(modeSelector);
      await tester.tap(modeSelector);
      await tester.pumpAndSettle();
      await tester.tap(find.text('One-way').last);
      await tester.pumpAndSettle();
      obstacle = _prefab(harness.session, 'obstacle');
      expect(obstacle.revision, 3);
      expect(
        obstacle.collisionShapes.single.collisionMode,
        TerrainSourceCollisionMode.oneWay,
      );
    },
  );

  testWidgets('route isolates owners and commits whole-pixel polygons', (
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
        home: Scaffold(body: PrefabCreatorPage(controller: harness.session)),
      ),
    );
    await tester.pumpAndSettle();
    await _openOwnerLibrary(tester);

    expect(
      find.byKey(const ValueKey<String>('prefab_polygon_workspace')),
      findsOneWidget,
    );
    expect(find.text('Save Definitions'), findsNothing);
    expect(_prefabApplyHandler(tester).canApplyEditorPage, isFalse);

    await _openPrefabSection(
      tester,
      toggleKey: 'prefab_polygon_creation_panel_toggle',
      bodyKey: 'prefab_polygon_creation_name_0',
    );

    final saveDraftFinder = find.byKey(
      const ValueKey<String>('prefab_polygon_save_draft'),
    );
    expect(tester.widget<OutlinedButton>(saveDraftFinder).onPressed, isNull);
    await tester.tap(
      find.byKey(const ValueKey<String>('prefab_polygon_new_shape')),
    );
    await tester.pump();
    expect(tester.widget<OutlinedButton>(saveDraftFinder).onPressed, isNull);
    final surface = find.byKey(
      const ValueKey<String>('prefab_polygon_scene_surface'),
    );
    await tester.tapAt(tester.getCenter(surface));
    await tester.pump();
    final routeState = tester.state(find.byType(PrefabCreatorPage));
    final localDraftState = routeState as EditorPageLocalDraftState;
    final shortcutHandler = routeState as EditorPageSessionShortcutHandler;
    expect(localDraftState.hasLocalDraftChanges, isTrue);
    expect(shortcutHandler.canHandleUndoSessionShortcut, isTrue);
    expect(shortcutHandler.handleUndoSessionShortcut(), isTrue);
    await tester.pump();
    expect(tester.widget<OutlinedButton>(saveDraftFinder).onPressed, isNull);
    expect(shortcutHandler.canHandleRedoSessionShortcut, isTrue);
    expect(shortcutHandler.handleRedoSessionShortcut(), isTrue);
    await tester.pump();
    expect(harness.session.canUndo, isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(tester.widget<OutlinedButton>(saveDraftFinder).onPressed, isNull);

    await tester.tap(
      find.byKey(const ValueKey<String>('prefab_polygon_new_shape')),
    );
    await tester.pump();

    final platformOwner = find.byKey(
      const ValueKey<String>('prefab_polygon_owner_platform'),
    );
    await tester.ensureVisible(platformOwner);
    await tester.tap(platformOwner);
    await tester.pump();
    expect(tester.widget<OutlinedButton>(saveDraftFinder).onPressed, isNull);
    expect(
      find.textContaining(
        'Finish or cancel the active polygon operation before switching',
      ),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('prefab_polygon_cancel_draft')),
    );
    await tester.pump();
    await tester.ensureVisible(platformOwner);
    await tester.tap(platformOwner);
    await tester.pump();
    expect(tester.widget<OutlinedButton>(saveDraftFinder).onPressed, isNull);
    expect(find.textContaining('platform_module:module_a'), findsWidgets);

    await tester.tap(
      find.byKey(const ValueKey<String>('prefab_polygon_owner_obstacle')),
    );
    await tester.pump();
    expect(find.text('0.5 px'), findsNothing);
    await tester.tap(
      find.byKey(const ValueKey<String>('prefab_polygon_new_shape')),
    );
    await tester.pump();

    final center = tester.getCenter(surface);
    await tester.tapAt(center + const Offset(22, 22));
    await tester.tapAt(center + const Offset(34, 22));
    await tester.tapAt(center + const Offset(22, 34));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
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
      12,
    );
    final impactText = tester.widget<Text>(
      find.byKey(const ValueKey<String>('prefab_polygon_downstream_impact')),
    );
    expect(impactText.data, contains('3 placement(s) in 2 chunk(s)'));
    expect(impactText.data, contains('chunk revisions stay unchanged'));

    expect(_prefabShortcutHandler(tester).handleUndoSessionShortcut(), isTrue);
    await tester.pump();
    obstacle = _prefab(harness.session, 'obstacle');
    expect(obstacle.revision, 1);
    expect(obstacle.collisionShapes, hasLength(1));

    expect(_prefabShortcutHandler(tester).handleRedoSessionShortcut(), isTrue);
    await tester.pump();
    obstacle = _prefab(harness.session, 'obstacle');
    expect(obstacle.revision, 2);

    await _openPrefabSection(
      tester,
      toggleKey: 'prefab_polygon_shapes_panel_toggle',
      bodyKey: 'prefab_shape_list',
    );

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
      find.byKey(const ValueKey<String>('prefab_polygon_save_edit')),
    );
    await tester.pump();
    obstacle = _prefab(harness.session, 'obstacle');
    expect(obstacle.revision, 2);
    expect(find.text('Use a whole-pixel value.'), findsOneWidget);

    await tester.enterText(yField, '6');
    await tester.tap(
      find.byKey(const ValueKey<String>('prefab_polygon_save_edit')),
    );
    await tester.pump();
    obstacle = _prefab(harness.session, 'obstacle');
    expect(obstacle.revision, 3);
    final editedVertex = obstacle.collisionShapes
        .singleWhere((shape) => shape.shapeId == 'collision_002')
        .vertices
        .first;
    expect(editedVertex.xHalfPixels, 10);
    expect(editedVertex.yHalfPixels, 12);

    await tester.tap(
      find.byKey(
        const ValueKey<String>('prefab_polygon_diagnostics_panel_toggle'),
      ),
    );
    await tester.pumpAndSettle();
    final diagnostic = find.text(
      'prefab_collision_shape_outside_visual_bounds',
    );
    await tester.ensureVisible(diagnostic);
    await tester.tap(diagnostic);
    await tester.pump();
    final shapeTile = tester.widget<ListTile>(
      find
          .descendant(
            of: find.byKey(
              const ValueKey<String>('prefab_polygon_shape_collision_001'),
            ),
            matching: find.byType(ListTile),
          )
          .first,
    );
    expect(shapeTile.selected, isTrue);

    expect(harness.session.pendingChanges.changedItemIds, <String>['obstacle']);
    expect(harness.session.exportError, isNull);
  });

  testWidgets(
    'current owner forms preserve polygons across metadata and lifecycle edits',
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
      await _openOwnerLibrary(tester);

      final originalShapes = _prefab(
        harness.session,
        'obstacle',
      ).collisionShapes;
      await tester.tap(
        find.byKey(const ValueKey<String>('prefab_polygon_owner_obstacle')),
      );
      await tester.pump();
      expect(
        find.byKey(
          const ValueKey<String>('prefab_v3_owner_inline_editor_obstacle'),
        ),
        findsOneWidget,
      );
      final statusField = find.byKey(
        const ValueKey<String>('prefab_v3_owner_status_field'),
      );
      await tester.ensureVisible(statusField);
      await tester.pump();
      await tester.tap(statusField);
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
      final applyOwnerMetadata = find.byKey(
        const ValueKey<String>('prefab_v3_owner_inline_apply_obstacle'),
      );
      await tester.ensureVisible(applyOwnerMetadata);
      await tester.pumpAndSettle();
      await tester.tap(applyOwnerMetadata);
      await tester.pumpAndSettle();

      var obstacle = _prefab(harness.session, 'obstacle');
      expect(obstacle.revision, 2);
      expect(obstacle.status, PrefabStatus.deprecated);
      expect(obstacle.anchorXPx, 9);
      expect(obstacle.tags, <String>['boss', 'test']);
      expect(obstacle.collisionShapes, originalShapes);

      expect(
        _prefabShortcutHandler(tester).handleUndoSessionShortcut(),
        isTrue,
      );
      await tester.pump();
      obstacle = _prefab(harness.session, 'obstacle');
      expect(obstacle.revision, 1);
      expect(obstacle.status, PrefabStatus.active);
      expect(obstacle.collisionShapes, originalShapes);
      expect(
        _prefabShortcutHandler(tester).handleRedoSessionShortcut(),
        isTrue,
      );
      await tester.pump();
      expect(_prefab(harness.session, 'obstacle').revision, 2);

      final obstacleOwner = find.byKey(
        const ValueKey<String>('prefab_polygon_owner_obstacle'),
      );
      await tester.ensureVisible(obstacleOwner);
      await tester.tap(obstacleOwner);
      await tester.pump();
      final renameOwner = find.byKey(
        const ValueKey<String>('prefab_v3_owner_rename'),
      );
      await tester.ensureVisible(renameOwner);
      await tester.tap(renameOwner);
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey<String>('prefab_v3_inline_rename_id')),
        'platform',
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('prefab_v3_inline_rename_apply')),
      );
      await tester.pump();
      expect(find.text('Enter a unique trimmed ID.'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey<String>('prefab_v3_inline_rename_id')),
        'obstacle_renamed',
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('prefab_v3_inline_rename_apply')),
      );
      await tester.pumpAndSettle();
      obstacle = _prefab(harness.session, 'obstacle');
      expect(obstacle.id, 'obstacle_renamed');
      expect(obstacle.revision, 3);
      expect(obstacle.collisionShapes, originalShapes);

      await tester.tap(
        find.byKey(const ValueKey<String>('prefab_polygon_owner_obstacle')),
      );
      await tester.pump();
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
        find.byKey(
          const ValueKey<String>('prefab_polygon_owner_obstacle_renamed_copy'),
        ),
      );
      await tester.pump();
      final deleteOwner = find.byKey(
        const ValueKey<String>('prefab_v3_owner_delete'),
      );
      await tester.ensureVisible(deleteOwner);
      await tester.tap(deleteOwner);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('prefab_v3_owner_delete_confirm')),
      );
      await tester.pumpAndSettle();
      expect(
        (harness.session.document! as PrefabV3Document).data.prefabs.any(
          (prefab) => prefab.prefabKey == 'obstacle_renamed_copy',
        ),
        isFalse,
      );

      await _openPrefabSection(
        tester,
        toggleKey: 'prefab_v3_owner_create_section_toggle',
        bodyKey: 'prefab_v3_owner_id_field',
      );
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
      final createOwner = find.byKey(
        const ValueKey<String>('prefab_v3_owner_inline_create_apply'),
      );
      await tester.ensureVisible(createOwner);
      await tester.tap(createOwner);
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
      expect(_prefabApplyHandler(tester).canApplyEditorPage, isTrue);
      unawaited(_prefabApplyHandler(tester).applyEditorPage());
      await tester.pumpAndSettle();
      expect(find.text('Apply Prefab-v3 Changes'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Cancel').last);
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'owner atlas catalog filters usage and creates from a visual slice card',
    (tester) async {
      tester.view.physicalSize = const Size(1800, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final harness = await _buildHarness(
        document: _currentDocumentWithUnusedSlice(),
      );
      addTearDown(harness.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(body: PrefabCreatorPage(controller: harness.session)),
        ),
      );
      await tester.pumpAndSettle();
      await _openOwnerLibrary(tester);
      await _openPrefabSection(
        tester,
        toggleKey: 'prefab_v3_owner_create_section_toggle',
        bodyKey: 'prefab_v3_owner_id_field',
      );

      expect(
        find.byKey(
          const ValueKey<String>('prefab_v3_owner_atlas_slice_search'),
        ),
        findsOneWidget,
      );
      expect(find.text('12x12 · Used by decoration'), findsOneWidget);
      expect(find.text('20x20 · Used by obstacle'), findsOneWidget);
      expect(find.text('8x6 · Unused'), findsOneWidget);
      final sourceExplorer = find.byKey(
        const ValueKey<String>('prefab_v3_owner_atlas_slice_source_filter'),
      );
      expect(sourceExplorer, findsOneWidget);
      await tester.tap(sourceExplorer);
      await tester.pumpAndSettle();
      expect(
        find.byKey(
          const ValueKey<String>('atlas_source_explorer_folder_assets'),
        ),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(
          const ValueKey<String>(
            'atlas_source_explorer_file_assets/obstacles.png',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('1 of 3 atlas slices'), findsOneWidget);
      expect(
        find.byKey(
          const ValueKey<String>(
            'prefab_v3_owner_atlas_slice_card_obstacle_slice',
          ),
        ),
        findsOneWidget,
      );
      await tester.tap(sourceExplorer);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('atlas_source_explorer_all')),
      );
      await tester.pumpAndSettle();
      expect(find.text('3 of 3 atlas slices'), findsOneWidget);

      await tester.enterText(
        find.byKey(
          const ValueKey<String>('prefab_v3_owner_atlas_slice_search'),
        ),
        'flora',
      );
      await tester.pump();
      expect(find.text('1 of 3 atlas slices'), findsOneWidget);
      expect(
        find.byKey(
          const ValueKey<String>(
            'prefab_v3_owner_atlas_slice_card_unused_slice',
          ),
        ),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(
          const ValueKey<String>('prefab_v3_owner_atlas_slice_clear_search'),
        ),
      );
      await tester.pump();
      expect(find.text('3 of 3 atlas slices'), findsOneWidget);

      await tester.tap(
        find.byKey(
          const ValueKey<String>('prefab_v3_owner_atlas_slice_usage_used'),
        ),
      );
      await tester.pump();
      expect(
        find.byKey(
          const ValueKey<String>(
            'prefab_v3_owner_atlas_slice_card_unused_slice',
          ),
        ),
        findsNothing,
      );
      expect(find.text('2 of 3 atlas slices'), findsOneWidget);

      await tester.tap(
        find.byKey(
          const ValueKey<String>('prefab_v3_owner_atlas_slice_usage_unused'),
        ),
      );
      await tester.pump();
      final unusedCard = find.byKey(
        const ValueKey<String>('prefab_v3_owner_atlas_slice_card_unused_slice'),
      );
      expect(unusedCard, findsOneWidget);
      expect(find.text('1 of 3 atlas slices'), findsOneWidget);
      await tester.tap(unusedCard);
      await tester.pump();

      expect(
        tester
            .widget<TextFormField>(
              find.byKey(
                const ValueKey<String>('prefab_v3_owner_anchor_x_field'),
              ),
            )
            .controller!
            .text,
        '4',
      );
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(
                const ValueKey<String>('prefab_v3_owner_anchor_y_field'),
              ),
            )
            .controller!
            .text,
        '3',
      );

      await tester.enterText(
        find.byKey(const ValueKey<String>('prefab_v3_owner_id_field')),
        'unused_owner',
      );
      final create = find.byKey(
        const ValueKey<String>('prefab_v3_owner_inline_create_apply'),
      );
      await tester.ensureVisible(create);
      await tester.tap(create);
      await tester.pumpAndSettle();

      final created = _prefab(harness.session, 'unused_owner');
      expect(created.sliceId, 'unused_slice');
      expect(created.anchorXPx, 4);
      expect(created.anchorYPx, 3);
    },
  );

  testWidgets(
    'inline prefab metadata protects dirty owner and workspace navigation',
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
      await _openOwnerLibrary(tester);

      final obstacleOwner = find.byKey(
        const ValueKey<String>('prefab_polygon_owner_obstacle'),
      );
      await tester.tap(obstacleOwner);
      await tester.pump();
      expect(find.text('Edit prefab metadata'), findsNothing);
      expect(
        find.byKey(
          const ValueKey<String>('prefab_v3_owner_inline_editor_obstacle'),
        ),
        findsOneWidget,
      );
      tester.widget<EditorListCard>(obstacleOwner).onTap!();
      await tester.pump();
      expect(
        find.byKey(
          const ValueKey<String>('prefab_v3_owner_inline_editor_obstacle'),
        ),
        findsNothing,
      );
      tester.widget<EditorListCard>(obstacleOwner).onTap!();
      await tester.pump();
      expect(
        find.byKey(
          const ValueKey<String>('prefab_v3_owner_inline_editor_obstacle'),
        ),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('prefab_v3_owner_tags_field')),
        'unsaved',
      );
      await tester.pump();
      final routeState = tester.state(find.byType(PrefabCreatorPage));
      expect(
        (routeState as EditorPageLocalDraftState).hasLocalDraftChanges,
        isTrue,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('prefab_v3_view_atlas_slices')),
      );
      await tester.pump();
      expect(
        find.textContaining(
          'Apply or cancel the prefab owner draft before switching views',
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey<String>('prefab_v3_owner_inline_editor_obstacle'),
        ),
        findsOneWidget,
      );

      final platformOwner = find.byKey(
        const ValueKey<String>('prefab_polygon_owner_platform'),
      );
      tester.widget<EditorListCard>(platformOwner).onTap!();
      await tester.pumpAndSettle();
      expect(
        find.byKey(
          const ValueKey<String>('prefab_v3_owner_unsaved_edit_dialog'),
        ),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(
          const ValueKey<String>('prefab_v3_owner_unsaved_edit_cancel'),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(
          const ValueKey<String>('prefab_v3_owner_inline_editor_obstacle'),
        ),
        findsOneWidget,
      );

      tester.widget<EditorListCard>(platformOwner).onTap!();
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          const ValueKey<String>('prefab_v3_owner_unsaved_edit_discard'),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(
          const ValueKey<String>('prefab_v3_owner_inline_editor_platform'),
        ),
        findsOneWidget,
      );
      expect(_prefab(harness.session, 'obstacle').tags, <String>['test']);
    },
  );

  testWidgets(
    'inline prefab creation cancels safely and guards owner changes',
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
      await _openOwnerLibrary(tester);
      final beforeDocument = harness.session.document;

      await _openPrefabSection(
        tester,
        toggleKey: 'prefab_v3_owner_create_section_toggle',
        bodyKey: 'prefab_v3_owner_id_field',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('prefab_v3_owner_id_field')),
        'draft_owner',
      );
      await tester.pump();
      expect(
        (tester.state(
          find.byType(PrefabCreatorPage),
        ) as EditorPageLocalDraftState).hasLocalDraftChanges,
        isTrue,
      );

      final platformOwner = find.byKey(
        const ValueKey<String>('prefab_polygon_owner_platform'),
      );
      tester.widget<EditorListCard>(platformOwner).onTap!();
      await tester.pumpAndSettle();
      expect(
        find.byKey(
          const ValueKey<String>('prefab_v3_owner_unsaved_create_dialog'),
        ),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(
          const ValueKey<String>('prefab_v3_owner_unsaved_create_cancel'),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('prefab_v3_owner_id_field')),
        findsOneWidget,
      );

      final cancel = find.byKey(
        const ValueKey<String>('prefab_v3_owner_inline_create_cancel'),
      );
      await tester.ensureVisible(cancel);
      await tester.tap(cancel);
      await tester.pump();
      expect(harness.session.document, same(beforeDocument));
      expect(harness.session.canUndo, isFalse);
      expect(
        (harness.session.document! as PrefabV3Document).data.prefabs.any(
          (prefab) => prefab.id == 'draft_owner',
        ),
        isFalse,
      );
      expect(
        find.byKey(const ValueKey<String>('prefab_v3_owner_id_field')),
        findsNothing,
      );
    },
  );

  testWidgets('stale prefab metadata stays mounted with its local values', (
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
        home: Scaffold(body: PrefabCreatorPage(controller: harness.session)),
      ),
    );
    await tester.pumpAndSettle();
    await _openOwnerLibrary(tester);

    await tester.tap(
      find.byKey(const ValueKey<String>('prefab_polygon_owner_obstacle')),
    );
    await tester.pump();
    final tagsField = find.byKey(
      const ValueKey<String>('prefab_v3_owner_tags_field'),
    );
    await tester.enterText(tagsField, 'local');
    await tester.pump();

    final original = _prefab(harness.session, 'obstacle');
    final before = PrefabV3MetadataSnapshot.fromPrefab(original);
    harness.session.applyCommand(
      AuthoringCommand(
        kind: PrefabDomainPlugin.commitPrefabV3MetadataCommandKind,
        payload: <String, Object?>{
          'prefabKey': original.prefabKey,
          'commit': PrefabV3MetadataCommit(
            before: before,
            after: PrefabV3MetadataSnapshot(
              status: PrefabStatus.deprecated,
              kind: before.kind,
              visualSource: before.visualSource,
              anchorXPx: before.anchorXPx,
              anchorYPx: before.anchorYPx,
              tags: before.tags,
            ),
          ),
        },
      ),
    );
    await tester.pump();
    expect(_prefab(harness.session, 'obstacle').revision, 2);

    final apply = find.byKey(
      const ValueKey<String>('prefab_v3_owner_inline_apply_obstacle'),
    );
    await tester.ensureVisible(apply);
    await tester.tap(apply);
    await tester.pump();

    expect(_prefab(harness.session, 'obstacle').revision, 2);
    expect(
      find.byKey(
        const ValueKey<String>('prefab_v3_owner_inline_editor_obstacle'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('prefab_v3_owner_form_error')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<EditableText>(
            find.descendant(of: tagsField, matching: find.byType(EditableText)),
          )
          .controller
          .text,
      'local',
    );
  });

  testWidgets('current atlas form ignores semantic no-op input callbacks', (
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
        home: Scaffold(body: PrefabCreatorPage(controller: harness.session)),
      ),
    );
    await tester.pumpAndSettle();
    await _openOwnerLibrary(tester);

    await tester.tap(
      find.byKey(const ValueKey<String>('prefab_v3_view_atlas_slices')),
    );
    await tester.pumpAndSettle();
    await _openPrefabSection(
      tester,
      toggleKey: 'atlas_slice_selection_section_toggle',
      bodyKey: 'atlas_selection_w_field',
    );

    final routeState = tester.state(find.byType(PrefabCreatorPage));
    final localDraftState = routeState as EditorPageLocalDraftState;
    final widthField = tester.widget<TextField>(
      find.byKey(const ValueKey<String>('atlas_selection_w_field')),
    );
    final loadedWidth = widthField.controller!.text;
    widthField.onChanged?.call(loadedWidth);
    await tester.pump();

    expect(localDraftState.hasLocalDraftChanges, isFalse);
    expect(harness.session.pendingChanges.hasChanges, isFalse);

    await tester.enterText(
      find.byKey(const ValueKey<String>('atlas_selection_w_field')),
      '${int.parse(loadedWidth) + 1}',
    );
    await tester.pump();
    expect(localDraftState.hasLocalDraftChanges, isTrue);

    await tester.enterText(
      find.byKey(const ValueKey<String>('atlas_selection_w_field')),
      loadedWidth,
    );
    await tester.pump();
    expect(localDraftState.hasLocalDraftChanges, isFalse);

    await tester.tap(
      find.byKey(const ValueKey<String>('prefab_v3_view_owners')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('prefab_polygon_owner_obstacle')),
      findsOneWidget,
    );
    expect(
      find.text(
        'Apply the slice form or undo its local draft before switching.',
      ),
      findsNothing,
    );
  });

  testWidgets(
    'current atlas form commits slices and protects local drafts and references',
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
      await _openOwnerLibrary(tester);

      await tester.tap(
        find.byKey(const ValueKey<String>('prefab_v3_view_atlas_slices')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('atlas_slice_row_decoration_slice')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('atlas_slice_id_field')),
        findsNothing,
      );
      await _openPrefabSection(
        tester,
        toggleKey: 'atlas_slice_library_section_toggle',
        bodyKey: 'atlas_slice_row_decoration_slice',
      );
      await _openPrefabSection(
        tester,
        toggleKey: 'atlas_slice_setup_section_toggle',
        bodyKey: 'atlas_slice_id_field',
      );
      expect(
        find.byKey(const ValueKey<String>('atlas_slice_row_decoration_slice')),
        findsOneWidget,
      );
      expect(
        find.textContaining('Selected for editing in Source & Slice Setup'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('decoration_slice, 12 by 12 pixels, no tags'),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const ValueKey<String>('atlas_slice_id_field')),
        'bonus_slice',
      );
      await tester.pump();
      expect(
        find.textContaining('Creating a new prefab slice'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('atlas_slice_setup_section_toggle')),
        findsNothing,
      );
      expect(
        find.byKey(
          const ValueKey<String>('atlas_slice_selection_section_toggle'),
        ),
        findsNothing,
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

      expect(
        _prefabShortcutHandler(tester).handleUndoSessionShortcut(),
        isTrue,
      );
      await tester.pumpAndSettle();
      expect(
        (harness.session.document! as PrefabV3Document).data.slices.any(
          (slice) => slice.id == 'bonus_slice',
        ),
        isFalse,
      );
      expect(
        _prefabShortcutHandler(tester).handleRedoSessionShortcut(),
        isTrue,
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
        (harness.session.document! as PrefabV3Document).data.slices.any(
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
        (harness.session.document! as PrefabV3Document).tileData.tileSlices.any(
          (slice) => slice.id == 'tile_bonus',
        ),
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
      expect(
        _prefabShortcutHandler(tester).handleUndoSessionShortcut(),
        isTrue,
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
        find.byKey(const ValueKey<String>('prefab_polygon_owner_obstacle')),
        findsOneWidget,
      );
      expect(_prefabApplyHandler(tester).canApplyEditorPage, isFalse);
    },
  );

  testWidgets(
    'current module form preserves references across retained module workflows',
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
      await _openOwnerLibrary(tester);

      await tester.tap(
        find.byKey(const ValueKey<String>('prefab_v3_view_platform_modules')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('platform_module_row_module_a')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('platform_module_id_field')),
        findsNothing,
      );
      await _openPrefabSection(
        tester,
        toggleKey: 'platform_module_library_section_toggle',
        bodyKey: 'platform_module_row_module_a',
      );
      await _openPrefabSection(
        tester,
        toggleKey: 'platform_module_advanced_controls_toggle',
        bodyKey: 'platform_module_id_field',
      );
      expect(
        find.byKey(const ValueKey<String>('platform_module_row_module_a')),
        findsOneWidget,
      );
      expect(
        find.textContaining('Selected for editing in Edit selected module'),
        findsOneWidget,
      );
      expect(find.text('Editing platform module "module_a"'), findsOneWidget);
      expect(
        find.bySemanticsLabel('module_a, active, 1 cells, 16 pixel tiles'),
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
      await tester.pump();
      expect(
        find.byKey(
          const ValueKey<String>('platform_module_advanced_controls_toggle'),
        ),
        findsNothing,
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

      expect(
        _prefabShortcutHandler(tester).handleUndoSessionShortcut(),
        isTrue,
      );
      await tester.pumpAndSettle();
      expect(_module(harness.session, 'module_a').revision, 1);
      expect(_module(harness.session, 'module_a').tileSize, 16);
      expect(
        _prefabShortcutHandler(tester).handleRedoSessionShortcut(),
        isTrue,
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
        (harness.session.document! as PrefabV3Document).tileData.platformModules
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
      expect(find.text('Create platform module'), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(
                const ValueKey<String>('platform_module_rename_button'),
              ),
            )
            .onPressed,
        isNull,
      );
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
        (harness.session.document! as PrefabV3Document).tileData.platformModules
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
      expect(
        _prefabShortcutHandler(tester).handleUndoSessionShortcut(),
        isTrue,
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
        find.byKey(const ValueKey<String>('prefab_polygon_owner_obstacle')),
        findsOneWidget,
      );
      expect(_prefabApplyHandler(tester).canApplyEditorPage, isTrue);
    },
  );
}

EditorPageSessionShortcutHandler _prefabShortcutHandler(WidgetTester tester) =>
    tester.state(find.byType(PrefabCreatorPage))
        as EditorPageSessionShortcutHandler;

EditorPageApplyHandler _prefabApplyHandler(WidgetTester tester) =>
    tester.state(find.byType(PrefabCreatorPage)) as EditorPageApplyHandler;

Future<_Harness> _buildHarness({PrefabV3Document? document}) async {
  final root = Directory.systemTemp.createTempSync('prefab_stage_page_');
  final loadedDocument = document ?? _currentDocument();
  final session = EditorSessionController(
    pluginRegistry: AuthoringPluginRegistry(
      plugins: <AuthoringDomainPlugin>[_PrefabPlugin(loadedDocument)],
    ),
    initialPluginId: PrefabDomainPlugin.pluginId,
    initialWorkspacePath: root.path,
  );
  await session.loadWorkspace();
  return _Harness(root: root, session: session);
}

PrefabV3Document _currentDocument() {
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
  return PrefabV3Document(
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

PrefabV3Document _currentDocumentWithColliderFreeObstacle() {
  final document = _currentDocument();
  final data = document.data.copyWith(
    prefabs: document.data.prefabs.map(
      (prefab) => prefab.prefabKey == 'obstacle'
          ? prefab.copyWith(collisionShapes: const <TerrainSourceShapeDef>[])
          : prefab,
    ),
  );
  return document.copyWith(
    data: data,
    prefabBaselineContents: PrefabV3FileCodec.encode(data),
  );
}

PrefabV3Document _currentDocumentWithUnusedSlice() {
  final document = _currentDocument();
  final data = document.data.copyWith(
    slices: <AtlasSliceDef>[
      ...document.data.slices,
      const AtlasSliceDef(
        id: 'unused_slice',
        sourceImagePath: 'assets/decorations.png',
        x: 0,
        y: 0,
        width: 8,
        height: 6,
        tags: <String>['flora'],
      ),
    ],
  );
  return document.copyWith(
    data: data,
    prefabBaselineContents: PrefabV3FileCodec.encode(data),
  );
}

PrefabV3Def _prefab(EditorSessionController session, String prefabKey) {
  final document = session.document! as PrefabV3Document;
  return document.data.prefabs.singleWhere(
    (prefab) => prefab.prefabKey == prefabKey,
  );
}

AtlasSliceDef _slice(EditorSessionController session, String sliceId) {
  final document = session.document! as PrefabV3Document;
  return <AtlasSliceDef>[
    ...document.data.slices,
    ...document.tileData.tileSlices,
  ].singleWhere((slice) => slice.id == sliceId);
}

TileModuleDef _module(EditorSessionController session, String moduleId) {
  final document = session.document! as PrefabV3Document;
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

Future<void> _openPrefabSection(
  WidgetTester tester, {
  required String toggleKey,
  required String bodyKey,
}) async {
  final body = find.byKey(ValueKey<String>(bodyKey));
  if (body.evaluate().isNotEmpty) return;
  final toggle = find.byKey(ValueKey<String>(toggleKey));
  expect(toggle, findsOneWidget);
  await tester.ensureVisible(toggle);
  await tester.tap(toggle);
  await tester.pumpAndSettle();
  expect(body, findsOneWidget);
}

Future<void> _openOwnerLibrary(WidgetTester tester) => _openPrefabSection(
  tester,
  toggleKey: 'prefab_owner_library_section_toggle',
  bodyKey: 'prefab_owner_catalog_search',
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

final class _PrefabPlugin implements AuthoringDomainPlugin {
  const _PrefabPlugin(this.document);

  final PrefabV3Document document;
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
