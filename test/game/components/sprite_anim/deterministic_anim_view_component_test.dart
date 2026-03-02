import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/core/snapshots/entity_render_snapshot.dart';
import 'package:rpg_runner/core/snapshots/enums.dart';
import 'package:rpg_runner/game/components/sprite_anim/deterministic_anim_view_component.dart';
import 'package:rpg_runner/game/components/sprite_anim/sprite_anim_set.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ward status mask contributes persistent tint overlay', () async {
    final image = await _singlePixelImage();
    final animation = SpriteAnimation(<SpriteAnimationFrame>[
      SpriteAnimationFrame(Sprite(image), 0.1),
    ]);
    final animSet = SpriteAnimSet(
      animations: <AnimKey, SpriteAnimation>{AnimKey.idle: animation},
      stepTimeSecondsByKey: const <AnimKey, double>{AnimKey.idle: 0.1},
      oneShotKeys: const <AnimKey>{},
      frameSize: Vector2.all(1.0),
    );

    final view = DeterministicAnimViewComponent(animSet: animSet);
    view.setStatusVisualMask(EntityStatusVisualMask.ward);
    view.update(1 / 60.0);

    expect(view.paint.colorFilter, isNotNull);
    image.dispose();
  });
}

Future<ui.Image> _singlePixelImage() async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  final paint = ui.Paint()..color = const ui.Color(0xFFFFFFFF);
  canvas.drawRect(const ui.Rect.fromLTWH(0, 0, 1, 1), paint);
  final picture = recorder.endRecording();
  return picture.toImage(1, 1);
}
