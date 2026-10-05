import 'dart:math' as math;

import '../../combat/actor_hurtbox_catalog.dart';
import '../../combat/actor_combat_pose.dart';
import '../../combat/combat_geometry.dart';
import '../../contracts/render_anim_set_definition.dart';
import '../../enemies/enemy_catalog.dart';
import '../../npcs/npc_catalog.dart';
import '../../players/characters/eloise.dart';
import '../../collision/terrain/terrain_numeric.dart';
import '../collider_aabb_utils.dart';
import '../actor_facing.dart';
import '../../snapshots/enums.dart';
import '../world.dart';

/// Resolves visible body poses before broadphase. It never changes terrain
/// colliders, placement, movement capability or navigation signatures.
final class CombatHurtboxSystem {
  const CombatHurtboxSystem({
    required this.tickHz,
    this.playerRenderAnim = eloiseRenderAnim,
  });
  final int tickHz;
  final RenderAnimSetDefinition playerRenderAnim;

  void step(EcsWorld world) {
    final poses = world.animState;
    for (var i = 0; i < poses.denseEntities.length; i++) {
      final actor = poses.denseEntities[i];
      final ci = world.worldContactCapsule.tryIndexOf(actor);
      if (ci == null) continue;
      final ei = world.enemy.tryIndexOf(actor);
      final ni = world.npc.tryIndexOf(actor);
      final anim = poses.anim[i];
      final render = ei != null
          ? const EnemyCatalog().get(world.enemy.enemyId[ei]).renderAnim
          : ni != null
          ? const NpcCatalog().get(world.npc.npcId[ni]).renderAnim
          : playerRenderAnim;
      final stepTicks = math.max(
        1,
        ((render.stepTimeSecondsByKey[anim] ?? .1) * tickHz).round(),
      );
      final frame = poses.animFrame[i] ~/ stepTicks;
      var capsule = ei != null
          ? ActorHurtboxCatalog.enemy(world.enemy.enemyId[ei], anim, frame)
          : ni != null
          ? ActorHurtboxCatalog.npc(world.npc.npcId[ni], anim, frame)
          : ActorHurtboxCatalog.player(anim, frame);
      if (capsule == null) {
        final scale = terrainPhysicsTicksPerWorldUnit.toDouble();
        final c = world.worldContactCapsule;
        final x = c.offsetXTicks[ci] / scale;
        final y = c.offsetYTicks[ci] / scale;
        final spine = c.verticalHalfSegmentTicks[ci] / scale;
        capsule = CombatCapsule(
          x,
          y - spine,
          x,
          y + spine,
          c.radiusTicks[ci] / scale,
        );
      }
      final angle = actorCombatPoseAngle(world, actor, anim);
      final mirror = ei == null && ni == null && anim == AnimKey.backStrike
          ? (actorFacing(world, actor) == Facing.left ? 1.0 : -1.0)
          : colliderFacingSign(world, actor).toDouble();
      world.combatHurtbox.set(
        actor,
        capsule.transformed(mirror: mirror, angle: angle),
        angle: angle,
      );
    }
  }
}
