import 'dart:math' as math;

import '../../collision/terrain/terrain_numeric.dart';
import '../../abilities/ability_def.dart';
import '../../snapshots/enums.dart';
import '../../terrain/water_region.dart';
import '../world.dart';

/// Classifies fluid contact before movement and refreshes it after integration.
///
/// Uses the facing-aware capsule centre column and quantized vertical extent.
/// Lateral grazing does not start swimming. Half-open X bounds keep adjoining
/// pools continuous. Maximum immersion wins if streamed pools share a boundary;
/// results do not depend on iteration order. This system never moves actors.
class WaterImmersionSystem {
  void step(EcsWorld world, Iterable<WaterRegion> regions) {
    final state = world.swimState;
    for (var index = 0; index < state.denseEntities.length; index++) {
      final entity = state.denseEntities[index];
      final ti = world.transform.tryIndexOf(entity);
      final ci = world.worldContactCapsule.tryIndexOf(entity);
      final mi = world.movement.tryIndexOf(entity);
      final bi = world.body.tryIndexOf(entity);
      if (ti == null ||
          ci == null ||
          mi == null ||
          bi == null ||
          !world.body.enabled[bi] ||
          world.body.isKinematic[bi]) {
        state.setImmersion(index, 0);
        continue;
      }
      final capsule = world.worldContactCapsule;
      final facing = world.movement.facing[mi] == Facing.right ? 1 : -1;
      final x =
          physicsCoordinateToTicks(world.transform.posX[ti]) +
          capsule.offsetXTicks[ci] * facing;
      final y =
          physicsCoordinateToTicks(world.transform.posY[ti]) +
          capsule.offsetYTicks[ci];
      final halfHeight =
          capsule.radiusTicks[ci] + capsule.verticalHalfSegmentTicks[ci];
      var immersion = 0;
      for (final region in regions) {
        if (x < region.leftTicks || x >= region.rightTicks) continue;
        final depth =
            math.min(y + halfHeight, region.bottomTicks) -
            math.max(y - halfHeight, region.topTicks);
        if (depth > 0) {
          immersion = math.max(immersion, depth * 1000 ~/ (2 * halfHeight));
        }
      }
      state.setImmersion(index, immersion);
      if (state.swimming[index]) {
        final intent = world.mobilityIntent.tryIndexOf(entity);
        if (intent != null &&
            world.mobilityIntent.slot[intent] == AbilitySlot.mobility) {
          world.mobilityIntent.tick[intent] = -1;
          world.mobilityIntent.commitTick[intent] = -1;
        }
        final active = world.activeAbility.tryIndexOf(entity);
        if (active != null &&
            world.activeAbility.slot[active] == AbilitySlot.mobility) {
          world.activeAbility.clear(entity);
        }
      }
      if (state.swimming[index] && world.movement.dashTicksLeft[mi] > 0) {
        // Water ends an active dash before its next velocity write. Ordinary
        // jump/control gates remain authoritative for the following stroke.
        world.movement.dashTicksLeft[mi] = 0;
        world.gravityControl.removeEntity(entity);
      }
    }
  }
}
