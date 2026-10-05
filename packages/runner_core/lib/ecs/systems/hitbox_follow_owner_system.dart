import 'dart:math' as math;

import '../../combat/actor_combat_pose.dart';
import '../../combat/combat_pose_catalog.dart';
import '../../enemies/enemy_catalog.dart';
import '../../npcs/npc_catalog.dart';
import '../../players/characters/eloise.dart';
import '../../snapshots/enums.dart';
import '../actor_facing.dart';
import '../entity_id.dart';
import '../stores/hitbox_store.dart';
import '../world.dart';

/// Synchronizes the position of hitbox entities with their owners.
///
/// **Responsibilities**:
/// *   Iterate over all active hitboxes (entities with `HitboxStore`).
/// *   Retrieve the owner's current position.
/// *   Apply the hitbox's local offset (defined at spawn).
/// *   Update the hitbox's `Transform` component to match the calculated world position.
///
/// **Usage Note**:
/// This system ensures that a sword swing or projectile hitbox moves *with* the
/// character/projectile effectively. It runs every tick to prevent "hitbox drift".
class HitboxFollowOwnerSystem {
  HitboxFollowOwnerSystem({this.tickHz = 60});
  final int tickHz;
  final List<EntityId> _toDespawn = <EntityId>[];

  /// Executes the synchronization logic.
  void step(EcsWorld world, {int currentTick = 0}) {
    final hitboxes = world.hitbox;
    // Early exit if no hitboxes exist.
    if (hitboxes.denseEntities.isEmpty) return;

    _toDespawn.clear();

    for (var hi = 0; hi < hitboxes.denseEntities.length; hi += 1) {
      final hitbox = hitboxes.denseEntities[hi];

      // Safety: The hitbox entity itself must have a Transform component to be positioned.
      if (!world.transform.has(hitbox)) {
        _toDespawn.add(hitbox);
        continue;
      }

      if (hitboxes.attachment[hi] == HitboxAttachment.worldAnchor) {
        final profile = hitboxes.profile[hi];
        if (profile != null) {
          final frame =
              ((currentTick - hitboxes.spawnTick[hi]) ~/
                      hitboxes.frameStepTicks[hi])
                  .clamp(0, profile.frames.length - 1);
          hitboxes.capsules[hi] = profile.frames[frame];
        }
        continue;
      }

      final owner = hitboxes.owner[hi];

      // If the owner has been destroyed or lacks a transform,
      // we cannot position the hitbox relative to it.
      final ownerTi = world.transform.tryIndexOf(owner);
      if (ownerTi == null) {
        _toDespawn.add(hitbox);
        continue;
      }

      final profile = hitboxes.profile[hi];
      if (profile != null) {
        world.transform.setPosXY(
          hitbox,
          world.transform.posX[ownerTi],
          world.transform.posY[ownerTi],
        );
        final ai = world.animState.tryIndexOf(owner);
        final active = world.activeAbility.tryIndexOf(owner);
        // Interrupted or overridden poses have no invisible weapon damage.
        if (ai == null ||
            active == null ||
            world.activeAbility.abilityId[active] != hitboxes.abilityId[hi]) {
          hitboxes.capsules[hi] = const [];
          continue;
        }
        final anim = world.animState.anim[ai];
        if (anim != AnimKey.strike &&
            anim != AnimKey.strike2 &&
            anim != AnimKey.backStrike &&
            anim != AnimKey.ambush) {
          hitboxes.capsules[hi] = const [];
          continue;
        }
        final selected =
            anim == AnimKey.backStrike &&
                profile == CombatPoseCatalog.eloiseStrike
            ? CombatPoseCatalog.eloiseBackStrike
            : profile;
        final ei = world.enemy.tryIndexOf(owner);
        final ni = world.npc.tryIndexOf(owner);
        final render = ei != null
            ? const EnemyCatalog().get(world.enemy.enemyId[ei]).renderAnim
            : ni != null
            ? const NpcCatalog().get(world.npc.npcId[ni]).renderAnim
            : eloiseRenderAnim;
        final step = math.max(
          1,
          ((render.stepTimeSecondsByKey[anim] ?? .1) * tickHz).round(),
        );
        final frame = (world.animState.animFrame[ai] ~/ step).clamp(
          0,
          selected.frames.length - 1,
        );
        final mirror = actorFacing(world, owner) == selected.artFacing
            ? 1.0
            : -1.0;
        final angle = actorCombatPoseAngle(world, owner, anim);
        hitboxes.capsules[hi] = [
          for (final capsule in selected.frames[frame])
            capsule.transformed(mirror: mirror, angle: angle),
        ];
        continue;
      }

      // Calculate world position: Owner Position + Local Offset.
      final x = world.transform.posX[ownerTi] + hitboxes.offsetX[hi];
      final y = world.transform.posY[ownerTi] + hitboxes.offsetY[hi];

      // specific Snap behavior: We overwrite the position completely.
      // Physics forces are not applied here; it's a hard attachment.
      world.transform.setPosXY(hitbox, x, y);
    }

    for (final e in _toDespawn) {
      world.destroyEntity(e);
    }
  }
}
