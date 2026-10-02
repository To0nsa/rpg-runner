import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runner_core/collision/terrain/terrain_compiler.dart';
import 'package:runner_core/collision/terrain/terrain_geometry.dart';
import 'package:runner_core/collision/terrain/terrain_polygon.dart';
import 'package:runner_core/npcs/npc_catalog.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:runner_editor/src/app/pages/chunkCreator/v2/chunk_pocket_overlay.dart';
import 'package:runner_editor/src/app/pages/shared/terrain_polygon_scene_painter.dart';
import 'package:runner_editor/src/chunks/chunk_pocket_projection.dart';

void main() {
  test('one red gap groups every affected player, enemy and NPC', () {
    final warnings = buildChunkPocketWarnings(_geometry());
    expect(warnings, hasLength(1));
    final actors = warnings.single.actors;
    for (final character in PlayerCharacterRegistry.all) {
      expect(actors, contains('Player: ${character.displayName}'));
    }
    for (final id in NpcCatalog.supportedIds) {
      expect(actors, contains('NPC: ${id.name}'));
    }
    expect(actors, containsAll(['Enemy: grojib', 'Enemy: hashash']));
    expect(
      actors.any((label) => label.contains('unoco') || label.contains('derf')),
      isFalse,
    );
  });

  test('actor lists omit capsules that fit through the same gap', () {
    final warnings = buildChunkPocketWarnings(_geometry(gap: 24));
    expect(warnings, isNotEmpty);
    final actors = warnings.expand((w) => w.actors);
    expect(actors.any((label) => label.startsWith('Player:')), isFalse);
    expect(actors, contains('NPC: warrior'));
  });

  testWidgets(
    'replaces warnings after geometry changes and undo; pauses drafts',
    (tester) async {
      final trapped = _geometry();
      final clear = _geometry(gap: 80);
      await _mount(tester, trapped);
      await _finishCheck(tester);
      expect(_painter(tester).warnings, hasLength(1));
      expect(find.textContaining('NPC: warrior'), findsOneWidget);

      await _mount(tester, trapped, paused: true);
      expect(_painter(tester).warnings, isEmpty);
      expect(find.textContaining('paused'), findsOneWidget);
      await _mount(tester, clear);
      expect(_painter(tester).warnings, isEmpty);
      await _finishCheck(tester);
      expect(
        find.text('No steep-sided fall pockets detected.'),
        findsOneWidget,
      );

      await _mount(tester, trapped);
      await _finishCheck(tester);
      expect(_painter(tester).warnings, hasLength(1));

      await _mount(tester, null);
      expect(_painter(tester).warnings, isEmpty);
      expect(find.textContaining('unavailable'), findsOneWidget);
    },
  );

  testWidgets('obsolete work cannot restore warnings over newer geometry', (
    tester,
  ) async {
    await _mount(tester, _geometry());
    await tester.pump(const Duration(milliseconds: 151));
    await _mount(tester, _geometry(gap: 80));
    await _finishCheck(tester);
    expect(_painter(tester).warnings, isEmpty);
    expect(find.text('No steep-sided fall pockets detected.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  test('red fill follows the pocket under pan and zoom', () async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    ChunkPocketPainter(
      warnings: buildChunkPocketWarnings(_geometry()),
      transform: TerrainPolygonViewportTransform(
        origin: const Offset(20, 10),
        zoom: 2,
      ),
    ).paint(canvas, const Size(320, 240));
    final picture = recorder.endRecording();
    final image = await picture.toImage(320, 240);
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    // World (70, 20) is inside the wedge; world (20, 20) is solid rock.
    final inside = (50 * 320 + 160) * 4;
    expect(bytes.getUint8(inside), greaterThan(bytes.getUint8(inside + 1)));
    expect(bytes.getUint8(inside + 3), greaterThan(0));
    expect(bytes.getUint8((50 * 320 + 60) * 4 + 3), 0);
    image.dispose();
    picture.dispose();
  });
}

Future<void> _mount(
  WidgetTester tester,
  TerrainGeometry? geometry, {
  bool paused = false,
}) => tester.pumpWidget(
  MaterialApp(
    home: SizedBox(
      width: 400,
      height: 300,
      child: ChunkPocketOverlay(
        geometry: geometry,
        paused: paused,
        transform: TerrainPolygonViewportTransform(
          origin: Offset.zero,
          zoom: 1,
        ),
      ),
    ),
  ),
);

Future<void> _finishCheck(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 151));
  for (var attempt = 0; attempt < 200; attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
    if (find.text('Checking pockets…').evaluate().isEmpty) return;
  }
  fail('Pocket worker did not finish.');
}

ChunkPocketPainter _painter(WidgetTester tester) =>
    tester
            .widget<CustomPaint>(
              find.byKey(const ValueKey('chunk_pocket_zones')),
            )
            .painter!
        as ChunkPocketPainter;

TerrainGeometry _geometry({double gap = 0}) => const TerrainCompiler().compile([
  _polygon('left', [(0, 0), (40, 0), (70, 100), (0, 100)]),
  _polygon('right', [
    (100 + gap, 0),
    (140 + gap, 0),
    (140 + gap, 100),
    (70 + gap, 100),
  ]),
], geometryVersion: 1);

TerrainPolygonInput _polygon(String id, List<(double, double)> vertices) =>
    TerrainPolygonInput.fromWorld(
      sourcePath: 'test/$id',
      identity: TerrainSourceIdentity(
        chunkIndex: 0,
        chunkKey: 'test',
        placementKey: id,
        shapeId: id,
      ),
      vertices: vertices,
      collisionMode: TerrainCollisionMode.solid,
    );
