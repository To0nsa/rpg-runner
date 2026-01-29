Current `canAffordJump/canAffordDash/canAffordMelee/canAffordProjectile` approach **doesn’t scale** because every new slot/ability category forces you to **add fields + wire them end-to-end** (SnapshotBuilder → Snapshot → UI). You can already see the hardcoded per-slot cost computation in `SnapshotBuilder`  and the “per-ability boolean” shape in `PlayerHudSnapshot` .

## The clean fix: model affordability per *slot*, not per *ability*

### Option A (recommended): `affordableMask` + slot-indexed arrays (fast + scalable)

Replace the N booleans with **one bitmask** keyed by a stable slot enum (Jump/Mobility/Primary/Secondary/Projectile/Bonus).

**PlayerHudSnapshot (concept)**

* `int affordableMask`  // bit i = slot i affordable
* `Int16List cooldownLeftBySlot`
* `Int16List cooldownTotalBySlot`
* `Uint8List inputModeBySlot` (or `List<AbilityInputMode>`)
* (optional) `Uint8List blockReasonBySlot` (cooldown / stamina / mana / locked)

UI then does:

* `isAffordable(slot) => (affordableMask & (1 << slot.index)) != 0`

Why this is good:

* Adding a new slot is **one enum value**, not 5 new fields.
* You can keep everything fixed-size and stable (important for determinism/networking style constraints you already apply to enums) .
* No Map allocations, no string keys, no “HUD schema explosion”.

## How to compute affordability without per-ability plumbing

In `SnapshotBuilder` you already look up the equipped ability per slot and compute its costs manually (jump/dash/melee/projectile) . Generalize that:

1. For each **slot**:

* resolve equipped ability id from `EquippedLoadoutStore`
* get `AbilityDef` from `AbilityCatalog`
* derive `staminaCost/manaCost` (defaulting to tuning if null)

2. Decide affordability:

* `hasSlotEquipped` (mask check like you do for projectile) 
* `stamina >= staminaCost && mana >= manaCost`
* optionally also factor in “cooldown remaining == 0” depending on how you define “affordable” vs “enabled”

3. Set the corresponding bit in `affordableMask`.

That avoids “demultiplying itself per ability” because the loop is slot-driven, not field-driven.

## One important design decision

Define **two separate concepts** (don’t mix them):

* **Affordable** = resources sufficient (stamina/mana)
* **Enabled** = affordable **and** cooldown == 0 **and** not locked by state (stun, etc.)

Right now your UI likely treats “disabled” as affordability OR cooldown . Keeping these separate prevents messy UI logic later.

Update docs\gdd\03_ingame_hud.md when taking care of it.
