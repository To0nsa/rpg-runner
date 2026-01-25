# Phase 7: Ability Input Semantics + Buffering

## Goal
Align input and activation with `ability_system_design.md`:

- Commit timing matches targeting model (tap vs hold-release).
- Single-slot input buffer during **Recovery**.
- Mobility preemption of combat abilities.
- Deterministic, slot-based input mapping.

This phase does **not** add new gameplay abilities; it upgrades input flow and
activation rules to be future-proof and scalable.

---

## Design Contracts (Non-Negotiable)

1. **Commit timing is deterministic**  
   - Tap → commit on press.  
   - Hold → commit on release.  
   - Committed-hold → commit on hold start (future extension).  

2. **Buffering rules**  
   - If pressed during **Recovery**, the newest input is buffered.  
   - Only **one** buffered input exists at a time (latest wins).  
   - Buffer expires after a short window (8–10 ticks @ 60Hz).  
   - Buffer clears on forced interruption (stun/death).

3. **Mobility preemption**  
   - Dash/jump preempt combat abilities.  
   - Combat intents scheduled during windup/active must be canceled.

4. **Aim lock for mobility**  
   - Mobility cannot start while aiming; aim must be released first.

---

## Data Model

### PlayerInputStore (Per-Tick)
Adds slot-level input signals while keeping backward compatibility:

- `projectilePressed` (unified projectile slot)
- `secondaryPressed`, `bonusPressed` (future-facing)
- `lastAbilitySlotPressed` (latest press in a tick)

Existing commands (`ProjectilePressedCommand`, `StrikePressedCommand`, `SecondaryPressedCommand`)
map into these slot signals in `GameCore.applyCommands`.

### AbilityInputBufferStore (Persistent)
Stores a **single buffered input** across ticks:

- `hasBuffered`
- `slot`
- `abilityId`
- `aimDirX`, `aimDirY`
- `facing`
- `commitTick`
- `expiresTick`

### ActiveAbilityStateStore (Persistent)
Now includes execution timing to gate input:

- `phase` (windup/active/recovery/idle)
- `windupTicks`, `activeTicks`, `recoveryTicks`, `totalTicks`
- `commitTick`

---

## Systems

### ActiveAbilityPhaseSystem
Runs every tick (after ControlLock updates), and is the single authority for
phase transitions:

- Derives `phase` from `(currentTick - commitTick)` and per-ability timings.
- Clears `ActiveAbilityState` when total duration completes.
- Clears buffered input on forced interruption (stun/death).

### AbilityActivationSystem
Responsible for **combat + mobility input**:

- Reads slot presses from `PlayerInputStore`.
- If **busy**:
  - During **Recovery** → buffer latest input.
  - Otherwise → ignore input.
- If **idle**:
  - Prefer latest press this tick.
  - If no press and buffer exists → commit buffered action.

It writes into existing intent stores:

- `MeleeIntent` for melee abilities
- `ProjectileIntent` for projectile abilities (spells + throws)
- `MobilityIntent` for mobility abilities (dash/roll/jump)

### MobilitySystem (Mobility)
Maintains mobility preemption rules:

- If dash starts, clear pending combat intents and replace `ActiveAbilityState`.
- Dash is blocked while aiming (projectile/melee aim active).
 - Jump intents are executed in `PlayerMovementSystem` (buffer/coyote aware).

---

## Input/Router Alignment

The Core consumes **commit events** (pressed commands). The input layer chooses
the commit timing that matches the ability’s targeting model:

- **Tap:** enqueue press immediately.
- **Hold-release:** enqueue press on release (with aim committed in the same tick).
