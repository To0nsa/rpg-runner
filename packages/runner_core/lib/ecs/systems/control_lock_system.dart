import '../world.dart';

/// Refreshes control lock masks and removes expired locks each tick.
///
/// This system should run **early** in the tick pipeline, before any
/// gameplay systems that check locks.
///
/// **Responsibilities**:
/// - Recompute [activeMask] for each entity based on current tick
/// - Remove entities from the store when all locks have expired
class ControlLockSystem {
  /// Steps the lock system, refreshing masks and cleaning up expired entries.
  void step(EcsWorld world, {required int currentTick}) {
    final store = world.controlLock;

    // Iterate backwards to safely remove while iterating
    for (int i = store.denseEntities.length - 1; i >= 0; i--) {
      final entity = store.denseEntities[i];

      // Refresh the active mask
      store.refreshMask(i, currentTick);

      // Remove entity from store if no locks are active
      if (store.activeMask[i] == 0) {
        store.removeEntity(entity);
      }
    }
  }
}
