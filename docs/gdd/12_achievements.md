# Achievements

Achievements exist to:
- Add **long-term goals** without adding raw power creep.
- Teach and reinforce **skill expression** (timing, resource discipline, risk decisions).
- Drive **repeat play** via Weekly participation + personal improvement loops.
- Feed horizontal progression systems: **cosmetics, profile identity, Codex, QoL**, unlock currency.

> Rule: Achievements must **never** grant permanent combat power in competitive contexts.

---

## 1. Modes & Integrity

### 1.1 Mode eligibility
Achievements can be tagged with one of:
- **Any**: valid in Practice + Competitive/Weekly.
- **Weekly**: only valid in Weekly Challenge (fixed seed/rules).
- **Competitive**: only valid in competitive runs (if you split Weekly vs other competitive modes later).
- **Practice**: only valid in Practice (usually for “lab/experimentation” achievements).

### 1.2 Anti-cheese rules (baseline)
- **No prestige achievements** (rank/top %) in Practice.
- “Win”/“distance” achievements must require **non-trivial duration** (e.g., distance ≥ X OR time alive ≥ Y) to avoid “restart spam”.
- Count-based achievements should be **lifetime totals** (not reset on uninstall) but expose per-season ladders optionally.

---

## 2. Categories

We ship 4 categories (each with tiered thresholds):
1) **Milestones** (pure progress counters)
2) **Mastery** (skill checks)
3) **Build Exploration** (variety / discovery)
4) **Weekly / Seasonal** (retention hooks)

---

## 3. Tiering model

Each achievement can have 1–3 tiers:
- **Bronze / Silver / Gold**
- Thresholds are designed to be achievable across weeks/months.
- Rewards scale per tier.

**Default threshold scaling** (guideline):
- Bronze = “I tried it”
- Silver = “I’m consistent”
- Gold = “I’m committed / skilled”

---

## 4. Tracking Metrics

### 4.1 Core counters (minimal v1)
- `runs_started_total`
- `runs_completed_total`
- `distance_total_m`
- `best_distance_m` (per mode)
- `time_alive_total_s`
- `enemies_killed_total`
- `bosses_killed_total` (if bosses exist later; keep optional)
- `weekly_participations_total`
- `weekly_streak_weeks` (consecutive participation)
- `ghosts_beaten_total`
- `parries_total`
- `perfect_parries_total` (tight window)
- `dodges_total` (or “damage avoided” events)
- `damage_taken_total`
- `no_hit_segments_completed_total`
- `statuses_applied_total` + per-status counters (`bleed_applied_total`, `stun_applied_total`, etc.)
- `unique_weapons_used_count` (lifetime)
- `unique_abilities_used_count` (lifetime)
- `unique_procs_triggered_count` (lifetime)
- `resource_spent_total` (mana/stamina) + per-resource
- `cooldowns_used_total` (ability casts)

### 4.2 Snapshot-proofing / determinism
- Achievements should be resolved on **server-authoritative** results for Weekly/Competitive (or deterministic replay verification).
- Practice can resolve locally, but still uses deterministic counters.

---

## 5. Rewards (non-power)

### 5.1 Reward types
- **Cosmetics**: skins, trails, UI themes, emotes.
- **Profile**: titles, badges, frames.
- **Codex**: entries/unlocks (lore + mechanical tips).
- **QoL**: additional loadout presets, training tools, stat breakdown overlays.
- **Unlock Currency**: buys **sidegrades/unlocks**, not raw upgrades.

### 5.2 Default reward curve (v1 intent)
- Bronze: small currency + Codex snippet
- Silver: currency + badge
- Gold: cosmetic or title (and optionally a QoL unlock if it’s a “meta” achievement)

---

## 6. Achievement List v1 (48 total, tiered)

Legend:
- **Mode**: Any / Weekly / Competitive / Practice
- **Thresholds**: B/S/G

### 6.1 Milestones (12)

| ID | Name | Mode | Thresholds (B/S/G) | Notes |
|---|---|---:|---|---|
| M01 | First Steps | Any | Complete runs: 1 / 10 / 50 | Completion = “run ended legitimately” (not immediate quit) |
| M02 | Marathoner | Any | Best distance: 2k / 10k / 50k meters | Per-mode best distance can be separate later |
| M03 | Road Warrior | Any | Total distance: 25k / 250k / 2,500k meters | Lifetime grind, but reasonable |
| M04 | Still Standing | Any | Time alive total: 30m / 5h / 50h | |
| M05 | Slayer | Any | Enemies killed: 250 / 2,500 / 25,000 | |
| M06 | Efficient | Any | Runs completed without revive: 5 / 25 / 100 | If revives exist |
| M07 | Collector | Any | Collectibles picked: 100 / 1,000 / 10,000 | Uses your “collectibles” run stat |
| M08 | Spell Budget | Any | Resource spent total: 5k / 50k / 500k | Sum mana+stamina, tracked separately too |
| M09 | Cast Happy | Any | Ability casts: 250 / 2,500 / 25,000 | |
| M10 | Clean Slate | Any | Finish runs with 0 unused healing: 3 / 15 / 50 | Forces planning; skip if no healing items |
| M11 | Survivor | Any | Finish run with HP ≤ 10%: 1 / 5 / 20 | Clutch moments |
| M12 | The Routine | Any | Play days: 3 / 14 / 60 | Distinct calendar days played |

### 6.2 Mastery (12)

| ID | Name | Mode | Thresholds (B/S/G) | Skill contract |
|---|---|---:|---|---|
| S01 | Parry Initiate | Any | Parries in one run: 3 / 10 / 25 | Teaches timing |
| S02 | Perfect Form | Any | Perfect parries in one run: 1 / 5 / 15 | “Perfect” = tight window |
| S03 | No-Hit Segment | Any | No-hit segments: 1 / 3 / 10 | Define segment = N seconds or N chunks |
| S04 | Iron Lungs | Any | Survive with low resources (avg) in run: 1 / 5 / 20 | Avg mana+stamina under threshold |
| S05 | Risk Taker | Any | Finish a run with 0 healing used: 1 / 5 / 20 | Not necessarily no-hit |
| S06 | Tempo | Any | Use 3 abilities within X ticks repeatedly: 1 / 5 / 20 | Encourages combos |
| S07 | Crowd Control | Any | Apply CC then kill within T seconds: 3 / 15 / 50 | CC = stun/slow/root |
| S08 | Execution | Any | Kill streak without taking damage: 10 / 25 / 50 | |
| S09 | Dodge Discipline | Any | Avoid X telegraphed attacks in a run: 3 / 10 / 25 | Needs “telegraph avoided” event |
| S10 | Minimalist | Any | Reach distance with only 1 ability type used: 500m / 2k / 10k | Forces constraints |
| S11 | Comeback | Any | Recover from ≤10% HP to ≥50% HP and survive 30s: 1 / 3 / 10 | Requires healing/regeneration |
| S12 | Flawless | Weekly | Finish Weekly run with 0 hits taken: 1 / 2 / 5 | Weekly-only prestige |

### 6.3 Build Exploration (12)

| ID | Name | Mode | Thresholds (B/S/G) | Intent |
|---|---|---:|---|---|
| B01 | Loadout Tinkerer | Any | Unique loadouts saved: 2 / 10 / 25 | Promotes presets |
| B02 | Weapon Tourist | Any | Unique Primary weapons used: 3 / 8 / 15 | Lifetime |
| B03 | Offhand Dabbler | Any | Unique Offhand gear used: 2 / 6 / 12 | |
| B04 | Arcane Arsenal | Any | Unique Projectile items used: 2 / 6 / 12 | |
| B05 | Utility Specialist | Any | Unique Utility gear used: 2 / 6 / 12 | |
| B06 | Ability Explorer | Any | Unique abilities used: 10 / 25 / 50 | Across all slots |
| B07 | Proc Hunter | Any | Unique procs triggered: 5 / 12 / 25 | Includes gear procs |
| B08 | Status Scientist | Any | Unique statuses applied: 3 / 6 / 10 | bleed/stun/burn/slow/etc |
| B09 | Two-Handed Main | Any | Distance with 2H equipped: 1k / 10k / 50k | Encourages style |
| B10 | Dual Setup | Any | Distance with 1H + offhand: 1k / 10k / 50k | |
| B11 | Elemental Path | Any | Apply elemental statuses: 25 / 250 / 2,500 | burn/freeze/poison etc |
| B12 | Control Path | Any | Apply control statuses: 25 / 250 / 2,500 | stun/slow/root etc |

### 6.4 Weekly / Seasonal (12)

| ID | Name | Mode | Thresholds (B/S/G) | Retention hook |
|---|---|---:|---|---|
| W01 | Weekly Visitor | Weekly | Participate: 1 / 5 / 20 | “Participate” = submit a run |
| W02 | Consistency | Weekly | Weekly streak: 2 / 4 / 12 weeks | Consecutive weeks |
| W03 | Personal Best | Weekly | Improve own weekly score: 1 / 5 / 20 | Week-over-week improvement |
| W04 | Ghost Racer | Weekly | Beat ghosts: 1 / 10 / 50 | Any ghost count |
| W05 | Top Bracket | Weekly | Place top: 50% / 20% / 5% | Percentile based |
| W06 | Score Hunter | Weekly | Reach score thresholds: A / S / SS | Use your scoring ladder if present |
| W07 | The Climb | Weekly | Improve rank within a week: 10 / 50 / 200 places | Requires rank tracking |
| W08 | First Submit | Weekly | Submit within first 24h: 1 / 3 / 10 | Encourages early-week engagement |
| W09 | Late Push | Weekly | Submit in last 24h: 1 / 3 / 10 | Encourages comeback |
| W10 | Clean Run | Weekly | No revive used: 1 / 3 / 10 | Prestige |
| W11 | Specialist Week | Weekly | Finish weekly using constrained archetype: 1 / 3 / 10 | Weekly rule can set archetype constraints |
| W12 | Season Finisher | Competitive | Seasons completed: 1 / 2 / 5 | Season = N weeks; optional |

---

## 7. Implementation notes

- Each achievement resolves from a **single event stream** (run summary + key events) to avoid “state divergence”.
- Achievements are authored data; thresholds, mode tags, and rewards are not hardcoded.
- “Weekly” achievements must validate against the **fixed seed/ruleset identity** to prevent cross-week carry.

---

## 8. Tuning checklist

- Bronze tiers should be achievable within the first **1–3 sessions**.
- Gold tiers should be achievable within **weeks**, not years (except 1–2 capstones).
- Weekly/Competitive tiers must not require unhealthy playtime; prefer **skill** over raw volume.
- Add 1–2 “social flex” rewards (titles/frames) tied to Weekly prestige tiers.

