import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runner_editor/src/app/pages/chunkCreator/chunk_creator_page.dart';
import 'package:runner_editor/src/app/pages/chunkCreator/staging/chunk_actor_terrain_overlay_painter.dart';
import 'package:runner_editor/src/app/pages/chunkCreator/staging/chunk_compiled_edge_overlay_painter.dart';
import 'package:runner_editor/src/app/pages/chunkCreator/staging/chunk_marker_placement_overlay_painter.dart';
import 'package:runner_editor/src/app/pages/shared/editor_page_local_draft_state.dart';
import 'package:runner_editor/src/chunks/chunk_domain_models.dart';
import 'package:runner_editor/src/chunks/chunk_domain_plugin.dart';
import 'package:runner_editor/src/chunks/chunk_v2_file_codec.dart';
import 'package:runner_editor/src/chunks/chunk_v2_file_data.dart';
import 'package:runner_editor/src/chunks/chunk_v2_staging_models.dart';
import 'package:runner_editor/src/levels/level_domain_models.dart';
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
        find.byKey(const ValueKey<String>('chunk_polygon_staging_workspace')),
        findsOneWidget,
      );
      expect(harness.plugin.loadCount, 1);
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
      final seamInspector = find.byKey(
        const ValueKey<String>('chunk_seam_inspector'),
      );
      final diagnosticsList = find.byKey(
        const ValueKey<String>('chunk_shape_diagnostics_list'),
      );
      await tester.ensureVisible(seamInspector);
      expect(seamInspector, findsOneWidget);
      expect(
        find.textContaining('right → forest_chunk · compatible'),
        findsOneWidget,
      );
      expect(find.textContaining('steady-hard:tier=hard>hard'), findsOneWidget);
      await tester.drag(diagnosticsList, const Offset(0, 2000));
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
      await tester.drag(diagnosticsList, const Offset(0, -700));
      await tester.pump();
      await tester.drag(diagnosticsList, const Offset(0, -300));
      await tester.pump();
      await tester.drag(diagnosticsList, const Offset(0, -500));
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
        find.textContaining('Projectile terrain support remains later-phase'),
        findsOneWidget,
      );
      await tester.drag(diagnosticsList, const Offset(0, 2000));
      await tester.pump();
      expect(_chunk(harness.session, 'forest_chunk').revision, 4);
      expect(harness.session.pendingChanges.hasChanges, isFalse);
      await tester.tap(
        find.byKey(
          const ValueKey<String>('chunk_compiled_edge_inspect_toggle'),
        ),
      );
      await tester.pump();
      final lockedApply = tester.widget<FilledButton>(
        find.byKey(const ValueKey<String>('chunk_polygon_apply_locked')),
      );
      expect(lockedApply.onPressed, isNull);

      await tester.tap(
        find.byKey(const ValueKey<String>('chunk_polygon_shape_ground_001')),
      );
      await tester.pump();
      final deleteShape = find.byKey(
        const ValueKey<String>('chunk_polygon_delete_shape'),
      );
      await tester.ensureVisible(deleteShape);
      await tester.tap(deleteShape);
      await tester.pump();

      var forestChunk = _chunk(harness.session, 'forest_chunk');
      expect(forestChunk.revision, 5);
      expect(forestChunk.collisionShapes, isEmpty);
      expect(harness.session.pendingChanges.changedItemIds, <String>[
        'forest_chunk',
      ]);

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
      expect(reloadHandler.canReloadEditorPage, isFalse);

      await tester.drag(diagnosticsList, const Offset(0, 2000));
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey<String>('chunk_polygon_shape_ground_001')),
      );
      await tester.pump();
      final firstVertex = find.byKey(
        const ValueKey<String>('chunk_polygon_vertex_ground_001_0'),
      );
      await tester.ensureVisible(firstVertex);
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
      await tester.dragUntilVisible(
        outOfBoundsIssue,
        diagnosticsList,
        const Offset(0, -500),
      );
      expect(outOfBoundsIssue, findsOneWidget);

      await tester.drag(diagnosticsList, const Offset(0, 5000));
      await tester.pump();
      final editMetadata = find.byKey(
        const ValueKey<String>('chunk_polygon_edit_metadata'),
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
      await tester.enterText(
        find.byKey(
          const ValueKey<String>('chunk_polygon_metadata_surface_field'),
        ),
        ' moss ',
      );
      await tester.enterText(
        find.byKey(
          const ValueKey<String>('chunk_polygon_metadata_material_field'),
        ),
        ' ground_01 ',
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('chunk_polygon_metadata_apply')),
      );
      await tester.pumpAndSettle();

      forestChunk = _chunk(harness.session, 'forest_chunk');
      final editedShape = forestChunk.collisionShapes.single;
      expect(forestChunk.revision, 5);
      expect(editedShape.collisionMode, TerrainSourceCollisionMode.oneWay);
      expect(editedShape.surfaceKind, 'moss');
      expect(editedShape.materialKey, 'ground_01');
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
      await tester.drag(find.byType(ListView).last, const Offset(0, 1000));
      await tester.pump();
      final duplicateShape = find.byKey(
        const ValueKey<String>('chunk_polygon_duplicate_shape'),
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
        (harness.session.document! as ChunkV2StagingDocument).activeLevelId,
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

    final diagnosticsList = find.byKey(
      const ValueKey<String>('chunk_shape_diagnostics_list'),
    );
    final openOwner = find.byKey(
      const ValueKey<String>(
        'chunk_open_prefab_prefab_rock|95|10|0_collision_001',
      ),
    );
    await tester.scrollUntilVisible(
      openOwner,
      400,
      scrollable: find.descendant(
        of: diagnosticsList,
        matching: find.byType(Scrollable),
      ),
    );
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
        (harness.session.document! as ChunkV2StagingDocument).chunks.where(
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
      await tester.tap(
        find.byKey(const ValueKey<String>('chunk_v2_view_composition')),
      );
      await tester.pump();
      expect(
        find.byKey(const ValueKey<String>('chunk_v2_composition_workspace')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('chunk_v2_layer_add')),
      );
      await tester.pumpAndSettle();
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

      await tester.tap(
        find.byKey(const ValueKey<String>('chunk_v2_placement_add')),
      );
      await tester.pumpAndSettle();
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

      await tester.tap(
        find.byKey(const ValueKey<String>('chunk_v2_marker_add')),
      );
      await tester.pumpAndSettle();
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

      await tester.tap(
        find.byKey(const ValueKey<String>('chunk_v2_layer_edit_background')),
      );
      await tester.pumpAndSettle();
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

      await tester.tap(
        find.byKey(
          const ValueKey<String>('chunk_v2_placement_edit_prefab_rock|80|10|0'),
        ),
      );
      await tester.pumpAndSettle();
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

      await tester.tap(
        find.byKey(const ValueKey<String>('chunk_v2_marker_edit_derf|60|5|0')),
      );
      await tester.pumpAndSettle();
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

      await tester.tap(
        find.byKey(const ValueKey<String>('chunk_v2_layer_delete_background')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          const ValueKey<String>('chunk_v2_composition_delete_confirm'),
        ),
      );
      await tester.pumpAndSettle();
      expect(_chunk(harness.session, 'forest_chunk').tileLayers, isEmpty);

      await tester.tap(
        find.byKey(
          const ValueKey<String>(
            'chunk_v2_placement_delete_prefab_rock|85|10|0',
          ),
        ),
      );
      await tester.pumpAndSettle();
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

      await tester.tap(
        find.byKey(
          const ValueKey<String>('chunk_v2_marker_delete_derf|60|5|0'),
        ),
      );
      await tester.pumpAndSettle();
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
  final document = ChunkV2StagingDocument(
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
    availableLevelIds: const <String>['forest', 'meadow'],
    activeLevelId: 'forest',
  );
  final plugin = _StagingChunkPlugin(document);
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
  final document = session.document! as ChunkV2StagingDocument;
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
  final _StagingChunkPlugin plugin;

  void dispose() {
    session.dispose();
    if (root.existsSync()) root.deleteSync(recursive: true);
  }
}

final class _StagingChunkPlugin implements AuthoringDomainPlugin {
  _StagingChunkPlugin(this.document);

  final ChunkV2StagingDocument document;
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
