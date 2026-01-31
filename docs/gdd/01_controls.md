# Player Controls

## 1. Goals

### Core goals

- **Two-thumb playable**: left thumb = movement, right thumb = actions.
- **No accidental casts**: directional actions require an explicit commit and must be cancelable.
- **Readable timing**: actions happen when the player intends (minimize touch jitter + input ambiguity).
- **Skill expression without complexity**: mastery comes from timing, spacing, and commitment.

### Design principles

- **Consistency by targeting model** (tap vs aim+commit).
- **Determinism**: same input sequence → same outcome (especially under multi-touch).
- **Forgiveness where it improves feel**: buffer windows for “pressed during recovery", coyote/buffer for jump.

---

## 2. Input schema overview

### Left thumb: Movement

- **Joystick, X-axis only** → continuous axis in `[-1, 1]`.
- Movement is allowed unless a **hard lock** exists (e.g., stun).

**Current implementation**
- Default is a **fixed joystick** (`FixedJoystick`): no deadzone; axis is proportional to horizontal drag, clamped to `[-1, 1]`.
- Continuous axis is scheduled ahead with a small input lead/buffer (see §7).

### Right thumb: Actions

Six action buttons/slots:

1. **Jump** (tap)
2. **Mobility** (tap or aim+commit depending on equipped ability)
3. **Primary** (tap or aim+commit depending on equipped ability)
4. **Secondary** (tap or aim+commit depending on equipped ability)
5. **Projectile** (tap or aim+commit depending on equipped ability)
6. **Bonus** (tap or aim+commit depending on equipped ability)

**Loadout slot constraints (design contract)**
- **Jump slot**: Jump abilities only.
- **Mobility slot**: Mobility abilities only.
- **Primary slot**: Primary abilities.
- **Secondary slot**: Secondary abilities.
- **Projectile slot**: Projectile abilities.
- **Bonus slot**: may contain **Primary**, **Secondary** or **Projectile**, but **never Mobility**.

> Intent: Bonus is an extra tool slot, not a second escape.

---

## 3. Targeting models (the only allowed interaction patterns)

Every ability must map to one of these models. No one-off input patterns.

### 3.1 Tap actions (instant)

Use when the ability is:
- self / forward (facing direction) / auto-aim
- meant to be high tempo, low cognitive load

Interaction:
- **Tap-down → cast** (commit on press for responsiveness)
- If blocked (cooldown/resource), show feedback and do nothing.

**Current implementation details**
- All tap abilities must trigger on **tap-down** (`onTapDown`) via `ActionButton`.

#### Facing direction

Facing direction is the player’s default cast direction when an ability has no explicit aim.

### 3.2 Aim + commit (directional)

Use when direction materially matters and you want intentional aiming.

Interaction (must be identical across buttons):
1. **Touch down** on the action button → enter Aim Mode
2. **Drag** to select direction → preview updates
3. **Release** → **commit**

Key rule:
- **Commit happens on release**, not on press.

**Current implementation details**
- `DirectionalActionButton`:
  - enters aim mode on pointer down
  - updates aim on pointer move
  - commits on pointer up
  - supports cancel (see §5)

---

## 4. Aim Mode rules

### 4.1 Deadzone (anti-jitter)

- While holding, if drag stays within a small radius:
  - aim direction is considered **unset**
  - input should not “micro-aim" due to jitter

**Current implementation**
- Deadzone is `12px` by default (`DirectionalActionButtonTuning.deadzoneRadius`).

### 4.2 Aim stabilization / determinism

- Aim preview should not “dance".
- Direction updates should be stable and deterministic.

**Current implementation**
- Aim direction components are **quantized to 1/256 increments** (`AimQuantizer.quantize`) to collapse float noise and reduce redundant command spam.

### 4.3 Preview semantics when aim is “unset"

- When aiming is active but aim is cleared (inside deadzone), `AimPreviewModel.hasAim=false`.
- The aim ray component is configured to still draw a forward-facing ray even when no aim direction is set (so you effectively get “default forward" while holding).

---

## 5. Cancel rules

Aimed actions must be cancelable **without casting**.

### 5.1 Intent

On cancel:
- Aim preview clears immediately
- Aim Mode exits immediately
- No resource/cooldown is consumed
- Releasing after cancel does not commit

### 5.2 Cancel button

#### UI behavior
- A **Cancel** button appears **only while Aim Mode is active**.
- It is placed in a **fixed screen-space location** between the clock and distance display, so the player learns it.
- It must be reachable by the **right thumb** without crossing the action buttons.
- The Cancel button has a **large hitbox** (mobile-first), larger than the visual icon.

#### Trigger rules
Cancel triggers when **either** condition happens:
- The held pointer **releases inside** the Cancel hitbox

#### Failure-safe rule
If the pointer stream is canceled by the system (`onPointerCancel`), treat it as Cancel:
- reset aim
- do not commit

---

## 6. Priority & conflicts

### 6.1 Core simulation priority

The ability router resolves **at most one** action per simulation tick with this priority:

1. **Jump**
   - Jump is the primary “survival” action in a runner.
   - If `jumpPressed` is true, commit `AbilitySlot.jump` and return immediately.

2. **Mobility (Dash)**
   - Mobility is the secondary “survival” action.
   - If `dashPressed` is true, commit `AbilitySlot.mobility` and return immediately.

3. **Ability execution gating**
   - If the player is currently executing an ability:
     - During **Recovery**, a new press may be **buffered** (latest overwrites).
     - Outside Recovery, presses are **ignored** until the player returns to Idle.

4. **Combat abilities**
   - If the player is **Idle** and any combat slot is pressed, commit exactly one combat slot
     (see tie-break below).

5. **Buffered input**
   - If nothing is pressed this tick, commit buffered input if present and not expired.

---

### 6.2 Combat slot tie-break

When multiple combat buttons are pressed close together (including multi-touch), resolve the cast by **player intent**:

- The **most recently pressed combat button wins** (last-press wins).
- If multiple combat presses are indistinguishable (same tick / no reliable ordering), use a fixed deterministic fallback:
  - **Primary > Secondary > Projectile > Bonus**

Design takeaway:
- Combat should feel predictable: pressing a different combat button should always override earlier combat intent.
- Multi-touch should not privilege a specific combat slot by default; last-press wins is the standard.

---

## 7. Input buffering & timing

There are two distinct buffering concepts:

### 7.1 Scheduling lead/buffer for continuous inputs (movement + aim)

**Current implementation**
- Continuous inputs (move axis, aim directions) are **scheduled ahead** to smooth frame hitches:
  - lead window: `inputLead` ticks (default `1`)
  - additional "frame hitch buffer": `_inputBufferSeconds = 0.10s` in `RunnerInputRouter`
- This is not "gameplay forgiveness"; it’s command scheduling stability.

### 7.2 Gameplay forgiveness buffer for abilities pressed during recovery

**Current implementation**
- Ability input buffering uses `AbilityTuning.inputBufferSeconds = 0.15s`.
- Buffered input only records **one** ability; the latest press overwrites the previous buffer.
- Buffer expires at `commitTick + inputBufferTicks`.

At `tickHz = 60`:
- `0.15s ≈ 9 ticks`

### 7.3 Jump forgiveness

Jump "feel" typically also uses:
- **jump buffer** (pressed slightly before landing)
- **coyote time** (short grace after leaving ground)

Those values should live in a movement tuning doc or file-level tuning.

---

## 8. Button layout (current overlay)

`RunnerControlsOverlay` layout on the right side is a **2x3 grid** anchored to the bottom-right corner.

**Top Row** (from left to right):
- **Projectile** (Top Left)
- **Primary** (Top Middle)
- **Mobility** (Top Right)

**Bottom Row** (from left to right):
- **Bonus** (Bottom Left)
- **Secondary** (Bottom Middle)
- **Jump** (Bottom Right)

---

## 9. Bonus slot integration 

### 9.1 What "Bonus can be Primary/Secondary/Projectile but not Mobility" means in controls

Controls should treat Bonus as **its own button/slot**, but its **targeting model** is determined by the equipped ability:

- If Bonus ability is **tap-type** → Bonus button is an `ActionButton`.
- If Bonus ability is **aim-type** → Bonus button is a `DirectionalActionButton`.

**Important constraint**
- Bonus must never equip a Mobility ability. That rule belongs in the loadout/validation layer, not the UI.

---

## 10. Feedback rules (cooldown + affordability)

- Buttons render a **cooldown ring**.
- Buttons can be rendered "disabled" if:
  - not affordable (resource gating)
  - cooldown remaining > 0

- When action is unavailable, buttons should still acknowledge a press even when blocked (cooldown/resource), without committing.

---

## 11. Extensibility rules

Controls must scale without inventing new input patterns:

- **Tap** (instant)
- **Aim + commit** (directional)
- **placed** / **charge**; only if genuinely needed

Rule:
- Each ability declares its targeting model.
- UI selection is purely derived from the targeting model.
- Bonus does not create new models; it inherits the equipped ability’s model.

---
