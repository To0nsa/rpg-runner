import '../../combat/status/status.dart';
import '../../abilities/ability_catalog.dart';
import '../../abilities/ability_def.dart';
import '../stores/self_intent_store.dart';
import '../world.dart';

/// Executes self abilities (parry, block, buffs) based on committed intents.
///
/// **Execution Only**:
/// - Reads committed intents (`tick == currentTick`).
/// - Queues self status profiles (buffs/restoration/other self effects).
/// - Queues self purge profiles (cleanse effects).
/// - Does **not** deduct resources or start cooldowns.
class SelfAbilitySystem {
  SelfAbilitySystem({this.abilities = AbilityCatalog.shared, this.tickHz = 60});
  final AbilityResolver abilities;
  final int tickHz;
  void step(
    EcsWorld world, {
    required int currentTick,
    void Function(StatusRequest request)? queueStatus,
    void Function(PurgeRequest request)? queuePurge,
  }) {
    final intents = world.selfIntent;
    if (intents.denseEntities.isEmpty) return;

    final count = intents.denseEntities.length;
    for (var ii = 0; ii < count; ii += 1) {
      final executeTick = intents.tick[ii];

      if (executeTick != currentTick) continue;
      final target = intents.denseEntities[ii];
      if (world.deathState.has(target)) {
        _invalidateIntent(intents, ii);
        continue;
      }

      // Mark identity is captured at commit; a dead/despawned quarry cannot be
      // replaced by another actor while the action winds up.
      final mark = abilities.resolve(intents.abilityId[ii])?.hitDelivery;
      final quarry = intents.markTarget[ii];
      if (mark is MarkHitDelivery &&
          quarry != null &&
          world.health.has(quarry) &&
          world.health.hp[world.health.indexOf(quarry)] > 0 &&
          !world.deathState.has(quarry)) {
        world.targetMark.set(
          target,
          target: quarry,
          expiresTick: currentTick + (mark.durationTicks * tickHz / 60).ceil(),
          bonusBp: mark.bonusBp,
        );
      }
      if (queueStatus != null) {
        final profileId = intents.selfStatusProfileId[ii];
        if (profileId != StatusProfileId.none) {
          queueStatus(
            StatusRequest(
              target: target,
              profileId: profileId,
              tuning: intents.selfStatusTuning[ii],
            ),
          );
        }
      }
      if (queuePurge != null) {
        final profileId = intents.selfPurgeProfileId[ii];
        if (profileId != PurgeProfileId.none) {
          queuePurge(PurgeRequest(target: target, profileId: profileId));
        }
      }

      // Invalidate now to ensure no double-execution in same tick
      _invalidateIntent(intents, ii);
    }
  }

  void _invalidateIntent(SelfIntentStore intents, int index) {
    intents.tick[index] = -1;
    intents.commitTick[index] = -1;
  }
}
