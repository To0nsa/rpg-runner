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
    for (final isDecoration in [false, true]) {
      for (final angle in isDecoration ? [0.0] : [0.0, 90.0, 37.5]) {
        for (final flipX in isDecoration ? [false] : [false, true]) {
          for (final flipY in isDecoration ? [false] : [false, true]) {
            final view = StaticPrefabSpriteComponent(
              assetPath: 'rotation_test.png',
              srcRect: const Rect.fromLTWH(0, 0, 4, 2),
              position: Vector2(30, 40),
              size: Vector2(40, 20),
              flipX: flipX,
              flipY: flipY,
              rotationDegrees: angle,
              isDecoration: isDecoration,
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
            final expectedPaint = Paint()
              ..filterQuality = ui.FilterQuality.none;
            if (isDecoration) {
              expectedPaint.colorFilter = const ColorFilter.matrix(<double>[
                0.7,
                0,
                0,
                0,
                76.5,
                0,
                0.7,
                0,
                0,
                76.5,
                0,
                0,
                0.7,
                0,
                76.5,
                0,
                0,
                0,
                1,
                0,
              ]);
            }
            canvas.drawImageRect(
              sheet,
              const Rect.fromLTWH(0, 0, 4, 2),
              const Rect.fromLTWH(-20, -10, 40, 20),
              expectedPaint,
            );
            final actualPicture = actualRecorder.endRecording();
            final expectedPicture = expectedRecorder.endRecording();
            await tester.runAsync(() async {
              final actual = await actualPicture.toImage(100, 100);
              final expected = await expectedPicture.toImage(100, 100);
              final actualPixels = (await actual.toByteData())!.buffer
                  .asUint8List();
              expect(
                actualPixels,
                (await expected.toByteData())!.buffer.asUint8List(),
                reason:
                    'angle=$angle flipX=$flipX flipY=$flipY decoration=$isDecoration',
              );
              if (isDecoration) {
                expect(
                  actualPixels.sublist(
                    (45 * 100 + 40) * 4,
                    (45 * 100 + 40) * 4 + 4,
                  ),
                  [255, closeTo(76.5, 0.5), closeTo(76.5, 0.5), 255],
                );
                expect(
                  actualPixels.sublist(
                    (45 * 100 + 60) * 4,
                    (45 * 100 + 60) * 4 + 4,
                  ),
                  [closeTo(76.5, 0.5), closeTo(76.5, 0.5), 255, 255],
                );
                expect(actualPixels.sublist(0, 4), [0, 0, 0, 0]);
              }
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
    }
    await tester.pumpWidget(const SizedBox.shrink());
    game.images.clearCache();
  });
}
