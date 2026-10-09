import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/game/components/camera_space_snapped_sprite_animation.dart';
import 'package:rpg_runner/game/components/projectiles/projectile_render_registry.dart';
import 'package:rpg_runner/game/components/spell_impacts/spell_impact_render_registry.dart';
import 'package:rpg_runner/game/runner_flame/camera_shake_controller.dart';
import 'package:rpg_runner/game/runner_flame/event_feedback_system.dart';
import 'package:rpg_runner/game/tuning/combat_feedback_tuning.dart';
import 'package:runner_core/events/game_event.dart';
import 'package:runner_core/projectiles/projectile_id.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/util/vec2.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'orb flight pixels stay centered on the aim line in every frame',
    () async {
      final images = Images();
      addTearDown(images.clearCache);
      final registry = ProjectileRenderRegistry();
      await registry.load(images);
      final entry = registry.entryFor(ProjectileId.goddessOrb)!;
      for (final key in [AnimKey.spawn, AnimKey.idle]) {
        final animation = entry.animSet.animations[key]!;
        final anchor = entry.animSet.anchorFor(key);
        for (final frame in animation.frames) {
          final bounds = await _renderBounds((canvas) {
            canvas.translate(100, 100);
            canvas.scale(entry.renderScale.x, entry.renderScale.y);
            canvas.translate(
              -anchor.x * entry.animSet.frameSize.x,
              -anchor.y * entry.animSet.frameSize.y,
            );
            frame.sprite.render(canvas, size: entry.animSet.frameSize);
          });
          expect((bounds.center.dy - 100).abs(), lessThanOrEqualTo(2));
          expect((bounds.center.dx - 100).abs(), lessThan(6));
        }
      }
    },
  );

  for (final angle in [0.0, math.pi, math.pi / 4, math.pi * 3 / 4]) {
    test('orb burst covers the body at angle $angle', () async {
      final images = Images();
      addTearDown(images.clearCache);
      final registry = ProjectileRenderRegistry();
      await registry.load(images);
      final world = Component();
      final feedback = RunEventFeedbackSystem(
        world: world,
        projectileRenderRegistry: registry,
        spellImpactRenderRegistry: SpellImpactRenderRegistry(),
        combatFeedbackTuning: const CombatFeedbackTuning(),
        cameraShakeController: CameraShakeController(),
      );
      feedback.handleGameEvent(
        ProjectileHitEvent(
          tick: 10,
          projectileId: ProjectileId.goddessOrb,
          pos: const Vec2(60, 130),
          targetCenter: const Vec2(100, 100),
          facing: angle > math.pi / 2 ? Facing.left : Facing.right,
          rotationRad: angle,
        ),
      );
      feedback.flushProjectileHitEvents(
        cameraCenter: Vector2.zero(),
        priority: 1,
      );
      final impact = world.children
          .whereType<CameraSpaceSnappedSpriteAnimation>()
          .single;
      expect(impact.worldPosX, 100);
      expect(impact.worldPosY, 100);
      impact.animationTicker!.currentIndex = 2;
      final bounds = await _renderBounds(impact.renderTree);
      expect((bounds.center - const ui.Offset(100, 100)).distance, lessThan(6));
      expect(bounds.top, lessThan(100 - 22.5));
      expect(bounds.bottom, greaterThan(100 + 22.5));
      expect(bounds.left, lessThan(100 - 10));
      expect(bounds.right, greaterThan(100 + 10));

      // Other projectile art still uses the contact location.
      final contact = registry
          .entryFor(ProjectileId.iceBolt)!
          .impactPosition(
            const ProjectileHitEvent(
              tick: 10,
              projectileId: ProjectileId.iceBolt,
              pos: Vec2(60, 130),
              targetCenter: Vec2(100, 100),
              facing: Facing.right,
              rotationRad: 0,
            ),
          );
      expect(contact.x, 60);
      expect(contact.y, 130);
    });
  }
}

Future<ui.Rect> _renderBounds(void Function(ui.Canvas) render) async {
  final recorder = ui.PictureRecorder();
  render(ui.Canvas(recorder));
  final picture = recorder.endRecording();
  final image = await picture.toImage(200, 200);
  final pixels = (await image.toByteData())!;
  var left = 200, top = 200, right = 0, bottom = 0;
  for (var y = 0; y < 200; y++) {
    for (var x = 0; x < 200; x++) {
      if (pixels.getUint8((y * 200 + x) * 4 + 3) < 192) continue;
      left = math.min(left, x);
      right = math.max(right, x + 1);
      top = math.min(top, y);
      bottom = math.max(bottom, y + 1);
    }
  }
  image.dispose();
  picture.dispose();
  expect(right, greaterThan(left));
  return ui.Rect.fromLTRB(
    left.toDouble(),
    top.toDouble(),
    right.toDouble(),
    bottom.toDouble(),
  );
}
