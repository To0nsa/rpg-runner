import 'dart:io';
import 'dart:ui' as ui;

import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:rpg_runner/game/components/player/player_animations.dart';
import 'package:rpg_runner/game/components/player/player_view.dart';
import 'package:runner_core/players/characters/bounty_hunter.dart';
import 'package:runner_core/projectiles/projectile_id.dart';
import 'package:runner_core/snapshots/entity_render_snapshot.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/util/vec2.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader('Inter')..addFont(
          rootBundle.load('assets/fonts/Inter/static/Inter_24pt-Regular.ttf'),
        ))
        .load();
  });
  test('all Willow families render the blink blank and final-strip attack', () async {
    final images = Images();
    addTearDown(images.clearCache);
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawColor(const ui.Color(0xFF25313A), ui.BlendMode.src);
    var row = 0;
    for (final gun in [
      ProjectileId.hunterPistol,
      ProjectileId.hunterCrossbow,
      ProjectileId.hunterShotgun,
    ]) {
      final def = bountyHunterCharacter.withProjectile(gun);
      final set = await loadPlayerAnimations(
        images,
        renderAnim: def.renderAnim,
      );
      final view = PlayerView(
        animationSet: set,
        renderScale: Vector2.all(def.renderScale),
      );
      for (final key in [AnimKey.teleportOut, AnimKey.lunge]) {
        final count = key == AnimKey.teleportOut ? 10 : 5;
        expect(set.animations[key]!.loop, false);
        for (var frame = 0; frame < count; frame++) {
          view.applySnapshot(
            EntityRenderSnapshot(
              id: 1,
              kind: EntityKind.player,
              pos: const Vec2(0, 0),
              facing: Facing.right,
              anim: key,
              grounded: true,
              animFrame: frame * 3,
            ),
            tickHz: 60,
          );
          expect(view.animationTicker!.currentIndex, frame);
          final sprite = view.animationTicker!.getSprite();
          canvas.save();
          canvas.translate(frame * 128, row * 100);
          canvas.drawLine(
            const ui.Offset(0, 83),
            const ui.Offset(128, 83),
            ui.Paint()..color = const ui.Color(0xFF71868C),
          );
          sprite.render(
            canvas,
            position: Vector2(53, 60),
            size: set.frameSize * def.renderScale,
            anchor: set.anchor,
          );
          final paragraph =
              (ui.ParagraphBuilder(
                      ui.ParagraphStyle(fontSize: 10, fontFamily: 'Inter'),
                    )
                    ..pushStyle(ui.TextStyle(color: const ui.Color(0xFFD6D2C6)))
                    ..addText(
                      '${gun.name.replaceFirst('hunter', '')} ${key == AnimKey.lunge ? 'slash' : 'blink'} ${frame + 1}',
                    ))
                  .build()
                ..layout(const ui.ParagraphConstraints(width: 128));
          canvas.drawParagraph(paragraph, const ui.Offset(3, 86));
          paragraph.dispose();
          canvas.restore();
          if (key == AnimKey.teleportOut && frame == 4) {
            final blankRecorder = ui.PictureRecorder();
            sprite.render(ui.Canvas(blankRecorder), size: set.frameSize);
            final picture = blankRecorder.endRecording();
            final blank = await picture.toImage(89, 65);
            final bytes = await blank.toByteData();
            expect(bytes!.buffer.asUint8List().every((v) => v == 0), true);
            blank.dispose();
            picture.dispose();
          }
        }
        row++;
      }
    }
    final picture = recorder.endRecording();
    final review = await picture.toImage(1280, 600);
    final bytes = await review.toByteData(format: ui.ImageByteFormat.png);
    await Directory('.tmp').create(recursive: true);
    await File('.tmp/willow_blink_review.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
    review.dispose();
    picture.dispose();
  });
}
