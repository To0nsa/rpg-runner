import '../stores/hitbox_store.dart';
import '../stores/lifetime_store.dart';
import '../world.dart';

/// Processes requests to perform melee strikes.
///
/// **Responsibilities**:
/// *   Consumes committed melee intents created by input or enemy AI.
/// *   **Execution only**: converts `tick == currentTick` intents into ephemeral hitbox entities.
/// *   Spawns the actual "Hitbox" entity that performs collision checks (+ HitOnce + Lifetime).
/// *   Invalidates the intent immediately to prevent double execution in the same tick.
///
/// **Not responsible for**:
/// - Resource deduction (mana/stamina), cooldown start, or commit gating.
///   Those are handled at commit-time (e.g. AbilityActivationSystem / enemy commit logic).
///
/// **Workflow**:
/// 1. Filter intents that match the [currentTick] (synchronization via stamped execute tick).
/// 2. Invalidate the intent (so multi-pass in the same tick can’t double-spawn).
/// 3. Validate attacker existence + basic state (e.g. stunned checks).
/// 4. Spawn hitbox entity:
///    - Transform at attacker position
///    - HitboxDef from intent fields
///    - HitOnce marker
///    - LifetimeDef based on active window ticks
class MeleeStrikeSystem {
  /// Runs the system logic.
  ///
  /// [currentTick] is required to ensure we only process intents generated for THIS frame,
  /// preserving determinism.
  void step(EcsWorld world, {required int currentTick}) {
    final intents = world.meleeIntent;
    if (intents.denseEntities.isEmpty) return;

    // Iterate through all intents.
    for (var ii = 0; ii < intents.denseEntities.length; ii += 1) {
      final strikeer = intents.denseEntities[ii];

      final executeTick = intents.tick[ii];

      if (executeTick != currentTick) continue;

      // Invalidate now so accidental multi-pass execution in the same tick cannot
      // double-strike. (Intent is still ignored next tick due to stamp mismatch.)
      intents.tick[ii] = -1;
      intents.commitTick[ii] = -1;

      // -- Validation & Resource Checks --

      // Attacker must exist physically.
      final strikeerTi = world.transform.tryIndexOf(strikeer);
      if (strikeerTi == null) continue;

      // Cannot strike while stunned.
      if (world.controlLock.isStunned(strikeer, currentTick)) continue;

      // Attacker must have a faction to determine who they hit.
      final fi = world.faction.tryIndexOf(strikeer);
      if (fi == null) continue;
      final faction = world.faction.faction[fi];

      // -- Execution --

      // Spawn the hitbox.
      final hitbox = world.createEntity();
      world.transform.add(
        hitbox,
        // HitboxFollowOwnerSystem will position from `owner + offset`.
        // Initialize at owner's position to prevent 1-frame visual glitch.
        posX: world.transform.posX[strikeerTi],
        posY: world.transform.posY[strikeerTi],
        velX: 0.0,
        velY: 0.0,
      );
      world.hitbox.add(
        hitbox,
        HitboxDef(
          owner: strikeer,
          faction: faction,
          damage100: intents.damage100[ii],
          critChanceBp: intents.critChanceBp[ii],
          damageType: intents.damageType[ii],
          procs: intents.procs[ii],
          halfX: intents.halfX[ii],
          halfY: intents.halfY[ii],
          offsetX: intents.offsetX[ii],
          offsetY: intents.offsetY[ii],
          dirX: intents.dirX[ii],
          dirY: intents.dirY[ii],
        ),
      );
      // Ensure hitbox only hits things once.
      world.hitOnce.add(hitbox);
      // Hitbox is ephemeral.
      world.lifetime.add(
        hitbox,
        LifetimeDef(ticksLeft: intents.activeTicks[ii]),
      );
    }
  }
}
