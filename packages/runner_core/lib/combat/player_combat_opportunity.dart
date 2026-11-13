import 'dart:math' as math;

import '../abilities/ability_catalog.dart';
import '../abilities/ability_def.dart';
import '../ecs/entity_id.dart';
import '../ecs/hit/capsule_hit_utils.dart';
import '../ecs/world.dart';
import '../projectiles/projectile_catalog.dart';
import '../snapshots/combat_opportunity_snapshot.dart';
import '../snapshots/enums.dart';

/// Side-effect-free guidance query. No input, damage, aim or AI is changed.
/// Melee tests authored active blade capsules against the current body capsule;
/// projectile admission requires lifetime reach and a clear terrain sightline.
CombatOpportunitySnapshot? playerCombatOpportunity(
  EcsWorld world, {
  required EntityId player,
  required EntityId? target,
  required bool Function(double, double, double, double) pathClear,
}) {
  if (target == null || world.deathState.has(target)) return null;
  final hi = world.health.tryIndexOf(target);
  final ti = world.transform.tryIndexOf(target);
  final pi = world.transform.tryIndexOf(player);
  final li = world.equippedLoadout.tryIndexOf(player);
  if (hi == null ||
      ti == null ||
      pi == null ||
      li == null ||
      world.health.hp[hi] <= 0) {
    return null;
  }
  final x = world.transform.posX[ti], y = world.transform.posY[ti];
  final px = world.transform.posX[pi], py = world.transform.posY[pi];
  final dx = x - px, dy = y - py;
  final loadout = world.equippedLoadout;
  final primary = AbilityCatalog.shared.resolve(loadout.abilityPrimaryId[li]);
  final delivery = primary?.hitDelivery;
  final hurtIndex = world.combatHurtbox.tryIndexOf(target);
  final hurt = hurtIndex == null
      ? null
      : world.combatHurtbox.capsule[hurtIndex];
  var melee = false;
  if (delivery is MeleeHitDelivery && hurt != null) {
    final profile = delivery.profile;
    final facing = dx < 0 ? Facing.left : Facing.right;
    final mirror = facing == profile.artFacing ? 1.0 : -1.0;
    // Homing melee rotates its blade toward the target at commit.
    final angle = math.atan2(dy, dx) - (facing == Facing.left ? math.pi : 0);
    for (
      var i = profile.timing.activeStart;
      i < profile.timing.activeEnd;
      i++
    ) {
      for (final capsule in profile.frames[i]) {
        final blade = capsule.transformed(mirror: mirror, angle: angle);
        if (capsulesOverlap(
          firstAx: px + blade.ax,
          firstAy: py + blade.ay,
          firstBx: px + blade.bx,
          firstBy: py + blade.by,
          firstRadius: blade.radius,
          secondAx: x + hurt.ax,
          secondAy: y + hurt.ay,
          secondBx: x + hurt.bx,
          secondBy: y + hurt.by,
          secondRadius: hurt.radius,
        )) {
          melee = true;
          break;
        }
      }
      if (melee) break;
    }
  }
  final projectile = const ProjectileCatalog().get(
    loadout.projectileSlotSpellId[li],
  );
  final reach = projectile.speedUnitsPerSecond * projectile.lifetimeSeconds;
  final ai = world.activeAbility.tryIndexOf(player);
  return CombatOpportunitySnapshot(
    entityId: target,
    targetStationary:
        world.transform.velX[ti] == 0 && world.transform.velY[ti] == 0,
    x: x,
    y: y,
    playerIdle: ai == null || world.activeAbility.abilityId[ai] == null,
    inMeleeReach: melee,
    inProjectileReach:
        dx * dx + dy * dy <= reach * reach && pathClear(px, py, x, y),
  );
}
