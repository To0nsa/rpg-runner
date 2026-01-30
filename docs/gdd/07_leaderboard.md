# Leaderboards

This document defines **what leaderboards are**, how they’re **keyed**, **ranked**, **submitted**, and **displayed** across the three run contexts:

- **Practice** → local-only **PB scoreboard** (device).
- **Competitive (Season)** → global leaderboard.
- **Weekly Challenge** → global leaderboard + end-of-week Top-10 achievement.

---

## 1. Goals (non-negotiable)

1. **Fairness**
   - Comparable runs must share the same **seed + rulesetVersion + scoreVersion**.
2. **Determinism**
   - Ranking must use deterministic run stats (score/distance/duration), not wall-clock time.
3. **Clarity**
   - UI shows Top 10 + your pinned rank, and makes ghost selection explicit.
4. **Async-first UX**
   - Leaderboards must never block “Start Run”; show cached/stale data immediately.
5. **Version integrity (hard gate)**
   - **Old / incompatible versions may not enter Competitive or Weekly at all.**
   - Practice remains always playable.

---

## 2. Version model (terminology)

- `buildVersion`: human-readable build tag (e.g. 1.3.2+45). Not a gating key by itself.
- `gameCompatVersion`: **coarse compatibility gate**. If this differs from the active board’s compat, Competitive/Weekly are **locked**.
- `rulesetVersion`: gameplay-affecting rules (spawns, costs, timings, physics knobs, etc.).
- `scoreVersion`: score formula version (weights, multipliers, rank thresholds, etc.).
- `ghostVersion`: replay/ghost serialization schema.

**Rule:** Competitive/Weekly require exact `gameCompatVersion` match with the active board.  
(Later relax to `>= minCompatVersion`, but start strict to avoid edge-case fairness issues.)

---

## 3. Modes & eligibility

### 3.1 Practice (PB scoreboard)
- Random seed, no submissions, no ghosts.
- Stored on-device only (PB feedback loop).
- Never blocked by version.

### 3.2 Competitive (Season)
- Fixed seed per `(levelId, seasonId)` window; submission + Top-10 ghosts enabled.
- **Eligibility:** user must run a compatible client:
  - `client.gameCompatVersion == board.gameCompatVersion`
  - otherwise **mode is locked** (cannot start the run).

### 3.3 Weekly Challenge
- Fixed seed + fixed ruleset for the week; submission + Top-10 ghosts enabled.
- Weekly Top-10 achievement is awarded **at rollover**, not instantly.
- **Eligibility:** same hard gate as Competitive:
  - `client.gameCompatVersion == board.gameCompatVersion`
  - otherwise **mode is locked** (cannot start the run).

---

## 4. Board identity (the “board key”)

A leaderboard is uniquely identified by:

- `mode` : `Competitive | Weekly`
- `levelId`
- `windowId` : `seasonId` (Competitive) or `weekId` (Weekly)
- `rulesetVersion`
- `scoreVersion`

Recommended serialized shape:

```txt
BoardKey {
  mode,
  levelId,
  windowId,
  rulesetVersion,
  scoreVersion
}
```

**Why:** if any gameplay-affecting rule or score formula changes, you must bump version(s) so boards stay clean and comparable.

### 4.1 Board metadata (not part of BoardKey)
Boards also carry:

```txt
BoardMeta {
  gameCompatVersion,   // hard gate for entering the mode
  seed,                // fixed seed for the window
  opensAt, closesAt,   // window timing
}
```

`gameCompatVersion` is intentionally **not** in the BoardKey; it’s a *mode gate* (either you can enter, or you can’t).

---

## 5. Leaderboard entry schema

### 5.1 Minimal entry fields (server + client UI)

Each leaderboard row needs:

```txt
LeaderboardEntry {
  entryId            // server-generated stable id
  boardKey
  playerId           // opaque id
  displayName        // sanitized
  characterId        // optional (icon)
  score
  distanceMeters
  durationSeconds
  submittedAt        // server time for auditing only (NOT ranking)
  buildVersion
  gameCompatVersion
  rulesetVersion
  scoreVersion
  ghostRef?          // only for top-10 (see §7)
}
```

Score and its breakdown are computed deterministically from run stats.

### 5.2 Privacy
- `displayName` must be safe (length cap, profanity filter later).
- Avoid exposing raw `playerId`; keep it opaque.

---

## 6. Ranking rules (sorting / tie-breaks)

Use deterministic ranking:

1. Higher **score** wins.
2. If tied: higher **distanceMeters** wins.
3. If still tied: lower **durationSeconds** wins.

**Do not** use wall-clock time (`submittedAt`) as a tie-breaker for ranking.

---

## 7. Ghosts (Top 10 only)

Ghosts are restricted to **Top 10** for Competitive/Weekly boards.

### 7.1 Ghost key
Recommended:

- `boardKey`
- `rank` or `entryId`
- `ghostVersion`

### 7.2 Storage policy
- Server guarantees availability for Top 10 ghosts (everything else optional).
- Ghost payload must include `ghostVersion` and `gameCompatVersion`.
- If incompatible/missing, UI must disable “Race Ghost” and show why.

### 7.3 Ghost selection UX
- No implicit target selection: player explicitly chooses which Top-10 ghost to race.

---

## 8. Submission & validation pipeline (global)

### 8.1 Client prerequisites
A run may submit only if it satisfies:

- mode = Competitive/Weekly
- `client.gameCompatVersion == board.gameCompatVersion` (already guaranteed by hard gate)
- correct `levelId`, `windowId`
- correct `seed`
- correct `rulesetVersion`, `scoreVersion`
- replay compatible (if ghost is included)

### 8.2 Server validation (minimum sane posture)
On submission:

1. Validate `BoardKey` exists and is active.
2. Validate **compat gate**:
   - If `gameCompatVersion` mismatch: reject with `UPDATE_REQUIRED` (defensive).
3. Validate payload sanity (non-negative stats, bounds).
4. Persist entry.
5. If entry enters Top 10:
   - accept/store ghost payload (if provided and compatible)
   - update Top 10 set atomically for that board.

### 8.3 Weekly Top-10 achievement awarding
- Award happens **at week rollover** based on final standings.
- If ties occur around rank 10, the final ordering still produces a single Top 10 list.

---

## 9. UI surfaces

### 9.1 Dedicated Leaderboards screen (browse + ghost select)
- Mode selector:
  - Practice (PB) / Competitive (Season) / Weekly
- Board selector:
  - Practice: pick level → local PB list
  - Competitive: pick level → current season board
  - Weekly: current week board + countdown
- List:
  - Show **Top 10** always.
  - Show **your rank pinned**, even if outside top 10.
- Ghost panel:
  - Only for Competitive/Weekly
  - Explicit “Race Ghost” action

### 9.2 Mode lock UX (Update required)
If `client.gameCompatVersion != activeBoard.gameCompatVersion`:

- Competitive and Weekly buttons show a **lock** icon + “Update required”.
- Clicking shows:
  - required version label
  - an “Update” CTA (platform store deep link later)
  - fallback: “Play Practice” button

This is a **hard gate**: the user cannot start an incompatible Competitive/Weekly run.

### 9.3 Game Over overlay leaderboard panel (small)
Keep the Game Over leaderboard panel as a **small, fast Top-10 view**, and route deep browsing to the full Leaderboards screen.

---

## 10. Client storage architecture

### 10.1 Practice PB (local)
- `PracticeScoreboardStore` (SharedPreferences is fine initially).
- Sorting must match §6:
  - `score desc`
  - `distanceMeters desc`
  - `durationSeconds asc`
  - final tie-breaker: `runId desc` (stable)

### 10.2 Online (Competitive/Weekly)
- `OnlineLeaderboardStore`:
  - caches Top 10 + “my rank”
  - separate caches per BoardKey
- Never mix Practice PB data with online boards.

---

## 11. Error states (UI requirements)

- Offline:
  - Show cached results (if any), label as “Offline”.
  - Practice always playable.
  - Competitive/Weekly:
    - If board metadata is cached and compat matches, allow play.
    - If you cannot confirm compat/board state, disable entry (fail closed) or clearly mark “Cannot verify board (offline)”.
- **Update required:**
  - Competitive/Weekly are **locked** (cannot start runs, cannot view ghosts, cannot submit).
  - Practice remains available.
- No data:
  - “No runs yet.”

---

## 12. Minimal acceptance checklist

- Practice PB is local-only and never mixed with online boards.
- Competitive/Weekly boards are keyed by `(mode, levelId, windowId, rulesetVersion, scoreVersion)`.
- **Old versions cannot enter Competitive/Weekly** (hard gate on `gameCompatVersion`).
- Ranking uses deterministic tie-breakers (score → distance → duration).
- UI shows Top 10 + your pinned rank; ghost selection is explicit.
- Server defensively rejects mismatched submissions with `UPDATE_REQUIRED`.
