/// Shared sprite-strip animation loader utilities (render layer only).
library;

import 'dart:ui';

import 'package:flame/cache.dart';
import 'package:flame/components.dart';

import 'package:runner_core/contracts/render_anim_set_definition.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/util/vec2.dart';
import 'sprite_anim_set.dart';

Future<SpriteAnimSet> loadStripAnimations(
  Images images, {
  required int frameWidth,
  required int frameHeight,
  required Map<AnimKey, String> sourcesByKey,
  Map<AnimKey, int> rowByKey = const <AnimKey, int>{},
  required Vec2 anchorPoint,
  Map<AnimKey, int> frameStartByKey = const <AnimKey, int>{},
  Map<AnimKey, int> gridColumnsByKey = const <AnimKey, int>{},
  required Map<AnimKey, int> frameCountsByKey,
  required Map<AnimKey, double> stepTimeSecondsByKey,
  required Set<AnimKey> oneShotKeys,
}) async {
  final frameSize = Vector2(frameWidth.toDouble(), frameHeight.toDouble());

  assert(
    anchorPoint.x >= 0 && anchorPoint.x <= frameWidth,
    'anchorPoint.x must be in [0, $frameWidth] (got ${anchorPoint.x}).',
  );
  assert(
    anchorPoint.y >= 0 && anchorPoint.y <= frameHeight,
    'anchorPoint.y must be in [0, $frameHeight] (got ${anchorPoint.y}).',
  );
  final anchor = Anchor(
    anchorPoint.x / frameWidth,
    anchorPoint.y / frameHeight,
  );

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
    final startFrame = frameStartByKey[key] ?? 0;
    final gridColumns = gridColumnsByKey[key];

    assert(
      startFrame >= 0,
      'frameStartByKey[$key] must be >= 0 (got $startFrame).',
    );
    assert(
      gridColumns == null || gridColumns > 0,
      'gridColumnsByKey[$key] must be > 0 when provided.',
    );

    final sprites = List<Sprite>.generate(frameCount, (i) {
      final frameIndex = startFrame + i;
      final col = gridColumns == null ? frameIndex : frameIndex % gridColumns;
      final rowOffset = gridColumns == null ? 0 : frameIndex ~/ gridColumns;
      return Sprite(
        img,
        srcPosition: Vector2(
          frameWidth.toDouble() * col,
          frameHeight.toDouble() * (row + rowOffset),
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
    anchorPoint: renderAnim.anchorPoint,
    frameStartByKey: renderAnim.frameStartByKey,
    gridColumnsByKey: renderAnim.gridColumnsByKey,
    frameCountsByKey: renderAnim.frameCountsByKey,
    stepTimeSecondsByKey: renderAnim.stepTimeSecondsByKey,
    oneShotKeys: oneShotKeys,
  );

  // Default spawn to idle when no dedicated strip exists.
  // Some one-shot VFX sets (for example spell impacts) intentionally author
  // only AnimKey.hit, so we fall back to the first available animation.
  final idleOrFirst =
      animSet.animations[AnimKey.idle] ??
      (animSet.animations.isNotEmpty ? animSet.animations.values.first : null);
  if (idleOrFirst != null) {
    animSet.animations[AnimKey.spawn] ??= idleOrFirst;
  }

  return animSet;
}
