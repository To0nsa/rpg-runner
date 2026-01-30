# Run Types

This document defines the **run modes** for levels, including **seed policy**, **leaderboard eligibility**, and **ghost replay rules**.  
UI documents describe *where buttons live*; this document defines *what the modes mean*.

---

## 1. Goals

- Preserve **fair competition**: competitive runs must be comparable (same seed + same rules).
- Preserve **replayability**: practice runs should stay varied and low-pressure.
- Keep rules **deterministic and versionable** (ghost compatibility).

---

## 2. Definitions

### 2.1 Terms

- **Level**: a playable track/biome layout definition (obstacles + encounter scripting).
- **Seed**: RNG seed used to generate any randomized layout/encounters within a level.
- **Ruleset**: the set of modifiers and constraints applied to the run (e.g., fixed seed, allowed gear rules, scoring schema version).
- **Window**: the time period during which a competitive seed/ruleset is fixed and comparable across players.

### 2.2 Run eligibility

- **Leaderboard submission**: run result is sent to online boards.
- **Ghost submission**: run input record (or replay payload) can be stored and served to others (Top 10).
- **Competitive validity**: a run is valid if it matches the board’s `(seed, rulesetVersion, scoreVersion, gameVersionCompatibility)`.

---

## 3. Run Types Overview

Each level supports **two run types**, plus a featured weekly mode:

1) **Practice (Random Seed)**
- Random seed for variety.
- No leaderboard submission.
- No ghost submission.

2) **Competitive (Fixed Seed)**
- Fixed seed for a defined **Competitive Window**.
- Leaderboard submission enabled.
- Ghost submission enabled (Top 10).

**Weekly Challenge (Featured Competitive)**
- A featured competitive board that rotates weekly.
- Fixed seed + fixed ruleset for that week.
- Leaderboard + Top 10 ghosts.
- **Weekly Top-10 Achievement** (awarded when finishing the week in Top 10).

---

## 4. Practice (Random Seed)

### Purpose
Variety, learning, farming, experimentation. Zero pressure.

### Rules
- **Seed:** random per run.
- **Leaderboard:** **disabled** (no submission).
- **Ghosts:** **disabled** (no submission, no racing ghosts).
- **Rewards:** enabled (normal progression rewards).  
  - Sane default: same base rewards as Competitive to avoid forcing “competitive-only” play.

### Scoreboard
- Practice still show **local-only personal bests** in a scoreboard(device), but must not be compared globally.

---

## 5. Competitive (Fixed Seed)

### Purpose
Fair comparison + mastery chase for a specific level.

### Competitive Window (default)
- Competitive uses a **fixed seed per level per window**.
- **Default window:** a **Season** (4 weeks).
  - Rationale: keeps boards stable enough to matter, while still refreshing.
- Window identifiers are explicit (e.g., `S01`, `S02`, …).

### Rules
- **Seed:** fixed for `(levelId, seasonId)`.
- **Leaderboard:** enabled.
- **Ghosts:** enabled (store and serve **Top 10**).
- **Ghost selection:** player explicitly selects which Top-10 ghost to race (no implicit default target required).
- **Rewards:** enabled (normal progression rewards).

### Submission constraints
A run may submit only if:
- runType == Competitive
- `levelId` matches board
- `seasonId` matches current board window
- `seed` matches board seed
- `rulesetVersion` matches board
- `scoreVersion` matches board
- replay is compatible (for ghost submission)

---

## 6. Weekly Challenge (Featured Competitive)

### Purpose
A highly visible weekly competition that drives retention.

### Window (weekly)
- Weekly board rotates every week (e.g., `W2026-05`), with explicit countdown.

### Rules
- **Seed:** fixed for the weekly board.
- **Ruleset:** may include curated modifiers for the week, but must remain deterministic.
- **Leaderboard:** enabled (weekly leaderboard).
- **Ghosts:** enabled (Top 10 ghosts for that week).

### Rewards & Achievement (Weekly Top 10)
- Weekly grants normal run rewards (same base as Competitive by default).
- If the player **finishes the week in Top 10**, they earn a **Weekly Top-10 Achievement**.
  - Award timing: **on week rollover** (final standings), not immediately after a run.
  - Scope: per-week; achievement ID includes `weekId` (e.g., `weekly_top10_W2026-05`).
  - Nature: **cosmetic / status only** (badge, title, profile flair). No power, no pay-to-win.
  - Persistence: stored permanently in the player’s profile / Codex-like “Achievements” list.
  - Display: visible next to the player name in leaderboards, and in a profile badge row.
  - Ties: if multiple players tie for rank 10 by the board’s tie-break rules, only the final ordering counts.

### Relationship to Competitive
- Weekly is **not a replacement** for per-level Competitive boards.
- Weekly is its own board key and UI surface.
- Weekly entry points may route the player to the **Weekly Leaderboards** first if they want to pick a Top-10 ghost explicitly.

---

## 7. Leaderboard & Ghost Keys

### 7.1 Board key (recommended)
A leaderboard is uniquely identified by:

- `mode` (Competitive | Weekly)
- `levelId`
- `windowId` (`seasonId` for Competitive, `weekId` for Weekly)
- `rulesetVersion`
- `scoreVersion`

### 7.2 Ghost key (recommended)
A ghost is identified by:

- `boardKey`
- `rank` or `entryId`
- `ghostVersion` (serialization/schema)

Only Top 10 per board must be guaranteed. Everything else is optional.

---

## 8. Sorting & Display Rules

- Ranking is **score-first**, with **time as a tie-breaker**.
- Ghost racing is restricted to Top 10 entries on Competitive/Weekly boards (no racing outside Top 10).
- Leaderboards UI must show:
  - **Top 10**
  - **Your rank pinned** (even if outside top 10)
- Ghost racing UI must show:
  - ghost compatibility (OK / incompatible / missing)
  - explicit selection of which top-10 ghost will be raced

---

## 9. Versioning & Compatibility (non-negotiable)

* **Hard gate (chosen strategy):**
  * If `client.gameCompatVersion != board.gameCompatVersion`:
    * **Competitive/Weekly are locked (cannot start runs).**
    * Leaderboards/ghosts are viewable only if you want, but **ghost racing is disabled**.
    * UI message: **“Update required to play Competitive/Weekly.”**
  * Practice remains available.

### Minimum policy (chosen strategy: hard reject + prompt update)
- Players may still **play** Competitive/Weekly on mismatched versions, but **cannot submit**.
- If versions mismatch:
  - **Leaderboard submission is rejected** and UI shows: **“Update required to submit to Competitive/Weekly.”**
  - **Ghost upload and ghost racing are disabled** with the same reason (compatibility/version mismatch).
- No “outdated boards” are created in this strategy (keeps boards clean and backend simple).
