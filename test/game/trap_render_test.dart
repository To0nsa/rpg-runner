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
import 'package:rpg_runner/game/components/traps/trap_cue_overlay.dart';
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
        }
      }
      images.clearCache();
    },
  );

  testWidgets(
    'camera overlay clears arbitrary world z-index and remains below HUD',
    (tester) async {
      final game = FlameGame(
        camera: CameraComponent.withFixedResolution(width: 600, height: 270),
      );
      final images = Images();
      final registry = TrapRenderRegistry();
      await tester.runAsync(() => registry.load(images));
      final views = TrapRenderSystem(world: game.world, registry: registry);
      final cues = TrapCueOverlay();
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
      game.camera.viewfinder.add(cues);
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
      for (final phase in [
        TrapPhase.idle,
        TrapPhase.warning,
        TrapPhase.active,
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
          ),
        ];
        views.sync(traps, cameraCenter: Vector2(300, 135));
        cues.traps = traps;
        cues.cameraCenter.setValues(300, 135);
        await tester.pump();
        game.update(0);
        final view = game.world.children.whereType<SpriteComponent>().single;
        expect(view.priority, phase == TrapPhase.idle ? -6 : -4);
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
          expect(at(174, 105), switch (phase) {
            TrapPhase.warning => [255, 212, 71, 255],
            TrapPhase.active => [255, 81, 72, 255],
            _ => [0, 255, 0, 255],
          });
          expect(at(174, 110), [0, 0, 255, 255]);
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
