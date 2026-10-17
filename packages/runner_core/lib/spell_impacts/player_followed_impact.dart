import '../ecs/collider_aabb_utils.dart';
import '../ecs/entity_id.dart';
import '../ecs/world.dart';
import '../events/game_event.dart';
import '../util/vec2.dart';
import 'spell_impact_id.dart';

/// Anchors a non-damaging effect to the player's current collider feet.
/// The captured position remains a fallback if the player view disappears.
SpellImpactEvent? playerFollowedImpact(
  EcsWorld world, {
  required EntityId player,
  required int tick,
  required SpellImpactId impactId,
}) {
  final ti = world.transform.tryIndexOf(player);
  if (ti == null) return null;
  final ci = world.colliderAabb.tryIndexOf(player);
  final offset = ci == null
      ? Vec2.zero
      : Vec2(
          world.colliderAabb.offsetX[ci] * colliderFacingSign(world, player),
          world.colliderAabb.offsetY[ci] + world.colliderAabb.halfY[ci],
        );
  return SpellImpactEvent(
    tick: tick,
    impactId: impactId,
    pos: Vec2(
      world.transform.posX[ti] + offset.x,
      world.transform.posY[ti] + offset.y,
    ),
    followEntityId: player,
    followOffset: offset,
  );
}
