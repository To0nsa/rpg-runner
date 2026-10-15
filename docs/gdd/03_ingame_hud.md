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

* **Health**, **Mana**, **Stamina**, in that fixed order, identified by heart,
  droplet and lightning icons as well as muted red, blue and green fills.
  Mana must remain recognizably blue and stamina recognizably green; muting
  the palette must not turn either resource grey.
* Health is 12 logical pixels tall; mana and stamina are 8. Tracks are 160
  pixels wide, reduced to 120 below a 600-pixel landscape viewport so the
  vitals, timer and score remain separate.
* Vitals, timer, score, boss panel, pause and exit share matte dark-iron backing,
  a single subdued gold border and small clipped corners. The palette echoes
  the hub, town and loadout menus. The boss panel sits below the top information
  row.
* The treatment follows the Lothringen brand's `Brand/VisualIdentity.md` and
  `Brand/VisuelTokens.md`: practical, aged and restrained. The timer uses Cinzel,
  compact score data uses Inter, and narrative captions retain Crimson Text.
  Ornament must stay quieter than the content.
* Spending appears immediately. Health loss leaves a pale trail for 180 ms,
  then drains over 420 ms. Restoration smooths continuously without restarting
  on every regeneration tick.
* At or below 25% health (while alive), the health outline pulses gently.
  Pausing or requesting reduced motion uses a steady outline and immediate
  resource values instead.
* Tapping a resource-blocked action briefly outlines the button and each
  missing resource for 450 ms. Cooldown and invalid-slot blocking do not
  produce a resource warning. Reduced motion uses a static temporary outline.

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
* **Play/pause button**, immediately after the distance/collectibles panel
* **Exit button (“X”)** (small, top-right corner, always accessible)
* The panel, play/pause and exit form one row with matching heights. Both
  buttons use the same 48-pixel width and at least a 48-pixel touch height.

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

### 3.3 Top-center: Time (always visible while running)

**Purpose:** keep elapsed time readable between vitals and the right-side group.

**Display**

* **Survival timer** (mm:ss)
* The **pause toggle** sits in the top-right group beside run performance.
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

The six action controls display slot symbols without visible text. The spell
button shows a heart when a health-restoration spell (Vital Surge) is equipped,
and a magic wand for other spells, in both the run HUD and Skills preview. Their
translucent backgrounds use the matching resource-bar colors under a dark-iron
overlay. Multiple resource costs blend those muted colors, and free actions
stay neutral. Single thin metal rims and flat symbols keep the controls quiet.
Cooldown rings and dimmed symbols communicate readiness. The Skills control
preview uses the same symbols and
framing with an aged-gold selection ring, while individual skill artwork stays
in the lists and details. The floating joystick carries the same simple rim and
a dark grip; movement arrows use the shared panel frame. Frames have no rivets,
scratches, inset rings or compass marks.
See [control presentation](01_controls.md#8-button-layout-current-overlay).

---

## 4. Context overlays (stateful HUD)

These are full-screen overlays that temporarily override normal HUD to express the *session state*.

### 4.1 Ready / pre-run

* Loading keeps the simulation at tick zero until the world and replay recorder
  are ready. The HUD and **Tap to start** appear only after both succeed.
* Required loading failures offer **Retry** and **Exit**. Retry before Start keeps
  the same run setup and ghost; a restart after playing obtains a fresh run.
* Loading has no artificial minimum delay. Optional ghost playback/render failures
  allow the live run to continue without that ghost.
* Single CTA (call to action): **Tap to start**
* Short one-line goal ("Survive as long as possible" style)
* Must block input except start.

### 4.2 Pause

* Minimal dim + optional pause menu later.
* Must visually confirm paused state.
* While paused, game input is ignored (controls disabled) but HUD can remain visible or dimmed. 
* Leaving the app pauses a playing run. Returning resumes it automatically;
  a manual pause or **Tap to start** state remains paused.
* Held movement and abilities are cleared when leaving the app. Players press
  them again after returning; background time does not advance the run.
* Pausing cancels actions queued before the next gameplay tick. A jump, attack,
  or aimed release pressed immediately before pause does not fire on resume.

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
* Loadout identity remains available through the Skills list and details;
  in-run control symbols consistently identify action slots.

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

