import 'dart:ui' as ui;

import 'package:flame/cache.dart';
import 'package:runner_core/enemies/enemy_catalog.dart';
import 'package:runner_core/enemies/enemy_id.dart';

import '../../game/components/sprite_anim/strip_animation_loader.dart';

/// Rasterizes only the catalog's first idle preview frame. Sheets are temporary;
/// the menu owner retains a small, alpha-trimmed image instead of entire atlases.
Future<ui.Image> loadEnemyPortrait(EnemyId id) async {
  final images = Images();
  try {
    final archetype = const EnemyCatalog().get(id);
    final def = archetype.renderAnim;
    final key = archetype.previewAnimKey;
    final frames = def.sourceFramesByKey[key];
    final parts = def.compositeFramesByKey[key];
    final set = await loadStripAnimations(
      images,
      frameWidth: def.frameWidth,
      frameHeight: def.frameHeight,
      sourcesByKey: {key: def.sourcesByKey[key]!},
      anchorPoint: def.anchorPoint,
      rowByKey: def.rowByKey,
      frameStartByKey: def.frameStartByKey,
      gridColumnsByKey: def.gridColumnsByKey,
      sourceFramesByKey: {
        if (frames != null) key: [frames.first],
      },
      compositeFramesByKey: {
        if (parts != null) key: [parts.first],
      },
      frameCountsByKey: {key: 1},
      stepTimeSecondsByKey: def.stepTimeSecondsByKey,
      oneShotKeys: {key},
    );
    final recorder = ui.PictureRecorder();
    set.animations[key]!.frames.first.sprite.render(ui.Canvas(recorder));
    final picture = recorder.endRecording();
    late final ui.Image frame;
    try {
      frame = await picture.toImage(def.frameWidth, def.frameHeight);
    } finally {
      picture.dispose();
    }
    try {
      return await _trimFrame(frame);
    } finally {
      frame.dispose();
    }
  } finally {
    images.clearCache();
  }
}

Future<ui.Image> _trimFrame(ui.Image frame) async {
  final data = await frame.toByteData(format: ui.ImageByteFormat.rawRgba);
  if (data == null) throw StateError('Cannot read enemy preview pixels.');
  var left = frame.width;
  var top = frame.height;
  var right = -1;
  var bottom = -1;
  for (var y = 0; y < frame.height; y++) {
    for (var x = 0; x < frame.width; x++) {
      if (data.getUint8((y * frame.width + x) * 4 + 3) == 0) continue;
      if (x < left) left = x;
      if (x > right) right = x;
      if (y < top) top = y;
      if (y > bottom) bottom = y;
    }
  }
  if (right < left) throw StateError('Enemy preview frame is empty.');
  final width = right - left + 1;
  final height = bottom - top + 1;
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawImageRect(
    frame,
    ui.Rect.fromLTWH(
      left.toDouble(),
      top.toDouble(),
      width.toDouble(),
      height.toDouble(),
    ),
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    ui.Paint()..filterQuality = ui.FilterQuality.none,
  );
  final picture = recorder.endRecording();
  try {
    return await picture.toImage(width, height);
  } finally {
    picture.dispose();
  }
}
