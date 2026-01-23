# Phase 6: Ability-Driven Animation

## Goal
Decouple **Animation Logic** from **Specific Gameplay Systems**.
Currently, the renderer (and `AnimSystem`) calculates the current animation frame by checking disjoint fields like `lastCastTick`, `lastMeleeTick`, `lastDashTick`. This is brittle and couples visual state to the specific system that ran (e.g., throwing a knife via `PlayerRangedWeaponSystem` stamps a different field than `SpellCastSystem`).

Phase 6 introduces a unified `ActiveAbilityStateStore` that acts as the single source of truth for "what is the character doing right now?".

---

## Design Pillars

### 1. Unified State Source
A single component store (`ActiveAbilityStateStore`) holds the active capability's state, regardless of whether it's a spell, melee attack, or dash.

### 2. Phase-Based Lifecycle
Instead of raw ticks, we track the **Phase** of the action explicitly or derive it from a single `startTick` + `AbilityDef`.
- **Windup**: Pre-damage frame.
- **Active**: Damage/Effect frame.
- **Recovery**: Post-action frame (anim lock).

### 3. Ability-Defined Keys
The specific animation to play is defined by `AbilityDef.animKey` (e.g., `AnimKey.cast` vs `AnimKey.throw`), not by "which code path executed".

---

## Schema Changes

### 1. `ActiveAbilityStateStore` (New)
Replaces the disparate fields in `ActionAnimStore`.

```dart
class ActiveAbilityStateStore extends EcsStore {
  // ... boilerplate ...

  /// The ID of the ability currently controlling the character.
  /// Null (or empty string) if idle.
  final List<AbilityKey?> abilityId;

  /// The tick when this ability started execution.
  /// Used to calculate (currentTick - startTick) for generic anim frame logic.
  final List<int> startTick;
  
  // Optional: Explicit Phase tracking if we need complex transitions
  // final List<AbilityPhase> phase; 
  
  // NOTE: We don't need 'lastMeleeTick' etc. anymore.
}
```

### 2. `ActionAnimStore` (Deprecation)
The following fields will be **removed** after migration:
- `lastMeleeTick`
- `lastCastTick`
- `lastRangedTick`
- `lastDashTick`

*(Note: We might keep `ActionAnimStore` as a container for other things, or rename it to `ActiveAbilityStateStore` entirely.)*

---

## System Architecture Shift

### OLD (Current)
1. `PlayerCastSystem` runs checks.
2. `SpellCastSystem` executes → Stamps `ActionAnim.lastCastTick = currentTick`.
3. `AnimSystem` checks: "Is (tick - lastCastTick) < duration? Play Cast."

### NEW (Phase 6)
1. `PlayerCastSystem` (or generic `AbilityActivationSystem`) validates start.
2. **Writer System** (e.g. `AbilityExecutionSystem`) sets `ActiveAbilityState.abilityId = 'eloise.ice_bolt'`, `startTick = currentTick`.
3. `AnimSystem` reads `ActiveAbilityState`:
   - Lookup `AbilityDef` for 'eloise.ice_bolt'.
   - Get `animKey` (e.g., `cast`).
   - Calculate frame: `(currentTick - startTick) / duration`.
   - Play animation.

---

## Migration Plan

### Step 1: Scaffold the Store
Create `ActiveAbilityStateStore` and add it to `EcsWorld`. Ensure it's populated for the player at spawn (empty default).

### Step 2: Dual Write (Transitional)
Update execution systems (`SpellCastSystem`, `RangedWeaponSystem`, `MeleeStrikeSystem`, `MovementSystem`) to:
1. Keep stamping the legacy `last*Tick` (for safety).
2. **Also write** to `ActiveAbilityStateStore` (set abilityId + startTick).

### Step 3: Update `AnimSystem` (Reader)
Refactor `AnimSystem` (or `SnapshotBuilder` animation logic) to:
1. Check `ActiveAbilityStateStore.abilityId`.
2. If present, lookup `AbilityDef` from `AbilityCatalog`.
3. Use `AbilityDef.animKey` to resolve the render asset.
4. Fallback to legacy logic only if `abilityId` is null (or during transition).

### Step 4: Delete Legacy Fields
Once `AnimSystem` solely relies on the new store:
1. Remove `lastMeleeTick`, `lastCastTick`, etc.
2. Remove legacy stamping code from consumers.

---

## Validation
- **Visual Regression**: Verify animations (Melee, Cast, Dash) play exactly as before.
- **Interrupts**: Ensure starting a new ability overwrites the previous state correctly (e.g., Dash cancelling Windup).
- **Network/Replay**: The new store is strictly deterministic and serializable.
