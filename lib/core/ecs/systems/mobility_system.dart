import '../../abilities/ability_def.dart';
import '../../snapshots/enums.dart';
import '../../players/player_tuning.dart';
import '../stores/mobility_intent_store.dart';
import '../world.dart';

/// Executes mobility intents (dash/roll) and applies movement state.
///
/// Responsibilities:
/// - Validate cooldown/stamina/locks at commit.
/// - Start cooldown + ActiveAbility state on commit.
/// - Apply dash movement and gravity suppression on execute tick.
class MobilitySystem {
  void step(
    EcsWorld world,
    MovementTuningDerived tuning, {
    required int currentTick,
  }) {
    final intents = world.mobilityIntent;
    if (intents.denseEntities.isEmpty) return;

    final movements = world.movement;
    final transforms = world.transform;
    final bodies = world.body;

    final count = intents.denseEntities.length;
    for (var ii = 0; ii < count; ii += 1) {
      final entity = intents.denseEntities[ii];
      if (intents.slot[ii] == AbilitySlot.jump) {
        continue;
      }
      final executeTick = intents.tick[ii];

      if (executeTick != currentTick) continue;

      _invalidateIntent(intents, ii);

      final mi = movements.tryIndexOf(entity);
      final ti = transforms.tryIndexOf(entity);
      final bi = bodies.tryIndexOf(entity);
      if (mi == null || ti == null || bi == null) continue;
      if (!bodies.enabled[bi] || bodies.isKinematic[bi]) continue;

      final activeTicks = intents.activeTicks[ii];
      if (activeTicks <= 0) continue;

      final modifierIndex = world.statModifier.tryIndexOf(entity);
      final moveSpeedMul = modifierIndex == null
          ? 1.0
          : world.statModifier.moveSpeedMul[modifierIndex];

      final dirX = intents.dirX[ii];
      movements.dashDirX[mi] = dirX;
      movements.dashTicksLeft[mi] = activeTicks;
      movements.facing[mi] = dirX >= 0 ? Facing.right : Facing.left;

      // Cancel vertical motion and suppress gravity to keep dash horizontal.
      transforms.velY[ti] = 0;
      transforms.velX[ti] = dirX * tuning.base.dashSpeedX * moveSpeedMul;
      world.gravityControl.setSuppressForTicks(entity, activeTicks);
    }
  }

  void _invalidateIntent(MobilityIntentStore intents, int index) {
    intents.tick[index] = -1;
    intents.commitTick[index] = -1;
  }
}
