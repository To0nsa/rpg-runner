Got it. Here’s a **pure game design** spec (no code, no implementation).

---

## `docs/design/player_controls_current_intent.md`

# Player Controls (Current Intent) — Game Design Spec

## 1. Goals

### Core goals

* **Two-thumb playable** on a phone: left thumb = movement, right thumb = actions.
* **Zero "accidental casts”**: abilities that require aim must be explicitly committed, and must be cancelable.
* **Readable combat timing**: player should feel that actions happen *when they chose*, not randomly due to touch jitter.
* **Skill expression without complexity**: mastery comes from timing, spacing, and commitment decisions.

### Design principles

* **Commitment > convenience** for aimed abilities.
* **Consistency**: same interaction model across all abilities of the same targeting type.
* **Forgiving input**: buffer + coyote-style forgiveness for mobility, but **not** for aim commits (aim commit must be intentional).

---

## 2. Input schema overview

### Left thumb: Movement

* **Horizontal move axis** only (runner).
* Output is a continuous value in `[-1, 1]`.
* Movement input is always allowed except if a hard-lock state exists (e.g., stun, knockdown).

### Right thumb: Actions

Four baseline actions:

* **Jump** (tap)
* **Mobility ability** (tap or aim+commit depending on ability)
* **Melee ability** (tap or aim+commit depending on ability)
* **Projectile ability** (tap or aim+commit depending on ability)

---

## 3. Action types and their interaction models

## 3.1. Tap actions (instant)

Used when:

* Ability has **no targeting** (self, forward, auto-aim, or fixed direction).
* Ability is meant to be **high tempo** and low cognitive load.
* Ability has a sane default depending on player facing direction.

Interaction:

* **Tap = cast**
* No hold, no aim preview.
* If unavailable (cooldown/resource), tap gives feedback but does nothing.

Examples:

* Jump, Dash
* "Auto-aim shot" (auto-forward projectile)
* "Sword parry" (self-centered shield)

---

## 3.2. Aim + commit actions (directional)

Used when:

* Ability direction matters and the game wants **intentional aiming**.

Interaction (must be consistent everywhere):

1. **Press and hold** the action button → enter *Aim Mode*
2. **Drag** to select a direction → show aim preview
3. **Release** → **commit** the cast

Key rule:

* **Commit happens on release**, not on initial press.

---

## 4. Aim Mode rules

### 4.1 Deadzone (anti-jitter)

* While holding, if the finger stays within a small radius from the initial press point:

  * The aim direction is considered **unset**
  * The preview is neutral
* This prevents accidental micro-aim commits.

### 4.2 Aim preview feedback

While holding and dragging:

* Show a **direction indicator** from the player (arrow / cone).
* Show **range** if applicable.
* Preview must update smoothly but should not "dance" (stabilized / snapped).

---

## 5. Cancel rules

Aimed actions must be cancelable **without casting**.

Allowed cancel gesture:

* **Drag into an explicit cancel button**

Cancel must:

* Clear preview
* Not consume resource
* Not trigger cooldown
* Not lock movement

---

## 6. Mobility vs Aim: commitment policy

This defines the "feel" of the game.

### Rule

* While in **Aim Mode**, player can still move (left thumb) but:

  * **Mobility abilities are blocked** until aim is committed or canceled

---

## 7. Input buffering and forgiveness

### For mobility abilities

* Use **input buffering**: if pressed slightly before landing, it should trigger on landing.
* Use **coyote time** for jump: short grace window after leaving ground.

These make the runner feel "tight” on mobile.

### For abilities

* All ability inputs (tap or aimed commit) use the **standard input buffer** (0.15s).
* Reasoning: allows fluid chaining of abilities (e.g. queueing an aimed shot during the recovery frames of a dash) without strict frame-perfect requirements.

---

## 8. Priority & conflicts

When multiple actions happen in the same moment, resolve consistently.

### Recommended priority order

1. **State locks** (stun/knockdown/death) override everything
2. **Cancel** (if cancel gesture detected)
3. **Aim commit** (release)
4. **Dash**
5. **Jump**
6. **Tap abilities**

Reasoning:

* Cancel must always work.
* Aim commit is a deliberate release event.
* Mobility abilities need to feel responsive.

---

## 9. Feedback rules

### When action is unavailable

If cooldown/resource blocks an action:

* Provide clear feedback:

  * cooldown ring / greying / short "denied” pulse
* No cast, no aim mode (unless you want "aim preview even when unavailable”, which is usually confusing)

### When in Aim Mode

* Button should visually indicate "holding”
* Preview should clearly show direction and (if relevant) range and hit zone

---

## 10. Extensibility

This controls spec must support future abilities without inventing new interactions every time.

Define **targeting categories**:

* **Instant (Tap)**: self / forward / auto-aim
* **Directional (Aim+commit)**: choose a direction
* **Placed (Aim+commit with position)**: choose a point on ground (later)
* **Hold/Charge**: press-hold to charge, release to fire (later)

Rule:

* Each ability must declare its targeting category.
* UI interaction is selected purely from that category (no one-off special cases).

---

## 11) Open decisions (to lock soon)

* Aim snapping: **8 vs 16 directions**
* Mobility during Aim Mode:

  * block dash/jump, or auto-cancel on mobility
* Whether projectile defaults to:

  * tap auto-forward, or aim+commit by default

---

If you paste the "Player controls (current intent)” section from your high-level doc (or tell me what you wrote there), I can align this 1:1 with your exact intent and remove any mismatch.
