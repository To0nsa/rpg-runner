import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/game/components/enemies/enemy_render_registry.dart';
import 'package:rpg_runner/game/components/projectiles/projectile_render_registry.dart';
import 'package:runner_core/combat/shoggoth_pose_catalog.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/projectiles/projectile_id.dart';
import 'package:runner_core/snapshots/enums.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'orb release stays inside the casting hands in both facings and aim angles',
    () async {
      final images = Images();
      addTearDown(images.clearCache);
      final actors = EnemyRenderRegistry();
      final projectiles = ProjectileRenderRegistry();
      await actors.load(images);
      await projectiles.load(images);
      final boss = actors.entryFor(EnemyId.shoggoth)!;
      final orb = projectiles.entryFor(ProjectileId.shoggothOrb)!;
      final sprite = boss.animSet.animations[AnimKey.cast]!.frames[8].sprite;
      final rgba = (await sprite.image.toByteData())!;
      final anchor = boss.animSet.anchorFor(AnimKey.cast);
      final offset = ShoggothPoseCatalog.orbReleaseOffset;
      final sourceX =
          offset.x / boss.renderScale.x + anchor.x * boss.animSet.frameSize.x;
      final sourceY =
          offset.y / boss.renderScale.y + anchor.y * boss.animSet.frameSize.y;
      expect(sourceX, 44);
      expect(sourceY, 79);
      var pink = 0;
      for (var y = sourceY.round() - 10; y <= sourceY.round() + 10; y++) {
        for (var x = sourceX.round() - 10; x <= sourceX.round() + 10; x++) {
          final i =
              ((sprite.srcPosition.y.toInt() + y) * sprite.image.width +
                  sprite.srcPosition.x.toInt() +
                  x) *
              4;
          if (rgba.getUint8(i) > 190 &&
              rgba.getUint8(i + 2) > 190 &&
              rgba.getUint8(i + 3) > 192) {
            pink++;
          }
        }
      }
      expect(
        pink,
        greaterThan(30),
        reason: 'the source marker must sit in the hand-tip casting ring',
      );

      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawColor(const ui.Color(0xFF1D2633), ui.BlendMode.src);
      final angles = [-math.pi / 6, 0.0, math.pi / 6];
      for (var row = 0; row < angles.length; row++) {
        for (var col = 0; col < Facing.values.length; col++) {
          final facing = Facing.values[col];
          final mirror = facing == Facing.left ? 1.0 : -1.0;
          final muzzle = ui.Offset(100 + mirror * offset.x, 65 + offset.y);
          canvas.save();
          canvas.translate(col * 400.0, row * 220.0);
          canvas.scale(2);
          canvas.save();
          canvas.translate(100, 65);
          canvas.scale(mirror, 1);
          sprite.render(
            canvas,
            size: boss.animSet.frameSize * boss.renderScale.x,
            anchor: anchor,
          );
          canvas.restore();
          canvas.save();
          canvas.translate(muzzle.dx, muzzle.dy);
          canvas.rotate((facing == Facing.left ? math.pi : 0) + angles[row]);
          orb.animSet.animations[AnimKey.idle]!.frames.first.sprite.render(
            canvas,
            size: orb.animSet.frameSize * orb.renderScale.x,
            anchor: orb.animSet.anchorFor(AnimKey.idle),
          );
          canvas.restore();
          canvas.restore();
        }
      }
      final picture = recorder.endRecording();
      final image = await picture.toImage(800, 660);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('.tmp/shoggoth_cast_release.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
      picture.dispose();
    },
  );
}
