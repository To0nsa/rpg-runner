import 'dart:io';
import 'dart:ui' as ui;

import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runner_core/interactions/world_interaction_catalog.dart';
import 'package:runner_core/interactions/world_interaction_render_catalog.dart';
import 'package:runner_core/snapshots/world_interaction_snapshot.dart';
import 'package:rpg_runner/game/components/interactions/world_interaction_render_registry.dart';
import 'package:rpg_runner/game/components/interactions/world_interaction_render_system.dart';
import 'package:rpg_runner/game/components/static_prefab_sprite_component.dart';
import 'package:runner_core/players/player_character_registry.dart';

import '../../packages/runner_core/test/test_support/world_interaction_run_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('fire mounts from persistent state, samples ticks, and retires', (
    tester,
  ) async {
    final images = Images();
    final registry = WorldInteractionRenderRegistry();
    await tester.runAsync(() => registry.load(images));
    final game = FlameGame();
    final views = WorldInteractionRenderSystem(
      world: game.world,
      registry: registry,
    );
    await tester.pumpWidget(GameWidget(game: game));
    await tester.runAsync(() => game.loaded);
    const id = WorldInteractionId.regenerationShrine;
    final def = WorldInteractionRenderCatalog.get(id);
    WorldInteractionSnapshot snapshot({bool active = true, int elapsed = 0}) =>
        WorldInteractionSnapshot(
          instanceId: '2:shrine',
          interactionId: id,
          x: 60,
          y: 60,
          scale: 1,
          zIndex: 1,
          active: active,
          elapsedTicks: elapsed,
        );
    views.sync(
      [snapshot(active: false)],
      tickHz: 60,
      cameraCenter: Vector2.zero(),
    );
    await tester.pump();
    expect(game.world.children.whereType<SpriteComponent>(), isEmpty);
    for (final hz in [30, 60, 120]) {
      for (var frame = 0; frame < 4; frame++) {
        views.sync(
          [snapshot(elapsed: frame * hz ~/ 10)],
          tickHz: hz,
          cameraCenter: Vector2.zero(),
        );
        await tester.pump();
        game.update(0);
        final view = game.world.children.whereType<SpriteComponent>().single;
        expect(view.sprite, same(registry.frame(id, frame)));
        expect(view.position, Vector2(60, 61));
        expect(view.priority, -4);
        expect(view.size.x, closeTo(26.8, 0.001));
        expect(view.anchor.x, def.anchor.x / def.source.width);
        game.update(12);
        expect(
          view.sprite,
          same(registry.frame(id, frame)),
          reason: 'Renderer elapsed time cannot animate a paused snapshot.',
        );
      }
    }
    views.sync([], tickHz: 60, cameraCenter: Vector2.zero());
    await tester.pump();
    game.update(0);
    expect(game.world.children.whereType<SpriteComponent>(), isEmpty);
    views.sync(
      [snapshot(elapsed: 18)],
      tickHz: 60,
      cameraCenter: Vector2.zero(),
    );
    await tester.pump();
    game.update(0);
    expect(
      game.world.children.whereType<SpriteComponent>().single.sprite,
      same(registry.frame(id, 3)),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    images.clearCache();
  });

  testWidgets('fire anchor aligns with the actual generated vasque sprite', (
    tester,
  ) async {
    final core = worldInteractionRunCore(PlayerCharacterRegistry.eloise);
    for (
      var i = 0;
      i < 120 && core.buildSnapshot().hud.blessings.isEmpty;
      i++
    ) {
      core.stepOneTick();
    }
    final snapshot = core.buildSnapshot();
    final shrine = snapshot.interactions.firstWhere((i) => i.active);
    final bowl = snapshot.staticPrefabSprites.singleWhere(
      (s) =>
          (s.x + s.width / 2 - shrine.x).abs() < 1 &&
          (s.y - shrine.y).abs() < 2,
    );
    final game = FlameGame();
    await tester.pumpWidget(GameWidget(game: game));
    await tester.runAsync(() => game.loaded);
    final registry = WorldInteractionRenderRegistry();
    await tester.runAsync(() => registry.load(game.images));
    final bowlView = StaticPrefabSpriteComponent(
      assetPath: bowl.assetPath,
      srcRect: ui.Rect.fromLTWH(
        bowl.srcX.toDouble(),
        bowl.srcY.toDouble(),
        bowl.srcWidth.toDouble(),
        bowl.srcHeight.toDouble(),
      ),
      position: Vector2(bowl.x, bowl.y),
      size: Vector2(bowl.width, bowl.height),
    )..priority = -5 + bowl.zIndex;
    game.world.add(bowlView);
    await tester.pump();
    await tester.runAsync(() => bowlView.loaded);
    final views = WorldInteractionRenderSystem(
      world: game.world,
      registry: registry,
    );
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder)
      ..drawColor(const ui.Color(0xff19232d), ui.BlendMode.src);
    for (var frame = 0; frame < 4; frame++) {
      views.sync(
        [
          WorldInteractionSnapshot(
            instanceId: shrine.instanceId,
            interactionId: shrine.interactionId,
            x: shrine.x,
            y: shrine.y,
            scale: shrine.scale,
            zIndex: shrine.zIndex,
            active: true,
            elapsedTicks: frame * 6,
          ),
        ],
        tickHz: 60,
        cameraCenter: Vector2.zero(),
      );
      await tester.pump();
      game.update(0);
      canvas.save();
      canvas.translate(64 + frame * 128 - shrine.x, 60 - shrine.y);
      bowlView.renderTree(canvas);
      game.world.children.whereType<SpriteComponent>().single.renderTree(
        canvas,
      );
      canvas.restore();
    }
    final picture = recorder.endRecording();
    await tester.runAsync(() async {
      final image = await picture.toImage(512, 110);
      final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      await Directory('.tmp').create(recursive: true);
      await File('.tmp/interaction_vasque_preview.png')
          .writeAsBytes(bytes.buffer.asUint8List());
      image.dispose();
    });
    picture.dispose();
    expect(bowlView.isMounted, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('common crop contains every nontransparent pixel of all four sources', () async {
    final registry = WorldInteractionRenderRegistry();
    final images = Images();
    await registry.load(images);
    final def = WorldInteractionRenderCatalog.get(
      WorldInteractionId.regenerationShrine,
    );
    for (var i = 0; i < 4; i++) {
      final sprite = registry.frame(WorldInteractionId.regenerationShrine, i);
      final bytes = (await sprite.image.toByteData())!;
      var opaque = 0;
      for (var y = 0; y < sprite.image.height; y++) {
        for (var x = 0; x < sprite.image.width; x++) {
          if (bytes.getUint8((y * sprite.image.width + x) * 4 + 3) == 0) {
            continue;
          }
          opaque++;
          expect(
            x >= def.source.x &&
                x < def.source.x + def.source.width &&
                y >= def.source.y &&
                y < def.source.y + def.source.height,
            isTrue,
          );
        }
      }
      expect(opaque, greaterThan(0));
    }
    // Save a review artifact using the same source crop/pivot as the renderer.
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder)
      ..drawColor(const ui.Color(0xff19232d), ui.BlendMode.src);
    for (var i = 0; i < 4; i++) {
      registry
          .frame(WorldInteractionId.regenerationShrine, i)
          .render(
            canvas,
            position: Vector2(15 + i * 70, 10),
            size: Vector2(53.6, 62.4),
          );
    }
    final picture = recorder.endRecording();
    final preview = await picture.toImage(290, 85);
    final bytes = (await preview.toByteData(format: ui.ImageByteFormat.png))!;
    await Directory('.tmp').create(recursive: true);
    await File('.tmp/interaction_fire_preview.png')
        .writeAsBytes(bytes.buffer.asUint8List());
    preview.dispose();
    picture.dispose();
    images.clearCache();
  });
}
