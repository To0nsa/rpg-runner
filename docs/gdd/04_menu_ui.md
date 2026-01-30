# Menu UI (Design Intent)

This document defines the intended **menu + meta UI** structure for the runner: what the player can do, what must stay fast/lean.

It follows the project stance: gameplay is **deterministic and fair**, and UI should not introduce friction that slows restart/iteration.

---

## 1. Goals

### 1.1 Primary goals

- **1-tap Start Run** from app launch with sane defaults (no required setup screens).
- Keep the **Play Hub lean** and avoid feature creep that competes with Start Run.
- Separate “choose/build” (Setup) from “feel/test” (Loadout Lab).
- Make **leaderboards + ghost runs** highly discoverable and easy to browse (core retention).
- Add monetization in a way that **does not undermine mastery or fairness**.

### 1.2 Non-goals (for early phases)

- Full narrative campaign UI.
- Complex economy screens (multiple currencies, bundles, seasonal battlepass UI).
- Social features beyond leaderboard/ghost.

---

## 2. Design & Architecture Contract

### 2.1 Source of truth

- Menu reads/writes persistent selection state:
  - `selectedLevelId`
  - `selectedRunType` (`Practice` | `Competitive`) for the selected level
  - `selectedCharacterId`
  - `equippedLoadout` (slot → abilityId)
- **Legality is enforced at equip-time**. In-run assumes loadout is valid.

### 2.2 UI responsibilities

- UI is allowed to:
  - navigate screens
  - write selection state (validated)
  - start/exit sessions
  - launch a training session (Loadout Lab)
- UI is **not** allowed to:
  - implement hidden gameplay logic
  - infer game outcomes by “looking at entities”
  - diverge from targeting/commit rules (tap vs aim+commit)

### 2.3 Controls consistency

- Loadout Lab uses the **same commit model** as in-game:
  - tap abilities commit on press
  - aim+commit abilities commit on release
  - cancel rules must remain consistent

### 2.4 Display Orientation (Hard Constraint)

- The entire app runs in **landscape (horizontal)** orientation.
- All menu screens and in-game UI must be designed for landscape first:
  - safe areas respected (notches)
  - minimum touch target sizes maintained

### 2.5 Competitive/Weekly Version Gate (Hard Constraint)

- **Competitive** and **Weekly** are **hard-gated** by compatibility:
  - If `client.gameCompatVersion != activeBoard.gameCompatVersion` then:
    - the mode is **locked** (cannot start a run)
    - submissions/ghost racing are implicitly unavailable
    - UI must show **“Update required”** and offer **Practice** as fallback
- Practice is never blocked by version.

---

## 3. Information Architecture

### 3.1 Screens

1. **Play Hub (Main Menu)**
2. **Setup Level**
3. **Setup Character Loadout**
4. **Loadout Lab (Ability Testing)**
5. **Leaderboards (Browse + Ghost Select)**
6. **Meta Access (Gold Store / Real Money Store / Library / Options)**

### 3.2 Navigation Map

- Launch → **Play Hub**
- From Play Hub:
  - `Start Run` → In-Game (starts the **selected level** using the **selected run type**: Practice/Competitive)
  - `Edit Level` → Setup Level (route)
  - `Edit Loadout` → Setup Character Loadout (route)
  - `Weekly` quick button → starts Weekly Challenge directly **if compatible**; otherwise shows “Update required” (does not change `selectedLevelId` by default)
  - Icons: `Leaderboards`, `Options`, `Library`, `Gold Store`, `Shop` → open those screens directly
- From Setup Character Loadout:
  - `Try on Dummy` → Loadout Lab
  - `Back` → Play Hub
  - `Level` → Setup Level (cross-link)
- From Loadout Lab:
  - `Back` → Setup Character Loadout
- From Setup Level:
  - `Back` → Play Hub
  - `Character` → Setup Character Loadout (cross-link)
  - `Leaderboard` action on Weekly card → Leaderboards screen (pre-filtered to Weekly)
- From Leaderboards:
  - `Back` → Play Hub
  - `Race Ghost` → starts a run with the selected ghost target
- From Meta access screens:
  - `Back` → Play Hub

---

## 4. Screen Specs

## 4.1 Play Hub (Main Menu)

### Purpose

Start fast. Show current setup summaries without clutter.

### Layout

- **Primary CTA:** `Start Run` (dominant).

- **Compact summary card: Selected Level**
  - name + small thumbnail
  - **Run Type badge**: `Practice (Random)` or `Competitive (Season)`
  - `Edit` button
  - **Weekly badge (en-avant)**
    - small badge line under the level summary, always visible but visually subordinate to Start Run
    - shows: `Weekly Challenge` + optional countdown (e.g. “ends in 2d 14h”)
    - **`Weekly` quick button**:
      - starts the weekly run immediately (no extra navigation)
      - optional secondary action: `Weekly LB` (opens Leaderboards pre-filtered to Weekly)

- **Compact summary card: Selected Loadout**
  - character portrait/icon
  - shows 5 equipped ability icons
  - `Edit` button

- **Small icons (top/right)**
  - `Leaderboards`
  - `Options`
  - `Library`
  - `Gold Store`
  - `Shop`

### Rules

- `Start Run` always uses the **Selected Level + Selected Run Type**.
- **Hard gate (Competitive/Weekly):** if `client.gameCompatVersion != activeBoard.gameCompatVersion`:
  - If Selected Run Type is `Competitive`, `Start Run` is **locked** and shows **“Update required”**.
  - The `Weekly` quick button is **locked** and shows **“Update required”**.
  - Provide a one-tap fallback: `Switch to Practice` / `Play Practice`.
- Practice is low-pressure and uses a **local Personal Best (PB) scoreboard**, not online leaderboards.

- Weekly badge must not compete with Start Run:
  - no large panels
  - avoid red-dot spam
  - keep it as one line + one compact button
- Never block Start Run on “non-critical” loading (thumbnails, store data, leaderboard fetch).
- If selection is invalid/missing: auto-fallback to defaults and still allow Start.

### Acceptance checklist

- Cold open → gameplay reachable in **one tap**.
- Weekly is visible without bloating the hub.
- Hub remains visually simple.

---

## 4.2 Setup Level Screen

### Purpose

Choose level cleanly, while surfacing the **Weekly Challenge** as the competitive “front” entry point.

### Layout

- Header: “Select Level”

- **Run Type selector (applies to normal levels)**
  - Segmented control: `Practice (Random)` | `Competitive (Season)`
  - Default: `Practice`
  - UX note:
    - Practice shows **PB** (local) for the selected level
    - Competitive shows **Rank + best score** (online) for the selected level & current season
    - **Hard gate:** if compat mismatches, the `Competitive (Season)` segment is **disabled/locked** with “Update required”.

- **Featured zone: Weekly Challenge**
  - Larger card pinned at the top (ideally visible without scrolling on typical phones)
  - Contents:
    - Title: “Weekly Challenge”
    - Week label + countdown (e.g. “Week 05 — ends in 2d 14h”)
    - Level thumbnail
    - Personal best + current rank (if available); weekly is always competitive
  - Actions:
    - `Play Weekly` (primary inside the card)
    - `Leaderboard` (secondary; opens Leaderboards pre-filtered to Weekly)
    - `Race Top Ghost` (secondary; routes to Weekly Leaderboards, player selects which top-10 ghost to race)
  - **Hard gate:** if compat mismatches, `Play Weekly` and `Race Top Ghost` are **disabled/locked** with “Update required”.

- **Standard zone: Levels List/Grid**
  - thumbnail, name, tags (biome/difficulty)
  - locked state + unlock condition
  - selecting a level updates `selectedLevelId` (run type remains whatever is selected in the selector)
  - row subtext (contextual):
    - Practice: show PB (local)
    - Competitive: show best score + rank (online) for current season

- Bottom:
  - `Back` and `Confirm`
  - `Character` (cross-link)

### Weekly Challenge rules (sane defaults)

- **Hard gate:** Weekly is not startable on incompatible builds; show “Update required” and route players to Practice.

- Weekly is a **single highlighted level** with:
  - fixed seed / deterministic ruleset for fairness
  - its own **per-week leaderboard** (separate from normal per-level boards)
- `Play Weekly` launches the weekly session directly and **does not change** the player’s normal selected level by default.

### Scalability hooks

- Filters: biome, difficulty, favorites, recent
- Weekly:
  - rules/modifiers details (tap card)
  - ghost chase targets (top 10 / above-you)
- Future: daily run modifiers

### Acceptance checklist

- Weekly Challenge is visible (top pinned card, no scrolling required on typical screens).
- Weekly can be started in **≤ 2 taps** from Play Hub (Hub → Weekly button).
- Normal level selection remains clear and unchanged for players who ignore weekly.

---

## 4.3 Setup Character Loadout Screen

### Purpose

Pick character and build the loadout (slot-based). The equipped section visually mirrors the in-game HUD cluster **on this page only**.

### Layout

- Header: “Character & Loadout”
- Character selector (carousel/list)

- **Gear slots (4 slots)**
  - primary (main weapon)
  - secondary (offhand weapon)
  - projectile (projectile weapon/spell)
  - utility (utility item)

**Gear → Ability relationship (explicit)**
- Gear determines what ability pools are available/unlocked:
  - Primary gear gates **Primary abilities**
  - Secondary gear gates **Secondary abilities**
  - Projectile gear gates **Projectile abilities**
  - Utility gear can provide passive bonuses
- Equipped ability slots still remain 5 (Primary/Secondary/Projectile/Bonus/Mobility). Gear filters what can be equipped into those slots.

- **Equipped abilities (5 slots) — HUD-mirrored layout**
  - This section is not a list. It mirrors the right-side action cluster:
    - Primary
    - Secondary
    - Projectile
    - Bonus
    - Mobility
  - Jump is fixed and can be shown as a disabled reference button.

- **Available / Unlockable abilities library (4 rows ONLY)**
  - Row 1: **Primary abilities**
  - Row 2: **Secondary abilities**
  - Row 3: **Mobility abilities**
  - Row 4: **Projectile abilities**
  - There is **no Bonus row**.

- **Selection behavior**
  - Tap an equipped slot in the HUD cluster → highlights valid abilities in the library.
  - **When Bonus is selected:** show a combined filtered list of **Primary + Secondary + Projectile** abilities (with row headers or merged list), and explicitly exclude Mobility.

- Bottom:
  - `Back`
  - `Try on Dummy`
  - `Level` (cross-link)

### Bonus slot rule (UI-visible)

- Bonus is a flexible slot:
  - **Allowed sources:** Primary/Secondary/Projectile libraries
  - **Forbidden:** Mobility (never equip mobility into Bonus)

### Validation rules (non-negotiable)

- Slots are never empty (fallback to default).
- Slot restrictions must match controls+ability contracts (Bonus cannot be Mobility).
- Locked abilities show lock + reason; incompatible abilities are hidden or disabled with a reason.

### Acceptance checklist

- Swap one ability in < 5 seconds.
- Equipped layout matches in-game action cluster (no mental remap).
- Bonus selection clearly shows the combined allowed pool (P/S/Projectile).
- Ability library remains simple: exactly 4 rows, no Bonus row.

---

## 4.4 Loadout Lab (Ability Testing)

### Purpose

Try abilities on controlled targets using real timing/feel without UI clutter.

### Core principle

This runs **real gameplay logic** in a **training level** (not a fake animation preview).

### Layout

- Fullscreen Flame scene:
  - player + dummy + flat ground
  - fixed camera (no scrolling)
- Docked UI overlay:
  - action buttons mapped to equipped slots (same semantics as in-game)
  - `Reset` (resets player position/velocity, clears spawned targets/projectiles, restores baseline state)
  - **Expandable panel: `Targets` (collapsed by default)**
    - `Spawn Grojib` (spawns one Grojib in a defined spawn zone)
    - `Spawn Unoco` (spawns one Unoco in a defined spawn zone)
    - `Despawn All` (if you want a non-destructive clear without resetting player)

### Rules

- Input semantics must match in-run rules (tap vs aim+commit, cancel).
- Lab never ends the session (no fail state).
- Pause lab simulation when screen is not visible.
- Spawn rules (keep stable + readable):
  - Spawns occur at **fixed coordinates** relative to the training ground.
  - Limit active spawns to avoid clutter/perf issues (default: max 3 living enemies total).
  - If limit reached: block spawn with a small toast (“Target limit reached”) or despawn oldest (pick one behavior and keep it consistent).
- Reset rules:
  - resets player transform + velocity
  - resets cooldowns and statuses
  - restores dummy baseline (if dummy is present)
  - clears all spawned enemies and projectiles

### Acceptance checklist

- Player can evaluate windup/active/recovery feel reliably (timing contract holds).
- `Targets` panel stays out of the way by default; spawning is still ≤ 2 taps (open panel → spawn).
- Reset returns the lab to a known baseline every time without stutter.

---

## 4.5 Leaderboards Screen (Browse + Ghost Select)

### Purpose

Provide a dedicated, full-page experience to browse **Competitive/Weekly leaderboards** (with ghosts) and a **Practice PB scoreboard** (local).

### Entry points

- Play Hub:
  - `Leaderboards` icon
- Setup Level:
  - `Leaderboard` on Weekly card opens here pre-filtered to Weekly
  - `Race Top Ghost` routes here pre-filtered to Weekly
- Results:
  - optional `View Leaderboards` link

### Layout (full page)

- Header: **Leaderboards**
- **Mode selector (prominent but compact)**
  - `Practice (PB)` local-only personal best scoreboard (no ghosts)
  - `Competitive (Season)` online leaderboard + ghosts
  - `Weekly Challenge` online leaderboard + ghosts
- **Board selector (within the chosen mode)**
  - Practice (PB): select a level → show your PB entries for that level (device-only).
  - Competitive (Season): select a level → show the online board for that level & current season.
  - Weekly: board is the current week (with countdown).
- **Leaderboard list**
  - Show **Top 10** always, on one page (no pagination for top 10).
  - Also show **Your rank** pinned at the bottom, even if you are outside top 10.
  - Each row shows: rank, player name, score, time, (optional) character icon.
  - Each Top-10 row has a **ghost affordance**:
    - `Race` button OR row tap opens a side panel with ghost details.
- **Ghost details panel (right-side drawer in landscape)**
  - Shows selected rank’s run summary + ghost compatibility status.
  - Actions:
    - `Race Ghost` (primary)
    - Optional: `Download/Cache` (if you separate fetch vs race)

### Default behaviors (sane defaults)

- Default selection on open:
  - Mode: `Competitive (Season)` (unless deep-linked to Weekly)
  - Board: Selected Level by default
  - No implicit ghost target selection required; player explicitly picks one from Top 10 before racing.
- Ghost availability:
  - If ghost is unavailable/incompatible: disable `Race Ghost` and show why (version mismatch / missing data).
- Mode availability:
  - If `client.gameCompatVersion != activeBoard.gameCompatVersion`, **lock** `Competitive (Season)` and `Weekly Challenge` with “Update required”.

### Rules

- Practice PB is **local-only** and must never be mixed with online leaderboards.
- Ghost racing is only available for Competitive/Weekly modes.

- **Hard gate (Competitive/Weekly):** if compat mismatches, those modes are **locked**:
  - Mode tabs/filters show a lock badge + “Update required”.
  - `Race Ghost` is disabled.
  - Any entry points that would start Competitive/Weekly runs are disabled.

- Leaderboards must never block Start Run:
  - all networking is async
  - show cached/stale data immediately if available
- Race ghost flow:
  - selecting a ghost does **not** change the player’s normal selected level/loadout
  - starting “Race Ghost” launches a run with that ghost overlay
- Keep scope tight:
  - top 10 + your rank is the primary surface
  - deeper pages (friends, regions, seasons) are later additions

### Acceptance checklist

- From Play Hub → Leaderboards visible in **≤ 2 taps**.
- Selecting any top-10 ghost and starting a race is fast and obvious.
- Player can always see **their own rank** even if outside top 10.
- Ghost selection is explicit (no ambiguity about which target you chose).

---

## 4.6 Meta Access (Gold Store / Real Money Store / Library / Options) — No Meta Hub

### Purpose

Keep non-run features separate so they never pollute the Play Hub, while remaining reachable from the main hub via **small icons only**.

### Layout / Navigation

- Access is via **small icons on the Play Hub** (and optionally on Results screen):
  - `Gold Store` icon → **In-Game Store** screen
  - `Library` icon → **Library / Codex** screen
  - `Shop` icon → **Real Money Store** screen
  - `Options` icon → **Options** screen
- Deep links are implicit:
  - tapping an icon opens the destination screen directly (no intermediate hub).

### In-Game Store (Gold Store)

**Purpose:** spend **earned gold** to progress collections.

**Scope**

- Buy **gears/items** (weapons / offhand / utility / projectile) using gold
- Buy **Codex entries** using gold (enemy pages, ability pages, gear pages)

**Not here**

- Real money pricing / IAP bundles
- Anything that compromises leaderboard fairness

### Real Money Store (IAP)

**Purpose:** monetize without compromising competition/fairness.

**Scope**

- Cosmetics (skins, VFX trails, UI themes)
- Supporter pack (one-time)
- QoL that doesn’t affect run power (extra loadout preset slots)

### Library / Codex

**Purpose:** browse discovered/unlocked content.

**Scope**

- Codex entries (enemies, abilities, gear, statuses)
- Locked vs unlocked visibility rules

### Options

**Purpose:** settings only.

**Scope**

- Controls, audio, video/accessibility, account/data, legal/credits
- Destructive actions require confirmation

### Acceptance checklist

- No meta content is required to start a run.
- Store screens never block Start Run.
- Each icon opens its destination in **1 tap** (no intermediate hub).
- Clear separation: **Gold Store ≠ Real Money Store ≠ Library ≠ Options**.

---

## 5. Monetization UX (Pricing, Offers, Ads) — Sane Defaults

Must preserve **fair competitive loop** and mastery.

### 5.1 Monetization principles (non-negotiable)

- No pay-to-win power that affects leaderboards/ghost fairness.
- Ads must be **opt-in** (rewarded), never mid-run.
- Purchases must not interrupt the core loop (Start Run remains clean).

### 5.2 Default product types

**A) Supporter Pack (one-time)**
- Cosmetic + small QoL (e.g., extra loadout preset slots)
- Explicitly no combat power

**B) Cosmetics**
- skins, VFX trails, UI themes

**C) QoL Packs**
- extra loadout preset slots
- extra character slot (if roster exists later)
- inventory convenience (if inventory exists later)

**D) Rewarded Ads**
- “Watch ad for X” when gated (currency top-up) or post-run bonus
- limit frequency and show clear value upfront
- never chain into multiple ads

### 5.3 Where monetization lives in the UI

- Real money store is its own screen (opened via hub icon).
- Gold store is its own screen (opened via hub icon).
- **Post-run Results** may show a single optional entry point:
  - `Watch Ad for Bonus` (only if it doesn’t distract from Retry)
- Play Hub: **no store panels** by default (keep it play-first).

### 5.4 Ads defaults (safe + non-annoying)

- No interstitial ads.
- Rewarded ad placements (choose 1–2 max early):
  1) Post-run: “+X currency” (optional)
  2) When gated: “Get X currency to proceed” (optional)
- Cooldown:
  - enforce a simple timer or daily cap to prevent spam.

### Acceptance checklist

- Monetization never blocks Start Run.
- No purchase/ads affect leaderboard fairness.
- Ads remain optional and readable (no dark patterns).

---

## 6. UX Principles

- **Play Hub stays lean**. If it competes with Start, it moves out.
- **Progressive disclosure**: summaries first, details on edit screens.
- **Consistency**: “Start” always means “start immediately with current setup.”
- **No accidental actions**: commit/cancel clarity must match gameplay.

---

## 7. Open Questions (Fill Later)

- First-launch defaults (level/character/loadout).
- Unlock model for levels/abilities.
- Whether drag & drop makes it into v1 or stays as enhancement.
