import '../../combat/status/status.dart';
import '../stores/self_intent_store.dart';
import '../world.dart';

/// Executes self abilities (parry, block, buffs) based on committed intents.
///
/// **Execution Only**:
/// - Reads committed intents (`tick == currentTick`).
/// - Applies effects (e.g., healing, buffs).
/// - Does **not** deduct resources or start cooldowns.
class SelfAbilitySystem {
  void step(
    EcsWorld world, {
    required int currentTick,
    void Function(StatusRequest request)? queueStatus,
  }) {
    final intents = world.selfIntent;
    if (intents.denseEntities.isEmpty) return;

    final count = intents.denseEntities.length;
    for (var ii = 0; ii < count; ii += 1) {
      final executeTick = intents.tick[ii];

      if (executeTick != currentTick) continue;

      if (queueStatus != null) {
        final profileId = intents.selfStatusProfileId[ii];
        if (profileId != StatusProfileId.none) {
          queueStatus(
            StatusRequest(
              target: intents.denseEntities[ii],
              profileId: profileId,
            ),
          );
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
