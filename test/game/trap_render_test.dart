import 'dart:ui' as ui;

import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/snapshots/trap_snapshot.dart';
import 'package:runner_core/traps/trap_catalog.dart';
import 'package:runner_core/traps/trap_id.dart';
import 'package:runner_core/traps/trap_placement.dart';
import 'package:rpg_runner/game/debug/trap_hitbox_overlay.dart';
import 'package:rpg_runner/game/debug/render_debug_flags.dart';
import 'package:rpg_runner/game/components/traps/trap_render_registry.dart';
import 'package:rpg_runner/game/components/traps/trap_render_system.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'all real trap sheet rectangles load at their authored dimensions',
    () async {
      final images = Images();
      final registry = TrapRenderRegistry();
      await registry.load(images);
      for (final id in TrapId.values) {
        final def = TrapCatalog.get(id);
        for (var i = 0; i < def.frames.length; i++) {
          final frame = registry.frame(id, i);
          expect(frame.srcPosition.x, def.frames[i].source.x);
          expect(frame.srcPosition.y, def.frames[i].source.y);
          expect(frame.srcSize.x, def.frames[i].source.width);
          expect(frame.srcSize.y, def.frames[i].source.height);
        }
      }
      images.clearCache();
    },
  );

  testWidgets(
    'launcher emergence and lowering retain every source pixel and anchor',
    (tester) async {
      final game = FlameGame();
      final images = Images();
      final registry = TrapRenderRegistry();
      await tester.runAsync(() => registry.load(images));
      final views = TrapRenderSystem(world: game.world, registry: registry);
      await tester.pumpWidget(GameWidget(game: game));
      await tester.runAsync(() => game.loaded);
      const source = TrapSourceRef(
        trapId: TrapId.poisonDarts,
        chunkKey: 'fixture',
        chunkIndex: 0,
        placementOrdinal: 0,
      );
      final sheet = registry.frame(TrapId.poisonDarts, 0).image;
      for (final facing in Facing.values) {
        for (final (frame, row, column) in [
          (0, 0, 0),
          (1, 0, 1),
          (2, 0, 2),
          for (var col = 0; col < 6; col++) (8 + col, 4, col),
        ]) {
          views.sync([
            TrapSnapshot(
              source: source,
              x: 100,
              y: 80,
              facing: facing,
              phase: frame < 3 ? TrapPhase.warning : TrapPhase.active,
              frameIndex: frame,
              zIndex: -21,
            ),
          ], cameraCenter: Vector2.zero());
          await tester.pump();
          game.update(0);
          final view = game.world.children.whereType<SpriteComponent>().single;
          expect(view.priority, -26);
          final actualRecorder = ui.PictureRecorder();
          view.renderTree(ui.Canvas(actualRecorder));
          final expectedRecorder = ui.PictureRecorder();
          final canvas = ui.Canvas(expectedRecorder)
            ..translate(100, 80)
            ..scale(facing == Facing.left ? -1 : 1, 1);
          // Compare with the full 128px cell, independently of catalog cropping.
          // The sheet-space pivot stays (64,72) throughout vertical movement.
          canvas.drawImageRect(
            sheet,
            Rect.fromLTWH(column * 128.0, row * 128.0, 128, 128),
            const Rect.fromLTWH(-64, -72, 128, 128),
            Paint()..filterQuality = FilterQuality.none,
          );
          final actualPicture = actualRecorder.endRecording();
          final expectedPicture = expectedRecorder.endRecording();
          await tester.runAsync(() async {
            final actual = await actualPicture.toImage(200, 160);
            final expected = await expectedPicture.toImage(200, 160);
            expect(
              (await actual.toByteData())!.buffer.asUint8List(),
              (await expected.toByteData())!.buffer.asUint8List(),
              reason: 'frame $frame facing $facing must not clip or shift',
            );
            actual.dispose();
            expected.dispose();
          });
          actualPicture.dispose();
          expectedPicture.dispose();
        }
      }
      await tester.pumpWidget(const SizedBox.shrink());
      images.clearCache();
    },
  );

  testWidgets(
    'trap animation never draws gameplay zones; exact hitboxes require debug',
    (tester) async {
      final game = FlameGame(
        camera: CameraComponent.withFixedResolution(width: 600, height: 270),
      );
      final images = Images();
      final registry = TrapRenderRegistry();
      await tester.runAsync(() => registry.load(images));
      final views = TrapRenderSystem(world: game.world, registry: registry);
      final hitboxes = TrapHitboxOverlay();
      final previousDebug = RenderDebugFlags.drawActorHitboxes;
      RenderDebugFlags.drawActorHitboxes = false;
      addTearDown(() => RenderDebugFlags.drawActorHitboxes = previousDebug);
      await tester.pumpWidget(GameWidget(game: game));
      await tester.runAsync(() => game.loaded);
      game.onGameResize(Vector2(600, 270));
      game.camera.viewfinder.position = Vector2(300, 135);
      game.world.add(
        RectangleComponent(
          position: Vector2.zero(),
          size: Vector2(600, 270),
          paint: Paint()..color = const Color(0xFF00FF00),
          priority: 1000000,
        ),
      );
      game.camera.viewfinder.add(hitboxes);
      game.camera.viewport.add(
        RectangleComponent(
          position: Vector2(173, 109),
          size: Vector2(3, 3),
          paint: Paint()..color = const Color(0xFF0000FF),
        ),
      );
      const source = TrapSourceRef(
        trapId: TrapId.spike,
        chunkKey: 'fixture',
        chunkIndex: 0,
        placementOrdinal: 0,
      );
      for (final (zIndex, phase) in [
        for (final z in [-21, -1, 3])
          for (final phase in TrapPhase.values) (z, phase),
      ]) {
        final frame = phase == TrapPhase.active ? 8 : 0;
        final traps = [
          TrapSnapshot(
            source: source,
            x: 200,
            y: 128,
            facing: Facing.right,
            phase: phase,
            frameIndex: frame,
            zIndex: zIndex,
          ),
        ];
        views.sync(traps, cameraCenter: Vector2(300, 135));
        hitboxes.traps = traps;
        hitboxes.cameraCenter.setValues(300, 135);
        await tester.pump();
        game.update(0);
        final view = game.world.children.whereType<SpriteComponent>().single;
        expect(view.priority, -5 + zIndex, reason: '$phase must retain depth');
        expect(view.sprite, same(registry.frame(TrapId.spike, frame)));
        final recorder = ui.PictureRecorder();
        game.camera.renderTree(ui.Canvas(recorder));
        final picture = recorder.endRecording();
        await tester.runAsync(() async {
          final image = await picture.toImage(600, 270);
          final pixels = (await image.toByteData())!;
          List<int> at(int x, int y) => [
            for (var c = 0; c < 4; c++) pixels.getUint8((y * 600 + x) * 4 + c),
          ];
          // Former border, filled zone, exclamation and damage-pose positions.
          for (final (x, y) in [(174, 105), (195, 110), (200, 92), (200, 94)]) {
            expect(at(x, y), [0, 255, 0, 255], reason: phase.name);
          }
          expect(at(174, 110), [0, 0, 255, 255]);
          image.dispose();
        });
        picture.dispose();
      }
      hitboxes.traps = [
        const TrapSnapshot(
          source: source,
          x: 200,
          y: 128,
          facing: Facing.right,
          phase: TrapPhase.active,
          frameIndex: 8,
          zIndex: -21,
        ),
      ];
      for (final enabled in [true, false]) {
        RenderDebugFlags.drawActorHitboxes = enabled;
        final recorder = ui.PictureRecorder();
        game.camera.renderTree(ui.Canvas(recorder));
        final picture = recorder.endRecording();
        await tester.runAsync(() async {
          final image = await picture.toImage(600, 270);
          final pixels = (await image.toByteData())!;
          // Active spike capsule remains available solely for hitbox debugging.
          final red = pixels.getUint8((94 * 600 + 200) * 4);
          expect(red, enabled ? greaterThan(0) : equals(0));
          // The removed warning border must stay absent even in debug mode.
          expect(pixels.getUint8((105 * 600 + 174) * 4), 0);
          image.dispose();
        });
        picture.dispose();
      }
      views.sync(const [], cameraCenter: Vector2.zero());
      await tester.pump();
      game.update(0);
      expect(game.world.children.whereType<SpriteComponent>(), isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
      images.clearCache();
    },
  );
}
