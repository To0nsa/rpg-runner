# In-Game HUD (Design Intent)

This document defines the **intended** in-game HUD for the runner: what the player should read/feel, what must be consistent, and what the UI layer is allowed to do.

It is written to align with the project’s strict separation: **Core is authoritative**, UI/HUD is **read-only** and reacts via **snapshots + events**.

---

## 1. HUD goals

### 1.1 Primary goals

* **Readability at runner speed**: the player must parse key information in < 200ms.
* **Low cognitive load**: show only what influences immediate decisions (jump, mobility, commit/aim, resource gating, danger).
* **Two-thumb friendliness**: HUD must not compete with thumbs or cover critical play-space.  
* **Deterministic and scalable**: HUD displays authoritative Core data (snapshot), no gameplay inference in UI.  

### 1.2 Non-goals

* No "chatty" UI, no constant popups, no clutter.
* No UI-driven gameplay logic (no hidden "assist rules" living only in UI).

---

## 2. Data & architecture contract

### 2.1 Source of truth: `GameStateSnapshot`

HUD must render from `GameStateSnapshot`, which contains tick, distance, pause/gameOver, camera center, and a dedicated `PlayerHudSnapshot hud`. 

### 2.2 HUD-only data: `PlayerHudSnapshot`

Current Core→HUD contract includes:

* **Resources**: `hp/hpMax`, `mana/manaMax`, `stamina/staminaMax`
* **Affordability flags**: `affordableMask`
* **Cooldowns**: abilities ticks left/total
* **Input modes**: `tapInputMode`, `aimInputMode`, `commitInputMode` (`AbilityInputMode`) so UI can render tap vs aim+commit affordances consistently
* **Run pickups**: `collectibles`, `collectibleScore` 

This split is deliberate so HUD doesn’t need to scan entities.

### 2.3 Rules

* UI must treat snapshots as **read-only** and must not simulate. 
* UI may send **Commands** (pause/start/exit), but never mutate Core state directly. 
* Transient UI-only state (menus, visibility) lives in `RunnerGameUiState` or similar, separate from gameplay. 

---

## 3. HUD layout zones

> The HUD is the information layer. Controls are separate and may be hidden/changed without redefining HUD.

### 3.1 Top-left: Player vitals (always visible while running)

**Purpose:** instantaneous survivability + "can I spend?" intuition.

**Display**

* **HP bar** (primary), **Stamina bar**, **Mana bar** in a compact stack.
* Bars are *thin, high-contrast, stable*, with minimal animation (avoid jitter).
* Subtle "low HP" state (pulse outline, not screen flash spam).

**Core mapping**

* From `snapshot.hud.hp/hpMax, stamina/staminaMax, mana/manaMax`. 

**Design rule**

* Resources never move around. No reflow that breaks muscle memory.

---

### 3.2 Top-right: Run performance (always visible while running)

**Purpose:** “how well am I doing” without distracting from survival, and provide an always-available safe **exit** affordance.

**Display**

* **Distance** (primary run metric)
* **Collectibles count** (optionally show collectibleScore later if it becomes decision-relevant)
* **Exit button (“X”)** (small, top-right corner, always accessible)

**Exit button rules**

* Must be **one-tap reachable** but not easy to mis-tap (small + padded hit area).
* On tap, **pause first**, then show a lightweight confirm dialog:

  * **Resume**
  * **Exit run** (returns to meta / main menu)
* Never instantly exit from a single tap (mis-taps on mobile are guaranteed).

**Core mapping**

* Distance comes from `snapshot.distance`.
* Collectibles and collectibleScore come from `snapshot.hud.collectibles/collectibleScore`.
* Exit is a **UI command** (not a snapshot field). It triggers the same “session state” flow as pause → confirm → exit.

---

### 3.3 Top-center: Session control + time (always visible while running)

**Purpose:** provide a single, consistent location for "session state".

**Display**

* **Survival timer** (mm:ss)
* **Pause toggle**
* Tiny "paused" tag when paused (avoid full overlay unless needed).

**Core mapping**

* Time can be derived from `snapshot.tick / tickHz` (UI knows tickHz via controller). 

**Rule**

* Pause is a command, not a state mutation in UI. UI triggers, Core enforces. 

---

### 3.4 Bottom layer: "Action readiness" (HUD aspect, not controls)

**Intent**

* Player must know at a glance:

  * which actions are **available**
  * which are **cooling down**
  * which are **resource-gated**
  * whether an action is **tap** vs **aim+commit**

**Core mapping**

* Availability: `affordableMask` + cooldown ticks left.
* Input model: `AbilityInputMode` per slot. 
* The targeting model contract is defined in controls doc (tap vs aim+commit) and must remain consistent across abilities.

---

## 4. Context overlays (stateful HUD)

These are full-screen overlays that temporarily override normal HUD to express the *session state*.

### 4.1 Ready / pre-run

* Single CTA (call to action): **Tap to start**
* Short one-line goal ("Survive as long as possible" style)
* Must block input except start.

### 4.2 Pause

* Minimal dim + optional pause menu later.
* Must visually confirm paused state.
* While paused, game input is ignored (controls disabled) but HUD can remain visible or dimmed. 

### 4.3 Game Over

**Design requirement from vision:** player must understand *why they died*. 

**Display**

* Title + **primary fail reason**
* Score presentation (immediate or "feed")
* Restart / Exit
* Leaderboard panel

**Core mapping**

* Use `RunEndedEvent` reason + deathInfo to build the subtitle ("fell behind", "fell into gap", "player died", etc.).  

---

## 5. Feedback rules (HUD language)

### 5.1 Resource gating feedback

If an action is blocked:

* **Never silently fail**.
* Prefer subtle feedback:
  * button/slot "shake" / short pulse
  * brief red/blue flash on the relevant resource bar (stamina/mana)
* No modal dialogs, no long text.

### 5.2 Cooldown feedback

* Cooldown should be readable as:
  * ring/arc fill
  * optional numeric countdown only when < 1s remaining (to reduce noise)

### 5.3 Aim mode feedback

For aim+commit abilities:

* show an **aim preview** (ray/arrow) while held
* show "commit on release" language through consistent visuals, not text
* allow cancel rules.

---

## 6. Safe areas, viewport, and occlusion rules

* All HUD elements must respect **SafeArea** and device cutouts.
* HUD must not cover the "critical read zone" in front of the player (runner speed readability).
* If letterboxing exists, prefer placing HUD in the bars when possible (or at least not inside the active play area). 

---

## 7. Extensibility roadmap (HUD evolves without rewrites)

### 7.1 Additions (still HUD-safe)

* Status effects on player (icons only, no scrolling list): stun/bleed/burn/slow, etc.
* "Danger" cues:
  * behind-camera threat (soft indicator near left edge)
* Loadout identity:
  * slot icons based on equipped ability (not text labels)

### 7.2 Contract-first approach

Every time you add a HUD feature, decide:

* **Is it authoritative gameplay data?** → add to Core snapshot/event.
* **Is it UI-only presentation state?** → keep in UI state.

Do **not** "derive gameplay meaning" from render entities in UI; that breaks determinism and makes refactors painful.  

---

## 8. Minimal acceptance checklist

When HUD "intent" is met (even if visuals are placeholder), you should be able to say:

* I can always read **HP/stamina/mana** instantly. 
* I can always read **distance + collectibles** instantly. 
* I can always tell which actions are **available**, **cooling down**, or **resource-gated**. 
* I understand the **exact death reason** on game over. 
* HUD never blocks gameplay visibility and respects safe areas.

---

## 9. Accessibility & Device Handling (later pro-level)

This HUD must remain readable and usable across a wide range of mobile devices and player preferences. The following rules are **design intent**.

### 9.1 Safe areas & cutouts

* All HUD elements must respect platform safe areas (notches, camera holes, rounded corners).
* HUD must never overlap the **critical read zone** (player + forward space). If space is constrained, HUD compresses inward before it intrudes into gameplay space.

### 9.2 Scaling tiers

Provide discrete HUD scale presets (not a continuous slider), so layouts remain stable and testable:

* **Small / Default / Large / XL**
  Rules:
* Scaling affects **text size + padding + icon size** together (no mismatched proportions).
* At Small, remove non-essential labels (keep icons + numbers).
* At XL, preserve safe margins; don’t let elements drift into the playfield.

### 9.3 Minimum hit targets

Any tappable HUD element (Pause, Exit “X”, confirm buttons) must meet:

* Minimum **48×48 dp** interactive area (including padding), even if the visual icon is smaller.
* Separation between tappable targets: enough spacing to avoid mis-taps during motion.
* Exit “X” must require a confirm step (never one-tap exit).

### 9.4 Left-handed / mirroring support

Offer a left-handed layout option that mirrors **interactive** HUD placement:

* Top-right controls (Pause/Exit) can remain top-right (industry standard), but any bottom-corner interaction cluster must support mirroring.
* Mirroring must not change the meaning of indicators (distance stays consistent, resource bars remain in one stable area unless explicitly configured).

### 9.5 Color-blind safe cues

Never rely on color alone to communicate state.
For action readiness / gating states, use at least **two channels**:

* Color + **shape/icon** (e.g., lock for cooldown, droplet/bolt for resource gate, cross for unavailable)
* Optional: pattern/outline (dashed ring for cooldown, solid ring for ready)
  Resource bars must remain readable in grayscale via:
* distinct icon + label
* clear fill level and contrast

### 9.6 Reduced motion

Provide a “Reduced Motion” option:

* Disable pulsing, bouncing, and attention-grabbing loops.
* Keep only essential transitions (e.g., cooldown progress still updates, but without animated easing).
* Avoid screen shake and aggressive flashes (especially on low HP).

### 9.7 Haptics & audio feedback toggles

Expose user toggles for:

* **Haptics** (Off / Minimal / Full)
* **UI sounds** (Off / On)
  Rules:
* “Blocked action” feedback should be available in **at least one non-visual form** (haptic tick or UI sound) when enabled.
* Haptics must be subtle and consistent (no long vibrations for frequent events like cooldown completion).

### 9.8 Localization & numeric formatting

* HUD must tolerate longer strings (e.g., localized “Paused”, “Exit run”) without breaking layout.
* Prefer icons + numbers over text wherever possible.
* Large numbers should abbreviate cleanly (e.g., 1.2k collectibles) if needed, but never at the cost of clarity.

### 9.9 Performance constraints

* HUD updates every tick, but expensive visual effects must be avoided (no heavy layout thrash, no per-tick allocations in UI logic).
* Prefer stable positions and simple primitives; animations should be optional and minimal.

This section is intentionally “policy-level”: it locks constraints that keep the HUD usable on real devices without dictating the widget tree.

