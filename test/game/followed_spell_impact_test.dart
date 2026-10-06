import 'dart:io';
import 'dart:ui' as ui;

import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/game/components/camera_space_snapped_sprite_animation.dart';
import 'package:rpg_runner/game/components/player/player_animations.dart';
import 'package:rpg_runner/game/components/player/player_view.dart';
import 'package:rpg_runner/game/components/projectiles/projectile_render_registry.dart';
import 'package:rpg_runner/game/components/spell_impacts/spell_impact_render_registry.dart';
import 'package:rpg_runner/game/feedback/followed_spell_impact_position.dart';
import 'package:rpg_runner/game/runner_flame/camera_shake_controller.dart';
import 'package:rpg_runner/game/runner_flame/event_feedback_system.dart';
import 'package:rpg_runner/game/tuning/combat_feedback_tuning.dart';
import 'package:runner_core/events/game_event.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:runner_core/snapshots/entity_render_snapshot.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/spell_impacts/spell_impact_id.dart';
import 'package:runner_core/util/vec2.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'live and ghost attachments interpolate the same player foot position',
    () {
      const event = SpellImpactEvent(
        tick: 100,
        impactId: SpellImpactId.holyBlessing,
        pos: Vec2(100, 224),
        followEntityId: 7,
        followOffset: Vec2(0, 24),
      );
      final previous = _entity(100, 200), current = _entity(140, 180);
      final sampled = followedSpellImpactPosition(
        event,
        entities: [current],
        previousById: {7: previous},
        alpha: .5,
      );
      expect(sampled, const Vec2(120, 214));
      expect(
        followedSpellImpactPosition(
          event,
          entities: [],
          previousById: {7: previous},
          alpha: 1,
        ),
        isNull,
      );
      expect(
        followedSpellImpactPosition(
          const SpellImpactEvent(
            tick: 100,
            impactId: SpellImpactId.fireExplosion,
            pos: Vec2(100, 224),
          ),
          entities: [current],
          previousById: {7: previous},
          alpha: .5,
        ),
        isNull,
      );
    },
  );

  test(
    'Holy strip is preloaded and attachment moves without restarting animation',
    () async {
      final images = Images();
      addTearDown(images.clearCache);
      final registry = SpellImpactRenderRegistry();
      expect(
        registry.assetPaths,
        contains('entities/effects/blessings/holy_02.png'),
      );
      await registry.load(images);
      final entry = registry.entryFor(SpellImpactId.holyBlessing)!;
      final anim = entry.animSet.animations[AnimKey.hit]!;
      expect(anim.frames, hasLength(16));
      expect(anim.frames.first.sprite.srcPosition, Vector2.zero());
      expect(anim.frames.last.sprite.srcPosition, Vector2(720, 0));
      expect(entry.animSet.anchorFor(AnimKey.hit), Anchor.bottomCenter);
      expect(entry.renderScale, Vector2.all(2));
      var pos = const Vec2(120, 224);
      final component = CameraSpaceSnappedSpriteAnimation(
        animation: anim,
        size: entry.animSet.frameSize,
        worldPosX: 120,
        worldPosY: 224,
        worldPosition: () => pos,
        animationTick: () => 100,
        animationStartTick: 100,
      );
      component.snapToCamera(Vector2.zero());
      expect(component.position, Vector2(120, 224));
      pos = const Vec2(180, 190);
      component.snapToCamera(Vector2.zero());
      expect(component.position, Vector2(180, 190));
      expect(component.animationStartTick, 100);
    },
  );

  testWidgets(
    'live blessing follows motion, freezes on pause, and finishes once',
    (tester) async {
      final game = FlameGame();
      await tester.pumpWidget(GameWidget(game: game));
      await tester.runAsync(() => game.loaded);
      final impacts = SpellImpactRenderRegistry();
      await tester.runAsync(() => impacts.load(game.images));
      final feedback = RunEventFeedbackSystem(
        world: game.world,
        projectileRenderRegistry: ProjectileRenderRegistry(),
        spellImpactRenderRegistry: impacts,
        combatFeedbackTuning: const CombatFeedbackTuning(),
        cameraShakeController: CameraShakeController(),
      );
      var tick = 100;
      var foot = const Vec2(120, 224);
      feedback.handleGameEvent(
        const SpellImpactEvent(
          tick: 100,
          impactId: SpellImpactId.holyBlessing,
          pos: Vec2(120, 224),
          followEntityId: 7,
          followOffset: Vec2(0, 24),
        ),
      );
      void flush() => feedback.flushSpellImpactEvents(
        cameraCenter: Vector2.zero(),
        animationTick: () => tick,
        tickHz: 60,
        priority: 20,
        followedPosition: (_) => foot,
      );
      flush();
      await tester.runAsync(() => game.ready());
      await tester.pump();
      final view = game.world.children
          .whereType<CameraSpaceSnappedSpriteAnimation>()
          .single;
      expect(view.position, Vector2(120, 224));
      tick += 18;
      foot = const Vec2(170, 200);
      game.update(0);
      expect(view.position, Vector2(170, 200));
      expect(view.animationTicker!.currentIndex, 6);
      game.update(10);
      expect(view.animationTicker!.currentIndex, 6);
      flush();
      expect(
        game.world.children.whereType<CameraSpaceSnappedSpriteAnimation>(),
        hasLength(1),
      );
      tick = 148;
      game.update(0);
      await tester.runAsync(() => game.ready());
      await tester.pump();
      expect(
        game.world.children.whereType<CameraSpaceSnappedSpriteAnimation>(),
        isEmpty,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  test('Holy frame review preserves feet anchor and player scale', () async {
    final images = Images();
    addTearDown(images.clearCache);
    final registry = SpellImpactRenderRegistry();
    await registry.load(images);
    final entry = registry.entryFor(SpellImpactId.holyBlessing)!;
    final playerSet = await loadPlayerAnimations(
      images,
      renderAnim: PlayerCharacterRegistry.eloise.renderAnim,
    );
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawColor(const ui.Color(0xFF172A23), ui.BlendMode.src);
    for (var i = 0; i < 6; i++) {
      final player = PlayerView(animationSet: playerSet);
      await player.onLoad();
      player.applySnapshot(_entity(0, 0), tickHz: 60);
      player.position.setValues(70 + 120 * i.toDouble(), 120);
      player.renderTree(canvas);
      final effect = CameraSpaceSnappedSpriteAnimation(
        animation: entry.animSet.animations[AnimKey.hit]!,
        size: entry.animSet.frameSize.clone(),
        worldPosX: 0,
        worldPosY: 0,
        anchor: entry.animSet.anchorFor(AnimKey.hit),
      );
      effect.scale.setFrom(entry.renderScale);
      effect.position.setValues(player.position.x, player.position.y + 24);
      effect.animationTicker!.currentIndex = i * 3;
      effect.renderTree(canvas);
    }
    final picture = recorder.endRecording();
    addTearDown(picture.dispose);
    final image = await picture.toImage(740, 180);
    addTearDown(image.dispose);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('build/test/boss_blessing_review.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data!.buffer.asUint8List());
  });
}

EntityRenderSnapshot _entity(double x, double y) => EntityRenderSnapshot(
  id: 7,
  kind: EntityKind.player,
  pos: Vec2(x, y),
  facing: Facing.right,
  anim: AnimKey.run,
  grounded: false,
);
