import 'dart:io';
import 'dart:ui' as ui;

import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/game/components/player/player_animations.dart';
import 'package:runner_core/players/characters/bounty_hunter.dart';
import 'package:runner_core/projectiles/projectile_id.dart';
import 'package:runner_core/snapshots/enums.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Willow release attachments touch the barrel pixels of every firing pose', () async {
    final images = Images();
    addTearDown(images.clearCache);
    final comparison = ui.PictureRecorder();
    final canvas = ui.Canvas(comparison);
    canvas.drawColor(const ui.Color(0xFF16252C), ui.BlendMode.src);
    var column = 0;
    for (final gun in hunterRangedWeaponIds) {
      final def = bountyHunterCharacter.withProjectile(gun);
      final set = await loadPlayerAnimations(
        images,
        renderAnim: def.renderAnim,
      );
      final muzzle = def.projectileMuzzles[gun]!;
      var row = 0;
      for (final key in [
        AnimKey.ranged,
        AnimKey.rangedAir,
        AnimKey.rangedRun,
      ]) {
        final count = key == AnimKey.rangedRun ? 8 : 1;
        for (var runFrame = 0; runFrame < count; runFrame++) {
          final frame = key == AnimKey.rangedRun ? 8 + runFrame : 1;
          final sprite = set.animations[key]!.frames[frame].sprite;
          final offset = muzzle.offset(
            renderAnim: def.renderAnim,
            grounded: key != AnimKey.rangedAir,
            velocityX: key == AnimKey.rangedRun ? 160 : 0,
            minMoveSpeed: def.tuning.movement.minMoveSpeed,
            currentTick: runFrame * 5,
            tickHz: 60,
          );
          final recorder = ui.PictureRecorder();
          sprite.render(ui.Canvas(recorder), size: set.frameSize);
          final picture = recorder.endRecording();
          final image = await picture.toImage(89, 65);
          final pixels = (await image.toByteData())!;
          final x = (offset.x / def.renderScale + def.renderAnim.anchorPoint.x)
              .round();
          final y = (offset.y / def.renderScale + def.renderAnim.anchorPoint.y)
              .floor();
          int alpha(int px) => pixels.getUint8((y * 89 + px) * 4 + 3);
          expect(
            x,
            greaterThan(48),
            reason: '$gun $key $runFrame outside the body',
          );
          expect(
            alpha(x - 1),
            greaterThanOrEqualTo(192),
            reason: '$gun $key $runFrame muzzle touches the last barrel pixel',
          );
          expect(
            alpha(x),
            0,
            reason: '$gun $key $runFrame shot starts just beyond the barrel',
          );
          image.dispose();
          picture.dispose();
          // Use the actual live scale and anchor for the review contact sheet.
          canvas.save();
          canvas.translate(column * 220.0, row * 150.0);
          canvas.scale(2);
          sprite.render(
            canvas,
            position: Vector2(45, 50),
            size: set.frameSize * def.renderScale,
            anchor: set.anchor,
          );
          canvas.drawCircle(
            ui.Offset(45 + offset.x, 50 + offset.y),
            1,
            ui.Paint()..color = const ui.Color(0xFF65FF98),
          );
          canvas.restore();
          row++;
        }
      }
      column++;
    }
    final picture = comparison.endRecording();
    if (Platform.environment['WILLOW_MUZZLE_CAPTURE'] == 'true') {
      final image = await picture.toImage(220 * column, 1500);
      final png = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      await File('.tmp/willow_muzzle_render.png')
          .writeAsBytes(png.buffer.asUint8List());
      image.dispose();
    }
    picture.dispose();
  });
}
