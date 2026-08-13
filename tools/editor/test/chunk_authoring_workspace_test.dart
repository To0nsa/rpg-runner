import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:runner_editor/src/app/pages/chunkCreator/chunk_creator_page.dart';
import 'package:runner_editor/src/app/pages/chunkCreator/v2/chunk_actor_terrain_overlay_painter.dart';
import 'package:runner_editor/src/app/pages/chunkCreator/v2/chunk_compiled_edge_overlay_painter.dart';
import 'package:runner_editor/src/app/pages/chunkCreator/v2/chunk_marker_placement_overlay_painter.dart';
import 'package:runner_editor/src/app/pages/chunkCreator/v2/chunk_scene_coordinator.dart';
import 'package:runner_editor/src/app/pages/chunkCreator/v2/chunk_scene_surface.dart';
import 'package:runner_editor/src/app/pages/chunkCreator/v2/chunk_scene_visual_source.dart';
import 'package:runner_editor/src/app/pages/shared/editor_list_card.dart';
import 'package:runner_editor/src/app/pages/shared/editor_page_local_draft_state.dart';
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
      expect(find.text('Owners & terrain collision'), findsOneWidget);
      expect(find.text('Layers, prefabs & markers'), findsOneWidget);
      final sceneSlot = find.byKey(const ValueKey<String>('chunk_scene_slot'));
      final sidebarSlot = find.byKey(
        const ValueKey<String>('chunk_sidebar_slot'),
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
        find.byKey(const ValueKey<String>('chunk_polygon_owner_meadow_chunk')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('chunk_expanded_collision_overlay')),
        findsOneWidget,
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
        find.byKey(const ValueKey<String>('chunk_polygon_source_fill_notice')),
        findsOneWidget,
      );
      expect(
        find.text(
          '1 direct + 1 expanded = 2/512 shapes · 8/4096 exposed edges',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          '1 reachable neighbor(s) · 1 directed scheduler seam(s) · '
          '1 compatible · 0 failing',
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('chunk_polygon_shapes_panel')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('chunk_polygon_seams_panel')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('chunk_polygon_diagnostics_panel')),
        findsOneWidget,
      );
      final seamInspector = find.byKey(
        const ValueKey<String>('chunk_seam_inspector'),
      );
      final seamList = find.byKey(const ValueKey<String>('chunk_seam_list'));
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
      final sidebarBodyKeys = <String>[
        'chunk_shape_list',
        'chunk_seam_list',
        'chunk_diagnostics_list',
      ];
      Future<void> expectExpandable({
        required String panelKey,
        required String bodyKey,
      }) async {
        final toggle = find.byKey(
          ValueKey<String>('chunk_polygon_${panelKey}_panel_toggle'),
        );
        await tester.scrollUntilVisible(
          toggle,
          200,
          scrollable: authoringSidebarScrollable,
        );
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(find.byKey(ValueKey<String>(bodyKey)), findsNothing);
        for (final otherBodyKey in sidebarBodyKeys.where(
          (key) => key != bodyKey,
        )) {
          expect(find.byKey(ValueKey<String>(otherBodyKey)), findsOneWidget);
        }
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(find.byKey(ValueKey<String>(bodyKey)), findsOneWidget);
      }

      await expectExpandable(panelKey: 'shapes', bodyKey: 'chunk_shape_list');
      await expectExpandable(panelKey: 'seams', bodyKey: 'chunk_seam_list');
      await expectExpandable(
        panelKey: 'diagnostics',
        bodyKey: 'chunk_diagnostics_list',
      );
      await tester.ensureVisible(seamInspector);
      expect(seamInspector, findsOneWidget);
      expect(
        find.textContaining('right → forest_chunk · compatible'),
        findsOneWidget,
      );
      expect(find.textContaining('steady-hard:tier=hard>hard'), findsOneWidget);
      expect(seamList, findsOneWidget);
      await tester.drag(authoringSidebar, const Offset(0, 2000));
      await tester.pump();
      expect(
        find.byKey(
          const ValueKey<String>(
            'chunk_expanded_shape_prefab_rock|95|10|0_collision_001',
          ),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('prefab prefab_rock rev 3'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('chunk_compiled_edge_overlay')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(
          const ValueKey<String>('chunk_compiled_edge_inspect_toggle'),
        ),
      );
      await tester.pump();
      final edgeOverlay = find.byKey(
        const ValueKey<String>('chunk_compiled_edge_overlay'),
      );
      final edgePainter =
          tester.widget<CustomPaint>(edgeOverlay).painter!
              as ChunkCompiledEdgeOverlayPainter;
      await tester.tapAt(
        tester.getTopLeft(edgeOverlay) +
            edgePainter.transform.origin +
            Offset(
              30 * edgePainter.transform.zoom,
              10 * edgePainter.transform.zoom,
            ),
      );
      await tester.pump();
      expect(
        find.byKey(const ValueKey<String>('chunk_compiled_edge_inspector')),
        findsOneWidget,
      );
      final selectedEdgePainter =
          tester.widget<CustomPaint>(edgeOverlay).painter!
              as ChunkCompiledEdgeOverlayPainter;
      expect(
        selectedEdgePainter.selectedEdgeId?.canonicalKey,
        '0/12:forest_chunk/-/10:ground_001/0/0',
      );
      expect(
        find.text('0/12:forest_chunk/-/10:ground_001/0/0'),
        findsOneWidget,
      );
      expect(find.text('absolute slope 0° (0 units)'), findsOneWidget);
      expect(find.textContaining('tangent (1024, 0)'), findsOneWidget);
      expect(find.text('diagnostics none'), findsOneWidget);
      expect(_chunk(harness.session, 'forest_chunk').revision, 4);
      expect(harness.session.pendingChanges.hasChanges, isFalse);
      await tester.tap(
        find.byKey(const ValueKey<String>('chunk_actor_terrain_toggle')),
      );
      await tester.pump();
      final actorOverlay = find.byKey(
        const ValueKey<String>('chunk_actor_terrain_overlay'),
      );
      expect(actorOverlay, findsOneWidget);
      expect(
        tester.widget<CustomPaint>(actorOverlay).painter,
        isA<ChunkActorTerrainOverlayPainter>(),
      );
      expect(
        find.textContaining('player pathfinding graph is not defined'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Éloïse: navigation surface yes · eligible yes'),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('chunk_actor_terrain_selector')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Derf').last);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('perch-eligible surfaces · 32 px minimum'),
        findsOneWidget,
      );
      expect(
        find.textContaining('horizontal span 40 px / 32 px pass'),
        findsOneWidget,
      );
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
      expect(find.textContaining('0 RNG draws'), findsOneWidget);
      final grojibMarker = find.byKey(
        const ValueKey<String>('chunk_marker_placement_grojib|30|5|0'),
      );
      await tester.drag(authoringSidebar, const Offset(0, -700));
      await tester.pump();
      await tester.drag(authoringSidebar, const Offset(0, -300));
      await tester.pump();
      await tester.drag(authoringSidebar, const Offset(0, -500));
      await tester.pump();
      await tester.ensureVisible(grojibMarker);
      await tester.tap(grojibMarker);
      await tester.pump();
      expect(
        find.byKey(const ValueKey<String>('chunk_selected_marker_evidence')),
        findsOneWidget,
      );
      expect(
        find.textContaining('Core valid · requested body'),
        findsOneWidget,
      );
      expect(find.textContaining('salt 2'), findsOneWidget);
      expect(
        find.textContaining('Hashash placement is deferred by runtime'),
        findsOneWidget,
      );
      expect(
        find.textContaining('runtime ballistic projectiles sweep'),
        findsOneWidget,
      );
      await tester.drag(authoringSidebar, const Offset(0, 2000));
      await tester.pump();
      expect(_chunk(harness.session, 'forest_chunk').revision, 4);
      expect(harness.session.pendingChanges.hasChanges, isFalse);
      await tester.tap(
        find.byKey(
          const ValueKey<String>('chunk_compiled_edge_inspect_toggle'),
        ),
      );
      await tester.pump();
      final applySource = tester.widget<FilledButton>(
        find.byKey(const ValueKey<String>('chunk_polygon_apply_source')),
      );
      expect(applySource.onPressed, isNull);

      await tester.tap(
        find.byKey(const ValueKey<String>('chunk_polygon_shape_ground_001')),
      );
      await tester.pump();
      final deleteShape = find.byKey(
        const ValueKey<String>('chunk_polygon_delete_shape'),
      );
      await tester.tap(deleteShape);
      await tester.pump();

      var forestChunk = _chunk(harness.session, 'forest_chunk');
      expect(forestChunk.revision, 5);
      expect(forestChunk.collisionShapes, isEmpty);
      expect(harness.session.pendingChanges.changedItemIds, <String>[
        'forest_chunk',
      ]);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey<String>('chunk_polygon_apply_source')),
            )
            .onPressed,
        isNotNull,
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('chunk_polygon_apply_source')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Apply Chunk-v2 Changes'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Cancel').last);
      await tester.pumpAndSettle();

      final routeState = tester.state(find.byType(ChunkCreatorPage));
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
      await tester.tap(
        find.byKey(const ValueKey<String>('chunk_polygon_shape_ground_001')),
      );
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
        const ValueKey<String>('chunk_polygon_apply_vertex'),
      );
      await tester.ensureVisible(xField);
      await tester.enterText(xField, '12.25');
      await tester.enterText(yField, '10.5');
      await Scrollable.ensureVisible(
        tester.element(applyVertex),
        alignment: 0.5,
      );
      await tester.pump();
      await tester.tap(applyVertex);
      await tester.pump();

      expect(find.text('Use an integer or .5 value.'), findsOneWidget);
      forestChunk = _chunk(harness.session, 'forest_chunk');
      expect(forestChunk.revision, 4);
      expect(harness.session.pendingChanges.hasChanges, isFalse);

      await tester.enterText(xField, '12.5');
      await tester.tap(applyVertex);
      await tester.pump();

      forestChunk = _chunk(harness.session, 'forest_chunk');
      expect(forestChunk.revision, 5);
      expect(
        forestChunk.collisionShapes.single.vertices,
        contains(
          const TerrainSourceVertexDef(xHalfPixels: 25, yHalfPixels: 21),
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
      final editMetadata = find.descendant(
        of: shapeList,
        matching: find.byKey(
          const ValueKey<String>('chunk_polygon_edit_metadata'),
        ),
      );
      await Scrollable.ensureVisible(
        tester.element(editMetadata),
        alignment: 0.5,
      );
      await tester.pump();
      await tester.tap(editMetadata);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('chunk_polygon_metadata_dialog')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('chunk_polygon_metadata_mode')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('oneWay').last);
      await tester.pumpAndSettle();
      expect(
        find.byKey(
          const ValueKey<String>('chunk_polygon_material_preview_empty'),
        ),
        findsOneWidget,
      );
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
      await tester.tap(find.text('grass_dirt').last);
      await tester.pumpAndSettle();
      expect(
        find.byKey(
          const ValueKey<String>('chunk_polygon_material_preview_fill'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey<String>('chunk_polygon_material_preview_surface'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey<String>('chunk_polygon_material_preview_foreground'),
        ),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('chunk_polygon_metadata_apply')),
      );
      await tester.pumpAndSettle();

      forestChunk = _chunk(harness.session, 'forest_chunk');
      final editedShape = forestChunk.collisionShapes.single;
      expect(forestChunk.revision, 5);
      expect(editedShape.collisionMode, TerrainSourceCollisionMode.oneWay);
      expect(editedShape.surfaceKind, 'ground');
      expect(editedShape.materialKey, 'grass_dirt');
      expect(harness.session.pendingChanges.changedItemIds, <String>[
        'forest_chunk',
      ]);
      expect(shortcutHandler.handleUndoSessionShortcut(), isTrue);
      await tester.pump();
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

    final domainSelector = find.byKey(
      const ValueKey<String>('chunk_scene_domain_selector'),
    );
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
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const ValueKey<String>('chunk_polygon_undo_button')),
          )
          .onPressed,
      isNotNull,
    );

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

    await tester.tap(
      find.byKey(const ValueKey<String>('chunk_polygon_undo_button')),
    );
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

  testWidgets('selected chunk shapes show their metadata subsection', (
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
    final groundShape = find.byKey(
      const ValueKey<String>('chunk_polygon_shape_ground_001'),
    );
    await tester.scrollUntilVisible(
      groundShape,
      100,
      scrollable: find
          .descendant(of: authoringSidebar, matching: find.byType(Scrollable))
          .first,
    );
    await tester.tap(groundShape);
    await tester.pump();

    final metadataSection = find.byKey(
      const ValueKey<String>('chunk_polygon_metadata_section'),
    );
    expect(metadataSection, findsOneWidget);
    expect(find.text('Collision mode: solid'), findsOneWidget);
    expect(find.text('Surface: —'), findsOneWidget);
    expect(find.text('Material: —'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('chunk_polygon_edit_metadata')),
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
        find.byKey(const ValueKey<String>('chunk_owners_terrain_card')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('chunk_composition_card')),
        findsOneWidget,
      );
      final sceneSlot = find.byKey(const ValueKey<String>('chunk_scene_slot'));
      final sidebarSlot = find.byKey(
        const ValueKey<String>('chunk_sidebar_slot'),
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
      expect(tester.widget<OutlinedButton>(newRectangle).onPressed, isNotNull);
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
      for (final tool in const <String>['createPolygon']) {
        expect(
          tester
              .widget<ChoiceChip>(
                find.byKey(ValueKey<String>('chunk_polygon_tool_$tool')),
              )
              .onSelected,
          isNull,
        );
      }
      await tester.tap(
        find.byKey(const ValueKey<String>('chunk_polygon_new_shape')),
      );
      await tester.pump();
      expect(tester.widget<OutlinedButton>(saveDraft).onPressed, isNotNull);
      expect(tester.widget<OutlinedButton>(newRectangle).onPressed, isNull);
      expect(
        find.textContaining('Finish or cancel the active terrain edit'),
        findsNWidgets(2),
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const ValueKey<String>('chunk_v2_owner_edit')),
            )
            .onPressed,
        isNull,
      );
      for (final key in const <String>[
        'chunk_v2_layer_add',
        'chunk_v2_placement_add',
        'chunk_v2_marker_add',
      ]) {
        expect(
          tester
              .widget<FilledButton>(find.byKey(ValueKey<String>(key)))
              .onPressed,
          isNull,
        );
      }
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
      for (final tool in const <String>[
        'createPolygon',
        'moveVertex',
        'insertVertex',
      ]) {
        expect(
          tester
              .widget<ChoiceChip>(
                find.byKey(ValueKey<String>('chunk_polygon_tool_$tool')),
              )
              .onSelected,
          isNotNull,
        );
      }
      expect(find.text('Place vertex'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

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
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.3)),
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
      find.byKey(const ValueKey<String>('chunk_composition_card')),
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

    expect(find.text('Tile layer metadata'), findsOneWidget);
    expect(find.text('Add layer'), findsOneWidget);
    expect(find.text('Paint tiles'), findsNothing);
    expect(find.text('Erase tiles'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('chunk_tile_paint_tool')),
      findsNothing,
    );
  });

  testWidgets('expanded collision opens its exact owning prefab', (
    tester,
  ) async {
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

    final openOwner = find.byKey(
      const ValueKey<String>(
        'chunk_open_prefab_prefab_rock|95|10|0_collision_001',
      ),
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

      await tester.tap(
        find.byKey(const ValueKey<String>('chunk_polygon_undo_button')),
      );
      await tester.pump();
      expect(_chunk(harness.session, 'forest_chunk').revision, 4);
      await tester.tap(
        find.byKey(const ValueKey<String>('chunk_polygon_redo_button')),
      );
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
        find.byKey(const ValueKey<String>('chunk_owners_terrain_card')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('chunk_composition_card')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('chunk_v2_view_composition')),
        findsNothing,
      );
      final sceneElement = tester.element(
        find.byKey(const ValueKey<String>('chunk_scene_surface')),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('chunk_owners_terrain_card_toggle')),
      );
      await tester.pumpAndSettle();
      expect(
        tester.element(
          find.byKey(const ValueKey<String>('chunk_scene_surface')),
        ),
        same(sceneElement),
      );
      Future<void> tapCompositionControl(String key) async {
        final control = find.byKey(ValueKey<String>(key));
        await Scrollable.ensureVisible(tester.element(control), alignment: 0.4);
        await tester.pumpAndSettle();
        await tester.tap(control);
        await tester.pumpAndSettle();
      }

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
        'chunk_v2_placement_edit_prefab_rock|95|10|0',
      );
      final noOpPlacementApply = find.byKey(
        const ValueKey<String>('chunk_v2_placement_dialog_apply'),
      );
      await tester.ensureVisible(noOpPlacementApply);
      await tester.tap(noOpPlacementApply);
      await tester.pumpAndSettle();
      expect(_chunk(harness.session, 'forest_chunk').revision, 4);
      expect(
        find.textContaining('Composition change was rejected'),
        findsNothing,
      );

      await tapCompositionControl('chunk_v2_layer_add');
      final routeState = tester.state(find.byType(ChunkCreatorPage));
      final localDraftState = routeState as EditorPageLocalDraftState;
      final shortcutHandler = routeState as EditorPageSessionShortcutHandler;
      final reloadHandler = routeState as EditorPageReloadHandler;
      expect(localDraftState.hasLocalDraftChanges, isTrue);
      expect(reloadHandler.canReloadEditorPage, isFalse);
      expect(shortcutHandler.canHandleUndoSessionShortcut, isFalse);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey<String>('chunk_polygon_apply_source')),
            )
            .onPressed,
        isNull,
      );
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

      await tapCompositionControl('chunk_v2_placement_add');
      await tester.enterText(
        find.byKey(const ValueKey<String>('chunk_v2_placement_x_field')),
        '80',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('chunk_v2_placement_y_field')),
        '10',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('chunk_v2_placement_z_field')),
        '2',
      );
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      final scaleField = find.byKey(
        const ValueKey<String>('chunk_v2_placement_scale_1.0'),
      );
      await tester.ensureVisible(scaleField);
      await tester.tap(scaleField);
      await tester.pumpAndSettle();
      await tester.tap(find.text('×0.6').last);
      final flipYField = find.byKey(
        const ValueKey<String>('chunk_v2_placement_flip_y_field'),
      );
      await Scrollable.ensureVisible(
        tester.element(flipYField),
        alignment: 0.5,
      );
      await tester.pump();
      await tester.tap(flipYField);
      final applyPlacement = find.byKey(
        const ValueKey<String>('chunk_v2_placement_dialog_apply'),
      );
      await tester.pump();
      await tester.tap(applyPlacement);
      await tester.pumpAndSettle();
      edited = _chunk(harness.session, 'forest_chunk');
      expect(edited.revision, 6);
      final addedPlacement = edited.prefabs.singleWhere(
        (placement) => placement.x == 80,
      );
      expect(addedPlacement.prefabKey, 'prefab_rock');
      expect(addedPlacement.zIndex, 2);
      expect(addedPlacement.scale, 0.6);
      expect(addedPlacement.flipY, isTrue);
      final addedPrefabStackEntry = find.byKey(
        const ValueKey<String>('chunk_visual_stack_prefab_prefab_rock|80|10|0'),
      );
      expect(addedPrefabStackEntry, findsOneWidget);
      expect(
        tester.getTopLeft(initialPrefabStackEntry).dx,
        lessThan(tester.getTopLeft(addedPrefabStackEntry).dx),
      );

      await tapCompositionControl('chunk_v2_marker_add');
      await tester.enterText(
        find.byKey(const ValueKey<String>('chunk_v2_marker_x_field')),
        '60',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('chunk_v2_marker_y_field')),
        '5',
      );
      final applyMarker = find.byKey(
        const ValueKey<String>('chunk_v2_marker_dialog_apply'),
      );
      await tester.ensureVisible(applyMarker);
      await tester.tap(applyMarker);
      await tester.pumpAndSettle();
      edited = _chunk(harness.session, 'forest_chunk');
      expect(edited.revision, 7);
      expect(
        edited.markers.any(
          (marker) =>
              marker.markerId == 'derf' && marker.x == 60 && marker.y == 5,
        ),
        isTrue,
      );

      await tapCompositionControl('chunk_v2_layer_edit_background');
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
        'chunk_v2_placement_edit_prefab_rock|80|10|0',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('chunk_v2_placement_x_field')),
        '85',
      );
      final editPlacementApply = find.byKey(
        const ValueKey<String>('chunk_v2_placement_dialog_apply'),
      );
      await tester.ensureVisible(editPlacementApply);
      await tester.tap(editPlacementApply);
      await tester.pumpAndSettle();
      edited = _chunk(harness.session, 'forest_chunk');
      expect(edited.revision, 9);
      expect(edited.prefabs.any((placement) => placement.x == 85), isTrue);

      await tapCompositionControl('chunk_v2_marker_edit_derf|60|5|0');
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

      await tapCompositionControl('chunk_v2_layer_delete_background');
      await tester.tap(
        find.byKey(
          const ValueKey<String>('chunk_v2_composition_delete_confirm'),
        ),
      );
      await tester.pumpAndSettle();
      expect(_chunk(harness.session, 'forest_chunk').tileLayers, isEmpty);

      await tapCompositionControl(
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

      await tapCompositionControl('chunk_v2_marker_delete_derf|60|5|0');
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
      await tester.tap(
        find.byKey(const ValueKey<String>('chunk_polygon_undo_button')),
      );
      await tester.pump();
      expect(
        _chunk(
          harness.session,
          'forest_chunk',
        ).markers.any((marker) => marker.markerId == 'derf'),
        isTrue,
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('chunk_polygon_redo_button')),
      );
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
      await tester.tap(
        find.byKey(const ValueKey<String>('chunk_owners_terrain_card_toggle')),
      );
      await tester.pumpAndSettle();
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
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const ValueKey<String>('chunk_polygon_undo_button')),
          )
          .onPressed,
      isNotNull,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('chunk_polygon_undo_button')),
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey<String>('chunk_polygon_owner_forest_chunk')),
      findsOneWidget,
    );
    expect(_chunk(harness.session, 'forest_chunk').revision, 4);
    expect(harness.session.pendingChanges.hasChanges, isFalse);
  });
}

Future<_Harness> _buildHarness() async {
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
  final plugin = _ChunkPlugin(document);
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
  _ChunkPlugin(this.document);

  final ChunkV2Document document;
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
