import 'package:runner_core/events/game_event.dart';
import 'package:runner_core/snapshots/entity_render_snapshot.dart';
import 'package:runner_core/util/vec2.dart';

import '../util/math_util.dart';

/// Shared live/ghost attachment sampling using known snapshots only.
Vec2? followedSpellImpactPosition(
  SpellImpactEvent event, {
  required Iterable<EntityRenderSnapshot> entities,
  required Map<int, EntityRenderSnapshot> previousById,
  required double alpha,
}) {
  final id = event.followEntityId;
  if (id == null) return null;
  for (final entity in entities) {
    if (entity.id != id) continue;
    final previous = previousById[id] ?? entity;
    return Vec2(
      lerpDouble(previous.pos.x, entity.pos.x, alpha) + event.followOffset.x,
      lerpDouble(previous.pos.y, entity.pos.y, alpha) + event.followOffset.y,
    );
  }
  return null;
}
