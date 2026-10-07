import 'dart:io';
import 'dart:ui' as ui;

import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/game/components/enemies/enemy_render_registry.dart';
import 'package:rpg_runner/game/components/projectiles/projectile_render_registry.dart';
import 'package:rpg_runner/game/components/spell_impacts/spell_impact_render_registry.dart';
import 'package:rpg_runner/game/components/sprite_anim/composite_frame_sprite.dart';
import 'package:runner_core/combat/ancient_god_pose_catalog.dart';
import 'package:runner_core/enemies/enemy_catalog.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/projectiles/projectile_id.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/spell_impacts/spell_impact_id.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Ancient God exported frames, scales and composed beams load exactly',
    () async {
      final images = Images();
      addTearDown(images.clearCache);
      final actors = EnemyRenderRegistry();
      await actors.load(images);
      for (final id in [
        EnemyId.voidbornGoddess,
        EnemyId.shoggoth,
        EnemyId.voidcaller,
        EnemyId.shoggothMinion,
        EnemyId.voidTentacle,
      ]) {
        final entry = actors.entryFor(id)!;
        expect(entry.renderScale.x, 1.5);
        for (final animation in entry.animSet.animations.values) {
          for (final frame in animation.frames) {
            final s = frame.sprite;
            expect(
              s.srcPosition.x + s.srcSize.x,
              lessThanOrEqualTo(s.image.width),
            );
            expect(
              s.srcPosition.y + s.srcSize.y,
              lessThanOrEqualTo(s.image.height),
            );
          }
        }
      }
      final goddess = actors
          .entryFor(EnemyId.voidbornGoddess)!
          .animSet
          .animations[AnimKey.ranged]!;
      expect(goddess.frames, hasLength(36));
      expect(goddess.frames.first.sprite.srcPosition.y, 465);
      expect(goddess.frames[6].sprite.srcPosition.y, 558);
      expect(goddess.frames.last.sprite.srcPosition.x, 4002);
      final projectiles = ProjectileRenderRegistry();
      await projectiles.load(images);
      for (final id in [
        ProjectileId.goddessOrb,
        ProjectileId.shoggothOrb,
        ProjectileId.voidClaw,
      ]) {
        expect(projectiles.entryFor(id), isNotNull);
      }
      final impacts = SpellImpactRenderRegistry();
      await impacts.load(images);
      for (final id in [
        SpellImpactId.voidVerticalBeam,
        SpellImpactId.voidDiagonalBeam,
      ]) {
        final entry = impacts.entryFor(id)!;
        expect(entry.animSet.animations[AnimKey.hit]!.frames, hasLength(12));
        expect(
          entry.animSet.animations[AnimKey.hit]!.frames[5].sprite,
          isA<CompositeFrameSprite>(),
        );
        expect(entry.renderScale.x, 1.5);
      }
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawColor(const ui.Color(0xFF1D2633), ui.BlendMode.src);
      final panels = [
        (
          EnemyId.voidbornGoddess,
          AnimKey.strike,
          AncientGodPoseCatalog.goddessClaws,
        ),
        (EnemyId.shoggoth, AnimKey.strike, AncientGodPoseCatalog.shoggothSweep),
        (EnemyId.shoggoth, AnimKey.strike2, AncientGodPoseCatalog.shoggothSpin),
        (
          EnemyId.voidTentacle,
          AnimKey.strike,
          AncientGodPoseCatalog.tentacleLash,
        ),
      ];
      for (var row = 0; row < panels.length; row++) {
        final (id, key, profile) = panels[row];
        final entry = actors.entryFor(id)!;
        final set = entry.animSet;
        final animation = set.animations[key]!;
        final indices = List.generate(
          4,
          (col) =>
              profile.timing.activeStart +
              col *
                  (profile.timing.activeEnd - profile.timing.activeStart - 1) ~/
                  3,
        );
        for (var col = 0; col < 4; col++) {
          final index = indices[col];
          final position = Vector2(140 + col * 260.0, 120 + row * 160.0);
          animation.frames[index].sprite.render(
            canvas,
            position: position,
            size: set.frameSize * 1.5,
            anchor: set.anchorFor(key),
          );
          final a = const EnemyCatalog().get(id).collider;
          canvas.drawRect(
            ui.Rect.fromCenter(
              center: ui.Offset(position.x, position.y + a.offsetY),
              width: a.halfX * 2,
              height: a.halfY * 2,
            ),
            ui.Paint()
              ..color = const ui.Color(0x9999BBDD)
              ..style = ui.PaintingStyle.stroke,
          );
          for (final shape in profile.frames[index]) {
            final start = ui.Offset(
                  position.x + shape.ax,
                  position.y + shape.ay,
                ),
                end = ui.Offset(position.x + shape.bx, position.y + shape.by);
            canvas.drawLine(
              start,
              end,
              ui.Paint()
                ..color = const ui.Color(0x66FF4444)
                ..strokeWidth = shape.radius * 2
                ..strokeCap = ui.StrokeCap.round,
            );
          }
        }
      }
      for (var row = 0; row < 2; row++) {
        final id = row == 0
            ? SpellImpactId.voidVerticalBeam
            : SpellImpactId.voidDiagonalBeam;
        final set = impacts.entryFor(id)!.animSet;
        final animation = set.animations[AnimKey.hit]!;
        for (var col = 0; col < 4; col++) {
          animation.frames[[0, 4, 5, 9][col]].sprite.render(
            canvas,
            position: Vector2(150 + col * 260.0, 900 + row * 250.0),
            size: set.frameSize * 1.5,
            anchor: set.anchorFor(AnimKey.hit),
          );
        }
      }
      final picture = recorder.endRecording();
      final image = await picture.toImage(1100, 1190);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('.tmp/ancient_god_preview.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
      picture.dispose();
    },
  );
}
