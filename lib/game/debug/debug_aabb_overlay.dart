/// Reusable helper for syncing AABB debug overlays from Core snapshots.
library;

import 'package:flame/components.dart';
import 'package:flutter/widgets.dart';

import '../../core/snapshots/entity_render_snapshot.dart';
import '../util/math_util.dart' as math;

void syncDebugAabbOverlays({
  required Iterable<EntityRenderSnapshot> entities,
  required bool enabled,
  required Component parent,
  required Map<int, RectangleComponent> pool,
  required int priority,
  required Paint paint,
  bool Function(EntityRenderSnapshot e)? include,
  Map<int, EntityRenderSnapshot>? prevById,
  double alpha = 1.0,
  Vector2? cameraCenter,
}) {
  if (!enabled) {
    if (pool.isEmpty) return;
    for (final view in pool.values) {
      view.removeFromParent();
    }
    pool.clear();
    return;
  }

  final seen = <int>{};

  for (final e in entities) {
    if (include != null && !include(e)) continue;
    final size = e.size;
    if (size == null) continue;

    seen.add(e.id);

    var view = pool[e.id];
    if (view == null) {
      view = RectangleComponent(
        size: Vector2(size.x, size.y),
        anchor: Anchor.center,
        paint: paint,
      )..priority = priority;
      pool[e.id] = view;
      parent.add(view);
    } else {
      view.size.setValues(size.x, size.y);
    }

    final prev = prevById == null ? null : prevById[e.id];
    final prevPos = prev?.pos ?? e.pos;
    final worldX = math.lerpDouble(prevPos.x, e.pos.x, alpha);
    final worldY = math.lerpDouble(prevPos.y, e.pos.y, alpha);
    if (cameraCenter == null) {
      view.position.setValues(
        math.roundToPixels(worldX),
        math.roundToPixels(worldY),
      );
    } else {
      view.position.setValues(
        math.snapWorldToPixelsInCameraSpace1d(worldX, cameraCenter.x),
        math.snapWorldToPixelsInCameraSpace1d(worldY, cameraCenter.y),
      );
    }
  }

  if (pool.isEmpty) return;
  final toRemove = <int>[];
  for (final id in pool.keys) {
    if (!seen.contains(id)) toRemove.add(id);
  }
  for (final id in toRemove) {
    pool.remove(id)?.removeFromParent();
  }
}
