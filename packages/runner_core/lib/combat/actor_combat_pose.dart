import 'dart:math' as math;

import '../ecs/actor_facing.dart';
import '../ecs/entity_id.dart';
import '../ecs/world.dart';
import '../snapshots/enums.dart';

/// Rotates aimed player melee art and geometry by the same committed angle.
/// Autonomous actors use upright horizontal poses, mirrored by current facing;
/// turning during a committed attack must not add a half-turn to that mirror.
/// Player back-strike art already points behind the actor.
double actorCombatPoseAngle(EcsWorld world, EntityId actor, AnimKey anim) {
  if (anim != AnimKey.strike && anim != AnimKey.backStrike) return 0;
  if (world.enemy.has(actor) || world.npc.has(actor)) return 0;
  final mi = world.meleeIntent.tryIndexOf(actor);
  final ai = world.activeAbility.tryIndexOf(actor);
  if (mi == null ||
      ai == null ||
      world.meleeIntent.abilityId[mi] != world.activeAbility.abilityId[ai]) {
    return 0;
  }
  final facing = actorFacing(world, actor) == Facing.right ? 1 : -1;
  final sourceDirection = anim == AnimKey.backStrike ? -facing : facing;
  final angle =
      math.atan2(world.meleeIntent.dirY[mi], world.meleeIntent.dirX[mi]) -
      (sourceDirection < 0 ? math.pi : 0);
  return math.atan2(math.sin(angle), math.cos(angle));
}
