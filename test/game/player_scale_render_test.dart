import 'dart:io';
import 'dart:ui' as ui;

import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/game/components/player/player_animations.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:runner_core/players/player_character_definition.dart';
import 'package:runner_core/projectiles/projectile_id.dart';
import 'package:runner_core/snapshots/enums.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'all Willow guns match Eloise idle reference height and grounded support',
    () async {
      final images = Images();
      addTearDown(images.clearCache);
      final definitions = [
        PlayerCharacterRegistry.eloise,
        for (final gun in [
          ProjectileId.hunterPistol,
          ProjectileId.hunterCrossbow,
          ProjectileId.hunterShotgun,
        ])
          PlayerCharacterRegistry.resolve(PlayerCharacterId.bountyHunter)
              .withProjectile(gun),
      ];
      const zoom = 4.0;
      const floor = 100.0;
      final heights = <List<int>>[];
      final comparison = ui.PictureRecorder();
      final canvas = ui.Canvas(comparison);
      canvas.drawColor(const ui.Color(0xFF16252C), ui.BlendMode.src);
      for (var column = 0; column < definitions.length; column++) {
        final def = definitions[column];
        final set = await loadPlayerAnimations(
          images,
          renderAnim: def.renderAnim,
        );
        final groundedY =
            floor - def.catalog.colliderOffsetY - def.catalog.colliderHalfY;
        final frameHeights = <int>[];
        for (final frame in set.animations[AnimKey.idle]!.frames) {
          final recorder = ui.PictureRecorder();
          final c = ui.Canvas(recorder)..scale(zoom);
          frame.sprite.render(
            c,
            position: Vector2(60, groundedY),
            size: set.frameSize * def.renderScale,
            anchor: set.anchor,
          );
          final picture = recorder.endRecording();
          final image = await picture.toImage(480, 440);
          final rgba = (await image.toByteData())!;
          var top = 440, bottom = -1;
          for (var y = 0; y < 440; y++) {
            for (var x = 0; x < 480; x++) {
              if (rgba.getUint8((y * 480 + x) * 4 + 3) < 192) continue;
              // Measure the head over the body pivot, excluding a held gun or
              // crossbow extending above it. Feet use the full silhouette.
              if ((x - 60 * zoom).abs() <= zoom && y < top) top = y;
              if (y > bottom) bottom = y;
            }
          }
          expect(
            bottom + 1,
            closeTo(floor * zoom, 1),
            reason: '${def.displayName} feet',
          );
          frameHeights.add(bottom - top + 1);
          image.dispose();
          picture.dispose();
        }
        heights.add(frameHeights);
        canvas.save();
        canvas.translate(column * 480, 0);
        canvas.scale(zoom);
        canvas.drawLine(
          const ui.Offset(0, floor),
          const ui.Offset(120, floor),
          ui.Paint()
            ..color = const ui.Color(0xFFB99A52)
            ..strokeWidth = .25,
        );
        set.animations[AnimKey.idle]!.frames.first.sprite.render(
          canvas,
          position: Vector2(60, groundedY),
          size: set.frameSize * def.renderScale,
          anchor: set.anchor,
        );
        canvas.restore();
      }
      for (final willow in heights.skip(1)) {
        expect(willow.first, closeTo(heights.first.first, zoom));
      }
      final picture = comparison.endRecording();
      if (Platform.environment['WILLOW_SCALE_CAPTURE'] == 'true') {
        final image = await picture.toImage(1920, 440);
        final png = (await image.toByteData(format: ui.ImageByteFormat.png))!;
        await File('.tmp/willow_scale_grounded.png')
            .writeAsBytes(png.buffer.asUint8List());
        image.dispose();
      }
      picture.dispose();
    },
  );
}
