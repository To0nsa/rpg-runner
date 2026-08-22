import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:runner_editor/src/app/pages/chunkCreator/chunk_creator_page.dart';
import 'package:runner_editor/src/app/pages/chunkCreator/v2/chunk_actor_terrain_overlay_painter.dart';
import 'package:runner_editor/src/app/pages/chunkCreator/v2/chunk_marker_placement_overlay_painter.dart';
import 'package:runner_editor/src/app/pages/chunkCreator/v2/chunk_prefab_catalog_browser.dart';
import 'package:runner_editor/src/app/pages/chunkCreator/v2/chunk_polygon_level_visual_source.dart';
import 'package:runner_editor/src/app/pages/chunkCreator/v2/chunk_scene_coordinator.dart';
import 'package:runner_editor/src/app/pages/chunkCreator/v2/chunk_scene_surface.dart';
import 'package:runner_editor/src/app/pages/chunkCreator/v2/chunk_scene_visual_source.dart';
import 'package:runner_editor/src/app/pages/chunkCreator/v2/chunk_v2_composition_forms.dart';
import 'package:runner_editor/src/app/pages/shared/editor_list_card.dart';
import 'package:runner_editor/src/app/pages/shared/editor_page_local_draft_state.dart';
import 'package:runner_editor/src/app/pages/shared/editor_scene_viewport_frame.dart';
import 'package:runner_editor/src/chunks/chunk_v2_actor_terrain_projection.dart';
import 'package:runner_editor/src/chunks/chunk_domain_models.dart';
import 'package:runner_editor/src/chunks/chunk_domain_plugin.dart';
import 'package:runner_editor/src/chunks/chunk_v2_file_codec.dart';
import 'package:runner_editor/src/chunks/chunk_v2_file_data.dart';
import 'package:runner_editor/src/chunks/chunk_v2_metadata_commit.dart';
import 'package:runner_editor/src/chunks/chunk_v2_models.dart';
import 'package:runner_editor/src/levels/level_domain_models.dart';
import 'package:runner_editor/src/parallax/parallax_domain_models.dart';
import 'package:runner_editor/src/domain/authoring_plugin_registry.dart';
import 'package:runner_editor/src/domain/authoring_types.dart';
import 'package:runner_editor/src/prefabs/domain/prefab_domain_models.dart';
import 'package:runner_editor/src/prefabs/models/models.dart';
import 'package:runner_editor/src/session/editor_session_controller.dart';
import 'package:runner_editor/src/terrain_authoring/terrain_source_models.dart';
import 'package:runner_editor/src/workspace/editor_workspace.dart';

void main() {
  testWidgets(
    'new terrain drafts use the authored material and preview every gesture',
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
          home: Scaffold(body: ChunkCreatorPage(controller: harness.session)),
        ),
      );
      await tester.pumpAndSettle();

      ChunkPolygonLevelVisualSource materialPreview() => tester.widget(
        find.byKey(
          const ValueKey<String>('chunk_polygon_terrain_material_preview'),
        ),
      );

      expect(materialPreview().terrainShapes, hasLength(1));
      await tester.tap(
        find.byKey(const ValueKey<String>('chunk_polygon_new_shape')),
      );
      await tester.pump();

      final surfaceFinder = find.byKey(
        const ValueKey<String>('chunk_scene_surface'),
      );
      final surface = tester.widget<ChunkSceneSurface>(
        find.ancestor(
          of: surfaceFinder,
          matching: find.byType(ChunkSceneSurface),
        ),
      );
      Offset scenePoint(double x, double y) =>
          tester.getTopLeft(surfaceFinder) +
          surface.transform.origin +
          Offset(x * surface.transform.zoom, y * surface.transform.zoom);

      await tester.tapAt(scenePoint(60, 15));
      await tester.tapAt(scenePoint(80, 15));
      await tester.pump();
      expect(materialPreview().terrainShapes, hasLength(1));

      await tester.tapAt(scenePoint(80, 30));
      await tester.pump();
      var draft = materialPreview().terrainShapes!.last;
      expect(materialPreview().terrainShapes, hasLength(2));
      expect(draft.surfaceKind, 'ground');
      expect(draft.materialKey, 'grass_dirt');
      expect(_chunk(harness.session, 'forest_chunk').revision, 4);
      expect(harness.session.pendingChanges.hasChanges, isFalse);

      await tester.tap(
        find.byKey(const ValueKey<String>('chunk_polygon_tool_moveVertex')),
      );
      await tester.pump();
      final gesture = await tester.startGesture(scenePoint(60, 15));
      await gesture.moveTo(scenePoint(64, 18));
      await tester.pump();
      draft = materialPreview().terrainShapes!.last;
      expect(
        draft.vertices.first,
        const TerrainSourceVertexDef(xHalfPixels: 128, yHalfPixels: 36),
      );
      expect(_chunk(harness.session, 'forest_chunk').revision, 4);
      expect(harness.session.pendingChanges.hasChanges, isFalse);
      await gesture.up();
    },
  );

  testWidgets(
    'creation selectors configure rectangles and retain their choices',
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
          home: Scaffold(body: ChunkCreatorPage(controller: harness.session)),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('chunk_polygon_creation_panel')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('chunk_polygon_shapes_panel')),
        findsOneWidget,
      );
      expect(find.text('Create terrain shape'), findsOneWidget);
      expect(find.text('Existing terrain shapes'), findsOneWidget);
      final creationPanelToggle = find.byKey(
        const ValueKey<String>('chunk_polygon_creation_panel_toggle'),
      );
      expect(creationPanelToggle, findsOneWidget);
      await tester.tap(creationPanelToggle);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('chunk_polygon_creation_section')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('chunk_polygon_shapes_panel')),
        findsOneWidget,
      );
      await tester.tap(creationPanelToggle);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('chunk_polygon_creation_section')),
        findsOneWidget,
      );

      final modeSelector = find.byKey(
        const ValueKey<String>('chunk_polygon_creation_mode_selector'),
      );
      final materialSelector = find.byKey(
        const ValueKey<String>('chunk_polygon_creation_material_selector'),
      );
      final newRectangle = find.byKey(
        const ValueKey<String>('chunk_polygon_new_rectangle'),
      );
      final shapeName = find.byKey(
        const ValueKey<String>('chunk_polygon_creation_name_0'),
      );
      final legacyCreationPreviewButton = find.byKey(
        const ValueKey<String>(
          'chunk_polygon_creation_material_preview_button',
        ),
      );
      final grassDirtPreviewButton = find.byKey(
        const ValueKey<String>(
          'chunk_polygon_creation_material_preview_grass_dirt',
        ),
      );
      await tester.ensureVisible(modeSelector);

      expect(
        tester
            .widget<DropdownButton<TerrainSourceCollisionMode>>(modeSelector)
            .value,
        TerrainSourceCollisionMode.solid,
      );
      expect(
        tester
            .widget<DropdownButton<TerrainSourceCollisionMode>>(modeSelector)
            .items!
            .map((item) => item.value),
        contains(TerrainSourceCollisionMode.none),
      );
      expect(
        tester.widget<DropdownButton<String>>(materialSelector).value,
        'grass_dirt',
      );
      expect(legacyCreationPreviewButton, findsNothing);
      expect(grassDirtPreviewButton, findsNothing);

      await tester.tap(materialSelector);
      await tester.pumpAndSettle();
      expect(grassDirtPreviewButton, findsOneWidget);
      await tester.tap(grassDirtPreviewButton);
      await tester.pumpAndSettle();
      expect(
        find.byKey(
          const ValueKey<String>('chunk_polygon_read_only_material_dialog'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(TextButton, 'Close'));
      await tester.pumpAndSettle();

      tester
          .widget<DropdownButton<TerrainSourceCollisionMode>>(modeSelector)
          .onChanged!(TerrainSourceCollisionMode.oneWay);
      tester.widget<DropdownButton<String>>(materialSelector).onChanged!('');
      await tester.pump();
      await tester.ensureVisible(shapeName);
      await tester.enterText(shapeName, 'one_way_ledge');
      await tester.ensureVisible(newRectangle);
      await tester.tap(newRectangle);
      await tester.pump();
      expect(find.text('Rectangle tool ready'), findsOneWidget);

      final surfaceFinder = find.byKey(
        const ValueKey<String>('chunk_scene_surface'),
      );
      final surface = tester.widget<ChunkSceneSurface>(
        find.ancestor(
          of: surfaceFinder,
          matching: find.byType(ChunkSceneSurface),
        ),
      );
      Offset scenePoint(double x, double y) =>
          tester.getTopLeft(surfaceFinder) +
          surface.transform.origin +
          Offset(x * surface.transform.zoom, y * surface.transform.zoom);
      final gesture = await tester.startGesture(scenePoint(60, 15));
      await gesture.moveTo(scenePoint(80, 30));
      await tester.pump();
      expect(find.text('Drawing rectangle'), findsOneWidget);

      expect(
        tester
            .widget<DropdownButton<TerrainSourceCollisionMode>>(modeSelector)
            .onChanged,
        isNull,
      );
      expect(
        tester.widget<DropdownButton<String>>(materialSelector).onChanged,
        isNull,
      );

      final materialPreview = tester.widget<ChunkPolygonLevelVisualSource>(
        find.byKey(
          const ValueKey<String>('chunk_polygon_terrain_material_preview'),
        ),
      );
      final preview = materialPreview.terrainShapes!.last;
      expect(preview.collisionMode, TerrainSourceCollisionMode.oneWay);
      expect(preview.materialKey, isNull);

      await gesture.up();
      await tester.pump();
      expect(find.text('Rectangle draft ready'), findsOneWidget);
      expect(
        tester
            .widget<DropdownButton<TerrainSourceCollisionMode>>(modeSelector)
            .onChanged,
        isNull,
      );
      expect(
        tester.widget<DropdownButton<String>>(materialSelector).onChanged,
        isNull,
      );

      final saveDraft = find.byKey(
        const ValueKey<String>('chunk_polygon_save_draft'),
      );
      await tester.ensureVisible(saveDraft);
      await tester.tap(saveDraft);
      await tester.pump();

      final created = _chunk(harness.session, 'forest_chunk').collisionShapes
          .singleWhere((shape) => shape.shapeId == 'one_way_ledge');
      expect(created.collisionMode, TerrainSourceCollisionMode.oneWay);
      expect(created.materialKey, isNull);
      expect(
        tester
            .widget<DropdownButton<TerrainSourceCollisionMode>>(modeSelector)
            .value,
        TerrainSourceCollisionMode.oneWay,
      );
      expect(tester.widget<DropdownButton<String>>(materialSelector).value, '');
      expect(find.text('2 total'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('chunk_polygon_creation_name_1')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey<String>('chunk_polygon_selected_shape_editor'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'explicit chunk-v2 route edits active-level owners without reloading source',
    (tester) async {
      tester.view.physicalSize = const Size(1800, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final harness = await _buildHarness();
      addTearDown(harness.dispose);
      expect(harness.plugin.loadCount, 1);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(body: ChunkCreatorPage(controller: harness.session)),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('chunk_authoring_workspace')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('chunk_workspace_wide')),
        findsOneWidget,
      );
      expect(find.text('Chunk creation scene'), findsOneWidget);
      expect(find.text('Chunk owners'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('chunk_terrain_card')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('chunk_prefabs_card')),
        findsNothing,
      );
      final domainSelectorFinder = find.byKey(
        const ValueKey<String>('chunk_scene_domain_selector'),
      );
      final domainSelector = tester.widget<SegmentedButton<ChunkSceneDomain>>(
        domainSelectorFinder,
      );
      expect(
        domainSelector.segments.map((segment) => segment.value),
        <ChunkSceneDomain>[
          ChunkSceneDomain.terrain,
          ChunkSceneDomain.prefabs,
          ChunkSceneDomain.markers,
          ChunkSceneDomain.layers,
        ],
      );
      final globalControls = find.byKey(
        const ValueKey<String>('chunk_scene_global_controls'),
      );
      expect(
        tester.getBottomLeft(globalControls).dy,
        lessThan(tester.getTopLeft(domainSelectorFinder).dy),
      );
      final ownerSidebarSlot = find.byKey(
        const ValueKey<String>('chunk_owner_sidebar_slot'),
      );
      final sceneSlot = find.byKey(const ValueKey<String>('chunk_scene_slot'));
      final sidebarSlot = find.byKey(
        const ValueKey<String>('chunk_sidebar_slot'),
      );
      expect(
        tester.getTopRight(ownerSidebarSlot).dx,
        lessThan(tester.getTopLeft(sceneSlot).dx),
      );
      expect(
        tester.getTopRight(sceneSlot).dx,
        lessThan(tester.getTopLeft(sidebarSlot).dx),
      );
      expect(harness.plugin.loadCount, 1);
      final scene = harness.session.scene;
      expect(scene, isA<ChunkV2Scene>());
      expect(
        (scene as ChunkV2Scene).activeParallaxTheme?.parallaxThemeId,
        'forest',
      );
      expect(
        find.byKey(const ValueKey<String>('chunk_polygon_owner_forest_chunk')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('chunk_owner_preview_forest_chunk')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('chunk_polygon_owner_meadow_chunk')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('chunk_expanded_collision_overlay')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('chunk_compiled_edges_toggle')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('chunk_polygon_snap_selector')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('chunk_compiled_edge_overlay')),
        findsNothing,
      );
      final shapeEdgesToggle = find.byKey(
        const ValueKey<String>('chunk_shape_edges_toggle'),
      );
      expect(shapeEdgesToggle, findsOneWidget);
      expect(tester.widget<FilterChip>(shapeEdgesToggle).selected, isFalse);
      await tester.tap(shapeEdgesToggle);
      await tester.pump();
      expect(
        find.byKey(const ValueKey<String>('chunk_compiled_edge_overlay')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey<String>('chunk_polygon_terrain_material_preview'),
        ),
        findsOneWidget,
      );
      expect(_chunk(harness.session, 'forest_chunk').revision, 4);
      expect(harness.session.pendingChanges.hasChanges, isFalse);
      await tester.tap(shapeEdgesToggle);
      await tester.pump();
      expect(
        find.byKey(const ValueKey<String>('chunk_compiled_edge_overlay')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('chunk_polygon_parallax_background')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey<String>('chunk_polygon_terrain_material_preview'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('chunk_polygon_parallax_foreground')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey<String>('chunk_polygon_visual_at_or_above_terrain'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('chunk_authoring_overlay')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('chunk_bounds_overlay')),
        findsOneWidget,
      );
      final viewportFrame = find.descendant(
        of: find.byKey(const ValueKey<String>('chunk_creation_scene')),
        matching: find.byType(EditorSceneViewportFrame),
      );
      expect(viewportFrame, findsOneWidget);
      expect(
        tester.widget<EditorSceneViewportFrame>(viewportFrame).showBorder,
        isTrue,
      );
      final visualPreviewToggle = find.byKey(
        const ValueKey<String>('chunk_visual_preview_toggle'),
      );
      expect(visualPreviewToggle, findsOneWidget);
      expect(tester.widget<FilterChip>(visualPreviewToggle).selected, isFalse);
      await tester.tap(visualPreviewToggle);
      await tester.pump();

      expect(tester.widget<FilterChip>(visualPreviewToggle).selected, isTrue);
      expect(tester.widget<FilterChip>(shapeEdgesToggle).onSelected, isNull);
      expect(
        tester.widget<EditorSceneViewportFrame>(viewportFrame).showBorder,
        isFalse,
      );
      expect(
        find.byKey(const ValueKey<String>('chunk_authoring_overlay')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('chunk_bounds_overlay')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('chunk_expanded_collision_overlay')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('chunk_compiled_edge_overlay')),
        findsNothing,
      );
      expect(
        find.byKey(
          const ValueKey<String>('chunk_polygon_terrain_material_preview'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey<String>('chunk_polygon_visual_at_or_above_terrain'),
        ),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('chunk_scene_surface')),
      );
      await tester.pump();
      expect(_chunk(harness.session, 'forest_chunk').revision, 4);
      expect(harness.session.pendingChanges.hasChanges, isFalse);

      await tester.tap(visualPreviewToggle);
      await tester.pump();
      expect(tester.widget<FilterChip>(visualPreviewToggle).selected, isFalse);
      expect(
        tester.widget<EditorSceneViewportFrame>(viewportFrame).showBorder,
        isTrue,
      );
      expect(
        find.byKey(const ValueKey<String>('chunk_authoring_overlay')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('chunk_bounds_overlay')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('chunk_expanded_collision_overlay')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('chunk_polygon_source_fill_notice')),
        findsNothing,
      );
      expect(
        find.text(
          '1 direct + 1 expanded = 2/512 collidable shapes · 0 render-only · '
          '8/4096 exposed edges',
        ),
        findsNothing,
      );
      expect(
        find.text(
          '1 reachable neighbor(s) · 1 directed scheduler seam(s) · '
          '1 compatible · 0 failing',
        ),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('chunk_polygon_shapes_panel')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('chunk_polygon_seams_panel')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('chunk_polygon_diagnostics_panel')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('chunk_diagnostics_card')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey<String>('chunk_compiled_edge_inspect_toggle'),
        ),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('chunk_compiled_edge_overlay')),
        findsNothing,
      );
      final shapeList = find.byKey(const ValueKey<String>('chunk_shape_list'));
      final authoringSidebar = find.byKey(
        const ValueKey<String>('chunk_authoring_sidebar'),
      );
      final authoringSidebarScrollable = find
          .descendant(of: authoringSidebar, matching: find.byType(Scrollable))
          .first;
      expect(
        find.descendant(of: shapeList, matching: find.byType(Scrollable)),
        findsNothing,
      );
      final shapePanelToggle = find.byKey(
        const ValueKey<String>('chunk_polygon_shapes_panel_toggle'),
      );
      await tester.scrollUntilVisible(
        shapePanelToggle,
        200,
        scrollable: authoringSidebarScrollable,
      );
      await tester.tap(shapePanelToggle);
      await tester.pumpAndSettle();
      expect(shapeList, findsNothing);
      await tester.tap(shapePanelToggle);
      await tester.pumpAndSettle();
      expect(shapeList, findsOneWidget);
      expect(_chunk(harness.session, 'forest_chunk').revision, 4);
      expect(harness.session.pendingChanges.hasChanges, isFalse);
      expect(
        find.byKey(const ValueKey<String>('chunk_actor_terrain_toggle')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('chunk_actor_terrain_selector')),
        findsOneWidget,
      );
      final globalControlsWrap = tester.widget<Wrap>(
        find.byKey(const ValueKey<String>('chunk_scene_global_controls')),
      );
      final actorControlIndex = globalControlsWrap.children.indexWhere(
        (child) =>
            child.key == const ValueKey<String>('chunk_actor_terrain_toggle'),
      );
      expect(actorControlIndex, greaterThanOrEqualTo(0));
      expect(
        globalControlsWrap.children[actorControlIndex + 1].key,
        const ValueKey<String>('chunk_marker_placement_toggle'),
      );
      expect(
        find.byKey(const ValueKey<String>('chunk_actor_terrain_overlay')),
        findsNothing,
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('chunk_actor_terrain_toggle')),
      );
      await tester.pump();
      final actorOverlay = find.byKey(
        const ValueKey<String>('chunk_actor_terrain_overlay'),
      );
      expect(actorOverlay, findsOneWidget);
      final actorPainter = tester.widget<CustomPaint>(actorOverlay).painter;
      expect(actorPainter, isA<ChunkActorTerrainOverlayPainter>());
      expect(
        (actorPainter! as ChunkActorTerrainOverlayPainter).actor,
        ChunkV2TerrainActor.eloise,
      );
      expect(find.textContaining('Éloïse-walkable surfaces'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey<String>('chunk_marker_placement_toggle')),
      );
      await tester.pump();
      final markerOverlay = find.byKey(
        const ValueKey<String>('chunk_marker_placement_overlay'),
      );
      expect(markerOverlay, findsOneWidget);
      expect(
        tester.widget<CustomPaint>(markerOverlay).painter,
        isA<ChunkMarkerPlacementOverlayPainter>(),
      );
      expect(find.textContaining('0 RNG draws'), findsNothing);
      expect(_chunk(harness.session, 'forest_chunk').revision, 4);
      expect(harness.session.pendingChanges.hasChanges, isFalse);
      final routeState = tester.state(find.byType(ChunkCreatorPage));
      final applyHandler = routeState as EditorPageApplyHandler;
      expect(applyHandler.canApplyEditorPage, isFalse);

      final groundShape = find.byKey(
        const ValueKey<String>('chunk_polygon_shape_ground_001'),
      );
      await tester.scrollUntilVisible(
        groundShape,
        200,
        scrollable: authoringSidebarScrollable,
      );
      await tester.tap(groundShape);
      await tester.pump();
      final deleteShape = find.byKey(
        const ValueKey<String>('chunk_polygon_delete_shape'),
      );
      await tester.scrollUntilVisible(
        deleteShape,
        160,
        scrollable: authoringSidebarScrollable,
      );
      await tester.tap(deleteShape);
      await tester.pump();

      var forestChunk = _chunk(harness.session, 'forest_chunk');
      expect(forestChunk.revision, 5);
      expect(forestChunk.collisionShapes, isEmpty);
      expect(harness.session.pendingChanges.changedItemIds, <String>[
        'forest_chunk',
      ]);
      expect(applyHandler.canApplyEditorPage, isTrue);
      unawaited(applyHandler.applyEditorPage());
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();
      expect(find.text('Apply Chunk-v2 Changes'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Cancel').last);
      await tester.pumpAndSettle();

      final localDraftState = routeState as EditorPageLocalDraftState;
      final shortcutHandler = routeState as EditorPageSessionShortcutHandler;
      final reloadHandler = routeState as EditorPageReloadHandler;
      expect(localDraftState.hasLocalDraftChanges, isTrue);
      expect(shortcutHandler.canHandleUndoSessionShortcut, isTrue);
      expect(shortcutHandler.handleUndoSessionShortcut(), isTrue);
      await tester.pump();

      forestChunk = _chunk(harness.session, 'forest_chunk');
      expect(forestChunk.revision, 4);
      expect(forestChunk.collisionShapes, hasLength(1));
      expect(harness.session.pendingChanges.hasChanges, isFalse);
      expect(reloadHandler.canReloadEditorPage, isTrue);

      await tester.drag(authoringSidebar, const Offset(0, 2000));
      await tester.pump();
      await tester.scrollUntilVisible(
        groundShape,
        100,
        scrollable: authoringSidebarScrollable,
      );
      await tester.tap(groundShape);
      await tester.pump();
      final firstVertex = find.byKey(
        const ValueKey<String>('chunk_polygon_vertex_ground_001_0'),
      );
      await tester.scrollUntilVisible(
        firstVertex,
        100,
        scrollable: authoringSidebarScrollable,
      );
      await tester.tap(firstVertex);
      await tester.pump();
      final xField = find.byKey(
        const ValueKey<String>('chunk_polygon_vertex_x_field'),
      );
      final yField = find.byKey(
        const ValueKey<String>('chunk_polygon_vertex_y_field'),
      );
      final applyVertex = find.byKey(
        const ValueKey<String>('chunk_polygon_save_edit'),
      );
      expect(find.text('Apply exact vertex'), findsNothing);
      expect(find.text('Save edit'), findsOneWidget);
      await tester.ensureVisible(xField);
      await tester.enterText(xField, '12.5');
      await tester.enterText(yField, '10');
      await Scrollable.ensureVisible(
        tester.element(applyVertex),
        alignment: 0.5,
      );
      await tester.pump();
      await tester.tap(applyVertex);
      await tester.pump();

      expect(find.text('Use a whole-pixel value.'), findsOneWidget);
      forestChunk = _chunk(harness.session, 'forest_chunk');
      expect(forestChunk.revision, 4);
      expect(harness.session.pendingChanges.hasChanges, isFalse);

      await tester.enterText(xField, '12');
      await tester.tap(applyVertex);
      await tester.pump();

      forestChunk = _chunk(harness.session, 'forest_chunk');
      expect(forestChunk.revision, 5);
      expect(
        forestChunk.collisionShapes.single.vertices,
        contains(
          const TerrainSourceVertexDef(xHalfPixels: 24, yHalfPixels: 20),
        ),
      );
      expect(harness.session.pendingChanges.changedItemIds, <String>[
        'forest_chunk',
      ]);
      expect(shortcutHandler.handleUndoSessionShortcut(), isTrue);
      await tester.pump();
      forestChunk = _chunk(harness.session, 'forest_chunk');
      expect(forestChunk.revision, 4);
      expect(harness.session.pendingChanges.hasChanges, isFalse);

      await tester.enterText(xField, '101');
      await tester.tap(applyVertex);
      await tester.pump();
      forestChunk = _chunk(harness.session, 'forest_chunk');
      expect(forestChunk.revision, 4);
      expect(harness.session.pendingChanges.hasChanges, isFalse);
      expect(tester.widget<TextField>(xField).controller!.text, '101');
      final outOfBoundsIssue = find.text('chunk_collision_shape_out_of_bounds');
      expect(outOfBoundsIssue, findsNothing);

      await tester.drag(authoringSidebar, const Offset(0, 5000));
      await tester.pump();
      tester
          .state<ScrollableState>(authoringSidebarScrollable)
          .position
          .jumpTo(0);
      await tester.pump();
      final modeSelector = find.descendant(
        of: shapeList,
        matching: find.byKey(
          const ValueKey<String>('chunk_polygon_metadata_mode'),
        ),
      );
      await Scrollable.ensureVisible(
        tester.element(modeSelector),
        alignment: 0.5,
      );
      await tester.pump();
      await tester.tap(modeSelector);
      await tester.pumpAndSettle();
      await tester.tap(find.text('oneWay').last);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          const ValueKey<String>('chunk_polygon_metadata_surface_selector'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('ground').last);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          const ValueKey<String>('chunk_polygon_metadata_material_selector'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Grass / Dirt · grass_dirt').last);
      await tester.pumpAndSettle();

      forestChunk = _chunk(harness.session, 'forest_chunk');
      final editedShape = forestChunk.collisionShapes.single;
      expect(forestChunk.revision, 7);
      expect(editedShape.collisionMode, TerrainSourceCollisionMode.oneWay);
      expect(editedShape.surfaceKind, 'ground');
      expect(editedShape.materialKey, 'grass_dirt');
      expect(harness.session.pendingChanges.changedItemIds, <String>[
        'forest_chunk',
      ]);
      for (var index = 0; index < 3; index += 1) {
        expect(shortcutHandler.handleUndoSessionShortcut(), isTrue);
        await tester.pump();
      }
      forestChunk = _chunk(harness.session, 'forest_chunk');
      expect(forestChunk.revision, 4);
      expect(
        forestChunk.collisionShapes.single.collisionMode,
        TerrainSourceCollisionMode.solid,
      );
      expect(forestChunk.collisionShapes.single.surfaceKind, isNull);
      expect(forestChunk.collisionShapes.single.materialKey, isNull);
      expect(harness.session.pendingChanges.hasChanges, isFalse);

      await tester.pumpAndSettle();
      tester
          .state<ScrollableState>(authoringSidebarScrollable)
          .position
          .jumpTo(0);
      await tester.pump();
      final duplicateShape = find.descendant(
        of: shapeList,
        matching: find.byKey(
          const ValueKey<String>('chunk_polygon_duplicate_shape'),
        ),
      );
      await tester.ensureVisible(duplicateShape);
      await tester.tap(duplicateShape);
      await tester.pump();
      forestChunk = _chunk(harness.session, 'forest_chunk');
      expect(forestChunk.revision, 5);
      expect(forestChunk.collisionShapes, hasLength(2));
      final duplicatedShape = forestChunk.collisionShapes.singleWhere(
        (shape) => shape.shapeId == 'ground_002',
      );
      expect(
        duplicatedShape.vertices,
        contains(
          const TerrainSourceVertexDef(xHalfPixels: 102, yHalfPixels: 20),
        ),
      );
      expect(shortcutHandler.handleUndoSessionShortcut(), isTrue);
      await tester.pump();
      forestChunk = _chunk(harness.session, 'forest_chunk');
      expect(forestChunk.revision, 4);
      expect(forestChunk.collisionShapes, hasLength(1));
      expect(harness.session.pendingChanges.hasChanges, isFalse);

      await tester.tap(
        find.byKey(const ValueKey<String>('chunk_polygon_level_selector')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('meadow').last);
      await tester.pumpAndSettle();

      expect(
        (harness.session.document! as ChunkV2Document).activeLevelId,
        'meadow',
      );
      expect(
        find.byKey(const ValueKey<String>('chunk_polygon_owner_meadow_chunk')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('chunk_polygon_owner_forest_chunk')),
        findsNothing,
      );
      expect(harness.plugin.loadCount, 1);
    },
  );

  testWidgets('scene and composition cards share prefab and marker selection', (
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
        home: Scaffold(body: ChunkCreatorPage(controller: harness.session)),
      ),
    );
    await tester.pumpAndSettle();

    final sidebar = find.byKey(
      const ValueKey<String>('chunk_authoring_sidebar'),
    );
    final sidebarScrollable = find
        .descendant(of: sidebar, matching: find.byType(Scrollable))
        .first;
    final domainSelector = find.byKey(
      const ValueKey<String>('chunk_scene_domain_selector'),
    );
    tester
        .widget<SegmentedButton<ChunkSceneDomain>>(domainSelector)
        .onSelectionChanged!(<ChunkSceneDomain>{ChunkSceneDomain.prefabs});
    await tester.pump();
    expect(find.text('Create prefab placement'), findsOneWidget);
    expect(find.text('Existing prefab placements'), findsOneWidget);
    final prefabCreationToggle = find.byKey(
      const ValueKey<String>('chunk_prefab_creation_panel_toggle'),
    );
    await tester.scrollUntilVisible(
      prefabCreationToggle,
      200,
      scrollable: sidebarScrollable,
    );
    await tester.tap(prefabCreationToggle);
    await tester.pumpAndSettle();
    expect(
      find.byKey(
        const ValueKey<String>('chunk_prefab_creation_form_forest_chunk'),
      ),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('chunk_prefab_placements_section')),
      findsOneWidget,
    );
    await tester.tap(prefabCreationToggle);
    await tester.pumpAndSettle();
    final prefabCard = find.byKey(
      const ValueKey<String>('chunk_v2_placement_prefab_rock|95|10|0'),
    );
    await tester.scrollUntilVisible(
      prefabCard,
      240,
      scrollable: sidebarScrollable,
    );
    await tester.tap(prefabCard);
    await tester.pump();

    expect(
      tester.widget<SegmentedButton<ChunkSceneDomain>>(domainSelector).selected,
      <ChunkSceneDomain>{ChunkSceneDomain.prefabs},
    );
    expect(tester.widget<EditorListCard>(prefabCard).isSelected, isTrue);
    var prefabPainter =
        tester
                .widget<CustomPaint>(
                  find.byKey(
                    const ValueKey<String>('chunk_prefab_selection_overlay'),
                  ),
                )
                .painter!
            as ChunkScenePrefabSelectionPainter;
    expect(prefabPainter.selectedPrefabKey, 'prefab_rock|95|10|0');

    final surfaceFinder = find.byKey(
      const ValueKey<String>('chunk_scene_surface'),
    );
    final sceneSurface = tester.widget<ChunkSceneSurface>(
      find.ancestor(
        of: surfaceFinder,
        matching: find.byType(ChunkSceneSurface),
      ),
    );
    Offset scenePoint(double x, double y) =>
        tester.getTopLeft(surfaceFinder) +
        sceneSurface.transform.origin +
        Offset(
          x * sceneSurface.transform.zoom,
          y * sceneSurface.transform.zoom,
        );
    await tester.tapAt(scenePoint(200, 100));
    await tester.pump();
    expect(
      find.byKey(const ValueKey<String>('chunk_prefab_selection_overlay')),
      findsNothing,
    );
    await tester.tapAt(scenePoint(95, 10));
    await tester.pump();
    prefabPainter =
        tester
                .widget<CustomPaint>(
                  find.byKey(
                    const ValueKey<String>('chunk_prefab_selection_overlay'),
                  ),
                )
                .painter!
            as ChunkScenePrefabSelectionPainter;
    expect(prefabPainter.selectedPrefabKey, 'prefab_rock|95|10|0');
    expect(tester.widget<EditorListCard>(prefabCard).isSelected, isTrue);

    tester
        .widget<SegmentedButton<ChunkSceneDomain>>(domainSelector)
        .onSelectionChanged!(<ChunkSceneDomain>{ChunkSceneDomain.markers});
    await tester.pump();
    expect(find.text('Create enemy marker'), findsOneWidget);
    expect(find.text('Existing enemy markers'), findsOneWidget);
    final markerCreationToggle = find.byKey(
      const ValueKey<String>('chunk_marker_creation_panel_toggle'),
    );
    await tester.scrollUntilVisible(
      markerCreationToggle,
      200,
      scrollable: sidebarScrollable,
    );
    await tester.tap(markerCreationToggle);
    await tester.pumpAndSettle();
    expect(
      find.byKey(
        const ValueKey<String>('chunk_marker_creation_form_forest_chunk'),
      ),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('chunk_enemy_markers_section')),
      findsOneWidget,
    );
    await tester.tap(markerCreationToggle);
    await tester.pumpAndSettle();
    final markerCard = find.byKey(
      const ValueKey<String>('chunk_v2_marker_hashash|40|5|0'),
    );
    await tester.scrollUntilVisible(
      markerCard,
      240,
      scrollable: sidebarScrollable,
    );
    await tester.tap(markerCard);
    await tester.pump();
    expect(
      tester.widget<SegmentedButton<ChunkSceneDomain>>(domainSelector).selected,
      <ChunkSceneDomain>{ChunkSceneDomain.markers},
    );
    expect(tester.widget<EditorListCard>(markerCard).isSelected, isTrue);
    final markerPainter =
        tester
                .widget<CustomPaint>(
                  find.byKey(
                    const ValueKey<String>('chunk_marker_placement_overlay'),
                  ),
                )
                .painter!
            as ChunkMarkerPlacementOverlayPainter;
    expect(markerPainter.selectedMarkerKey, 'hashash|40|5|0');
    expect(harness.session.pendingChanges.hasChanges, isFalse);
  });

  testWidgets('direct prefab placement previews locally and commits once', (
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
        home: Scaffold(body: ChunkCreatorPage(controller: harness.session)),
      ),
    );
    await tester.pumpAndSettle();

    final domainSelector = tester.widget<SegmentedButton<ChunkSceneDomain>>(
      find.byKey(const ValueKey<String>('chunk_scene_domain_selector')),
    );
    domainSelector.onSelectionChanged!(<ChunkSceneDomain>{
      ChunkSceneDomain.prefabs,
    });
    await tester.pump();
    final placeTool = find.byKey(
      const ValueKey<String>('chunk_prefab_tool_place'),
    );
    tester.widget<ChoiceChip>(placeTool).onSelected!(true);
    await tester.pump();

    final surfaceFinder = find.byKey(
      const ValueKey<String>('chunk_scene_surface'),
    );
    final sceneSurface = tester.widget<ChunkSceneSurface>(
      find.ancestor(
        of: surfaceFinder,
        matching: find.byType(ChunkSceneSurface),
      ),
    );
    Offset scenePoint(double x, double y) =>
        tester.getTopLeft(surfaceFinder) +
        sceneSurface.transform.origin +
        Offset(
          x * sceneSurface.transform.zoom,
          y * sceneSurface.transform.zoom,
        );
    final gesture = await tester.startGesture(scenePoint(64, 32));
    await tester.pump();
    expect(
      find.byKey(const ValueKey<String>('chunk_prefab_gesture_preview')),
      findsOneWidget,
    );
    expect(_chunk(harness.session, 'forest_chunk').revision, 4);
    expect(_chunk(harness.session, 'forest_chunk').prefabs, hasLength(1));
    expect(harness.session.pendingChanges.hasChanges, isFalse);
    final routeState = tester.state(find.byType(ChunkCreatorPage));
    final shortcutHandler = routeState as EditorPageSessionShortcutHandler;
    expect(shortcutHandler.canHandleUndoSessionShortcut, isTrue);

    await gesture.moveTo(scenePoint(80, 32));
    await tester.pump();
    expect(_chunk(harness.session, 'forest_chunk').revision, 4);
    expect(_chunk(harness.session, 'forest_chunk').prefabs, hasLength(1));

    await gesture.up();
    await tester.pump();
    final accepted = _chunk(harness.session, 'forest_chunk');
    expect(accepted.revision, 5);
    expect(accepted.prefabs, hasLength(2));
    expect(
      accepted.prefabs.where((placement) => placement.x == 80).single.y,
      32,
    );
    expect(harness.session.pendingChanges.hasChanges, isTrue);
    expect(
      find.byKey(const ValueKey<String>('chunk_prefab_gesture_preview')),
      findsNothing,
    );

    expect(shortcutHandler.handleUndoSessionShortcut(), isTrue);
    await tester.pump();
    expect(_chunk(harness.session, 'forest_chunk').revision, 4);
    expect(_chunk(harness.session, 'forest_chunk').prefabs, hasLength(1));
    expect(harness.session.pendingChanges.hasChanges, isFalse);

    final rejected = await tester.startGesture(scenePoint(112, 64));
    await rejected.up();
    await tester.pump();
    expect(_chunk(harness.session, 'forest_chunk').revision, 4);
    expect(_chunk(harness.session, 'forest_chunk').prefabs, hasLength(1));
    expect(harness.session.pendingChanges.hasChanges, isFalse);
    expect(find.textContaining('Prefab scene change was rejected'), findsOne);
  });

  testWidgets(
    'visual prefab library drives creation and inline placement editing',
    (tester) async {
      tester.view.physicalSize = const Size(1800, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final tree = PrefabV3Def(
        prefabKey: 'prefab_tree',
        id: 'tree',
        revision: 1,
        status: PrefabStatus.active,
        kind: PrefabKind.decoration,
        visualSource: const PrefabVisualSource.atlasSlice('tree_slice'),
        anchorXPx: 8,
        anchorYPx: 12,
        collisionShapes: const <TerrainSourceShapeDef>[],
        tags: const <String>['dark', 'foliage'],
      );
      final harness = await _buildHarness(
        additionalPrefabs: <PrefabV3Def>[tree],
      );
      addTearDown(harness.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(body: ChunkCreatorPage(controller: harness.session)),
        ),
      );
      await tester.pumpAndSettle();

      tester
          .widget<SegmentedButton<ChunkSceneDomain>>(
            find.byKey(const ValueKey<String>('chunk_scene_domain_selector')),
          )
          .onSelectionChanged!(<ChunkSceneDomain>{ChunkSceneDomain.prefabs});
      await tester.pump();

      expect(
        find.byKey(const ValueKey<String>('chunk_prefab_catalog_selector')),
        findsNothing,
      );
      expect(find.byType(ChunkPrefabCatalogBrowser), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey<String>('chunk_prefab_catalog_search')),
        'dark foliage',
      );
      await tester.pump();
      expect(find.text('1 of 2 prefabs'), findsOneWidget);
      await tester.tap(
        find.byKey(
          const ValueKey<String>('chunk_prefab_catalog_card_prefab_tree'),
        ),
      );
      await tester.pump();

      expect(find.text('Selected: tree'), findsOneWidget);
      expect(
        tester
            .widget<ChunkV2PlacementForm>(
              find.byType(ChunkV2PlacementForm).first,
            )
            .prefab,
        same(tree),
      );

      final sidebar = find.byKey(
        const ValueKey<String>('chunk_authoring_sidebar'),
      );
      final sidebarScrollable = find
          .descendant(of: sidebar, matching: find.byType(Scrollable))
          .first;
      final editPlacement = find.byKey(
        const ValueKey<String>('chunk_v2_placement_edit_prefab_rock|95|10|0'),
      );
      await tester.scrollUntilVisible(
        editPlacement,
        280,
        scrollable: sidebarScrollable,
      );
      await tester.tap(editPlacement);
      await tester.pumpAndSettle();

      const placementKey = 'prefab_rock|95|10|0';
      final inlineEditor = find.byKey(
        const ValueKey<String>(
          'chunk_v2_placement_inline_editor_$placementKey',
        ),
      );
      expect(find.byType(AlertDialog), findsNothing);
      expect(inlineEditor, findsOneWidget);
      final routeState = tester.state(find.byType(ChunkCreatorPage));
      final reloadHandler = routeState as EditorPageReloadHandler;
      final shortcutHandler = routeState as EditorPageSessionShortcutHandler;
      final localDraftState = routeState as EditorPageLocalDraftState;
      final domainSelector = find.byKey(
        const ValueKey<String>('chunk_scene_domain_selector'),
      );
      expect(reloadHandler.canReloadEditorPage, isTrue);
      expect(shortcutHandler.canHandleUndoSessionShortcut, isFalse);
      expect(localDraftState.hasLocalDraftChanges, isFalse);
      expect(
        tester
            .widget<SegmentedButton<ChunkSceneDomain>>(domainSelector)
            .onSelectionChanged,
        isNotNull,
      );
      expect(
        tester
            .widget<ChoiceChip>(
              find.byKey(const ValueKey<String>('chunk_prefab_tool_move')),
            )
            .onSelected,
        isNotNull,
      );
      expect(
        find.byKey(
          const ValueKey<String>(
            'chunk_v2_placement_inline_close_$placementKey',
          ),
        ),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(
          const ValueKey<String>(
            'chunk_v2_placement_inline_catalog_${placementKey}_search',
          ),
        ),
        'foliage',
      );
      await tester.pump();
      final inlineTreeCard = find.byKey(
        const ValueKey<String>(
          'chunk_v2_placement_inline_catalog_'
          '${placementKey}_card_prefab_tree',
        ),
      );
      await tester.ensureVisible(inlineTreeCard);
      await tester.pumpAndSettle();
      await tester.tap(inlineTreeCard);
      await tester.pump();
      expect(
        tester
            .widget<ChunkV2PlacementForm>(
              find.byType(ChunkV2PlacementForm).last,
            )
            .prefab,
        same(tree),
      );
      expect(_chunk(harness.session, 'forest_chunk').revision, 4);
      expect(
        _chunk(harness.session, 'forest_chunk').prefabs.single.prefabKey,
        'prefab_rock',
      );

      tester
          .widget<SegmentedButton<ChunkSceneDomain>>(domainSelector)
          .onSelectionChanged!(<ChunkSceneDomain>{ChunkSceneDomain.markers});
      await tester.pump();
      expect(inlineEditor, findsNothing);
      expect(
        find.byKey(const ValueKey<String>('chunk_markers_card')),
        findsOne,
      );
      expect(_chunk(harness.session, 'forest_chunk').revision, 4);
      expect(reloadHandler.canReloadEditorPage, isTrue);
      expect(localDraftState.hasLocalDraftChanges, isFalse);

      tester
          .widget<SegmentedButton<ChunkSceneDomain>>(domainSelector)
          .onSelectionChanged!(<ChunkSceneDomain>{ChunkSceneDomain.prefabs});
      await tester.pump();
      await tester.ensureVisible(editPlacement);
      await tester.tap(editPlacement);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(
          const ValueKey<String>(
            'chunk_v2_placement_inline_catalog_${placementKey}_search',
          ),
        ),
        'foliage',
      );
      await tester.pump();
      await tester.ensureVisible(inlineTreeCard);
      await tester.pumpAndSettle();
      await tester.tap(inlineTreeCard);
      await tester.pump();

      final apply = find.byKey(
        const ValueKey<String>('chunk_v2_placement_inline_apply_$placementKey'),
      );
      await tester.ensureVisible(apply);
      await tester.tap(apply);
      await tester.pumpAndSettle();

      final edited = _chunk(harness.session, 'forest_chunk');
      expect(edited.revision, 5);
      expect(edited.prefabs.single.prefabKey, 'prefab_tree');
      expect(edited.prefabs.single.prefabId, 'tree');
      expect(inlineEditor, findsNothing);
      expect(reloadHandler.canReloadEditorPage, isTrue);
      expect(shortcutHandler.canHandleUndoSessionShortcut, isTrue);

      final deletePlacement = find.byKey(
        const ValueKey<String>('chunk_v2_placement_delete_prefab_tree|95|10|0'),
      );
      await tester.scrollUntilVisible(
        deletePlacement,
        240,
        scrollable: sidebarScrollable,
      );
      await tester.tap(deletePlacement);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        tester
            .widget<ChoiceChip>(
              find.byKey(const ValueKey<String>('chunk_prefab_tool_move')),
            )
            .onSelected,
        isNull,
      );
      await tester.tap(find.widgetWithText(TextButton, 'Cancel').last);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ChoiceChip>(
              find.byKey(const ValueKey<String>('chunk_prefab_tool_move')),
            )
            .onSelected,
        isNotNull,
      );
    },
  );

  testWidgets('direct prefab move cancels cleanly then accepts one drag', (
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
        home: Scaffold(body: ChunkCreatorPage(controller: harness.session)),
      ),
    );
    await tester.pumpAndSettle();

    tester
        .widget<SegmentedButton<ChunkSceneDomain>>(
          find.byKey(const ValueKey<String>('chunk_scene_domain_selector')),
        )
        .onSelectionChanged!(<ChunkSceneDomain>{ChunkSceneDomain.prefabs});
    await tester.pump();
    tester
        .widget<ChoiceChip>(
          find.byKey(const ValueKey<String>('chunk_prefab_tool_move')),
        )
        .onSelected!(true);
    await tester.pump();

    final surfaceFinder = find.byKey(
      const ValueKey<String>('chunk_scene_surface'),
    );
    final surface = tester.widget<ChunkSceneSurface>(
      find.ancestor(
        of: surfaceFinder,
        matching: find.byType(ChunkSceneSurface),
      ),
    );
    Offset point(double x, double y) =>
        tester.getTopLeft(surfaceFinder) +
        surface.transform.origin +
        Offset(x * surface.transform.zoom, y * surface.transform.zoom);

    final cancelled = await tester.startGesture(point(95, 10));
    await cancelled.moveTo(point(80, 16));
    await tester.pump();
    expect(
      find.byKey(const ValueKey<String>('chunk_prefab_gesture_preview')),
      findsOneWidget,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await cancelled.up();
    await tester.pump();
    expect(_chunk(harness.session, 'forest_chunk').revision, 4);
    expect(_chunk(harness.session, 'forest_chunk').prefabs.single.x, 95);
    expect(harness.session.pendingChanges.hasChanges, isFalse);

    final accepted = await tester.startGesture(point(95, 10));
    await accepted.moveTo(point(80, 16));
    await accepted.up();
    await tester.pump();
    final moved = _chunk(harness.session, 'forest_chunk');
    expect(moved.revision, 5);
    expect(moved.prefabs.single.x, 80);
    expect(moved.prefabs.single.y, 16);
    expect(harness.session.pendingChanges.hasChanges, isTrue);
    final expanded = (harness.session.scene as ChunkV2Scene)
        .collisionExpansionByChunkKey['forest_chunk']!
        .expansion!
        .expandedPrefabShapes
        .single;
    expect(expanded.placementX, 80);
    expect(expanded.placementY, 16);
  });

  testWidgets('direct marker placement keeps anchors separate from evidence', (
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
        home: Scaffold(body: ChunkCreatorPage(controller: harness.session)),
      ),
    );
    await tester.pumpAndSettle();

    tester
        .widget<SegmentedButton<ChunkSceneDomain>>(
          find.byKey(const ValueKey<String>('chunk_scene_domain_selector')),
        )
        .onSelectionChanged!(<ChunkSceneDomain>{ChunkSceneDomain.markers});
    await tester.pump();
    tester
        .widget<ChoiceChip>(
          find.byKey(const ValueKey<String>('chunk_marker_tool_place')),
        )
        .onSelected!(true);
    await tester.pump();

    final surfaceFinder = find.byKey(
      const ValueKey<String>('chunk_scene_surface'),
    );
    final surface = tester.widget<ChunkSceneSurface>(
      find.ancestor(
        of: surfaceFinder,
        matching: find.byType(ChunkSceneSurface),
      ),
    );
    Offset point(double x, double y) =>
        tester.getTopLeft(surfaceFinder) +
        surface.transform.origin +
        Offset(x * surface.transform.zoom, y * surface.transform.zoom);

    final gesture = await tester.startGesture(point(60.5, 5.5));
    await gesture.moveTo(point(70.5, 5.5));
    await tester.pump();
    expect(
      find.byKey(const ValueKey<String>('chunk_marker_gesture_preview')),
      findsOneWidget,
    );
    expect(_chunk(harness.session, 'forest_chunk').revision, 4);
    expect(_chunk(harness.session, 'forest_chunk').markers, hasLength(2));
    var painter =
        tester
                .widget<CustomPaint>(
                  find.byKey(
                    const ValueKey<String>('chunk_marker_placement_overlay'),
                  ),
                )
                .painter!
            as ChunkMarkerPlacementOverlayPainter;
    expect(painter.showResolvedEvidence, isFalse);

    await gesture.up();
    await tester.pump();
    final accepted = _chunk(harness.session, 'forest_chunk');
    expect(accepted.revision, 5);
    expect(accepted.markers, hasLength(3));
    expect(accepted.markers.where((marker) => marker.x == 71).single.y, 6);
    expect(
      (harness.session.scene as ChunkV2Scene)
          .collisionExpansionByChunkKey['forest_chunk'],
      isNotNull,
    );
    expect(
      find.byKey(const ValueKey<String>('chunk_marker_gesture_preview')),
      findsNothing,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('chunk_marker_placement_toggle')),
    );
    await tester.pump();
    painter =
        tester
                .widget<CustomPaint>(
                  find.byKey(
                    const ValueKey<String>('chunk_marker_placement_overlay'),
                  ),
                )
                .painter!
            as ChunkMarkerPlacementOverlayPainter;
    expect(painter.showResolvedEvidence, isTrue);

    tester
        .widget<ChoiceChip>(
          find.byKey(const ValueKey<String>('chunk_marker_tool_select')),
        )
        .onSelected!(true);
    await tester.pump();
    final currentSurface = tester.widget<ChunkSceneSurface>(
      find.ancestor(
        of: surfaceFinder,
        matching: find.byType(ChunkSceneSurface),
      ),
    );
    await tester.tapAt(
      tester.getTopLeft(surfaceFinder) +
          currentSurface.transform.origin +
          Offset(
            71 * currentSurface.transform.zoom,
            6 * currentSurface.transform.zoom,
          ),
    );
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pump();
    expect(_chunk(harness.session, 'forest_chunk').revision, 6);
    expect(_chunk(harness.session, 'forest_chunk').markers, hasLength(2));

    tester
        .widget<ChoiceChip>(
          find.byKey(const ValueKey<String>('chunk_marker_tool_place')),
        )
        .onSelected!(true);
    await tester.pump();
    final rejectedSurface = tester.widget<ChunkSceneSurface>(
      find.ancestor(
        of: surfaceFinder,
        matching: find.byType(ChunkSceneSurface),
      ),
    );
    final rejected = await tester.startGesture(
      tester.getTopLeft(surfaceFinder) +
          rejectedSurface.transform.origin +
          Offset(
            112 * rejectedSurface.transform.zoom,
            60 * rejectedSurface.transform.zoom,
          ),
    );
    await rejected.up();
    await tester.pump();
    expect(_chunk(harness.session, 'forest_chunk').revision, 6);
    expect(_chunk(harness.session, 'forest_chunk').markers, hasLength(2));
    expect(find.textContaining('Marker scene change was rejected'), findsOne);
  });

  testWidgets(
    'direct marker move suppresses stale evidence and cancels safely',
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
          home: Scaffold(body: ChunkCreatorPage(controller: harness.session)),
        ),
      );
      await tester.pumpAndSettle();
      tester
          .widget<SegmentedButton<ChunkSceneDomain>>(
            find.byKey(const ValueKey<String>('chunk_scene_domain_selector')),
          )
          .onSelectionChanged!(<ChunkSceneDomain>{ChunkSceneDomain.markers});
      await tester.pump();
      tester
          .widget<ChoiceChip>(
            find.byKey(const ValueKey<String>('chunk_marker_tool_move')),
          )
          .onSelected!(true);
      await tester.pump();

      final surfaceFinder = find.byKey(
        const ValueKey<String>('chunk_scene_surface'),
      );
      final surface = tester.widget<ChunkSceneSurface>(
        find.ancestor(
          of: surfaceFinder,
          matching: find.byType(ChunkSceneSurface),
        ),
      );
      Offset point(double x, double y) =>
          tester.getTopLeft(surfaceFinder) +
          surface.transform.origin +
          Offset(x * surface.transform.zoom, y * surface.transform.zoom);

      final cancelled = await tester.startGesture(point(40, 5));
      await cancelled.moveTo(point(60.5, 5.5));
      await tester.pump();
      final previewPainter =
          tester
                  .widget<CustomPaint>(
                    find.byKey(
                      const ValueKey<String>('chunk_marker_placement_overlay'),
                    ),
                  )
                  .painter!
              as ChunkMarkerPlacementOverlayPainter;
      expect(previewPainter.suppressedMarkerKey, 'hashash|40|5|0');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await cancelled.up();
      await tester.pump();
      expect(_chunk(harness.session, 'forest_chunk').revision, 4);
      expect(
        _chunk(
          harness.session,
          'forest_chunk',
        ).markers.singleWhere((marker) => marker.markerId == 'hashash').x,
        40,
      );

      final accepted = await tester.startGesture(point(40, 5));
      await accepted.moveTo(point(60.5, 5.5));
      await accepted.up();
      await tester.pump();
      final moved = _chunk(harness.session, 'forest_chunk');
      expect(moved.revision, 5);
      final hashash = moved.markers.singleWhere(
        (marker) => marker.markerId == 'hashash',
      );
      expect(hashash.x, 61);
      expect(hashash.y, 6);
      expect(hashash.placement, markerPlacementGround);
      expect(harness.session.pendingChanges.hasChanges, isTrue);
    },
  );

  testWidgets(
    'selected chunk shapes edit metadata inline and preview material',
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
          home: Scaffold(body: ChunkCreatorPage(controller: harness.session)),
        ),
      );
      await tester.pumpAndSettle();

      final authoringSidebar = find.byKey(
        const ValueKey<String>('chunk_authoring_sidebar'),
      );
      final groundShape = find.byKey(
        const ValueKey<String>('chunk_polygon_shape_ground_001'),
      );
      final sidebarScrollable = find
          .descendant(of: authoringSidebar, matching: find.byType(Scrollable))
          .first;
      await tester.scrollUntilVisible(
        groundShape,
        100,
        scrollable: sidebarScrollable,
      );
      await tester.tap(groundShape);
      await tester.pump();

      final metadataSection = find.byKey(
        const ValueKey<String>('chunk_polygon_metadata_section'),
      );
      expect(metadataSection, findsOneWidget);
      final modeSelector = find.byKey(
        const ValueKey<String>('chunk_polygon_metadata_mode'),
      );
      final surfaceSelector = find.byKey(
        const ValueKey<String>('chunk_polygon_metadata_surface_selector'),
      );
      final materialSelector = find.byKey(
        const ValueKey<String>('chunk_polygon_metadata_material_selector'),
      );
      final legacyPreviewButton = find.byKey(
        const ValueKey<String>('chunk_polygon_material_preview_button'),
      );
      final grassDirtPreviewButton = find.byKey(
        const ValueKey<String>(
          'chunk_polygon_metadata_material_preview_grass_dirt',
        ),
      );
      expect(modeSelector, findsOneWidget);
      expect(surfaceSelector, findsOneWidget);
      expect(materialSelector, findsOneWidget);
      expect(legacyPreviewButton, findsNothing);
      expect(grassDirtPreviewButton, findsNothing);

      await tester.scrollUntilVisible(
        surfaceSelector,
        100,
        scrollable: sidebarScrollable,
      );
      await tester.tap(surfaceSelector);
      await tester.pumpAndSettle();
      await tester.tap(find.text('ground').last);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        materialSelector,
        100,
        scrollable: sidebarScrollable,
      );
      await tester.tap(materialSelector);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Grass / Dirt · grass_dirt').last);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        modeSelector,
        100,
        scrollable: sidebarScrollable,
      );
      await tester.tap(modeSelector);
      await tester.pumpAndSettle();
      await tester.tap(find.text('oneWay').last);
      await tester.pumpAndSettle();

      final edited = _chunk(harness.session, 'forest_chunk');
      expect(edited.revision, 7);
      expect(
        edited.collisionShapes.single.collisionMode,
        TerrainSourceCollisionMode.oneWay,
      );
      expect(edited.collisionShapes.single.surfaceKind, 'ground');
      expect(edited.collisionShapes.single.materialKey, 'grass_dirt');

      await tester.scrollUntilVisible(
        materialSelector,
        100,
        scrollable: sidebarScrollable,
      );
      await tester.tap(materialSelector);
      await tester.pumpAndSettle();
      expect(grassDirtPreviewButton, findsOneWidget);
      await tester.tap(grassDirtPreviewButton);
      await tester.pumpAndSettle();
      final previewDialog = find.byKey(
        const ValueKey<String>('chunk_polygon_read_only_material_dialog'),
      );
      expect(previewDialog, findsOneWidget);
      expect(
        find.byKey(
          const ValueKey<String>('chunk_polygon_read_only_material_preview'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: previewDialog,
          matching: find.byType(DropdownButton),
        ),
        findsNothing,
      );
      await tester.tap(
        find.byKey(
          const ValueKey<String>('chunk_polygon_material_preview_close'),
        ),
      );
      await tester.pumpAndSettle();
      expect(previewDialog, findsNothing);
    },
  );

  testWidgets('axis-aligned rectangles expose one exact dimension editor', (
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
        home: Scaffold(body: ChunkCreatorPage(controller: harness.session)),
      ),
    );
    await tester.pumpAndSettle();

    final authoringSidebar = find.byKey(
      const ValueKey<String>('chunk_authoring_sidebar'),
    );
    final authoringSidebarScrollable = find
        .descendant(of: authoringSidebar, matching: find.byType(Scrollable))
        .first;
    final shape = find.byKey(
      const ValueKey<String>('chunk_polygon_shape_ground_001'),
    );
    await tester.scrollUntilVisible(
      shape,
      100,
      scrollable: authoringSidebarScrollable,
    );
    expect(find.text('Solid · Rectangle'), findsOneWidget);
    expect(find.text('4 vertices'), findsOneWidget);
    await tester.tap(shape);
    await tester.pump();

    final xField = find.byKey(
      const ValueKey<String>('chunk_polygon_rectangle_x_field'),
    );
    final bottomField = find.byKey(
      const ValueKey<String>('chunk_polygon_rectangle_bottom_field'),
    );
    final widthField = find.byKey(
      const ValueKey<String>('chunk_polygon_rectangle_width_field'),
    );
    final heightField = find.byKey(
      const ValueKey<String>('chunk_polygon_rectangle_height_field'),
    );
    final apply = find.byKey(const ValueKey<String>('chunk_polygon_save_edit'));
    expect(find.text('Apply rectangle dimensions'), findsNothing);
    expect(find.text('Save edit'), findsOneWidget);
    await tester.scrollUntilVisible(
      xField,
      100,
      scrollable: authoringSidebarScrollable,
    );
    await tester.enterText(xField, '10');
    await tester.enterText(bottomField, '50');
    await tester.enterText(widthField, '40');
    await tester.enterText(heightField, '35');
    await tester.scrollUntilVisible(
      apply,
      100,
      scrollable: authoringSidebarScrollable,
    );
    await tester.tap(apply);
    await tester.pump();

    final updated = _chunk(harness.session, 'forest_chunk');
    expect(updated.revision, 5);
    expect(
      updated.collisionShapes.single.vertices,
      const <TerrainSourceVertexDef>[
        TerrainSourceVertexDef(xHalfPixels: 20, yHalfPixels: 30),
        TerrainSourceVertexDef(xHalfPixels: 100, yHalfPixels: 30),
        TerrainSourceVertexDef(xHalfPixels: 100, yHalfPixels: 100),
        TerrainSourceVertexDef(xHalfPixels: 20, yHalfPixels: 100),
      ],
    );
  });

  testWidgets('reclicking an edited shape offers save discard and cancel', (
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
        home: Scaffold(body: ChunkCreatorPage(controller: harness.session)),
      ),
    );
    await tester.pumpAndSettle();

    final sidebar = find.byKey(
      const ValueKey<String>('chunk_authoring_sidebar'),
    );
    final scrollable = find
        .descendant(of: sidebar, matching: find.byType(Scrollable))
        .first;
    final shape = find.byKey(
      const ValueKey<String>('chunk_polygon_shape_ground_001'),
    );
    await tester.scrollUntilVisible(shape, 100, scrollable: scrollable);
    await tester.tap(shape);
    await tester.pump();
    await tester.tap(shape);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('chunk_polygon_selected_shape_editor')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('chunk_polygon_unsaved_edit_dialog')),
      findsNothing,
    );
    await tester.tap(shape);
    await tester.pump();

    final nameField = find.byKey(
      const ValueKey<String>('chunk_polygon_shape_name_ground_001'),
    );
    final xField = find.byKey(
      const ValueKey<String>('chunk_polygon_rectangle_x_field'),
    );
    await tester.scrollUntilVisible(nameField, 100, scrollable: scrollable);
    await tester.enterText(nameField, 'main_floor');
    await tester.scrollUntilVisible(xField, 100, scrollable: scrollable);
    await tester.enterText(xField, '12');

    Future<void> reclickShape() async {
      await tester.scrollUntilVisible(shape, 100, scrollable: scrollable);
      await tester.tap(shape);
      await tester.pumpAndSettle();
    }

    await reclickShape();
    expect(
      find.byKey(const ValueKey<String>('chunk_polygon_unsaved_edit_dialog')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('chunk_polygon_unsaved_edit_cancel')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('chunk_polygon_selected_shape_editor')),
      findsOneWidget,
    );
    expect(_chunk(harness.session, 'forest_chunk').revision, 4);

    await reclickShape();
    await tester.tap(
      find.byKey(const ValueKey<String>('chunk_polygon_unsaved_edit_discard')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('chunk_polygon_selected_shape_editor')),
      findsNothing,
    );
    expect(_chunk(harness.session, 'forest_chunk').revision, 4);
    expect(
      _chunk(harness.session, 'forest_chunk').collisionShapes.single.shapeId,
      'ground_001',
    );

    await tester.tap(shape);
    await tester.pump();
    await tester.scrollUntilVisible(nameField, 100, scrollable: scrollable);
    await tester.enterText(nameField, 'main_floor');
    await tester.scrollUntilVisible(xField, 100, scrollable: scrollable);
    await tester.enterText(xField, '12');
    await reclickShape();
    await tester.tap(
      find.byKey(const ValueKey<String>('chunk_polygon_unsaved_edit_save')),
    );
    await tester.pumpAndSettle();

    final saved = _chunk(harness.session, 'forest_chunk');
    expect(saved.revision, 5);
    expect(saved.collisionShapes.single.shapeId, 'main_floor');
    expect(saved.collisionShapes.single.vertices.first.xHalfPixels, 24);
    expect(
      find.byKey(const ValueKey<String>('chunk_polygon_selected_shape_editor')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('chunk_polygon_shape_main_floor')),
      findsOneWidget,
    );
  });

  testWidgets(
    'chunk creation scene and sidebar remain usable at narrow width',
    (tester) async {
      tester.view.physicalSize = const Size(900, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final harness = await _buildHarness();
      addTearDown(harness.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(body: ChunkCreatorPage(controller: harness.session)),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('chunk_workspace_narrow')),
        findsOneWidget,
      );
      expect(find.byType(TabBar), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('chunk_creation_scene')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('chunk_owner_sidebar')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('chunk_terrain_card')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('chunk_prefabs_card')),
        findsNothing,
      );
      final sceneSlot = find.byKey(const ValueKey<String>('chunk_scene_slot'));
      final ownerSidebarSlot = find.byKey(
        const ValueKey<String>('chunk_owner_sidebar_slot'),
      );
      final sidebarSlot = find.byKey(
        const ValueKey<String>('chunk_sidebar_slot'),
      );
      expect(
        tester.getBottomLeft(sceneSlot).dy,
        lessThan(tester.getTopLeft(ownerSidebarSlot).dy),
      );
      expect(
        tester.getBottomLeft(sceneSlot).dy,
        lessThan(tester.getTopLeft(sidebarSlot).dy),
      );

      expect(
        find.byKey(const ValueKey<String>('chunk_shape_list')),
        findsOneWidget,
      );
      final authoringSidebar = find.byKey(
        const ValueKey<String>('chunk_authoring_sidebar'),
      );
      final sidebarScrollable = find
          .descendant(of: authoringSidebar, matching: find.byType(Scrollable))
          .first;
      final newRectangle = find.byKey(
        const ValueKey<String>('chunk_polygon_new_rectangle'),
      );
      await tester.scrollUntilVisible(
        newRectangle,
        100,
        scrollable: sidebarScrollable,
      );
      expect(newRectangle, findsOneWidget);
      expect(tester.widget<FilledButton>(newRectangle).onPressed, isNotNull);
      final saveDraft = find.byKey(
        const ValueKey<String>('chunk_polygon_save_draft'),
      );
      expect(tester.widget<OutlinedButton>(saveDraft).onPressed, isNull);
      expect(
        find.byKey(
          const ValueKey<String>('chunk_polygon_tool_createRectangle'),
        ),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('chunk_polygon_tool_createPolygon')),
        findsNothing,
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('chunk_polygon_new_shape')),
      );
      await tester.pump();
      expect(tester.widget<OutlinedButton>(saveDraft).onPressed, isNull);
      expect(tester.widget<FilledButton>(newRectangle).onPressed, isNull);
      expect(find.textContaining('Add at least 3 vertices.'), findsOneWidget);
      expect(
        find.textContaining('Finish or cancel the active terrain edit'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<SegmentedButton<ChunkSceneDomain>>(
              find.byKey(const ValueKey<String>('chunk_scene_domain_selector')),
            )
            .onSelectionChanged,
        isNull,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const ValueKey<String>('chunk_v2_owner_edit')),
            )
            .onPressed,
        isNull,
      );
      expect(
        find.byKey(const ValueKey<String>('chunk_v2_layer_add')),
        findsNothing,
      );
      for (final tool in const <String>['select', 'translateShape']) {
        expect(
          tester
              .widget<ChoiceChip>(
                find.byKey(ValueKey<String>('chunk_polygon_tool_$tool')),
              )
              .onSelected,
          isNull,
        );
      }
      expect(
        find.byKey(
          const ValueKey<String>('chunk_polygon_tool_createRectangle'),
        ),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('chunk_polygon_tool_createPolygon')),
        findsNothing,
      );
      for (final tool in const <String>['moveVertex', 'insertVertex']) {
        expect(
          tester
              .widget<ChoiceChip>(
                find.byKey(ValueKey<String>('chunk_polygon_tool_$tool')),
              )
              .onSelected,
          isNotNull,
        );
      }
      expect(find.text('Place vertex'), findsNothing);
      expect(find.text('Continue drawing'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('every right-side tab shares all document diagnostics', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = await _buildHarness(
      additionalIssues: const <ValidationIssue>[
        ValidationIssue(
          severity: ValidationSeverity.warning,
          code: 'test_forest_warning',
          message: 'Forest owner warning.',
          sourcePath: 'chunks/forest_chunk.json',
          ownerKey: 'forest_chunk',
        ),
        ValidationIssue(
          severity: ValidationSeverity.info,
          code: 'test_meadow_info',
          message: 'Meadow owner information.',
          sourcePath: 'chunks/meadow_chunk.json',
          ownerKey: 'meadow_chunk',
        ),
      ],
    );
    addTearDown(harness.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(body: ChunkCreatorPage(controller: harness.session)),
      ),
    );
    await tester.pumpAndSettle();

    final expectedIssues = harness.session.issues;
    final ownerPreview = find.byKey(
      const ValueKey<String>('chunk_owner_preview_forest_chunk'),
    );
    expect(ownerPreview, findsOneWidget);
    expect(
      find.descendant(
        of: ownerPreview,
        matching: find.byType(ChunkPolygonLevelVisualSource),
      ),
      findsNWidgets(3),
    );
    expect(
      find.descendant(
        of: ownerPreview,
        matching: find.byType(ChunkSceneVisualSource),
      ),
      findsOneWidget,
    );
    for (final key in const <String>[
      'chunk_collision_expansion_summary',
      'chunk_polygon_source_fill_notice',
      'chunk_seam_summary',
      'chunk_actor_terrain_summary',
      'chunk_marker_placement_summary',
    ]) {
      expect(find.byKey(ValueKey<String>(key)), findsNothing);
    }
    expect(
      find.byKey(const ValueKey<String>('chunk_polygon_tool_createPolygon')),
      findsNothing,
    );
    expect(find.text('Place vertex'), findsNothing);
    await tester.tap(
      find.byKey(const ValueKey<String>('chunk_marker_placement_toggle')),
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey<String>('chunk_marker_placement_overlay')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('chunk_marker_placement_summary')),
      findsNothing,
    );
    final panelKeys = <ChunkSceneDomain, String>{
      ChunkSceneDomain.terrain: 'chunk_terrain_card',
      ChunkSceneDomain.prefabs: 'chunk_prefabs_card',
      ChunkSceneDomain.markers: 'chunk_markers_card',
      ChunkSceneDomain.layers: 'chunk_layers_card',
    };
    for (final entry in panelKeys.entries) {
      tester
          .widget<SegmentedButton<ChunkSceneDomain>>(
            find.byKey(const ValueKey<String>('chunk_scene_domain_selector')),
          )
          .onSelectionChanged!(<ChunkSceneDomain>{entry.key});
      await tester.pump();

      final activePanel = find.byKey(ValueKey<String>(entry.value));
      final diagnostics = find.byKey(
        const ValueKey<String>('chunk_diagnostics_card'),
      );
      expect(activePanel, findsOneWidget);
      expect(diagnostics, findsOneWidget);
      expect(
        tester.getBottomLeft(activePanel).dy,
        lessThan(tester.getTopLeft(diagnostics).dy),
      );
      for (final (index, issue) in expectedIssues.indexed) {
        expect(
          find.byKey(
            ValueKey<String>('chunk_diagnostic_${index}_${issue.code}'),
          ),
          findsOneWidget,
        );
      }
      if (expectedIssues.isEmpty) {
        expect(find.text('No validation issues.'), findsOneWidget);
      }
    }
  });

  testWidgets('chunk scene shows its tile grid and retains terrain snapping', (
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
        home: Scaffold(body: ChunkCreatorPage(controller: harness.session)),
      ),
    );
    await tester.pumpAndSettle();

    final visualPreview = find.byKey(
      const ValueKey<String>('chunk_visual_preview_toggle'),
    );
    final showGrid = find.byKey(
      const ValueKey<String>('chunk_show_grid_toggle'),
    );
    final creationSnapToGrid = find.byKey(
      const ValueKey<String>('chunk_polygon_creation_snap_to_grid'),
    );
    final editSnapToGrid = find.byKey(
      const ValueKey<String>('chunk_polygon_edit_snap_to_grid'),
    );
    final gridOverlay = find.byKey(
      const ValueKey<String>('chunk_tile_grid_overlay'),
    );
    expect(showGrid, findsOneWidget);
    expect(creationSnapToGrid, findsOneWidget);
    expect(editSnapToGrid, findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('chunk_scene_global_controls')),
        matching: find.text('Snap to grid'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('chunk_polygon_creation_panel')),
        matching: creationSnapToGrid,
      ),
      findsOneWidget,
    );
    expect(
      tester.getTopRight(visualPreview).dx,
      lessThan(tester.getTopLeft(showGrid).dx),
    );
    expect(tester.widget<FilterChip>(showGrid).selected, isFalse);
    expect(tester.widget<SwitchListTile>(creationSnapToGrid).value, isFalse);
    expect(gridOverlay, findsNothing);

    await tester.tap(showGrid);
    await tester.pump();
    expect(tester.widget<FilterChip>(showGrid).selected, isTrue);
    expect(gridOverlay, findsOneWidget);

    await tester.tap(visualPreview);
    await tester.pump();
    expect(gridOverlay, findsNothing);
    expect(tester.widget<FilterChip>(showGrid).onSelected, isNull);
    expect(tester.widget<SwitchListTile>(creationSnapToGrid).onChanged, isNull);
    await tester.tap(visualPreview);
    await tester.pump();
    expect(gridOverlay, findsOneWidget);

    tester.widget<SwitchListTile>(creationSnapToGrid).onChanged!(true);
    await tester.pump();
    expect(tester.widget<SwitchListTile>(creationSnapToGrid).value, isTrue);

    final authoringSidebar = find.byKey(
      const ValueKey<String>('chunk_authoring_sidebar'),
    );
    final sidebarScrollable = find
        .descendant(of: authoringSidebar, matching: find.byType(Scrollable))
        .first;
    final groundShape = find.byKey(
      const ValueKey<String>('chunk_polygon_shape_ground_001'),
    );
    await tester.scrollUntilVisible(
      groundShape,
      160,
      scrollable: sidebarScrollable,
    );
    await tester.tap(groundShape);
    await tester.pump();
    expect(editSnapToGrid, findsOneWidget);
    expect(tester.widget<SwitchListTile>(editSnapToGrid).value, isFalse);
    expect(
      find.descendant(
        of: find.byKey(
          const ValueKey<String>('chunk_polygon_selected_shape_editor'),
        ),
        matching: editSnapToGrid,
      ),
      findsOneWidget,
    );
    tester.widget<SwitchListTile>(editSnapToGrid).onChanged!(true);
    await tester.pump();
    expect(tester.widget<SwitchListTile>(editSnapToGrid).value, isTrue);
    expect(tester.widget<SwitchListTile>(creationSnapToGrid).value, isTrue);
    tester.widget<SwitchListTile>(creationSnapToGrid).onChanged!(false);
    await tester.pump();
    expect(tester.widget<SwitchListTile>(creationSnapToGrid).value, isFalse);
    expect(tester.widget<SwitchListTile>(editSnapToGrid).value, isTrue);

    tester
        .widget<SegmentedButton<ChunkSceneDomain>>(
          find.byKey(const ValueKey<String>('chunk_scene_domain_selector')),
        )
        .onSelectionChanged!(<ChunkSceneDomain>{ChunkSceneDomain.prefabs});
    await tester.pump();
    expect(creationSnapToGrid, findsNothing);
    expect(editSnapToGrid, findsNothing);
    expect(showGrid, findsOneWidget);
    expect(gridOverlay, findsOneWidget);

    tester
        .widget<SegmentedButton<ChunkSceneDomain>>(
          find.byKey(const ValueKey<String>('chunk_scene_domain_selector')),
        )
        .onSelectionChanged!(<ChunkSceneDomain>{ChunkSceneDomain.terrain});
    await tester.pump();
    expect(tester.widget<SwitchListTile>(creationSnapToGrid).value, isFalse);
    expect(tester.widget<SwitchListTile>(editSnapToGrid).value, isTrue);
  });

  testWidgets('wide chunk workspace supports enlarged text without overflow', (
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
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
        home: Scaffold(body: ChunkCreatorPage(controller: harness.session)),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('chunk_workspace_wide')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('chunk_creation_scene')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('chunk_terrain_card')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('tile layers remain metadata-only in the unified workspace', (
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
        home: Scaffold(body: ChunkCreatorPage(controller: harness.session)),
      ),
    );
    await tester.pumpAndSettle();

    tester
        .widget<SegmentedButton<ChunkSceneDomain>>(
          find.byKey(const ValueKey<String>('chunk_scene_domain_selector')),
        )
        .onSelectionChanged!(<ChunkSceneDomain>{ChunkSceneDomain.layers});
    await tester.pump();
    expect(
      find.byKey(const ValueKey<String>('chunk_layers_card')),
      findsOneWidget,
    );
    expect(find.text('Tile layer metadata'), findsOneWidget);
    expect(find.text('Add layer'), findsOneWidget);
    expect(find.text('Paint tiles'), findsNothing);
    expect(find.text('Erase tiles'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('chunk_tile_paint_tool')),
      findsNothing,
    );
  });

  testWidgets('placed prefab opens its exact source owner', (tester) async {
    tester.view.physicalSize = const Size(1800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = await _buildHarness();
    addTearDown(harness.dispose);
    final openedPrefabKeys = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: ChunkCreatorPage(
            controller: harness.session,
            onOpenOwningPrefab: openedPrefabKeys.add,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    tester
        .widget<SegmentedButton<ChunkSceneDomain>>(
          find.byKey(const ValueKey<String>('chunk_scene_domain_selector')),
        )
        .onSelectionChanged!(<ChunkSceneDomain>{ChunkSceneDomain.prefabs});
    await tester.pump();
    final openOwner = find.byKey(
      const ValueKey<String>('chunk_v2_placement_open_prefab_rock|95|10|0'),
    );
    await Scrollable.ensureVisible(tester.element(openOwner), alignment: 0.5);
    await tester.pumpAndSettle();
    await tester.tap(openOwner);
    await tester.pump();

    expect(openedPrefabKeys, <String>['prefab_rock']);
    expect(_chunk(harness.session, 'forest_chunk').revision, 4);
    expect(harness.session.pendingChanges.hasChanges, isFalse);
  });

  testWidgets(
    'chunk-v2 owner forms preserve non-owned fields across typed lifecycle edits',
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
          home: Scaffold(body: ChunkCreatorPage(controller: harness.session)),
        ),
      );
      await tester.pumpAndSettle();

      final original = _chunk(harness.session, 'forest_chunk');
      await tester.tap(
        find.byKey(const ValueKey<String>('chunk_v2_owner_edit')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('chunk_v2_owner_status_active')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(chunkStatusDeprecated).last);
      final difficultyField = find.byKey(
        const ValueKey<String>('chunk_v2_owner_difficulty_normal'),
      );
      await tester.ensureVisible(difficultyField);
      await tester.pump();
      await tester.tap(difficultyField);
      await tester.pumpAndSettle();
      await tester.tap(find.text(chunkDifficultyHard).last);
      final tagsField = find.byKey(
        const ValueKey<String>('chunk_v2_owner_tags_field'),
      );
      await tester.ensureVisible(tagsField);
      await tester.enterText(tagsField, ' zeta, forest, alpha, alpha ');
      final groundBandField = find.byKey(
        const ValueKey<String>('chunk_v2_owner_ground_band_z_field'),
      );
      await tester.ensureVisible(groundBandField);
      await tester.enterText(groundBandField, '-3');
      final applyMetadata = find.byKey(
        const ValueKey<String>('chunk_v2_owner_dialog_apply'),
      );
      await tester.ensureVisible(applyMetadata);
      await tester.tap(applyMetadata);
      await tester.pumpAndSettle();

      var edited = _chunk(harness.session, 'forest_chunk');
      expect(edited.revision, 5);
      expect(edited.status, chunkStatusDeprecated);
      expect(edited.difficulty, chunkDifficultyHard);
      expect(edited.tags, <String>['alpha', 'forest', 'zeta']);
      expect(edited.groundBandZIndex, -3);
      expect(edited.chunkKey, original.chunkKey);
      expect(edited.tileSize, original.tileSize);
      expect(edited.width, original.width);
      expect(edited.height, original.height);
      expect(edited.tileLayers, original.tileLayers);
      expect(edited.prefabs, original.prefabs);
      expect(edited.markers, original.markers);
      expect(edited.collisionShapes, original.collisionShapes);

      final routeState = tester.state(find.byType(ChunkCreatorPage));
      final shortcutHandler = routeState as EditorPageSessionShortcutHandler;
      expect(shortcutHandler.handleUndoSessionShortcut(), isTrue);
      await tester.pump();
      expect(_chunk(harness.session, 'forest_chunk').revision, 4);
      expect(shortcutHandler.handleRedoSessionShortcut(), isTrue);
      await tester.pump();
      expect(_chunk(harness.session, 'forest_chunk').revision, 5);

      await tester.tap(
        find.byKey(const ValueKey<String>('chunk_v2_owner_rename')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey<String>('chunk_v2_rename_id_field')),
        'forest_renamed',
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('chunk_v2_rename_apply')),
      );
      await tester.pumpAndSettle();
      edited = _chunk(harness.session, 'forest_chunk');
      expect(edited.id, 'forest_renamed');
      expect(edited.chunkKey, 'forest_chunk');
      expect(edited.revision, 6);

      await tester.tap(
        find.byKey(const ValueKey<String>('chunk_v2_owner_duplicate')),
      );
      await tester.pump();
      final duplicate = _chunk(harness.session, 'forest_renamed_copy');
      expect(duplicate.id, 'forest_renamed_copy');
      expect(duplicate.revision, 1);
      expect(duplicate.status, chunkStatusActive);
      expect(duplicate.levelId, edited.levelId);
      expect(duplicate.tileLayers, edited.tileLayers);
      expect(duplicate.prefabs, edited.prefabs);
      expect(duplicate.markers, edited.markers);
      expect(duplicate.collisionShapes, edited.collisionShapes);

      await tester.tap(
        find.byKey(const ValueKey<String>('chunk_v2_owner_create')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey<String>('chunk_v2_create_id_field')),
        'forest_empty',
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('chunk_v2_create_apply')),
      );
      await tester.pumpAndSettle();
      final created = _chunk(harness.session, 'forest_empty');
      expect(created.revision, 1);
      expect(created.status, chunkStatusDeprecated);
      expect(created.levelId, 'forest');
      expect(created.tileSize, original.tileSize);
      expect(created.width, original.width);
      expect(created.height, original.height);
      expect(created.tileLayers, isEmpty);
      expect(created.prefabs, isEmpty);
      expect(created.markers, isEmpty);
      expect(created.collisionShapes, isEmpty);

      await tester.tap(
        find.byKey(const ValueKey<String>('chunk_v2_owner_delete')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('chunk_v2_owner_delete_confirm')),
      );
      await tester.pumpAndSettle();
      expect(
        (harness.session.document! as ChunkV2Document).chunks.where(
          (chunk) => chunk.chunkKey == 'forest_empty',
        ),
        isEmpty,
      );
      expect(harness.plugin.loadCount, 1);
    },
  );

  testWidgets(
    'chunk-v2 composition forms edit canonical layers placements and markers',
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
          home: Scaffold(body: ChunkCreatorPage(controller: harness.session)),
        ),
      );
      await tester.pumpAndSettle();

      final original = _chunk(harness.session, 'forest_chunk');
      expect(
        find.byKey(const ValueKey<String>('chunk_creation_scene')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('chunk_terrain_card')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('chunk_layers_card')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('chunk_v2_view_composition')),
        findsNothing,
      );
      final sceneElement = tester.element(
        find.byKey(const ValueKey<String>('chunk_scene_surface')),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('chunk_terrain_card_toggle')),
      );
      await tester.pumpAndSettle();
      expect(
        tester.element(
          find.byKey(const ValueKey<String>('chunk_scene_surface')),
        ),
        same(sceneElement),
      );
      Future<void> selectDomain(ChunkSceneDomain domain) async {
        tester
            .widget<SegmentedButton<ChunkSceneDomain>>(
              find.byKey(const ValueKey<String>('chunk_scene_domain_selector')),
            )
            .onSelectionChanged!(<ChunkSceneDomain>{domain});
        await tester.pump();
      }

      Future<void> tapCompositionControl(
        ChunkSceneDomain domain,
        String key,
      ) async {
        await selectDomain(domain);
        final control = find.byKey(ValueKey<String>(key));
        await Scrollable.ensureVisible(tester.element(control), alignment: 0.4);
        await tester.pumpAndSettle();
        await tester.tap(control);
        await tester.pumpAndSettle();
      }

      await selectDomain(ChunkSceneDomain.layers);
      final groundStackEntry = find.byKey(
        const ValueKey<String>('chunk_visual_stack_ground'),
      );
      final initialPrefabStackEntry = find.byKey(
        const ValueKey<String>('chunk_visual_stack_prefab_prefab_rock|95|10|0'),
      );
      expect(
        find.byKey(const ValueKey<String>('chunk_visual_stack_preview')),
        findsOneWidget,
      );
      expect(groundStackEntry, findsOneWidget);
      expect(initialPrefabStackEntry, findsOneWidget);
      expect(find.text('Ground polygons · z=0 · 1 shape(s)'), findsOneWidget);
      expect(
        tester.getTopLeft(groundStackEntry).dx,
        lessThan(tester.getTopLeft(initialPrefabStackEntry).dx),
      );

      await tapCompositionControl(
        ChunkSceneDomain.prefabs,
        'chunk_v2_placement_edit_prefab_rock|95|10|0',
      );
      final noOpPlacementApply = find.byKey(
        const ValueKey<String>(
          'chunk_v2_placement_inline_apply_prefab_rock|95|10|0',
        ),
      );
      await tester.ensureVisible(noOpPlacementApply);
      await tester.tap(noOpPlacementApply);
      await tester.pumpAndSettle();
      expect(_chunk(harness.session, 'forest_chunk').revision, 4);
      expect(
        find.textContaining('Composition change was rejected'),
        findsNothing,
      );

      await tapCompositionControl(
        ChunkSceneDomain.layers,
        'chunk_v2_layer_add',
      );
      final routeState = tester.state(find.byType(ChunkCreatorPage));
      final localDraftState = routeState as EditorPageLocalDraftState;
      final shortcutHandler = routeState as EditorPageSessionShortcutHandler;
      final reloadHandler = routeState as EditorPageReloadHandler;
      expect(localDraftState.hasLocalDraftChanges, isTrue);
      expect(reloadHandler.canReloadEditorPage, isFalse);
      expect(shortcutHandler.canHandleUndoSessionShortcut, isFalse);
      final applyHandler = routeState as EditorPageApplyHandler;
      expect(applyHandler.canApplyEditorPage, isFalse);
      await tester.enterText(
        find.byKey(const ValueKey<String>('chunk_v2_layer_id_field')),
        'background',
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('chunk_v2_layer_dialog_apply')),
      );
      await tester.pumpAndSettle();
      var edited = _chunk(harness.session, 'forest_chunk');
      expect(edited.revision, 5);
      expect(edited.tileLayers.single.id, 'background');
      expect(edited.prefabs, original.prefabs);
      expect(edited.markers, original.markers);
      expect(edited.collisionShapes, original.collisionShapes);
      expect(reloadHandler.canReloadEditorPage, isTrue);
      expect(shortcutHandler.canHandleUndoSessionShortcut, isTrue);

      await selectDomain(ChunkSceneDomain.prefabs);
      expect(find.text('Create prefab placement'), findsOneWidget);
      expect(find.text('Existing prefab placements'), findsOneWidget);
      await tester.enterText(
        find.byKey(
          const ValueKey<String>('chunk_v2_placement_creation_x_field'),
        ),
        '80',
      );
      await tester.enterText(
        find.byKey(
          const ValueKey<String>('chunk_v2_placement_creation_y_field'),
        ),
        '10',
      );
      await tester.enterText(
        find.byKey(
          const ValueKey<String>('chunk_v2_placement_creation_z_field'),
        ),
        '2',
      );
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      final scaleField = find.byKey(
        const ValueKey<String>('chunk_v2_placement_creation_scale_1.0'),
      );
      await tester.ensureVisible(scaleField);
      await tester.tap(scaleField);
      await tester.pumpAndSettle();
      await tester.tap(find.text('×0.6').last);
      final flipYField = find.byKey(
        const ValueKey<String>('chunk_v2_placement_creation_flip_y_field'),
      );
      await Scrollable.ensureVisible(
        tester.element(flipYField),
        alignment: 0.5,
      );
      await tester.pump();
      await tester.tap(flipYField);
      final addPlacement = find.byKey(
        const ValueKey<String>('chunk_v2_placement_add'),
      );
      await Scrollable.ensureVisible(
        tester.element(addPlacement),
        alignment: 0.5,
      );
      await tester.pump();
      expect(find.byType(AlertDialog), findsNothing);
      await tester.tap(addPlacement);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      edited = _chunk(harness.session, 'forest_chunk');
      expect(edited.revision, 6);
      final addedPlacement = edited.prefabs.singleWhere(
        (placement) => placement.x == 80,
      );
      expect(addedPlacement.prefabKey, 'prefab_rock');
      expect(addedPlacement.zIndex, 2);
      expect(addedPlacement.scale, 0.6);
      expect(addedPlacement.flipY, isTrue);
      await selectDomain(ChunkSceneDomain.layers);
      final addedPrefabStackEntry = find.byKey(
        const ValueKey<String>('chunk_visual_stack_prefab_prefab_rock|80|10|0'),
      );
      expect(addedPrefabStackEntry, findsOneWidget);
      expect(
        tester.getTopLeft(initialPrefabStackEntry).dx,
        lessThan(tester.getTopLeft(addedPrefabStackEntry).dx),
      );

      await selectDomain(ChunkSceneDomain.markers);
      expect(find.text('Create enemy marker'), findsOneWidget);
      expect(find.text('Existing enemy markers'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey<String>('chunk_v2_marker_creation_x_field')),
        '60',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('chunk_v2_marker_creation_y_field')),
        '5',
      );
      final addMarker = find.byKey(
        const ValueKey<String>('chunk_v2_marker_add'),
      );
      await Scrollable.ensureVisible(tester.element(addMarker), alignment: 0.5);
      expect(find.byType(AlertDialog), findsNothing);
      await tester.tap(addMarker);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      edited = _chunk(harness.session, 'forest_chunk');
      expect(edited.revision, 7);
      expect(
        edited.markers.any(
          (marker) =>
              marker.markerId == 'derf' && marker.x == 60 && marker.y == 5,
        ),
        isTrue,
      );

      await tapCompositionControl(
        ChunkSceneDomain.layers,
        'chunk_v2_layer_edit_background',
      );
      expect(shortcutHandler.canHandleUndoSessionShortcut, isFalse);
      expect(shortcutHandler.handleUndoSessionShortcut(), isFalse);
      expect(_chunk(harness.session, 'forest_chunk').revision, 7);
      await tester.enterText(
        find.byKey(const ValueKey<String>('chunk_v2_layer_kind_field')),
        'backdrop',
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('chunk_v2_layer_visible_field')),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('chunk_v2_layer_dialog_apply')),
      );
      await tester.pumpAndSettle();
      edited = _chunk(harness.session, 'forest_chunk');
      expect(edited.revision, 8);
      expect(edited.tileLayers.single.kind, 'backdrop');
      expect(edited.tileLayers.single.visible, isFalse);

      await tapCompositionControl(
        ChunkSceneDomain.prefabs,
        'chunk_v2_placement_edit_prefab_rock|80|10|0',
      );
      await tester.enterText(
        find.byKey(
          const ValueKey<String>(
            'chunk_v2_placement_inline_prefab_rock|80|10|0_x_field',
          ),
        ),
        '85',
      );
      final editPlacementApply = find.byKey(
        const ValueKey<String>(
          'chunk_v2_placement_inline_apply_prefab_rock|80|10|0',
        ),
      );
      await tester.ensureVisible(editPlacementApply);
      await tester.tap(editPlacementApply);
      await tester.pumpAndSettle();
      edited = _chunk(harness.session, 'forest_chunk');
      expect(edited.revision, 9);
      expect(edited.prefabs.any((placement) => placement.x == 85), isTrue);

      await tapCompositionControl(
        ChunkSceneDomain.markers,
        'chunk_v2_marker_edit_derf|60|5|0',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('chunk_v2_marker_chance_field')),
        '75',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('chunk_v2_marker_salt_field')),
        '9',
      );
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      final editMarkerApply = find.byKey(
        const ValueKey<String>('chunk_v2_marker_dialog_apply'),
      );
      await tester.ensureVisible(editMarkerApply);
      await tester.tap(editMarkerApply);
      await tester.pumpAndSettle();
      edited = _chunk(harness.session, 'forest_chunk');
      expect(edited.revision, 10);
      final derf = edited.markers.singleWhere(
        (marker) => marker.markerId == 'derf',
      );
      expect(derf.chancePercent, 75);
      expect(derf.salt, 9);
      expect(derf.placement, markerPlacementGround);
      expect(edited.status, original.status);
      expect(edited.levelId, original.levelId);
      expect(edited.tags, original.tags);
      expect(edited.groundBandZIndex, original.groundBandZIndex);
      expect(edited.collisionShapes, original.collisionShapes);

      await tapCompositionControl(
        ChunkSceneDomain.layers,
        'chunk_v2_layer_delete_background',
      );
      await tester.tap(
        find.byKey(
          const ValueKey<String>('chunk_v2_composition_delete_confirm'),
        ),
      );
      await tester.pumpAndSettle();
      expect(_chunk(harness.session, 'forest_chunk').tileLayers, isEmpty);

      await tapCompositionControl(
        ChunkSceneDomain.prefabs,
        'chunk_v2_placement_delete_prefab_rock|85|10|0',
      );
      await tester.tap(
        find.byKey(
          const ValueKey<String>('chunk_v2_composition_delete_confirm'),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        _chunk(
          harness.session,
          'forest_chunk',
        ).prefabs.where((placement) => placement.x == 85),
        isEmpty,
      );

      await tapCompositionControl(
        ChunkSceneDomain.markers,
        'chunk_v2_marker_delete_derf|60|5|0',
      );
      await tester.tap(
        find.byKey(
          const ValueKey<String>('chunk_v2_composition_delete_confirm'),
        ),
      );
      await tester.pumpAndSettle();
      edited = _chunk(harness.session, 'forest_chunk');
      expect(
        edited.markers.where((marker) => marker.markerId == 'derf'),
        isEmpty,
      );
      expect(edited.prefabs, original.prefabs);
      expect(edited.markers, original.markers);
      expect(edited.collisionShapes, original.collisionShapes);
      expect(edited.revision, 13);
      expect(shortcutHandler.handleUndoSessionShortcut(), isTrue);
      await tester.pump();
      expect(
        _chunk(
          harness.session,
          'forest_chunk',
        ).markers.any((marker) => marker.markerId == 'derf'),
        isTrue,
      );
      expect(shortcutHandler.handleRedoSessionShortcut(), isTrue);
      await tester.pump();
      expect(
        _chunk(
          harness.session,
          'forest_chunk',
        ).markers.any((marker) => marker.markerId == 'derf'),
        isFalse,
      );
      expect(harness.plugin.loadCount, 1);
    },
  );

  testWidgets(
    'open composition dialog rejects an intervening owner revision once',
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
          home: Scaffold(body: ChunkCreatorPage(controller: harness.session)),
        ),
      );
      await tester.pumpAndSettle();
      tester
          .widget<SegmentedButton<ChunkSceneDomain>>(
            find.byKey(const ValueKey<String>('chunk_scene_domain_selector')),
          )
          .onSelectionChanged!(<ChunkSceneDomain>{ChunkSceneDomain.layers});
      await tester.pump();
      final addLayer = find.byKey(const ValueKey<String>('chunk_v2_layer_add'));
      await Scrollable.ensureVisible(tester.element(addLayer), alignment: 0.4);
      await tester.tap(addLayer);
      await tester.pumpAndSettle();

      final current = _chunk(harness.session, 'forest_chunk');
      final beforeMetadata = ChunkV2MetadataSnapshot.fromChunk(current);
      harness.session.applyCommand(
        AuthoringCommand(
          kind: ChunkDomainPlugin.commitChunkMetadataCommandKind,
          payload: <String, Object?>{
            'chunkKey': current.chunkKey,
            'commit': ChunkV2MetadataCommit(
              before: beforeMetadata,
              after: ChunkV2MetadataSnapshot(
                status: beforeMetadata.status,
                levelId: beforeMetadata.levelId,
                difficulty: beforeMetadata.difficulty,
                assemblyGroupId: beforeMetadata.assemblyGroupId,
                tags: beforeMetadata.tags,
                groundBandZIndex: beforeMetadata.groundBandZIndex + 1,
              ),
            ),
          },
        ),
      );
      await tester.pump();
      expect(_chunk(harness.session, 'forest_chunk').revision, 5);
      expect(harness.session.canUndo, isTrue);

      await tester.enterText(
        find.byKey(const ValueKey<String>('chunk_v2_layer_id_field')),
        'background',
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('chunk_v2_layer_dialog_apply')),
      );
      await tester.pumpAndSettle();

      final rejected = _chunk(harness.session, 'forest_chunk');
      expect(rejected.revision, 5);
      expect(rejected.tileLayers, isEmpty);
      expect(
        find.textContaining('Composition change was rejected'),
        findsOneWidget,
      );
      expect(harness.session.canUndo, isTrue);
      harness.session.undo();
      await tester.pump();
      expect(_chunk(harness.session, 'forest_chunk').revision, 4);
      expect(harness.session.canUndo, isFalse);
      expect(harness.session.pendingChanges.hasChanges, isFalse);
    },
  );

  testWidgets('deleting a level final owner keeps undo recovery available', (
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
        home: Scaffold(body: ChunkCreatorPage(controller: harness.session)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('chunk_v2_owner_delete')),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('final owner in the active level'), findsOne);
    await tester.tap(
      find.byKey(const ValueKey<String>('chunk_v2_owner_delete_confirm')),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('No chunk owners remain in this level'),
      findsOneWidget,
    );
    final createButton = tester.widget<FilledButton>(
      find.byKey(const ValueKey<String>('chunk_v2_owner_create')),
    );
    expect(createButton.onPressed, isNull);
    final routeState = tester.state(find.byType(ChunkCreatorPage));
    final shortcutHandler = routeState as EditorPageSessionShortcutHandler;
    expect(shortcutHandler.canHandleUndoSessionShortcut, isTrue);

    expect(shortcutHandler.handleUndoSessionShortcut(), isTrue);
    await tester.pump();
    expect(
      find.byKey(const ValueKey<String>('chunk_polygon_owner_forest_chunk')),
      findsOneWidget,
    );
    expect(_chunk(harness.session, 'forest_chunk').revision, 4);
    expect(harness.session.pendingChanges.hasChanges, isFalse);
  });
}

Future<_Harness> _buildHarness({
  List<ValidationIssue> additionalIssues = const <ValidationIssue>[],
  List<PrefabV3Def> additionalPrefabs = const <PrefabV3Def>[],
}) async {
  final root = Directory.systemTemp.createTempSync('chunk_stage_page_');
  final manifest = File(
    p.join(
      root.path,
      'assets',
      'authoring',
      'level',
      'terrain_material_defs.json',
    ),
  )..parent.createSync(recursive: true);
  manifest.writeAsStringSync(
    File(
      p.normalize(
        p.absolute(
          p.join(
            Directory.current.path,
            '..',
            '..',
            'assets',
            'authoring',
            'level',
            'terrain_material_defs.json',
          ),
        ),
      ),
    ).readAsStringSync(),
  );
  final forestChunk = _chunkData(
    chunkKey: 'forest_chunk',
    levelId: 'forest',
    shapeId: 'ground_001',
    placements: const <PlacedPrefabDef>[
      PlacedPrefabDef(
        prefabId: 'rock',
        prefabKey: 'prefab_rock',
        x: 95,
        y: 10,
        scale: 0.5,
        flipX: true,
      ),
    ],
    markers: const <PlacedMarkerDef>[
      PlacedMarkerDef(markerId: 'grojib', x: 30, y: 5, salt: 2),
      PlacedMarkerDef(markerId: 'hashash', x: 40, y: 5, salt: 3),
    ],
  );
  final meadowChunk = _chunkData(
    chunkKey: 'meadow_chunk',
    levelId: 'meadow',
    shapeId: 'ground_002',
  );
  final document = ChunkV2Document(
    chunks: <ChunkV2FileData>[forestChunk, meadowChunk],
    sourcePathByChunkKey: const <String, String>{
      'forest_chunk': 'chunks/forest_chunk.json',
      'meadow_chunk': 'chunks/meadow_chunk.json',
    },
    baselineContentsByChunkKey: <String, String>{
      'forest_chunk': ChunkV2FileCodec.encode(forestChunk),
      'meadow_chunk': ChunkV2FileCodec.encode(meadowChunk),
    },
    prefabData: PrefabV3FileData(
      slices: const <AtlasSliceDef>[],
      prefabs: <PrefabV3Def>[
        PrefabV3Def(
          prefabKey: 'prefab_rock',
          id: 'rock',
          revision: 3,
          status: PrefabStatus.active,
          kind: PrefabKind.obstacle,
          visualSource: const PrefabVisualSource.atlasSlice('rock_slice'),
          anchorXPx: 8,
          anchorYPx: 12,
          collisionShapes: <TerrainSourceShapeDef>[
            TerrainSourceShapeDef(
              shapeId: 'collision_001',
              vertices: const <TerrainSourceVertexDef>[
                TerrainSourceVertexDef(xHalfPixels: 0, yHalfPixels: 0),
                TerrainSourceVertexDef(xHalfPixels: 10, yHalfPixels: 0),
                TerrainSourceVertexDef(xHalfPixels: 10, yHalfPixels: 10),
                TerrainSourceVertexDef(xHalfPixels: 0, yHalfPixels: 10),
              ],
            ),
          ],
          tags: const <String>[],
        ),
        ...additionalPrefabs,
      ],
    ),
    tileData: PrefabTileFileData(
      tileSlices: const <AtlasSliceDef>[],
      platformModules: const <TileModuleDef>[],
    ),
    visualBoundsByPrefabKey: const <String, PrefabV3VisualBounds>{},
    groundTopYByLevelId: const <String, double>{'forest': 10, 'meadow': 10},
    levels: const <LevelDef>[_forestLevel, _meadowLevel],
    parallaxThemes: const <ParallaxThemeDef>[
      ParallaxThemeDef(
        parallaxThemeId: 'forest',
        revision: 1,
        layers: <ParallaxLayerDef>[
          ParallaxLayerDef(
            layerKey: 'forest_background',
            assetPath: 'assets/images/parallax/forest/Forest Layer 01.png',
            group: parallaxGroupBackground,
            parallaxFactor: 0.1,
            zOrder: 1,
            opacity: 1,
            yOffset: 0,
          ),
          ParallaxLayerDef(
            layerKey: 'forest_foreground',
            assetPath: 'assets/images/parallax/forest/Forest Layer 04.png',
            group: parallaxGroupForeground,
            parallaxFactor: 1,
            zOrder: 2,
            opacity: 1,
            yOffset: 0,
          ),
        ],
      ),
    ],
    availableLevelIds: const <String>['forest', 'meadow'],
    activeLevelId: 'forest',
  );
  final plugin = _ChunkPlugin(document, additionalIssues: additionalIssues);
  final session = EditorSessionController(
    pluginRegistry: AuthoringPluginRegistry(
      plugins: <AuthoringDomainPlugin>[plugin],
    ),
    initialPluginId: ChunkDomainPlugin.pluginId,
    initialWorkspacePath: root.path,
  );
  await session.loadWorkspace();
  return _Harness(root: root, session: session, plugin: plugin);
}

const LevelDef _forestLevel = LevelDef(
  levelId: 'forest',
  revision: 1,
  displayName: 'Forest',
  visualThemeId: 'forest',
  cameraCenterY: 25,
  groundTopY: 10,
  earlyPatternChunks: 0,
  easyPatternChunks: 0,
  normalPatternChunks: 0,
  noEnemyChunks: 0,
  enumOrdinal: 1,
  status: levelStatusActive,
);

const LevelDef _meadowLevel = LevelDef(
  levelId: 'meadow',
  revision: 1,
  displayName: 'Meadow',
  visualThemeId: 'meadow',
  cameraCenterY: 25,
  groundTopY: 10,
  earlyPatternChunks: 0,
  easyPatternChunks: 0,
  normalPatternChunks: 0,
  noEnemyChunks: 0,
  enumOrdinal: 2,
  status: levelStatusActive,
);

ChunkV2FileData _chunkData({
  required String chunkKey,
  required String levelId,
  required String shapeId,
  Iterable<PlacedPrefabDef> placements = const <PlacedPrefabDef>[],
  Iterable<PlacedMarkerDef> markers = const <PlacedMarkerDef>[],
}) => ChunkV2FileData(
  chunkKey: chunkKey,
  id: chunkKey,
  revision: 4,
  status: chunkStatusActive,
  levelId: levelId,
  tileSize: 16,
  width: 100,
  height: 50,
  difficulty: chunkDifficultyNormal,
  assemblyGroupId: defaultChunkAssemblyGroupId,
  tags: <String>[levelId],
  tileLayers: const <TileLayerDef>[],
  prefabs: placements,
  markers: markers,
  groundBandZIndex: 0,
  collisionShapes: <TerrainSourceShapeDef>[
    TerrainSourceShapeDef(
      shapeId: shapeId,
      vertices: const <TerrainSourceVertexDef>[
        TerrainSourceVertexDef(xHalfPixels: 20, yHalfPixels: 20),
        TerrainSourceVertexDef(xHalfPixels: 100, yHalfPixels: 20),
        TerrainSourceVertexDef(xHalfPixels: 100, yHalfPixels: 80),
        TerrainSourceVertexDef(xHalfPixels: 20, yHalfPixels: 80),
      ],
    ),
  ],
);

ChunkV2FileData _chunk(EditorSessionController session, String chunkKey) {
  final document = session.document! as ChunkV2Document;
  return document.chunks.singleWhere((chunk) => chunk.chunkKey == chunkKey);
}

final class _Harness {
  const _Harness({
    required this.root,
    required this.session,
    required this.plugin,
  });

  final Directory root;
  final EditorSessionController session;
  final _ChunkPlugin plugin;

  void dispose() {
    session.dispose();
    if (root.existsSync()) root.deleteSync(recursive: true);
  }
}

final class _ChunkPlugin implements AuthoringDomainPlugin {
  _ChunkPlugin(
    this.document, {
    this.additionalIssues = const <ValidationIssue>[],
  });

  final ChunkV2Document document;
  final List<ValidationIssue> additionalIssues;
  final ChunkDomainPlugin _delegate = ChunkDomainPlugin();
  int loadCount = 0;

  @override
  String get id => ChunkDomainPlugin.pluginId;

  @override
  Future<AuthoringDocument> loadFromRepo(EditorWorkspace workspace) async {
    loadCount += 1;
    return document;
  }

  @override
  List<ValidationIssue> validate(AuthoringDocument document) =>
      <ValidationIssue>[..._delegate.validate(document), ...additionalIssues];

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
