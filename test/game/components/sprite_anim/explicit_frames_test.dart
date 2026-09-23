import 'dart:ui' as ui;

import 'package:flame/cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runner_core/contracts/render_anim_set_definition.dart';
import 'package:runner_core/contracts/render_frame_rect.dart';
import 'package:runner_core/projectiles/projectile_id.dart';
import 'package:runner_core/projectiles/projectile_render_catalog.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/util/vec2.dart';
import 'package:rpg_runner/game/components/sprite_anim/strip_animation_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'explicit frame extraction and per-animation pivots keep native pixels',
    () async {
      final picture = ui.PictureRecorder();
      ui.Canvas(picture);
      final image = await picture.endRecording().toImage(1536, 1152);
      final images = Images();
      final def = const ProjectileRenderCatalog().get(ProjectileId.poisonDart);
      images.add(def.sourcesByKey[AnimKey.idle]!, image);
      final anim = await loadAnimSetFromDefinition(
        images,
        renderAnim: def,
        oneShotKeys: {AnimKey.hit},
      );
      expect(
        anim.animations[AnimKey.idle]!.frames.single.sprite.srcPosition.y,
        640,
      );
      expect(
        anim.animations[AnimKey.hit]!.frames.last.sprite.srcPosition.x,
        1408,
      );
      expect(
        anim.animations[AnimKey.hit]!.frames.last.sprite.srcPosition.y,
        768,
      );
      expect(anim.anchorFor(AnimKey.idle).x, 15 / 128);
      expect(anim.anchorFor(AnimKey.hit).x, 64 / 128);
      expect(anim.anchorFor(AnimKey.hit).y, 76 / 128);
      expect(anim.frameSize.x, 128);
      expect(
        anim.animations[AnimKey.spawn],
        same(anim.animations[AnimKey.idle]),
      );
      images.clearCache();
    },
  );

  test('explicit frames reject count, bounds and anchor mismatches', () async {
    final picture = ui.PictureRecorder();
    ui.Canvas(picture);
    final image = await picture.endRecording().toImage(16, 16);
    final images = Images()..add('sheet', image);
    for (final (frames, point) in [
      (<RenderFrameRect>[], const Vec2(0, 0)),
      ([const RenderFrameRect(9, 0, 8, 8)], const Vec2(0, 0)),
      ([const RenderFrameRect(0, 0, 8, 8)], const Vec2(9, 0)),
    ]) {
      final def = RenderAnimSetDefinition(
        frameWidth: 8,
        frameHeight: 8,
        anchorPoint: const Vec2(0, 0),
        anchorPointByKey: {AnimKey.idle: point},
        sourcesByKey: const {AnimKey.idle: 'sheet'},
        sourceFramesByKey: {AnimKey.idle: frames},
        frameCountsByKey: const {AnimKey.idle: 1},
        stepTimeSecondsByKey: const {AnimKey.idle: 0.1},
      );
      await expectLater(
        loadAnimSetFromDefinition(images, renderAnim: def, oneShotKeys: {}),
        throwsArgumentError,
      );
    }
    images.clearCache();
  });
}
