/// Reusable helper for syncing AABB debug overlays from Core snapshots.
library;

import 'package:flame/components.dart';
import 'package:flutter/widgets.dart';

import '../../core/snapshots/entity_render_snapshot.dart';

void syncDebugAabbOverlays({
  required Iterable<EntityRenderSnapshot> entities,
  required bool enabled,
  required Component parent,
  required Map<int, RectangleComponent> pool,
  required int priority,
  required Paint paint,
  bool Function(EntityRenderSnapshot e)? include,
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

    view.position.setValues(e.pos.x.roundToDouble(), e.pos.y.roundToDouble());
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

