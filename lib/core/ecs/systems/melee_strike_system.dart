import '../../snapshots/enums.dart';
import '../stores/hitbox_store.dart';
import '../stores/lifetime_store.dart';
import '../world.dart';

/// Processes requests to perform melee strikes.
///
/// **Responsibilities**:
/// *   Consumes [MeleeIntentStore] intents created by input or enemy AI.
/// *   Validates strike requirements (Cooldown, Stamina availability).
/// *   Deducts resource costs (Stamina, Cooldown Reset).
/// *   Spawns the actual "Hitbox" entity that performs collision checks.
///
/// **Workflow**:
/// 1.  Filter intents that match the [currentTick] (synchronization).
/// 2.  Validate Attacker State (Must exist, have cooldown component, etc.).
/// 3.  Check Costs (Is cooldown ready? Is there enough stamina?).
/// 4.  **Execute**:
///     *   Deduct Stamina.
///     *   Set Cooldown.
///     *   Create Hitbox entity with [HitboxDef], [HitOnce], and [LifetimeDef].
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

      final commitTick = intents.commitTick[ii];
      final executeTick = intents.tick[ii];

      // Commit stage (costs/cooldown start).
      if (commitTick == currentTick) {
        // Attacker must exist physically.
        final strikeerTi = world.transform.tryIndexOf(strikeer);
        if (strikeerTi == null) {
          intents.tick[ii] = -1;
          intents.commitTick[ii] = -1;
          continue;
        }

        // Cannot strike while stunned.
        if (world.controlLock.isStunned(strikeer, currentTick)) {
          intents.tick[ii] = -1;
          intents.commitTick[ii] = -1;
          continue;
        }

        // Attacker must respond to cooldowns.
        final ci = world.cooldown.tryIndexOf(strikeer);
        if (ci == null) {
          intents.tick[ii] = -1;
          intents.commitTick[ii] = -1;
          continue;
        }
        if (world.cooldown.meleeCooldownTicksLeft[ci] > 0) {
          intents.tick[ii] = -1;
          intents.commitTick[ii] = -1;
          continue;
        }

        // Stamina check.
        final staminaCost = intents.staminaCost100[ii];
        int? si;
        int? nextStamina;
        if (staminaCost > 0) {
          si = world.stamina.tryIndexOf(strikeer);
          if (si == null) {
            intents.tick[ii] = -1;
            intents.commitTick[ii] = -1;
            continue;
          }
          final currentStamina = world.stamina.stamina[si];
          if (currentStamina < staminaCost) {
            intents.tick[ii] = -1;
            intents.commitTick[ii] = -1;
            continue;
          }
          nextStamina = currentStamina - staminaCost;
        }

        // Phase 6: Ability state starts on commit.
        world.activeAbility.set(
          strikeer,
          id: intents.abilityId[ii],
          slot: intents.slot[ii],
          commitTick: currentTick,
          windupTicks: intents.windupTicks[ii],
          activeTicks: intents.activeTicks[ii],
          recoveryTicks: intents.recoveryTicks[ii],
          facingDir: intents.dirX[ii] >= 0 ? Facing.right : Facing.left,
        );

        if (si != null) {
          world.stamina.stamina[si] = nextStamina!;
        }
        world.cooldown.meleeCooldownTicksLeft[ci] = intents.cooldownTicks[ii];
      }

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
          damageType: intents.damageType[ii],
          statusProfileId: intents.statusProfileId[ii],
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
