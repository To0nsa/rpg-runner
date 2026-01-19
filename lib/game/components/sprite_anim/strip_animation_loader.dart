/// Shared sprite-strip animation loader utilities (render layer only).
library;

import 'dart:ui';

import 'package:flame/cache.dart';
import 'package:flame/components.dart';

import '../../../core/contracts/render_anim_set_definition.dart';
import '../../../core/snapshots/enums.dart';
import '../../../core/util/vec2.dart';
import 'sprite_anim_set.dart';

Future<SpriteAnimSet> loadStripAnimations(
  Images images, {
  required int frameWidth,
  required int frameHeight,
  required Map<AnimKey, String> sourcesByKey,
  Map<AnimKey, int> rowByKey = const <AnimKey, int>{},
  Vec2? anchorInFramePx,
  required Map<AnimKey, int> frameCountsByKey,
  required Map<AnimKey, double> stepTimeSecondsByKey,
  required Set<AnimKey> oneShotKeys,
}) async {
  final frameSize = Vector2(frameWidth.toDouble(), frameHeight.toDouble());

  final anchor = switch (anchorInFramePx) {
    null => Anchor.center,
    final a => () {
      assert(
        a.x >= 0 && a.x <= frameWidth,
        'anchorInFramePx.x must be in [0, $frameWidth] (got ${a.x}).',
      );
      assert(
        a.y >= 0 && a.y <= frameHeight,
        'anchorInFramePx.y must be in [0, $frameHeight] (got ${a.y}).',
      );
      return Anchor(a.x / frameWidth, a.y / frameHeight);
    }(),
  };

  final keysByPath = <String, List<AnimKey>>{};
  for (final entry in sourcesByKey.entries) {
    keysByPath.putIfAbsent(entry.value, () => <AnimKey>[]).add(entry.key);
  }

  // Load each unique path once (Images also caches globally, but this keeps the
  // loader itself allocation-light and predictable).
  final imagesByPath = <String, Image>{};
  for (final path in keysByPath.keys) {
    imagesByPath[path] = await images.load(path);
  }

  final animations = <AnimKey, SpriteAnimation>{};
  for (final entry in sourcesByKey.entries) {
    final key = entry.key;
    final path = entry.value;
    final img = imagesByPath[path]!;

    final stepTime =
        stepTimeSecondsByKey[key] ?? stepTimeSecondsByKey[AnimKey.idle] ?? 0.1;
    final frameCount =
        frameCountsByKey[key] ?? frameCountsByKey[AnimKey.idle] ?? 1;
    final row = rowByKey[key] ?? 0;

    final sprites = List<Sprite>.generate(frameCount, (i) {
      return Sprite(
        img,
        srcPosition: Vector2(
          frameWidth.toDouble() * i,
          frameHeight.toDouble() * row,
        ),
        srcSize: frameSize,
      );
    });

    animations[key] = SpriteAnimation.spriteList(
      sprites,
      stepTime: stepTime,
      loop: !oneShotKeys.contains(key),
    );
  }

  return SpriteAnimSet(
    animations: animations,
    stepTimeSecondsByKey: stepTimeSecondsByKey,
    oneShotKeys: oneShotKeys,
    frameSize: frameSize,
    anchor: anchor,
  );
}

Future<SpriteAnimSet> loadAnimSetFromDefinition(
  Images images, {
  required RenderAnimSetDefinition renderAnim,
  required Set<AnimKey> oneShotKeys,
}) async {
  final animSet = await loadStripAnimations(
    images,
    frameWidth: renderAnim.frameWidth,
    frameHeight: renderAnim.frameHeight,
    sourcesByKey: renderAnim.sourcesByKey,
    rowByKey: renderAnim.rowByKey,
    anchorInFramePx: renderAnim.anchorInFramePx,
    frameCountsByKey: renderAnim.frameCountsByKey,
    stepTimeSecondsByKey: renderAnim.stepTimeSecondsByKey,
    oneShotKeys: oneShotKeys,
  );

  // Default spawn to idle when no dedicated strip exists.
  animSet.animations[AnimKey.spawn] ??= animSet.animations[AnimKey.idle]!;

  return animSet;
}
