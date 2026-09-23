import 'dart:io';

import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/traps/trap_catalog.dart';
import 'package:runner_core/traps/trap_geometry.dart';
import 'package:runner_core/traps/trap_id.dart';
import 'package:runner_core/traps/trap_placement.dart';
import 'package:runner_editor/src/app/pages/chunkCreator/v2/chunk_trap_gesture.dart';
import 'package:runner_editor/src/app/pages/chunkCreator/v2/chunk_authoring_workspace.dart';
import 'package:runner_editor/src/app/pages/chunkCreator/v2/chunk_scene_surface.dart';
import 'package:runner_editor/src/app/pages/chunkCreator/v2/chunk_trap_visual_source.dart';
import 'package:runner_editor/src/chunks/chunk_domain_plugin.dart';
import 'package:runner_editor/src/chunks/chunk_v2_composition_operation.dart';
import 'package:runner_editor/src/chunks/chunk_v2_file_codec.dart';
import 'package:runner_editor/src/chunks/chunk_v2_file_data.dart';
import 'package:runner_editor/src/chunks/chunk_v2_models.dart';
import 'package:runner_editor/src/domain/authoring_plugin_registry.dart';
import 'package:runner_editor/src/domain/authoring_types.dart';
import 'package:runner_editor/src/session/editor_session_controller.dart';

import 'test_support/chunk_level_fixture.dart';

ChunkV2FileData example() => ChunkV2FileCodec.decode(
  File('../../docs/examples/water_pool_chunk.json').readAsStringSync(),
).copyWith(levelId: 'forest', waterRegions: [], traps: []);

void main() {
  late ChunkV2FileData chunk;
  late TrapPlacement trap;
  setUp(() {
    trap = TrapPlacement(
      trapId: TrapId.spike,
      x: 300,
      y: 160,
      trigger: TrapCatalog.get(TrapId.spike).defaultTrigger,
    );
    chunk = example().copyWith(traps: [trap]);
  });
  ChunkTrapGesture begin(
    ChunkTrapTool tool,
    Offset point, {
    TrapPlacement? selected,
    bool grid = false,
  }) => ChunkTrapGesture()
    ..tool = tool
    ..begin(
      chunk: chunk,
      pointer: 1,
      point: point,
      selected: selected ?? trap,
      zoom: 1,
      snapToGrid: grid,
      snapToNeighbors: false,
    );

  test(
    'sprite drag moves trigger with it; pointer preview is not a command',
    () {
      final gesture = begin(ChunkTrapTool.select, const Offset(300, 160));
      gesture.update(pointer: 1, point: const Offset(321.4, 149.2), zoom: 1);
      expect(gesture.candidate!.x, 321);
      expect(gesture.candidate!.y, 149);
      expect(gesture.candidate!.trigger, trap.trigger);
      expect(chunk.traps, [trap]);
      expect(gesture.finish(pointer: 2, point: Offset.zero, zoom: 1), isNull);
      final result = gesture.finish(
        pointer: 1,
        point: const Offset(321.4, 149.2),
        zoom: 1,
      )!;
      expect(result.error, isNull);
      expect(result.commit!.after.traps, [result.candidate]);
      expect(gesture.hasActiveOperation, isFalse);
    },
  );
  test('move, corner resize and redraw change only the trigger', () {
    final move = begin(ChunkTrapTool.moveTrigger, const Offset(200, 130));
    final moved = move.finish(
      pointer: 1,
      point: const Offset(210, 150),
      zoom: 1,
    )!;
    expect(moved.candidate.x, trap.x);
    expect(moved.candidate.trigger, TrapRect(-150, -24, 210, 64));
    final resize = begin(
      ChunkTrapTool.select,
      trapTriggerBounds(trap).bottomRight,
    );
    final resized = resize.finish(
      pointer: 1,
      point: trapTriggerBounds(trap).bottomRight + const Offset(30, 10),
      zoom: 1,
    )!;
    expect(resized.candidate.trigger, TrapRect(-160, -44, 240, 74));
    expect(resized.commit, isNotNull);
    final draw = begin(ChunkTrapTool.drawTrigger, const Offset(100, 90));
    final drawn = draw.finish(
      pointer: 1,
      point: const Offset(220, 150),
      zoom: 1,
    )!;
    expect(drawn.candidate.trigger, TrapRect(-200, -70, 120, 60));
    expect(drawn.candidate.x, trap.x);
  });
  test('grid, click no-op, cancellation and invalid drafts are bounded', () {
    final click = begin(
      ChunkTrapTool.select,
      const Offset(300, 160),
      grid: true,
    );
    expect(
      click.finish(pointer: 1, point: const Offset(300, 160), zoom: 1)!.commit,
      isNull,
    );
    final move = begin(
      ChunkTrapTool.select,
      const Offset(300, 160),
      grid: true,
    );
    move.update(pointer: 1, point: const Offset(321, 160), zoom: 1);
    expect(move.candidate!.x, 316);
    expect(move.cancel(), isTrue);
    expect(move.candidate, isNull);
    final draw = begin(ChunkTrapTool.drawTrigger, const Offset(100, 90));
    final invalid = draw.finish(
      pointer: 1,
      point: const Offset(100, 90),
      zoom: 1,
    )!;
    expect(invalid.error, isNotNull);
    expect(invalid.commit, isNull);
    final add = begin(ChunkTrapTool.place, const Offset(10, 10));
    expect(add.error, isNotNull);
    expect(
      add.finish(pointer: 1, point: const Offset(10, 10), zoom: 1)!.commit,
      isNull,
    );
  });
  test(
    'every catalog entry places explicit defaults; facing keeps trigger',
    () {
      chunk = chunk.copyWith(traps: []);
      for (final id in TrapId.values) {
        final gesture = ChunkTrapGesture()
          ..tool = ChunkTrapTool.place
          ..catalogId = id;
        expect(
          gesture.begin(
            chunk: chunk,
            pointer: 1,
            point: const Offset(350, 100),
            selected: null,
            zoom: 1,
            snapToGrid: false,
            snapToNeighbors: false,
          ),
          isTrue,
        );
        final result = gesture.finish(
          pointer: 1,
          point: const Offset(350, 100),
          zoom: 1,
        )!;
        expect(result.error, isNull, reason: id.name);
        expect(result.commit, isNotNull);
        expect(result.candidate.trigger, TrapCatalog.get(id).defaultTrigger);
        if (id != TrapId.spike) {
          final facing = result.candidate.copyWith(facing: Facing.left);
          expect(validateChunkTrapCandidate(chunk, facing), isNull);
          expect(
            trapTriggerBounds(facing),
            trapTriggerBounds(result.candidate),
          );
        }
      }
    },
  );
  test(
    'revision guard, Undo/Redo and Save/reload use the chunk transaction',
    () async {
      final workspace = await createChunkLevelFixture();
      final original = example();
      final file = File(
        workspace.resolve(
          'assets/authoring/level/chunks/forest/${original.chunkKey}.json',
        ),
      );
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(ChunkV2FileCodec.encode(original));
      final session = EditorSessionController(
        pluginRegistry: AuthoringPluginRegistry(plugins: [ChunkDomainPlugin()]),
        initialPluginId: ChunkDomainPlugin.pluginId,
        initialWorkspacePath: workspace.rootPath,
      );
      addTearDown(session.dispose);
      await session.loadWorkspace();
      ChunkV2FileData current() =>
          (session.document as ChunkV2Document).chunks.single;
      final commit = ChunkV2CompositionOperation.add(
        chunk: current(),
        target: ChunkV2CompositionTarget.traps,
      ).buildTrap(candidate: trap)!;
      final command = AuthoringCommand(
        kind: ChunkDomainPlugin.commitChunkCompositionCommandKind,
        payload: {'chunkKey': original.chunkKey, 'commit': commit},
      );
      session.applyCommand(command);
      expect(current().traps, [trap]);
      expect(current().revision, original.revision + 1);
      session.applyCommand(command);
      expect(current().revision, original.revision + 1);
      session.undo();
      expect(current().traps, isEmpty);
      session.redo();
      expect(current().traps, [trap]);
      await session.exportDirectWrite();
      expect(session.exportError, isNull);
      expect(ChunkV2FileCodec.decode(file.readAsStringSync()).traps, [trap]);
      await session.loadWorkspace();
      expect(current().traps, [trap]);
    },
  );

  testWidgets(
    'Traps tab places, selects, previews and edits through the scene',
    (tester) async {
      tester.view.physicalSize = const Size(1800, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final workspace = await tester.runAsync(createChunkLevelFixture);
      final original = example();
      final file = File(
        workspace!.resolve(
          'assets/authoring/level/chunks/forest/${original.chunkKey}.json',
        ),
      );
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(ChunkV2FileCodec.encode(original));
      final session = EditorSessionController(
        pluginRegistry: AuthoringPluginRegistry(plugins: [ChunkDomainPlugin()]),
        initialPluginId: ChunkDomainPlugin.pluginId,
        initialWorkspacePath: workspace.rootPath,
      );
      addTearDown(session.dispose);
      await tester.runAsync(session.loadWorkspace);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ChunkAuthoringWorkspace(controller: session)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Traps'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Spike'));
      await tester.tap(find.text('Spike'));
      await tester.pump();
      final surfaceFinder = find.byKey(const ValueKey('chunk_scene_surface'));
      Offset point(Offset world) {
        final surface = tester.widget<ChunkSceneSurface>(
          find.ancestor(
            of: surfaceFinder,
            matching: find.byType(ChunkSceneSurface),
          ),
        );
        return tester.getTopLeft(surfaceFinder) +
            surface.transform.origin +
            world * surface.transform.zoom;
      }

      await tester.tapAt(point(const Offset(300, 160)));
      await tester.pumpAndSettle();
      ChunkV2FileData current() =>
          (session.document as ChunkV2Document).chunks.single;
      expect(current().traps, hasLength(1));
      final saved = current().traps.single;
      final slider = find.byKey(const ValueKey('chunk_trap_frame'));
      await tester.ensureVisible(slider);
      tester.widget<Slider>(slider).onChanged!(9);
      await tester.pump();
      final overlay = tester.widget<ChunkTrapVisualSource>(
        find.byKey(const ValueKey('chunk_traps_overlay')),
      );
      expect(overlay.previewFrame, 9);
      expect(overlay.selected, saved);
      await tester.tap(find.text('Terrain'));
      await tester.pump();
      await tester.tap(find.text('Traps'));
      await tester.pump();
      final move = find.byKey(const ValueKey('chunk_trap_tool_moveTrigger'));
      await tester.ensureVisible(move);
      await tester.tap(move);
      await tester.pump();
      final gesture = await tester.startGesture(point(const Offset(200, 140)));
      await gesture.moveTo(point(const Offset(220, 140)));
      await tester.pump();
      expect(
        current().traps.single,
        saved,
        reason: 'Preview stays local until release.',
      );
      await gesture.up();
      await tester.pumpAndSettle();
      expect(current().traps.single.x, saved.x);
      expect(
        current().traps.single.trigger.offsetX,
        saved.trigger.offsetX + 20,
      );
      session.undo();
      await tester.pumpAndSettle();
      expect(current().traps.single, saved);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
