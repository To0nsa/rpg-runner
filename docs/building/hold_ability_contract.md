# Hold Ability Contract

This document defines the deterministic contract for hold-to-maintain abilities.

## Scope

- Applies to abilities authored with `AbilityHoldMode.holdToMaintain`.
- Current authored abilities:
  - `eloise.sword_parry`
  - `eloise.shield_block`

## Authoring Contract

In `AbilityDef`:

- `holdMode` controls whether an ability is maintainable after commit.
- `holdStaminaDrainPerSecond100` defines stamina drain while held (`100 == 1.0/s`).
- `activeTicks` remains authored at 60 Hz and is treated as the max hold window.
- `chargeProfile` (optional) authors charged-commit tiers shared by melee and
  projectile paths using 60 Hz hold thresholds (`minHoldTicks60`) and per-tier
  tuning (damage/crit/speed/pierce).

For the current defense holds:

- Max hold: `180` ticks at 60 Hz (3 seconds).
- Drain: `233` fixed/s (`~2.33 stamina/s`, `~7.0` over full hold).

## Input Contract

Input routers send `AbilitySlotHeldCommand` on hold transitions only.

- `held: true` once when pointer/button goes down.
- `held: false` once when pointer/button is released.

Core latches slot hold state across ticks, so absence of a hold command means
"no change" (not "released").

## Charge Tracking Contract

Authoritative charged-ability timing is derived in Core from latched hold state.

- `AbilityChargeTrackingSystem` records hold start tick, live hold ticks, and
  release-duration ticks per slot.
- Commit-time charge reads Core timing, not UI stopwatch time.
- For `AbilityInputLifecycle.holdMaintain`, tier selection still samples at
  commit tick. With the default "hold-start commits immediately" input flow,
  this resolves to the first tier unless a slot is intentionally pre-held
  before commit.

## Runtime Contract

`HoldAbilitySystem` runs after `ActiveAbilityPhaseSystem` each tick.

- Release while in windup/active ends hold early by forcing recovery.
- While held, stamina drains deterministically from authored per-second drain.
- Cooldown starts when hold ends (release, timeout, stamina depletion, or forced clear).
- If stamina reaches zero, hold ends and emits `AbilityHoldEndedEvent(staminaDepleted)`.
- When max hold elapses, hold ends and emits `AbilityHoldEndedEvent(timeout)`.

## UI Contract

HUD exposes `AbilityInputMode.holdMaintain` for hold abilities.

- `MeleeControl`, `SpellControl`, and Secondary slot now support hold buttons.
- Charged projectile preview/haptics are driven from Core snapshot charge state
  (`projectileChargeActive/ticks/tier`), not local UI stopwatch timing.
- UI shell listens for `AbilityHoldEndedEvent` and triggers haptics on auto-end
  through the centralized `UiHaptics` service.
