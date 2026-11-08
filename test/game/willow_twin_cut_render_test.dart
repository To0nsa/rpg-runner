import 'dart:io';
import 'dart:ui' as ui;

import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/game/components/player/player_animations.dart';
import 'package:rpg_runner/game/components/player/player_view.dart';
import 'package:runner_core/players/characters/bounty_hunter.dart';
import 'package:runner_core/projectiles/projectile_id.dart';
import 'package:runner_core/snapshots/entity_render_snapshot.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/util/vec2.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Twin Cut renders the eight blade-only frames for every weapon family', () async {
    final images = Images();
    addTearDown(images.clearCache);
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawColor(const ui.Color(0xFF25313A), ui.BlendMode.src);
    var row = 0;
    for (final (gun, family) in [
      (ProjectileId.hunterPistol, 'gun'),
      (ProjectileId.hunterCrossbow, 'crossbow'),
      (ProjectileId.hunterShotgun, 'shotgun'),
    ]) {
      final def = bountyHunterCharacter.withProjectile(gun);
      final set = await loadPlayerAnimations(
        images,
        renderAnim: def.renderAnim,
      );
      final animation = set.animations[AnimKey.twinStrike]!;
      expect(animation.loop, false);
      expect(animation.frames, hasLength(8));
      expect(set.animations.containsKey(AnimKey.tripleStrike), false);
      final view = PlayerView(
        animationSet: set,
        renderScale: Vector2.all(def.renderScale),
      );
      final bytes = await rootBundle.load(
        'assets/images/entities/player/bounty_hunter/$family/add_on_sheet.png',
      );
      final codec = await ui.instantiateImageCodec(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      );
      final source = (await codec.getNextFrame()).image;
      for (var frame = 0; frame < 8; frame++) {
        view.applySnapshot(
          EntityRenderSnapshot(
            id: 1,
            kind: EntityKind.player,
            pos: const Vec2(0, 0),
            facing: Facing.right,
            anim: AnimKey.twinStrike,
            grounded: true,
            animFrame: frame * 4,
          ),
          tickHz: 60,
        );
        expect(view.animationTicker!.currentIndex, frame);
        final sprite = view.animationTicker!.getSprite();
        final actualRecorder = ui.PictureRecorder();
        sprite.render(ui.Canvas(actualRecorder), size: set.frameSize);
        final actualPicture = actualRecorder.endRecording();
        final actual = await actualPicture.toImage(89, 65);
        final expectedRecorder = ui.PictureRecorder();
        ui.Canvas(expectedRecorder).drawImageRect(
          source,
          ui.Rect.fromLTWH(frame * 89.0, 130, 89, 65),
          const ui.Rect.fromLTWH(0, 0, 89, 65),
          ui.Paint()..filterQuality = ui.FilterQuality.none,
        );
        final expectedPicture = expectedRecorder.endRecording();
        final expected = await expectedPicture.toImage(89, 65);
        expect(
          (await actual.toByteData())!.buffer.asUint8List(),
          (await expected.toByteData())!.buffer.asUint8List(),
          reason: '$family frame ${frame + 1} must precede the weapon draw',
        );
        canvas.save();
        canvas.translate(frame * 178.0, row * 130.0);
        sprite.render(canvas, size: Vector2(178, 130));
        canvas.restore();
        actual.dispose();
        expected.dispose();
        actualPicture.dispose();
        expectedPicture.dispose();
      }
      source.dispose();
      codec.dispose();
      row++;
    }
    final picture = recorder.endRecording();
    final review = await picture.toImage(1424, 390);
    final bytes = await review.toByteData(format: ui.ImageByteFormat.png);
    await Directory('.tmp').create(recursive: true);
    await File('.tmp/willow_twin_cut_review.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
    review.dispose();
    picture.dispose();
  });
}
