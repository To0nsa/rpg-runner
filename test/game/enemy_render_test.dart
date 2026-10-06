import 'dart:io';
import 'dart:ui' as ui;

import 'package:flame/cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/game/components/enemies/enemy_render_registry.dart';
import 'package:rpg_runner/game/components/sprite_anim/ghost_outline_cache.dart';
import 'package:runner_core/combat/actor_combat_pose.dart';
import 'package:runner_core/ecs/stores/enemies/enemy_store.dart';
import 'package:runner_core/ecs/world.dart';
import 'package:runner_core/enemies/enemy_catalog.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/snapshots/entity_render_snapshot.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/util/vec2.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'real enemy strikes stay upright after turning in live and ghost views',
    () async {
      final images = Images();
      addTearDown(images.clearCache);
      final registry = EnemyRenderRegistry();
      await registry.load(images);
      final outlines = GhostOutlineCache();
      addTearDown(outlines.clear);
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawColor(const ui.Color(0xFF243249), ui.BlendMode.src);
      final attacks = [
        (EnemyId.grojib, 'grojib.strike', 4),
        (EnemyId.hashash, 'hashash.strike', 8),
        (EnemyId.unocoDemon, 'unoco.strike', 6),
      ];
      for (var row = 0; row < attacks.length; row++) {
        final (id, abilityId, frame) = attacks[row];
        final archetype = const EnemyCatalog().get(id);
        final entry = registry.entryFor(id)!;
        final views = [
          entry.createView(),
          entry.createView()..useGhostStyle(outlines),
        ];
        await outlines.prewarm([
          (
            entry.animSet.animations[AnimKey.strike]!.frames[frame].sprite,
            entry.animSet.frameSize,
          ),
        ], isCancelled: () => false);
        for (final view in views) {
          await view.onLoad();
        }
        for (final committedFacing in Facing.values) {
          final facing = committedFacing == Facing.left
              ? Facing.right
              : Facing.left;
          final world = EcsWorld();
          final actor = world.createEntity();
          world.enemy.add(
            actor,
            EnemyDef(
              enemyId: id,
              facing: facing,
              artFacing: archetype.artFacingDir,
            ),
          );
          world.meleeIntent.add(actor);
          final mi = world.meleeIntent.indexOf(actor);
          world.meleeIntent.abilityId[mi] = abilityId;
          world.meleeIntent.dirX[mi] = committedFacing == Facing.right ? 1 : -1;
          world.activeAbility.add(actor);
          world.activeAbility.abilityId[world.activeAbility.indexOf(actor)] =
              abilityId;
          final stepTicks =
              (archetype.renderAnim.stepTimeSecondsByKey[AnimKey.strike]! * 60)
                  .round();
          final snapshot = EntityRenderSnapshot(
            id: actor,
            kind: EntityKind.enemy,
            enemyId: id,
            pos: const Vec2(0, 0),
            facing: facing,
            artFacingDir: archetype.artFacingDir,
            anim: AnimKey.strike,
            grounded: id != EnemyId.unocoDemon,
            animFrame: frame * stepTicks,
            rotationRad: actorCombatPoseAngle(world, actor, AnimKey.strike),
          );
          for (var layer = 0; layer < views.length; layer++) {
            final view = views[layer];
            view.applySnapshot(snapshot, tickHz: 60);
            expect(view.angle, 0);
            expect(view.scale.y, archetype.renderScale);
            expect(
              view.scale.x,
              facing == archetype.artFacingDir
                  ? archetype.renderScale
                  : -archetype.renderScale,
            );
            expect(view.animationTicker!.currentIndex, frame);
            view.update(.5);
            expect(view.angle, 0);
            expect(view.animationTicker!.currentIndex, frame);
            view.position.setValues(
              110 + (committedFacing.index * 2 + layer) * 190,
              90 + row * 150,
            );
            view.renderTree(canvas);
          }
        }
      }
      final picture = recorder.endRecording();
      addTearDown(picture.dispose);
      final image = await picture.toImage(800, 470);
      addTearDown(image.dispose);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final output = File('build/test/enemy_attack_orientation.png');
      await output.parent.create(recursive: true);
      await output.writeAsBytes(bytes!.buffer.asUint8List());
    },
  );
}
