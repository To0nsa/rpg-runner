import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/game/components/sprite_anim/ghost_outline_cache.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'cached outline matches offset draws for scaled and mirrored sprites',
    () async {
      final source = await _sourceImage();
      addTearDown(source.dispose);
      final sprite = Sprite(
        source,
        srcPosition: Vector2(1, 0),
        srcSize: Vector2(2, 3),
      );
      final cache = GhostOutlineCache();
      addTearDown(cache.clear);
      for (final mirrored in [false, true]) {
        for (final size in [Vector2(2, 3), Vector2(4, 6)]) {
          final expected = await _pixels((canvas) {
            _transform(canvas, mirrored);
            final paint = ui.Paint()
              ..filterQuality = ui.FilterQuality.none
              ..colorFilter = const ui.ColorFilter.mode(
                ui.Color.fromARGB(230, 0, 0, 0),
                ui.BlendMode.srcATop,
              );
            for (final offset in const [
              ui.Offset(-1, -1),
              ui.Offset(-1, 0),
              ui.Offset(-1, 1),
              ui.Offset(1, 0),
              ui.Offset(1, -1),
              ui.Offset(1, 1),
              ui.Offset(0, -1),
              ui.Offset(0, 1),
            ]) {
              canvas.save();
              canvas.translate(offset.dx, offset.dy);
              sprite.render(canvas, size: size, overridePaint: paint);
              canvas.restore();
            }
          });
          for (var repeat = 0; repeat < 2; repeat++) {
            final actual = await _pixels((canvas) {
              _transform(canvas, mirrored);
              cache.render(canvas, sprite, size);
            });
            expect(actual.length, expected.length);
            for (var i = 0; i < actual.length; i++) {
              expect(
                (actual[i] - expected[i]).abs(),
                lessThanOrEqualTo(2),
                reason: 'channel $i',
              );
            }
          }
        }
      }
      expect(cache.frameCount, 2);
    },
  );

  test(
    'cache bounds retained textures and can be reused after clearing',
    () async {
      final source = await _sourceImage();
      addTearDown(source.dispose);
      final cache = GhostOutlineCache(maxBytes: 200);
      addTearDown(cache.clear);
      for (var i = 0; i < 20; i++) {
        await _pixels(
          (canvas) => cache.render(canvas, Sprite(source), Vector2(3, 3)),
        );
        expect(cache.estimatedBytes, lessThanOrEqualTo(200));
      }
      cache.clear();
      expect(cache.estimatedBytes, 0);
      expect(cache.frameCount, 0);
      await _pixels(
        (canvas) => cache.render(canvas, Sprite(source), Vector2(8, 8)),
      );
      expect(
        cache.estimatedBytes,
        0,
        reason: 'Oversize textures are not retained',
      );
      await _pixels(
        (canvas) => cache.render(canvas, Sprite(source), Vector2(3, 3)),
      );
      expect(cache.frameCount, 1);
    },
  );
}

void _transform(ui.Canvas canvas, bool mirrored) {
  canvas.translate(16, 4);
  canvas.scale(mirrored ? -2 : 2, 2);
}

Future<List<int>> _pixels(void Function(ui.Canvas) draw) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawColor(const ui.Color(0xFF8B7A69), ui.BlendMode.src);
  draw(canvas);
  final picture = recorder.endRecording();
  final image = await picture.toImage(40, 24);
  picture.dispose();
  final bytes = await image.toByteData();
  image.dispose();
  return bytes!.buffer.asUint8List().toList();
}

Future<ui.Image> _sourceImage() async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    const ui.Rect.fromLTWH(1, 0, 2, 1),
    ui.Paint()..color = const ui.Color(0xFFFFFFFF),
  );
  canvas.drawRect(
    const ui.Rect.fromLTWH(1, 1, 1, 2),
    ui.Paint()..color = const ui.Color(0xFF934DBC),
  );
  canvas.drawRect(
    const ui.Rect.fromLTWH(2, 2, 1, 1),
    ui.Paint()..color = const ui.Color(0x80999999),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(3, 3);
  picture.dispose();
  return image;
}
