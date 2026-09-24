import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runner_core/traps/trap_catalog.dart';
import 'package:runner_core/traps/trap_id.dart';
import 'package:runner_core/traps/trap_placement.dart';
import 'package:runner_editor/src/app/pages/chunkCreator/v2/chunk_scene_placement_layers.dart';
import 'package:runner_editor/src/app/pages/chunkCreator/v2/chunk_scene_visual_source.dart';
import 'package:runner_editor/src/app/pages/chunkCreator/v2/chunk_trap_gesture.dart';
import 'package:runner_editor/src/app/pages/chunkCreator/v2/chunk_trap_visual_source.dart';
import 'package:runner_editor/src/app/pages/shared/editor_scene_view_utils.dart';
import 'package:runner_editor/src/app/pages/shared/terrain_polygon_scene_painter.dart';
import 'package:runner_editor/src/chunks/chunk_domain_models.dart';

void main() {
  final trap = TrapPlacement(
    trapId: TrapId.spike,
    x: 300,
    y: 160,
    trigger: TrapCatalog.get(TrapId.spike).defaultTrigger,
  );

  test('selecting overlapping traps follows depth before source order', () {
    final front = trap.copyWith(zIndex: 5);
    final back = trap.copyWith(x: 301, zIndex: -21);
    expect(hitTestChunkTrap([front, back], const Offset(300, 160)), front);
    expect(hitTestChunkTrap([back, front], const Offset(300, 160)), front);
  });

  testWidgets('preview frames retain interleaved prefab and trap depth', (
    tester,
  ) async {
    final images = EditorUiImageCache();
    final workspace = Directory('../..').absolute.path;
    await tester.runAsync(
      () => images.ensureLoaded(
        '$workspace/assets/images/${TrapCatalog.get(TrapId.spike).assetPath}',
      ),
    );
    final prefabs = [
      for (final z in [-22, -21, -20])
        ChunkScenePlacedVisual(
          selectionKey: '$z',
          sourceIndex: z + 22,
          placement: PlacedPrefabDef(
            prefabId: 'fixture',
            x: 300,
            y: 160,
            zIndex: z,
          ),
          visualSource: null,
          worldBounds: const Rect.fromLTWH(280, 140, 40, 40),
        ),
    ];
    for (final z in [-21, 4]) {
      final selected = trap.copyWith(zIndex: z);
      for (final frame in [
        -1,
        0,
        TrapCatalog.get(TrapId.spike).firstHarmfulFrame,
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            home: ChunkScenePlacementLayers(
              workspaceRootPath: workspace,
              images: images,
              prefabs: prefabs,
              traps: [selected],
              selectedTrap: selected,
              previewFrame: frame,
              transform: TerrainPolygonViewportTransform(
                origin: Offset.zero,
                zoom: 1,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final stack = tester.widget<Stack>(
          find
              .descendant(
                of: find.byType(ChunkScenePlacementLayers),
                matching: find.byType(Stack),
              )
              .first,
        );
        expect(stack.children.map((c) => c.key), [
          const ValueKey(('prefabs', -22)),
          const ValueKey(('prefabs', -21)),
          if (z == -21) const ValueKey(('traps', -21)),
          const ValueKey(('prefabs', -20)),
          if (z == 4) const ValueKey(('traps', 4)),
        ], reason: 'frame $frame must not change depth');
        final visual = tester.widget<ChunkTrapVisualSource>(
          find.byType(ChunkTrapVisualSource),
        );
        expect(visual.traps.single.zIndex, z);
        expect(visual.previewFrame, frame);
        expect(visual.pass, ChunkTrapVisualPass.sprites);
      }
    }
    await tester.pumpWidget(const SizedBox());
    expect(
      images.loadedImageCount,
      1,
      reason: 'Depth partitions borrow the cache.',
    );
    images.dispose();
  });
}
