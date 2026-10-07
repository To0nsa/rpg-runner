import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/game/components/static_prefab_sprite_component.dart';

void main() {
  testWidgets('static decoration renders about its center after reflections', (
    tester,
  ) async {
    final sourceRecorder = ui.PictureRecorder();
    final sourceCanvas = ui.Canvas(sourceRecorder);
    sourceCanvas.drawRect(
      const Rect.fromLTWH(0, 0, 2, 2),
      Paint()..color = const Color(0xFFFF0000),
    );
    sourceCanvas.drawRect(
      const Rect.fromLTWH(2, 0, 2, 2),
      Paint()..color = const Color(0xFF0000FF),
    );
    final sourcePicture = sourceRecorder.endRecording();
    final sheet = (await tester.runAsync(() => sourcePicture.toImage(4, 2)))!;
    sourcePicture.dispose();
    final game = FlameGame();
    game.images.add('rotation_test.png', sheet);
    await tester.pumpWidget(GameWidget(game: game));
    await tester.runAsync(() => game.loaded);
    for (final angle in [0.0, 90.0, 37.5]) {
      for (final flipX in [false, true]) {
        for (final flipY in [false, true]) {
          final view = StaticPrefabSpriteComponent(
            assetPath: 'rotation_test.png',
            srcRect: const Rect.fromLTWH(0, 0, 4, 2),
            position: Vector2(30, 40),
            size: Vector2(40, 20),
            flipX: flipX,
            flipY: flipY,
            rotationDegrees: angle,
          );
          game.world.add(view);
          await tester.pump();
          await tester.runAsync(() => view.loaded);
          game.update(0);
          final actualRecorder = ui.PictureRecorder();
          view.renderTree(ui.Canvas(actualRecorder));
          final expectedRecorder = ui.PictureRecorder();
          final canvas = ui.Canvas(expectedRecorder)
            ..translate(50, 50)
            ..rotate(angle * math.pi / 180)
            ..scale(flipX ? -1 : 1, flipY ? -1 : 1);
          canvas.drawImageRect(
            sheet,
            const Rect.fromLTWH(0, 0, 4, 2),
            const Rect.fromLTWH(-20, -10, 40, 20),
            Paint()..filterQuality = ui.FilterQuality.none,
          );
          final actualPicture = actualRecorder.endRecording();
          final expectedPicture = expectedRecorder.endRecording();
          await tester.runAsync(() async {
            final actual = await actualPicture.toImage(100, 100);
            final expected = await expectedPicture.toImage(100, 100);
            expect(
              (await actual.toByteData())!.buffer.asUint8List(),
              (await expected.toByteData())!.buffer.asUint8List(),
              reason: 'angle=$angle flipX=$flipX flipY=$flipY',
            );
            actual.dispose();
            expected.dispose();
          });
          actualPicture.dispose();
          expectedPicture.dispose();
          view.removeFromParent();
          await tester.pump();
        }
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
    game.images.clearCache();
  });
}
