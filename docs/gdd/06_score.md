# Score

This document defines **how score is computed and presented** for a run, and how it feeds **local scoreboards** (Practice) and **global leaderboards** (Competitive/Weekly).

Scope: gameplay score (points) + UI breakdown + ranking data contract.  
Out of scope: reward economy math (handled in `run_types.md` / economy docs).

---

## 1. Goals

- Score must be **deterministic**: same inputs/seed → same score.
- Score must be **explainable**: end screen shows a breakdown of where points came from.
- Score must be **cheap to compute**: no heavy per-tick allocations; compute breakdown only on run end.
- Score must be **stable across platforms**: avoid wall-clock time and floating nondeterminism.
- Score must support **Practice vs Competitive/Weekly** modes cleanly.

---

## 2. Terms and units

### 2.1 Internal simulation units

- **tick**: deterministic simulation step count.
- **tickHz**: ticks per second (used to convert ticks → seconds).
- **world units**: internal distance units used by the simulation.

### 2.2 Player-facing units (UI)

Current conversions (code source of truth):

- **meters** = `floor(distanceUnits / unitsPerMeter)`
- **seconds** = `tick ~/ tickHz`

Where `unitsPerMeter = kWorldUnitsPerMeter` (currently **50**) in `lib/core/tuning/score_tuning.dart`.

---

## 3. Score model

Score is the sum of independent rows.

### 3.1 Row kinds

Implemented in Core as `RunScoreRowKind`:

- **Distance**
- **Time survived**
- **Collectibles**
- **Enemy kills** (one row per enemy type with ≥1 kill)

### 3.2 Current formula

Let:

- `m = floor(distanceUnits / unitsPerMeter)`
- `s = tick ~/ tickHz`
- `cCount = collectibles`
- `cScore = collectibleScore` (already computed by pickup rules; see §6.2)
- `kills[e] = enemyKillCounts[e]`

Then:

```
distancePoints = m * ScoreTuning.distanceScorePerMeter
timePoints     = s * ScoreTuning.timeScorePerSecond
collectPoints  = cScore
killPoints     = Σe (kills[e] * enemyKillScore(e))

totalScore = distancePoints + timePoints + collectPoints + killPoints
```

Enemy kill values (current):

- `Grojib` → `ScoreTuning.groundEnemyKillScore` (default 100)
- `UnocoDemon`  → `ScoreTuning.unocoDemonKillScore` (default 150)

### 3.3 Quantization (important gameplay implication)

- Distance points only increase when you cross the next **whole meter** (floor).
- Time points only increase when you cross the next **whole second** (integer division).

---

## 4. Data flow (Core → UI)

### 4.1 Authoritative computation

On run end, Core builds a `RunScoreBreakdown` via:

- `buildRunScoreBreakdown(...)` in `lib/core/scoring/run_score_breakdown.dart`

Inputs include:

- `tick`
- `distanceUnits`
- `collectibles`
- `collectibleScore`
- `enemyKillCounts[]`
- `tuning.score` (from `CoreTuning.score`)
- `tickHz`

Output:

- `rows: List<RunScoreRow>` (immutable)
- `totalPoints`

### 4.2 UI presentation

UI uses the breakdown to render:

- End-of-run score breakdown rows (distance/time/collectibles/enemy-kills)
- Total score
- Scoreboard/leaderboard entry summary (score + distance + duration)

Implementation note: the end screen “score feed” animation should be purely visual (UI-only), never re-computing score in a different way.

---

## 5. Scoreboard vs Leaderboard semantics

This aligns with `run_types.md` and menu UI flows.

### 5.1 Practice (local)

- **Practice runs** produce a **local Scoreboard**:
  - stored on-device
  - used for “PB” and personal progression feedback

### 5.2 Competitive (global)

- **Competitive runs** submit to a **global Leaderboard**.
- **Hard gate**: if the client build is not allowed for Competitive (compat mismatch), Competitive is locked:
  - **“Update required to submit to Competitive/Weekly.”**
  - Player may still play Practice.

### 5.3 Weekly (global, curated)

- Weekly is a **featured competitive level** (front-and-center in menu).
- Weekly uses the same scoring rules as Competitive (no special score math).
- Weekly rewards: **Top 10 → achievement** (see run_types decisions).
- Weekly is locked the same way as Competitive when incompatible.

---

## 6. What contributes to score (design intent + current state)

### 6.1 Distance (core runner signal)

- Reward forward progress, strongly correlated with survival.
- Current default: `5 points / meter`.

### 6.2 Collectibles

- Collectibles contribute via a **precomputed** `collectibleScore`, not “count * points” in the score breakdown.
- Current collectible base value: `CollectibleTuning.valuePerCollectible` (default **50**).

Design note: keeping `collectibleScore` as an explicit stat is future-proof for:
- different collectible types/rarities
- streak multipliers
- bonus pickups

### 6.3 Enemy kills

- Encourages proactive play (not just running).
- Current values are per-enemy-type and live in `ScoreTuning`.
- Breakdown shows one row per enemy type that was actually killed.

---

## 7. Ranking rules (tie-breakers)

### 7.1 Competitive/Weekly

For global leaderboards, pick a deterministic tie-breaker early:

1. Higher **score** wins.
2. If tied: higher **distanceMeters** wins.
3. If still tied: lower **durationSeconds** wins.

This is deterministic and feels fair for runner gameplay.

### 7.2 Practice

Current local scoreboard store uses:

1. Higher **score** wins.
2. If tied: higher **distanceMeters** wins.
3. If still tied: lower **durationSeconds** wins.

---

## 8. Determinism / anti-cheat posture (sane defaults)

- Score must be computed from authoritative run stats (ticks, distance, kills, pickups).
- Avoid wall-clock time (`DateTime.now`, `Stopwatch`) in score computation.
- For Competitive/Weekly submissions:
  - include `build/version` and `ghost schema version` in payload
  - server validates “allowed version” for that season/week (as per run_types)
  - server cannot accept incompatible ghost payloads for leaderboard submission.

(Full validation pipeline belongs in the leaderboard/ghost docs, but score must be designed with this in mind.)

---

## 9. Tuning knobs (where to edit)

- `lib/core/tuning/score_tuning.dart`
  - `timeScorePerSecond`
  - `distanceScorePerMeter`
  - `groundEnemyKillScore`
  - `unocoDemonKillScore`
  - `kWorldUnitsPerMeter`

- `lib/core/tuning/collectible_tuning.dart`
  - `valuePerCollectible`

---

## 10. Known gaps / TODOs

- When more enemy types are added, ensure:
  - `EnemyId.values` ordering is stable
  - `enemyKillCounts` uses `EnemyId.index` consistently
