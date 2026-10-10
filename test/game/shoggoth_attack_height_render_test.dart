import 'dart:io';
import 'dart:ui' as ui;

import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/game/components/enemies/enemy_render_registry.dart';
import 'package:rpg_runner/game/components/player/player_animations.dart';
import 'package:rpg_runner/game/tuning/player_render_tuning.dart';
import 'package:runner_core/combat/shoggoth_pose_catalog.dart';
import 'package:runner_core/enemies/enemy_catalog.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/players/characters/eloise.dart';
import 'package:runner_core/snapshots/enums.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Shoggoth attack pixels meet the grounded player torso in both facings', () async {
    final images = Images();
    addTearDown(images.clearCache);
    final registry = EnemyRenderRegistry();
    await registry.load(images);
    final entry = registry.entryFor(EnemyId.shoggoth)!;
    final player = await loadPlayerAnimations(
      images,
      renderAnim: eloiseRenderAnim,
    );
    final bossBody = const EnemyCatalog().get(EnemyId.shoggoth).collider;
    const floor = 105.0;
    final bossY = floor - bossBody.offsetY - bossBody.halfY;
    final playerY =
        floor - eloiseCatalog.colliderOffsetY - eloiseCatalog.colliderHalfY;
    final recorder = ui.PictureRecorder();
    final preview = ui.Canvas(recorder);
    preview.drawColor(const ui.Color(0xFF1D2633), ui.BlendMode.src);
    final samples = [
      (AnimKey.strike, 5, -45.0, ShoggothPoseCatalog.shoggothSweep),
      (AnimKey.strike, 7, -45.0, ShoggothPoseCatalog.shoggothSweep),
      (AnimKey.strike2, 3, -45.0, ShoggothPoseCatalog.shoggothSpin),
      (AnimKey.strike2, 4, -70.0, ShoggothPoseCatalog.shoggothSpin),
      (AnimKey.strike2, 6, 55.0, ShoggothPoseCatalog.shoggothSpin),
      (AnimKey.strike2, 7, 40.0, ShoggothPoseCatalog.shoggothSpin),
    ];
    for (var row = 0; row < samples.length; row++) {
      final (key, frame, targetOffset, profile) = samples[row];
      for (var col = 0; col < Facing.values.length; col++) {
        final facing = Facing.values[col];
        final mirror = facing == Facing.left ? 1.0 : -1.0;
        final targetX = 100 + targetOffset * mirror;
        void renderBoss(ui.Canvas canvas) {
          canvas.save();
          canvas.translate(100, bossY);
          canvas.scale(mirror, 1);
          entry.animSet.animations[key]!.frames[frame].sprite.render(
            canvas,
            size: entry.animSet.frameSize * entry.renderScale.x,
            anchor: entry.animSet.anchorFor(key),
          );
          canvas.restore();
        }

        final attackRecorder = ui.PictureRecorder();
        renderBoss(ui.Canvas(attackRecorder));
        final attackPicture = attackRecorder.endRecording();
        final attack = await attackPicture.toImage(200, 130);
        final rgba = (await attack.toByteData())!;
        var torsoPixels = 0;
        // Require visible attack pixels across the central 60% of the standing
        // body, rather than a scrape at the top of the player's head.
        for (
          var y = (floor - eloiseCatalog.colliderHeight * .8).ceil();
          y < floor - eloiseCatalog.colliderHeight * .2;
          y++
        ) {
          for (
            var x = (targetX - eloiseCatalog.colliderHalfX).ceil();
            x < targetX + eloiseCatalog.colliderHalfX;
            x++
          ) {
            if (rgba.getUint8((y * 200 + x) * 4 + 3) >= 192) torsoPixels++;
          }
        }
        expect(
          torsoPixels,
          greaterThan(3),
          reason: '$key frame $frame $facing',
        );
        attack.dispose();
        attackPicture.dispose();

        preview.save();
        preview.translate(col * 400.0, row * 260.0);
        preview.scale(2);
        preview.drawLine(
          const ui.Offset(0, floor),
          const ui.Offset(200, floor),
          ui.Paint()..color = const ui.Color(0xFF8899AA),
        );
        renderBoss(preview);
        player.animations[AnimKey.idle]!.frames.first.sprite.render(
          preview,
          position: Vector2(targetX, playerY),
          size: player.frameSize * const PlayerRenderTuning().scale,
          anchor: player.anchorFor(AnimKey.idle),
        );
        for (final shape in profile.frames[frame]) {
          preview.drawLine(
            ui.Offset(100 + mirror * shape.ax, bossY + shape.ay),
            ui.Offset(100 + mirror * shape.bx, bossY + shape.by),
            ui.Paint()
              ..color = const ui.Color(0x55FF5555)
              ..strokeWidth = shape.radius * 2
              ..strokeCap = ui.StrokeCap.round,
          );
        }
        preview.restore();
      }
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(800, samples.length * 260);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('.tmp/shoggoth_height_preview.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
    picture.dispose();
  });
}
