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

For the current defense holds:

- Max hold: `180` ticks at 60 Hz (3 seconds).
- Drain: `233` fixed/s (`~2.33 stamina/s`, `~7.0` over full hold).

## Input Contract

Input routers must schedule `AbilitySlotHeldCommand` continuously for held slots.

- `held: true` while pointer/button is down.
- `held: false` after release to overwrite any buffered future hold ticks.

Core resets per-tick input state, so absence of a hold command means "not held".

## Runtime Contract

`HoldAbilitySystem` runs after `ActiveAbilityPhaseSystem` each tick.

- Release while in windup/active ends hold early by forcing recovery.
- While held, stamina drains deterministically from authored per-second drain.
- Cooldown starts when hold ends (release, timeout, stamina depletion, or forced clear).
- If stamina reaches zero, hold ends and emits `AbilityHoldEndedEvent(staminaDepleted)`.
- When max hold elapses, hold ends and emits `AbilityHoldEndedEvent(timeout)`.

## UI Contract

HUD exposes `AbilityInputMode.holdMaintain` for hold abilities.

- `MeleeControl`, `BonusControl`, and Secondary slot now support hold buttons.
- UI shell listens for `AbilityHoldEndedEvent` and triggers haptics on auto-end
  through the centralized `UiHaptics` service.
