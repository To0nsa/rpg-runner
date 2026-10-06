import 'dart:io';
import 'dart:ui' as ui;

import 'package:flame/cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/game/components/enemies/enemy_render_registry.dart';
import 'package:rpg_runner/game/components/spell_impacts/spell_impact_render_registry.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/snapshots/entity_render_snapshot.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/spell_impacts/spell_impact_id.dart';
import 'package:runner_core/util/vec2.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Bringer wrapped rows, reversed entrance and spell frames load exactly',
    () async {
      final images = Images();
      addTearDown(images.clearCache);
      final actors = EnemyRenderRegistry();
      await actors.load(images);
      final entry = actors.entryFor(EnemyId.bringerOfDeath)!;
      final animations = entry.animSet.animations;
      expect(animations[AnimKey.spawn]!.frames.length, 10);
      expect(animations[AnimKey.spawn]!.frames.first.sprite.srcPosition.x, 840);
      expect(animations[AnimKey.spawn]!.frames.first.sprite.srcPosition.y, 372);
      expect(animations[AnimKey.spawn]!.frames.last.sprite.srcPosition.x, 700);
      expect(animations[AnimKey.spawn]!.frames.last.sprite.srcPosition.y, 279);
      expect(animations[AnimKey.strike]!.frames[8].sprite.srcPosition.x, 0);
      expect(animations[AnimKey.strike]!.frames[8].sprite.srcPosition.y, 279);
      expect(animations[AnimKey.cast]!.frames.length, 9);
      expect(animations[AnimKey.cast]!.frames.last.sprite.srcPosition.y, 465);
      final impacts = SpellImpactRenderRegistry();
      await impacts.load(images);
      final pillar = impacts
          .entryFor(SpellImpactId.deathPillar)!
          .animSet
          .animations[AnimKey.hit]!;
      expect(pillar.frames.length, 16);
      expect(pillar.frames.first.sprite.srcPosition.y, 558);
      expect(pillar.frames.last.sprite.srcPosition.x, 980);
      expect(pillar.frames.last.sprite.srcPosition.y, 651);
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawColor(const ui.Color(0xFF172A23), ui.BlendMode.src);
      for (var row = 0; row < 4; row++) {
        final key = [
          AnimKey.spawn,
          AnimKey.strike,
          AnimKey.cast,
          AnimKey.death,
        ][row];
        for (var col = 0; col < 4; col++) {
          final view = entry.createView();
          await view.onLoad();
          final frame = [0, 3, 6, 100][col];
          view.applySnapshot(
            EntityRenderSnapshot(
              id: 1,
              kind: EntityKind.enemy,
              enemyId: EnemyId.bringerOfDeath,
              pos: const Vec2(0, 0),
              facing: Facing.left,
              artFacingDir: Facing.left,
              anim: key,
              animFrame: frame * entry.animSet.ticksPerFrameFor(key, 60),
              grounded: true,
            ),
            tickHz: 60,
          );
          if (col == 3) {
            expect(
              view.animationTicker!.currentIndex,
              animations[key]!.frames.length - 1,
            );
          }
          view.position.setValues(140 + col * 190, 95 + row * 125);
          view.renderTree(canvas);
        }
      }
      final picture = recorder.endRecording();
      addTearDown(picture.dispose);
      final image = await picture.toImage(800, 520);
      addTearDown(image.dispose);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('build/test/bringer_animation_review.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
    },
  );
}
