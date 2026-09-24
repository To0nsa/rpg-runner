import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:runner_core/combat/ai_target_policy.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/npcs/npc_id.dart';
import 'package:runner_core/npcs/npc_catalog.dart';
import 'package:runner_core/enemies/enemy_catalog.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_editor/src/build/content_build_process.dart';
import 'package:runner_editor/src/app/pages/chunkCreator/v2/chunk_authoring_workspace.dart';
import 'package:runner_editor/src/app/pages/chunkCreator/v2/chunk_encounter_gesture.dart';
import 'package:runner_editor/src/app/pages/chunkCreator/v2/chunk_encounter_inspector.dart';
import 'package:runner_editor/src/app/pages/chunkCreator/v2/chunk_encounter_projection.dart';
import 'package:runner_editor/src/chunks/chunk_v2_collision_expansion.dart';
import 'package:runner_editor/src/app/pages/chunkCreator/v2/chunk_scene_coordinator.dart';
import 'package:runner_editor/src/app/pages/chunkCreator/v2/chunk_scene_surface.dart';
import 'package:runner_editor/src/chunks/chunk_encounter_edit.dart';
import 'package:runner_editor/src/chunks/chunk_domain_models.dart';
import 'package:runner_editor/src/chunks/chunk_domain_plugin.dart';
import 'package:runner_editor/src/chunks/chunk_v2_file_codec.dart';
import 'package:runner_editor/src/chunks/chunk_v2_file_data.dart';
import 'package:runner_editor/src/chunks/chunk_v2_models.dart';
import 'package:runner_editor/src/domain/authoring_plugin_registry.dart';
import 'package:runner_editor/src/session/editor_session_controller.dart';

import 'test_support/chunk_level_fixture.dart';

ChunkV2FileData example() => ChunkV2FileCodec.decode(
  File('../../docs/examples/rescue_encounter_chunk.json').readAsStringSync(),
).copyWith(levelId: 'forest');

void main() {
  test(
    'all NPC previews use terrain support and runtime anchors in both facings',
    () {
      final original = example();
      final group = original.encounters.single;
      final expansion = expandChunkV2Collision(
        chunk: original,
        prefabs: [],
        sourcePath: 'preview.json',
      ).expansion!;
      for (final id in NpcId.values) {
        for (final facing in Facing.values) {
          final member = editEncounterNpc(
            group.npcs.single,
            npcId: id,
            facing: facing,
          );
          final chunk = original.copyWith(
            encounters: [
              editEncounter(group, npcs: [member]),
            ],
          );
          final actor = projectChunkEncounterActors(
            chunk: chunk,
            expansion: expansion,
            groundTopY: 224,
            workspaceRootPath: Directory('../..').absolute.path,
          ).first;
          expect(actor.diagnostic, isNull);
          expect(actor.bounds.bottom, closeTo(224, .1));
          expect(actor.frame, isNotNull);
          expect(actor.body.dx, member.x);
          final destination = actor.frame!.runtimeDestination(
            bodyPoint: actor.body,
            sceneZoom: 1,
          );
          expect(
            destination.topLeft +
                actor.frame!.anchorPoint * actor.frame!.renderScale,
            actor.body,
          );
        }
      }
    },
  );
  test('member drag keeps identity and support; click, cancel and wrong pointer do not edit', () {
    final chunk = example();
    final group = chunk.encounters.single;
    final selection = ChunkEncounterSelection(
      group.id,
      memberId: group.npcs.single.id,
    );
    ChunkEncounterGesture begin({bool grid = false}) =>
        ChunkEncounterGesture()..begin(
          chunk: chunk,
          selected: selection,
          pointer: 1,
          point: const Offset(256, 197),
          zoom: 1,
          snapToGrid: grid,
          snapToNeighbors: false,
        );
    final moving = begin();
    moving.update(pointer: 1, point: const Offset(280.3, 40), zoom: 1);
    expect(moving.candidate!.npcs.single.x, 280);
    expect(moving.candidate!.npcs.single.id, selection.memberId);
    expect(
      moving.candidate!.npcs.single.placement,
      group.npcs.single.placement,
    );
    expect(chunk.encounters.single.npcs.single.x, 256);
    expect(moving.finish(pointer: 9, point: Offset.zero, zoom: 1), isNull);
    expect(moving.cancel(), isTrue);
    expect(moving.candidate, isNull);
    expect(
      begin(grid: true)
          .finish(pointer: 1, point: const Offset(256, 197), zoom: 1)!
          .commit,
      isNull,
    );
    final result = begin().finish(
      pointer: 1,
      point: const Offset(286, 100),
      zoom: 1,
    )!;
    expect(result.commit!.after.encounters.single.npcs.single.x, 286);
    expect(result.selection, selection);
  });

  test(
    'trigger moves independently and zero-area draw cannot create a command',
    () {
      final chunk = example();
      final group = chunk.encounters.single;
      final gesture = ChunkEncounterGesture()
        ..tool = ChunkEncounterTool.moveTrigger;
      gesture.begin(
        chunk: chunk,
        selected: ChunkEncounterSelection(group.id),
        pointer: 1,
        point: const Offset(80, 30),
        zoom: 1,
        snapToGrid: false,
        snapToNeighbors: false,
      );
      final result = gesture.finish(
        pointer: 1,
        point: const Offset(100, 40),
        zoom: 1,
      )!;
      expect(
        result.commit!.after.encounters.single.trigger.x,
        group.trigger.x + 20,
      );
      expect(
        result.commit!.after.encounters.single.npcs.single.x,
        group.npcs.single.x,
      );
      gesture.tool = ChunkEncounterTool.drawTrigger;
      gesture.begin(
        chunk: chunk,
        selected: ChunkEncounterSelection(group.id),
        pointer: 1,
        point: const Offset(80, 30),
        zoom: 1,
        snapToGrid: false,
        snapToNeighbors: false,
      );
      final invalid = gesture.finish(
        pointer: 1,
        point: const Offset(80, 30),
        zoom: 1,
      )!;
      expect(invalid.commit, isNull);
      expect(invalid.error, isNotNull);
    },
  );

  test(
    'every catalog actor has a legal distinct ID and capacity fails closed',
    () {
      final chunk = example();
      final group = chunk.encounters.single;
      for (final id in EnemyId.values) {
        final gesture = ChunkEncounterGesture()
          ..tool = ChunkEncounterTool.placeEnemy
          ..enemyId = id;
        gesture.begin(
          chunk: chunk,
          selected: ChunkEncounterSelection(group.id),
          pointer: 1,
          point: const Offset(450, 90),
          zoom: 1,
          snapToGrid: false,
          snapToNeighbors: false,
        );
        final result = gesture.finish(
          pointer: 1,
          point: const Offset(450, 90),
          zoom: 1,
        )!;
        expect(result.error, isNull);
        expect(result.commit!.after.encounters.single.enemies.last.enemyId, id);
      }
      final full = chunk.copyWith(
        encounters: [
          editEncounter(
            group,
            npcs: [
              for (var i = 0; i < 4; i++)
                editEncounterNpc(group.npcs.single, id: 'npc_$i'),
            ],
          ),
        ],
      );
      final gesture = ChunkEncounterGesture()
        ..tool = ChunkEncounterTool.placeNpc
        ..npcId = NpcId.huntress2;
      gesture.begin(
        chunk: full,
        selected: ChunkEncounterSelection(group.id),
        pointer: 1,
        point: const Offset(450, 90),
        zoom: 1,
        snapToGrid: false,
        snapToNeighbors: false,
      );
      expect(
        gesture
            .finish(pointer: 1, point: const Offset(450, 90), zoom: 1)!
            .error,
        isNotNull,
      );
    },
  );

  test(
    'stable selection survives deletion and Undo, but clears on owner bind',
    () {
      final chunk = example();
      final group = chunk.encounters.single;
      final selected = ChunkEncounterSelection(
        group.id,
        memberId: group.npcs.single.id,
      );
      final coordinator = ChunkSceneCoordinator()..selectEncounter(selected);
      coordinator.reconcileComposition(chunk.copyWith(encounters: []));
      expect(coordinator.selectedEncounter, selected);
      coordinator.reconcileComposition(chunk);
      expect(coordinator.selectedEncounter, selected);
      coordinator.bindOwner();
      expect(coordinator.selectedEncounter, isNull);
    },
  );

  test('marker conversion transfers exactly one ambient spawn in a guarded command', () {
    final chunk = example().copyWith(
      markers: const [
        PlacedMarkerDef(markerId: 'hashash', x: 420, y: 224, salt: 3),
        PlacedMarkerDef(
          markerId: 'unocoDemon',
          x: 460,
          y: 100,
          chancePercent: 50,
        ),
      ],
    );
    final marker = buildChunkPlacedMarkerSelections(chunk.markers)
        .singleWhere((m) => m.marker.markerId == 'unocoDemon');
    final result = convertChunkMarkerToEncounter(
      chunk: chunk,
      encounterId: chunk.encounters.single.id,
      markerSelectionKey: marker.selectionKey,
    );
    expect(result.commit.expectedRevision, chunk.revision);
    expect(result.commit.before.markers, hasLength(2));
    expect(result.commit.after.markers.single.markerId, 'hashash');
    final converted = result.commit.after.encounters.single.enemies.singleWhere(
      (e) => e.id == result.selection.memberId,
    );
    expect(converted.enemyId, EnemyId.unocoDemon);
    expect(converted.x, 460);
    expect(chunk.encounters.single.enemies, hasLength(1));
    expect(chunk.markers, hasLength(2));
    expect(
      () => convertChunkMarkerToEncounter(
        chunk: chunk,
        encounterId: chunk.encounters.single.id,
        markerSelectionKey: 'missing',
      ),
      throwsArgumentError,
    );
  });

  testWidgets(
    'author a rescue group, guard drafts, duplicate, undo, Save and reload',
    (tester) async {
      tester.view.physicalSize = const Size(1800, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final workspace = (await tester.runAsync(createChunkLevelFixture))!;
      if (Platform.environment['NPC_EDITOR_REVIEW'] == '1') {
        await tester.runAsync(() async {
          final dart = await resolveContentBuildDartExecutable();
          final fonts = p.join(
            File(dart).parent.parent.parent.path,
            'artifacts',
            'material_fonts',
          );
          for (final (family, name) in [
            ('Roboto', 'roboto-regular.ttf'),
            ('MaterialIcons', 'materialicons-regular.otf'),
          ]) {
            await (FontLoader(family)..addFont(
                  File(p.join(fonts, name))
                      .readAsBytes()
                      .then(ByteData.sublistView),
                ))
                .load();
          }
          final sources = [
            for (final id in NpcId.values)
              const NpcCatalog().get(id).renderAnim.sourcesByKey[AnimKey.idle]!,
            for (final id in EnemyId.values)
              const EnemyCatalog()
                  .get(id)
                  .renderAnim
                  .sourcesByKey[AnimKey.idle]!,
          ];
          for (final source in sources) {
            final target = File(workspace.resolve('assets/images/$source'));
            target.parent.createSync(recursive: true);
            File('../../assets/images/$source').copySync(target.path);
          }
        });
      }
      final original = example().copyWith(encounters: []);
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
      await tester.runAsync(session.loadWorkspace);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RepaintBoundary(
              key: const ValueKey('encounter_review'),
              child: ChunkAuthoringWorkspace(
                controller: session,
                playtestPlatformSupported: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      ChunkV2FileData current() =>
          (session.document as ChunkV2Document).chunks.single;
      final state = tester.state<ChunkAuthoringWorkspaceState>(
        find.byType(ChunkAuthoringWorkspace),
      );
      Future<void> tap(String key) async {
        final finder = find.byKey(ValueKey(key));
        await tester.ensureVisible(finder);
        await tester.tap(finder);
        await tester.pumpAndSettle();
      }

      await tester.ensureVisible(find.text('Encounters'));
      await tester.tap(find.text('Encounters'));
      await tester.pumpAndSettle();
      await tap('chunk_encounter_create');
      expect(current().encounters, hasLength(1));
      expect(current().encounters.single.npcs, isEmpty);
      expect(state.playtestReadiness.isReady, isFalse);
      final id = current().encounters.single.id;
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

      await tap('chunk_npc_card_huntress2');
      expect(
        current().encounters.single.npcs,
        isEmpty,
        reason: 'Catalog choice is view state.',
      );
      await tap('chunk_encounter_place_npc');
      await tester.tapAt(point(const Offset(256, 197)));
      await tester.pumpAndSettle();
      expect(current().encounters.single.npcs.single.npcId, NpcId.huntress2);
      final npc = current().encounters.single.npcs.single;
      await tap('chunk_encounter_place_enemy');
      await tester.tapAt(point(const Offset(416, 190)));
      await tester.pumpAndSettle();
      expect(current().encounters.single.enemies, hasLength(1));
      expect(state.playtestReadiness.isReady, isTrue);
      final enemy = current().encounters.single.enemies.single;
      tester
          .widget<DropdownButtonFormField<String>>(
            find.byType(DropdownButtonFormField<String>),
          )
          .onChanged!('playerOnly');
      await tester.pump();
      await tap('chunk_encounter_apply');
      expect(
        current().encounters.single.enemies.single.targetPolicy,
        AiTargetPolicy.playerOnly,
      );
      await tap('chunk_encounter_group_$id');
      await tap('chunk_encounter_default_points');
      final points = find.byKey(const ValueKey('chunk_encounter_points'));
      await tester.ensureVisible(points);
      await tester.enterText(points, '0');
      await tester.pump();
      expect(state.hasLocalDraftChanges, isTrue);
      await tester.ensureVisible(find.text('Terrain'));
      await tester.tap(find.text('Terrain'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('chunk_encounter_unsaved_edit_dialog')),
        findsOneWidget,
      );
      await tap('chunk_encounter_unsaved_edit_cancel');
      expect(tester.widget<TextField>(points).controller!.text, '0');
      expect(await state.finalizeLocalEdits(), isTrue);
      await tester.pumpAndSettle();
      expect(current().encounters.single.pointsPerNpc, 0);
      if (Platform.environment['NPC_EDITOR_REVIEW'] == '1') {
        for (var i = 0; i < 20; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)),
          );
          await tester.pump(const Duration(milliseconds: 50));
        }
        await tester.pumpAndSettle();
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('encounter_review')),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          File('../../.tmp/npc_editor_review.png')
              .writeAsBytesSync(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tap('chunk_encounter_default_points');
      await tap('chunk_encounter_apply');
      expect(current().encounters.single.pointsPerNpc, isNull);
      await tap('chunk_encounter_default_points');
      expect(tester.widget<TextField>(points).controller!.text, '250');
      await tap('chunk_encounter_apply');
      expect(current().encounters.single.pointsPerNpc, 250);
      await tester.ensureVisible(points);
      await tester.enterText(points, '-1');
      await tester.pump();
      expect(await state.finalizeLocalEdits(), isFalse);
      expect(current().encounters.single.pointsPerNpc, 250);
      await tester.enterText(points, '0');
      await tester.pump();
      expect(await state.finalizeLocalEdits(), isTrue);
      await tester.pumpAndSettle();
      await tap('chunk_encounter_member_${id}_${npc.id}');
      await tap('chunk_encounter_duplicate');
      expect(current().encounters.single.npcs, hasLength(2));
      final duplicateId = current().encounters.single.npcs.last.id;
      await tap('chunk_encounter_delete');
      expect(current().encounters.single.npcs, hasLength(1));
      state.handleUndoShortcut();
      await tester.pumpAndSettle();
      expect(current().encounters.single.npcs, hasLength(2));
      expect(
        tester
            .widget<ChunkEncounterInspector>(
              find.byType(ChunkEncounterInspector),
            )
            .member!
            .id,
        duplicateId,
      );
      state.handleRedoShortcut();
      await tester.pumpAndSettle();
      expect(current().encounters.single.npcs, hasLength(1));
      await tester.runAsync(session.exportDirectWrite);
      expect(session.exportError, isNull);
      final saved = ChunkV2FileCodec.decode(file.readAsStringSync());
      expect(saved.encounters.single.pointsPerNpc, 0);
      expect(saved.encounters.single.enemies.single.id, enemy.id);
      expect(
        saved.encounters.single.enemies.single.targetPolicy,
        AiTargetPolicy.playerOnly,
      );
      await tester.runAsync(session.loadWorkspace);
      await tester.pumpAndSettle();
      expect(current().encounters.single.npcs.single.id, npc.id);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
