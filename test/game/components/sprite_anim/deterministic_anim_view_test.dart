import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runner_core/snapshots/entity_render_snapshot.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:rpg_runner/game/components/sprite_anim/deterministic_anim_view.dart';
import 'package:rpg_runner/game/components/sprite_anim/sprite_anim_set.dart';
import 'package:rpg_runner/game/tuning/combat_feedback_tuning.dart';
import 'package:runner_core/combat/damage_type.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  SpriteAnimSet buildAnimSet(ui.Image image) {
    final animation = SpriteAnimation(<SpriteAnimationFrame>[
      SpriteAnimationFrame(Sprite(image), 0.1),
    ]);
    return SpriteAnimSet(
      animations: <AnimKey, SpriteAnimation>{AnimKey.idle: animation},
      stepTimeSecondsByKey: const <AnimKey, double>{AnimKey.idle: 0.1},
      oneShotKeys: const <AnimKey>{},
      frameSize: Vector2.all(1.0),
    );
  }

  test('ward status mask contributes persistent tint overlay', () async {
    final image = await _singlePixelImage();
    final animSet = buildAnimSet(image);

    final view = DeterministicAnimView(animSet: animSet);
    view.setStatusVisualMask(EntityStatusVisualMask.ward);
    view.update(1 / 60.0);

    expect(view.paint.colorFilter, isNotNull);
    image.dispose();
  });

  test('Poison remains visible between pulses alongside Slow', () async {
    final image = await _singlePixelImage();
    final view = DeterministicAnimView(animSet: buildAnimSet(image));
    view.setStatusVisualMask(
      EntityStatusVisualMask.poison | EntityStatusVisualMask.slow,
    );
    view.update(0.5);
    expect(view.paint.colorFilter, isNotNull);
    const tuning = CombatFeedbackTuning();
    expect(
      tuning.dotColorFor(DamageType.poison),
      isNot(tuning.dotColorFor(DamageType.fire)),
    );
    view.setStatusVisualMask(EntityStatusVisualMask.none);
    view.update(0);
    expect(view.paint.colorFilter, isNull);
    image.dispose();
  });

  test(
    'ghost visual style applies monochrome tint and lowered opacity',
    () async {
      final image = await _singlePixelImage();
      final animSet = buildAnimSet(image);

      final view = DeterministicAnimView(
        animSet: animSet,
        visualStyle: RenderVisualStyle.ghost,
      );
      view.update(1 / 60.0);

      expect(view.paint.colorFilter, isNotNull);
      expect(view.opacity, 1.0);
      image.dispose();
    },
  );
}

Future<ui.Image> _singlePixelImage() async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  final paint = ui.Paint()..color = const ui.Color(0xFFFFFFFF);
  canvas.drawRect(const ui.Rect.fromLTWH(0, 0, 1, 1), paint);
  final picture = recorder.endRecording();
  return picture.toImage(1, 1);
}
