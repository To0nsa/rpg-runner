# Menu UI (Design Intent)

This document defines the intended **menu + meta UI** structure for the runner: what the player can do, what must stay fast/lean.

It follows the project stance: gameplay is **deterministic and fair**, and UI should not introduce friction that slows restart/iteration.

---

## 1. Goals

### 1.1 Primary goals

* **1-tap Start Run** from app launch with sane defaults (no required setup screens).
* Keep the **Play Hub minimal forever** (no feature creep that competes with Start).
* Separate “choose/build” (Setup) from “feel/test” (Loadout Lab).
* Make room for **leaderboards + ghost runs** as first-class retention hooks. 
* Add monetization in a way that **does not undermine mastery or fairness**.

### 1.2 Non-goals (for early phases)

* Full narrative campaign UI.
* Complex economy screens (multiple currencies, bundles, seasonal battlepass UI).
* Social features beyond leaderboard/ghost.

---

## 2. Design & Architecture Contract

### 2.1 Source of truth

* Menu reads/writes persistent selection state:

  * `selectedLevelId`
  * `selectedCharacterId`
  * `equippedLoadout` (slot → abilityId)
* **Legality is enforced at equip-time**. In-run assumes loadout is valid.

### 2.2 UI responsibilities

* UI is allowed to:
  * navigate screens
  * write selection state (validated)
  * start/exit sessions
  * launch a training session (Loadout Lab)
* UI is **not** allowed to:
  * implement hidden gameplay logic
  * infer game outcomes by “looking at entities”
  * diverge from targeting/commit rules (tap vs aim+commit)

### 2.3 Controls consistency

* Loadout Lab uses the **same commit model** as in-game:
  * tap abilities commit on press
  * aim+commit abilities commit on release
  * cancel rules must remain consistent

---

## 3. Information Architecture

### 3.1 Screens

1. **Play Hub (Main Menu)**
2. **Setup Level**
3. **Setup Character Loadout**
4. **Loadout Lab (Ability Testing)**
5. **Meta (Store / Library / Options)**

### 3.2 Navigation Map

* Launch → **Play Hub**
* From Play Hub:
  * `Start Run` → In-Game
  * `Edit Level` → Setup Level tab
  * `Edit Loadout` → Setup Character Loadout tab
  * Icons: `Options`, `Library`, `Store` → Meta (deep link)
* From Setup Character Loadout:
  * `Try on Dummy` → Loadout Lab
  * `Back` → Play Hub
  * `Level` → Setup Level tab
* From Loadout Lab:
  * `Back` → Setup Character Loadout
* From Setup Level:
  * `Back` → Play Hub
  * `Character` → Setup Character Loadout tab
* Meta:
  * Back → Play Hub

---

## 4. Screen Specs

## 4.1 Play Hub (Main Menu)

### Purpose

Start fast. Show current setup summaries without clutter.

### Layout (zones)

* **Primary CTA:** `Start Run` (dominant).
* **Compact summary card: Selected Level**
  * name + small thumbnail
  * `Edit` button
* **Compact summary card: Selected Loadout**
  * character portrait/icon
  * 5 slot icons (Primary/Secondary/Mobility/Projectile/Bonus)
  * `Edit` button
* **Small icons:** `Options`, `Library`, `Store`, `Leaderboards`

### Rules

* Never block Start Run on “non-critical” loading (thumbnails, cosmetics, store data).
* If selection is invalid/missing: auto-fallback to defaults and still allow Start.

### Acceptance checklist

* Cold open → gameplay reachable in **one tap**.
* Hub remains visually simple even after adding store/social features (they live elsewhere).

---

## 4.2 Setup Level Screen

### Purpose

Choose level cleanly.

### Layout

* Header: “Select Level”
* List/grid:
  * thumbnail, name, tags (biome/difficulty)
  * locked state + unlock condition
* Bottom:
  * `Back` and `Confirm`
  * `Character` tab

### Scalability hooks

* Filters: biome, difficulty, favorites, recent
* Future: daily run modifiers

### Acceptance checklist

* Change level in < 3 taps from Play Hub.

---

## 4.3 Setup Character Loadout Screen

### Purpose

Pick character and build the loadout (slot-based).

### Layout

* Header: “Character & Loadout”
* Character selector (carousel/list)
* Loadout slots (5 rows/cards):

  * slot icon + name
  * selected ability icon/name
  * tap → ability picker
* Bottom:

  * `Back`
  * `Try on Dummy`
  * optional `Start Run` (secondary)

### Validation rules (non-negotiable)

* Slots are never empty (fallback to default). 
* Slot restrictions must match controls+ability contracts (Bonus cannot be Mobility).  
* Locked abilities show lock + reason; incompatible abilities are hidden or disabled with a reason.

### Acceptance checklist

* Swap one ability in < 5 seconds.
* Screen stays readable; no embedded gameplay viewport here (lab is separate).

---

## 4.4 Loadout Lab (Ability Testing)

### Purpose

Try abilities on a dummy using real timing/feel without UI clutter.

### Core principle

This runs **real gameplay logic** in a **training level** (not a fake animation preview).

### Layout

* Fullscreen Flame scene:

  * player + dummy + flat ground
  * fixed camera (no scrolling)
* Docked UI overlay:

  * action buttons mapped to equipped slots
  * `Reset` (dummy HP + player position)
  * optional toggles:

    * Infinite resources (default OFF)
    * Reduce cooldowns (default OFF)
    * Show hitboxes (dev-only)

### Rules

* Input semantics must match in-run rules (tap vs aim+commit, cancel). 
* Dummy never “ends the session” (no fail state).
* Pause lab simulation when screen is not visible.

### Acceptance checklist

* Player can evaluate windup/active/recovery feel reliably (timing contract holds). 

---

## 4.5 Meta Screen (Store / Library / Options)

### Purpose

Keep non-run features separate so they never pollute the Play Hub.

### Layout

* Tabs or sections:

  * **Store**
  * **Library/Codex**
  * **Options**
* Supports deep links:

  * Play Hub icons open the corresponding section

### Acceptance checklist

* No meta content is required to start a run.
* Store never blocks Start Run.

---

## 5. Social Features (Leaderboards + Ghost Runs)

These are retention-critical but must not add friction to starting runs. 

### 5.1 Sane defaults

* **Per-level leaderboard** is the primary social surface. 
* Ranking rule: **score-first, time as tie-breaker** (display both). 
* **Ghost runs**: race the top ghosts (top 10) as your “chase target.” 

### 5.2 Where it shows up in UI (minimal intrusion)

* **After Run (Game Over / Results):**

  * show your score + rank placement + “Next target”
  * buttons:

    * `Retry` (primary)
    * `Race Top Ghost` (secondary, if available)
    * `View Leaderboard` (secondary)
* **Setup Level Screen:**

  * small badge: “Best rank / Best score”
  * optional “Leaderboard” button (not required)
* **Play Hub (optional, minimal):**

  * a tiny “Personal best” line under the Selected Level card (no big panels)

### 5.3 Ghost selection UX

* Default target ghost:

  * “1 rank above you” if you have a rank
  * else “Top #10”
* Ghost list shows:

  * rank, score, time, version tag (for replay compatibility)
* Allow “Download/Cache ghost” lazily (never block start).

### 5.4 Determinism / compatibility rules (UI-visible)

* Ghosts must display a small compatibility indicator:

  * OK / Outdated version / Unavailable
* If incompatible:

  * don’t allow “Race ghost”
  * still allow “View leaderboard”

(Reason: ghosts rely on deterministic replay and versioned inputs.) 

### Acceptance checklist

* Social surfaces never prevent quick restart.
* Player can always identify “what to chase next” in 1–2 taps.

---

## 6. Monetization UX (Pricing, Offers, Ads) — Sane Defaults

Must preserve **fair competitive loop** and mastery. 

### 6.1 Monetization principles (non-negotiable)

* No pay-to-win power that affects leaderboards/ghost fairness.
* Ads must be **opt-in** (rewarded), never mid-run.
* Purchases must not interrupt the core loop (Start Run remains clean). 

### 6.2 Default product types

**A) Supporter Pack (one-time)**

* Purely cosmetic + small QoL (e.g., extra loadout preset slots)
* Explicitly no combat power

**B) Cosmetics**

* skins, VFX trails, UI themes, emotes (if any)
* safe for competitive integrity

**C) QoL Packs**

* extra loadout preset slots
* extra character slot (if you add roster management)
* inventory convenience (if inventory exists later)

**D) Rewarded Ads**

* “Watch ad for X” when gated (currency top-up) or post-run bonus
* limit frequency and show clear value upfront
* never chain into multiple ads

(These match your placeholder monetization direction.) 

### 6.3 Where monetization lives in the UI

* **Meta → Store** is the primary home for all monetization.
* **Post-run Results** may show a single optional entry point:

  * `Watch Ad for Bonus` (only if it doesn’t distract from Retry)
* Play Hub: **no store panels** by default (keep it play-first).

### 6.4 Offer defaults (safe + simple)

* Store sections:

  * Supporter Pack (top)
  * Cosmetics
  * QoL
* Limited-time offers (optional, later):

  * shown only in Store
  * never as blocking popups on launch
* Pricing display:

  * show local currency
  * always show “what you get” clearly (no lootbox ambiguity)

### 6.5 Ads defaults (safe + non-annoying)

* No interstitial ads.
* Rewarded ad placements (choose 1–2 max early):

  1. Post-run: “+X currency” (optional)
  2. When gated: “Get X currency to proceed” (optional)
* Cooldown:

  * enforce a simple timer or daily cap to prevent spam.

### Acceptance checklist

* Monetization never blocks Start Run.
* No purchase/ads affect leaderboard fairness.
* Ads remain optional and readable (no dark patterns).

---

## 7. UX Principles

* **Play Hub stays lean**. If it competes with Start, it moves out.
* **Progressive disclosure**: summaries first, details on edit screens.
* **Consistency**: “Start” always means “start immediately with current setup.”
* **No accidental actions**: match your controls intent (commit/cancel clarity). 

---

## 8. Open Questions (Fill Later)

* First-launch defaults (level/character/loadout).
* Unlock model for levels/abilities.
* Whether Loadout Lab supports quick inline swapping or always returns to Setup Loadout.
* Exact post-run Results layout (where leaderboard/ghost sits relative to Retry).

---

If you want, I can also refactor your existing `04_menu_ui.md` content into this exact structure (same headings/numbering) so it matches the rest of your doc set 1:1. 
