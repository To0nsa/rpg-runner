# Phase 6: Ability-Driven Action Animation

## Goal
Decouple **Action Animation** (Strike, Cast, Throw, Dash) from the specific systems that trigger them.
Currently, `AnimSystem` reconstructs the "Action" state by polling disparate fields (`lastMeleeTick`, `lastCastTick`, `dashTicksLeft`) and inferring priority. This is brittle and makes adding new actions (like "Charge" or "Channel") difficult.

Phase 6 introduces `ActiveAbilityState` as the single authoritative source for **Action Layer** animations, which feeds into the existing `AnimSignals` pipeline.

---

## Design Contracts

### 1. Layered Animation Model
Animation state is resolved by strictly layering independent state channels. **Higher layers always override lower layers.**

| Priority | Layer | Source of Truth | Example |
| :--- | :--- | :--- | :--- |
| **1** (Highest) | **Death** | `DeathStateStore` | `AnimKey.death` |
| **2** | **Stun** | `ControlLockStore` | `AnimKey.stun` |
| **3** | **Hit Reaction** | `LastDamageStore` | `AnimKey.hit` |
| **4** | **Active Action** | `ActiveAbilityStateStore` | `Strike`, `Cast`, `Dash` |
| **5** | **Locomotion** | `Movement` + `Physics` | `Run`, `Jump`, `Fall`, `Idle` |

*Note: Dash is elevated to an "Active Action" (Ability) in this model, removing the special `dashTicksLeft` check in AnimSystem.*

### 2. Active Ability Schema
The new store captures the **identity** and **context** of the currently executing ability.

```dart
class ActiveAbilityStateStore extends EcsStore {
  /// The specific Ability driving the animation.
  /// Null if no ability is active.
  final List<AbilityKey?> abilityId;

  /// The tick the ability entered its current execution flow.
  /// Used for `tick - startTick` animation timing.
  final List<int> startTick;

  /// The facing direction at the moment of commitment.
  /// (Some animations lock facing, others might update).
  final List<Facing> facing;

  /// Optional: Quantized aim direction for multi-directional sprites (Phase 7).
  final List<int> aimDir;
  
  // Note: 'Phase' (Windup/Active/Recovery) is derived from (currentTick - startTick) + AbilityDef.
}
```

### 3. Concurrency & Cancellation
*   **Single Channel**: Only one "Action" ability can be active at a time.
*   **Cancellation Rules**:
    *   **Stun/Death**: Forced interrupts **clear** or **invalidate** the `ActiveAbilityState`.
    *   **Hit**: Plays a visual overlay (or override) but **does not** necessarily clear the Ability State (unless tuning says "Hits Interrupt"). *Decision: Hit Anim overrides visuals but Ability State remains valid unless stunned.*
    *   **Natural End**: The system executing the ability (e.g., `AbilityExecutionSystem`) is responsible for **clearing** `abilityId` when the `recovery` phase completes.

---

## Migration Plan

### Step 1: Scaffold `ActiveAbilityStateStore`
Add the store to `EcsWorld`. Populate default values (null ability, current facing).

### Step 2: Write to New Store (Dual Write)
Update `PlayerCastSystem`, `RangedWeaponSystem`, `MeleeStrikeSystem`, and `MobilitySystem` (Dash) to write to `ActiveAbilityStateStore` in addition to their current logic.
*   *Note: Dash was previously "implicit" in movement. We must explicitly "start" the dash ability in `ActiveAbilityState`.*

### Step 3: Update `AnimSystem` Reader
Refactor `_stepPlayer` and `_stepEnemies` to build `AnimSignals` using the new store for the **Action Layer**.

**Old Logic (Simplified):**
```dart
lastMeleeTick > 0 ? ... : (dashTicks > 0 ? ... : ...)
```

**New Logic:**
```dart
// 1. Resolve Action Layer from Ability State
AnimKey? actionAnim;
int actionFrame = 0;

if (activeAbility.has(entity)) {
  final def = abilityCatalog.get(activeAbility.id);
  // Derive phase/frame
  final elapsed = currentTick - activeAbility.startTick;
  actionAnim = def.animKey; 
  actionFrame = elapsed; // or mapped by phase
}

// 2. Pass to Signals
final signals = AnimSignals.player(
   ...,
   activeActionAnim: actionAnim, // New Field
   activeActionFrame: actionFrame, // New Field
   ...
);
```

### Step 4: Update `AnimResolver`
Update `AnimResolver` to prioritize `signals.activeActionAnim` over the legacy `lastStrikeTick` / `dashTicksLeft` logic. Consolidate "Strike", "Cast", "Ranged", "Dash" into a single **Action Priority** block.

### Step 5: Clean Up
Remove `lastMeleeTick`, `lastCastTick`, `lastRangedTick` from `ActionAnimStore`.
Remove `dashTicksLeft` usage from Animation (keep in Movement if needed for physics, or migrate strictly to Ability).

---

## Validation
1.  **Determinism**: Verify `ActiveAbilityState` serialization.
2.  **Priority**: Test `Stun > Ability`. Ensure Dash doesn't play if Stunned.
3.  **Visuals**: Verify "Strike" plays correctly using `AbilityDef.animKey` instead of hardcoded `AnimKey.strike`.
