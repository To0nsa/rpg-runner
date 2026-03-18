# Achievement System Design (V1)

## Purpose

Achievements exist to:

* add **long-term goals** without adding raw power creep
* teach and reinforce **skill expression** (timing, resource discipline, risk decisions)
* drive **repeat play** through Weekly participation and personal improvement loops
* feed horizontal progression systems such as **cosmetics, profile identity, Codex, QoL, and unlock currency**

> **Non-negotiable rule:** achievements must **never** grant permanent combat power in competitive contexts.

---

## Design Principles

1. **No competitive power rewards**
   Achievements unlock cosmetics, profile identity, Codex content, QoL, or sidegrade/unlock currency only.

2. **Deterministic resolution first**
   Achievements must resolve from a stable run summary and a small set of explicit runtime events. Do not rely on UI state or inferred gameplay interpretation.

3. **Server authority where integrity matters**
   Weekly and any competitive mode must resolve from server-authoritative results or deterministic replay verification.

4. **Skill over grind in prestige layers**
   Weekly and mastery achievements should primarily reward execution, consistency, and improvement, not unhealthy volume.

5. **Data-driven authoring**
   Achievement definitions, thresholds, rewards, and mode restrictions must be data-authored, not hardcoded in gameplay logic.

6. **V1 should stay narrow**
   Only ship achievements backed by metrics the game can already measure clearly and cheaply.

---

## 1. Modes and Integrity

### 1.1 Mode tags

Each achievement has one mode tag:

* **Any**: valid in Practice and Weekly/competitive-eligible runs
* **Weekly**: valid only in Weekly Challenge runs under the fixed weekly ruleset
* **Competitive**: valid only in competitive runs if you later split Weekly from other ranked modes
* **Practice**: valid only in Practice, usually for experimentation or tutorial-like goals

### 1.2 Baseline anti-cheese rules

* Practice cannot award prestige achievements tied to rank, bracket, or leaderboard position.
* Any achievement based on run completion, distance, or survival must require a **minimum valid run**.
* Immediate quit, instant restart spam, or failed initialization must never count as a run completion.
* Lifetime counters should persist across reinstall/login restoration when the profile backend exists.
* Weekly achievements must validate against the exact **weekly ruleset identity** and submission contract.

### 1.3 Minimum valid run

A run is considered valid for achievement progress only if one of these is true:

* distance reached `>= minDistanceForValidity`
* time alive `>= minTimeAliveForValidity`
* a valid completion state was reached

Recommended V1 defaults:

* `minDistanceForValidity = 300m`
* `minTimeAliveForValidity = 60s`

Tune later per mode if needed.

---

## 2. Categories

V1 ships four categories:

1. **Milestones** — pure long-term progress counters
2. **Mastery** — execution and decision-making checks
3. **Build Exploration** — variety, discovery, and loadout experimentation
4. **Weekly / Seasonal** — participation, personal improvement, and prestige hooks

---

## 3. Tiering Model

Each achievement has one to three tiers:

* **Bronze**
* **Silver**
* **Gold**

Tier intent:

* **Bronze** = I tried it
* **Silver** = I can do it consistently
* **Gold** = I am skilled or committed

Tuning rule:

* Bronze should usually be reachable in the first **1 to 3 sessions**
* Silver should feel like short-term mastery or familiarity
* Gold should usually land across **weeks**, not years
* Only a very small number of capstones should be true long-haul goals

---

## 4. Tracking Metrics

## 4.1 Core counters for V1

These are the metrics V1 achievements are allowed to depend on:

* `runs_started_total`
* `runs_completed_total`
* `distance_total_m`
* `best_distance_m` (per mode where relevant)
* `time_alive_total_s`
* `enemies_killed_total`
* `weekly_participations_total`
* `weekly_streak_weeks`
* `ghosts_beaten_total`
* `parries_total`
* `perfect_parries_total`
* `damage_taken_total`
* `no_hit_segments_completed_total`
* `statuses_applied_total`
* per-status totals such as `bleed_applied_total`, `stun_applied_total`, `slow_applied_total`, `drench_applied_total`, etc.
* `unique_main_weapons_used_count`
* `unique_offhands_used_count`
* `unique_projectiles_used_count`
* `unique_spellbooks_used_count`
* `unique_accessories_used_count`
* `unique_abilities_used_count`
* `unique_procs_triggered_count`
* `resource_spent_total`
* per-resource totals such as `mana_spent_total`, `stamina_spent_total`
* `cooldowns_used_total`
* `kill_streak_without_damage_best`

## 4.2 Explicitly deferred metrics

The following are **not** required for V1 and should not block shipping the system:

* boss kill counters
* telegraph-avoidance counters
* rank delta inside a week
* time-window combo pattern evaluators
* average-resource-under-threshold evaluators
* calendar-day attendance unless profile/date infrastructure is already stable
* loadout preset save counters unless presets are already implemented in UX and persistence

These can be added later once telemetry contracts are stable.

---

## 5. Resolution Model

### 5.1 Single-source resolution

Achievements resolve from:

* a **run summary** for aggregate and end-of-run checks
* a compact set of **explicit key events** for skill checks

Avoid deriving achievements from transient presentation state.

### 5.2 Resolution authority

* **Practice**: may resolve locally
* **Weekly / Competitive**: must resolve on server-authoritative run results or deterministic replay verification

### 5.3 Progress scope

Each achievement declares one scope:

* `lifetime`
* `single_run`
* `weekly`
* `season`

### 5.4 Evaluator types

V1 achievement logic should use a small evaluator set only:

* `counter_threshold`
* `best_value_threshold`
* `run_predicate`
* `unique_count_threshold`
* `streak_threshold`
* `percentile_threshold`
* `personal_improvement_threshold`

Anything more complex should be deferred until there is a strong need.

---

## 6. Rewards (Non-Power Only)

### 6.1 Reward types

Achievements may grant:

* **Cosmetics**: skins, trails, UI themes, emotes
* **Profile**: titles, badges, frames
* **Codex**: entries, lore pages, mechanical tips
* **QoL**: loadout presets, training tools, stat breakdown overlays
* **Unlock Currency**: used only for sidegrades, cosmetics, or utility unlocks

### 6.2 Default reward curve

* **Bronze**: small currency reward plus Codex snippet
* **Silver**: currency plus badge or profile flair
* **Gold**: title, cosmetic, frame, or notable QoL unlock

### 6.3 Reward policy

Never grant:

* permanent damage bonuses
* permanent defense bonuses
* permanent stat growth
* exclusive combat-affecting unlocks required for competitive parity

---

## 7. Achievement List (V1)

V1 intentionally ships a **smaller, cleaner, implementation-safe set** instead of an oversized list with fuzzy contracts.

Total: **24 achievements**

* 6 Milestones
* 6 Mastery
* 6 Build Exploration
* 6 Weekly / Seasonal

---

## 7.1 Milestones (6)

| ID  | Name           | Mode | Thresholds (B/S/G)                            | Notes                                                         |
| --- | -------------- | ---: | --------------------------------------------- | ------------------------------------------------------------- |
| M01 | First Steps    |  Any | Complete runs: `1 / 10 / 50`                  | Completion must be a valid run end, not instant quit          |
| M02 | Marathoner     |  Any | Best distance: `500m / 2,000m / 10,000m`      | Cleaner V1 thresholds than oversized capstones                |
| M03 | Road Warrior   |  Any | Total distance: `5,000m / 50,000m / 250,000m` | Lifetime progress anchor                                      |
| M04 | Still Standing |  Any | Time alive total: `15m / 3h / 20h`            | Good for early retention                                      |
| M05 | Slayer         |  Any | Enemies killed: `100 / 1,000 / 10,000`        | Safe lifetime counter                                         |
| M06 | Cast Happy     |  Any | Ability casts: `100 / 1,000 / 10,000`         | Uses cooldown/cast totals already aligned with runtime intent |

### Why these stay

These are cheap, deterministic, easy to explain, and useful for onboarding players into the overall progression loop.

---

## 7.2 Mastery (6)

| ID  | Name           | Mode | Thresholds (B/S/G)                                                   | Skill contract                               |
| --- | -------------- | ---: | -------------------------------------------------------------------- | -------------------------------------------- |
| S01 | Parry Initiate |  Any | Parries in one run: `3 / 8 / 15`                                     | Teaches timing and reaction                  |
| S02 | Perfect Form   |  Any | Perfect parries in one run: `1 / 3 / 8`                              | Requires tight-window execution              |
| S03 | No-Hit Segment |  Any | No-hit segments completed: `1 / 3 / 8`                               | Segment duration must be explicitly authored |
| S04 | Risk Taker     |  Any | Finish a valid run with `0` healing used: `1 / 3 / 10`               | Strong, readable constraint                  |
| S05 | Execution      |  Any | Best kill streak without taking damage: `10 / 20 / 35`               | Clear skill expression                       |
| S06 | Comeback       |  Any | Recover from `<=10% HP` to `>=50% HP` and survive `30s`: `1 / 3 / 8` | Clutch recovery event                        |

### Why these stay

These are the mastery checks that are both readable and worth implementing. They reward timing, control, and survival without requiring fragile interpretation systems.

---

## 7.3 Build Exploration (6)

| ID  | Name              | Mode | Thresholds (B/S/G)                        | Intent                                     |
| --- | ----------------- | ---: | ----------------------------------------- | ------------------------------------------ |
| B01 | Weapon Tourist    |  Any | Unique main weapons used: `2 / 4 / 8`     | Encourages primary-slot exploration        |
| B02 | Offhand Dabbler   |  Any | Unique offhands used: `2 / 4 / 8`         | Supports shield / offhand exploration      |
| B03 | Arcane Arsenal    |  Any | Unique projectile items used: `2 / 4 / 8` | Promotes spell projectile variety          |
| B04 | Spellbook Scholar |  Any | Unique spellbooks used: `2 / 4 / 8`       | Matches current spellbook identity layer   |
| B05 | Ability Explorer  |  Any | Unique abilities used: `6 / 15 / 30`      | Cross-slot experimentation goal            |
| B06 | Status Scientist  |  Any | Unique statuses applied: `3 / 6 / 10`     | Reinforces status vocabulary and discovery |

### Why these stay

They fit the current gear ecosystem cleanly: main weapon, offhand, projectile, spellbook, abilities, and status identities already matter in the game. They promote horizontal engagement without inventing fake complexity.

### Explicit cut from old draft

The old `Two-Handed Main` achievement is removed from V1. The current vertical slice should not ship achievements centered on a weapon style that is not part of the active roster focus.

---

## 7.4 Weekly / Seasonal (6)

| ID  | Name           |   Mode | Thresholds (B/S/G)                                         | Retention / prestige role                              |
| --- | -------------- | -----: | ---------------------------------------------------------- | ------------------------------------------------------ |
| W01 | Weekly Visitor | Weekly | Submit valid weekly runs: `1 / 5 / 15`                     | Basic weekly participation hook                        |
| W02 | Consistency    | Weekly | Weekly streak: `2 / 4 / 8` weeks                           | Consecutive engagement, not too punishing              |
| W03 | Personal Best  | Weekly | Improve your own weekly best score: `1 / 3 / 10`           | Self-improvement loop                                  |
| W04 | Ghost Racer    | Weekly | Beat ghosts: `1 / 5 / 20`                                  | Social/competitive mastery without raw rank dependence |
| W05 | Top Bracket    | Weekly | Finish in top `50% / 20% / 5%`                             | Prestige achievement, Weekly only                      |
| W06 | Flawless       | Weekly | Finish a valid Weekly run with `0` hits taken: `1 / 2 / 5` | High-skill prestige capstone                           |

### Why these stay

This set keeps Weekly focused on the right things:

* show up
* improve yourself
* interact with ghosts
* perform well under fixed rules
* earn prestige through execution

### Explicit cuts from old draft

The following were removed from V1 because they add noise or verification cost without enough value:

* submit in first 24h
* submit in last 24h
* rank climb within the same week
* over-granular weekly attendance gimmicks

Those are retention mechanics, not strong achievements.

---

## 8. Deferred Achievement Candidates

These are valid future expansions, but should not be part of V1:

* no-revive run chains
* constrained archetype week rules
* percentile + score ladder hybrids
* proc-family achievements split by hook type
* resource discipline achievements based on authored low-resource windows
* telegraph dodge achievements
* preset/loadout save achievements
* season finisher achievements
* per-element path achievements (`burn`, `freeze`, `poison`, etc.)
* control path achievements (`stun`, `slow`, `silence`, etc.)

Ship V1 first. Expand only when telemetry and UX support it cleanly.

---

## 9. Authoring Schema

Each achievement should be authored as data.

Suggested structure:

```yaml
id: W06
name: Flawless
category: weekly
mode: weekly
scope: weekly
metric_type: run_predicate
evaluator: run_predicate
predicate_id: weekly_no_hit_clear
min_valid_run:
  distance_m: 300
  time_alive_s: 60
tiers:
  - tier: bronze
    threshold: 1
    reward_bundle_id: reward_w06_b
  - tier: silver
    threshold: 2
    reward_bundle_id: reward_w06_s
  - tier: gold
    threshold: 5
    reward_bundle_id: reward_w06_g
```

Minimum recommended fields:

* `id`
* `name`
* `category`
* `mode`
* `scope`
* `metric_type`
* `evaluator`
* `metric_key` or `predicate_id`
* `min_valid_run`
* `tiers[]`
* `reward_bundle_id`
* `visibility`
* `is_hidden_until_progress` if you want secret achievements later

---

## 10. Metric Contracts

For every non-trivial achievement, define:

* source metric or source event
* evaluation scope
* minimum valid run rule
* fail conditions
* whether progress can occur multiple times in one run
* whether resolution is local or server-authoritative

Examples:

### S02 — Perfect Form

* source event: `perfect_parry`
* scope: `single_run`
* valid modes: `Any`
* progress rule: count number of `perfect_parry` events in the run
* reset rule: counter resets at run start
* validity: run must satisfy minimum valid run
* authority: local in Practice, server-authoritative in Weekly

### W03 — Personal Best

* source metric: weekly submitted score
* scope: `weekly`
* valid modes: `Weekly`
* progress rule: count a success when current week best score exceeds previous recorded week best for the player
* authority: server-authoritative only

### B06 — Status Scientist

* source metric: unique status IDs applied across lifetime
* scope: `lifetime`
* valid modes: `Any`
* progress rule: increment unique set when a status application is confirmed on a valid target
* authority: local acceptable in Practice, authoritative summary preferred everywhere else

---

## 11. UI and UX Rules

* Show category and tier clearly.
* Show exact progress bars for milestone and exploration achievements.
* Show mastery achievements with strict condition text, not vague flavor wording.
* Weekly achievements should display the current weekly ruleset tag to avoid confusion.
* Prestige achievements should surface profile-facing rewards clearly.
* Avoid hidden math in descriptions; the player should understand what counts.

Examples of good player-facing phrasing:

* **Parry 8 attacks in a single valid run**
* **Finish a valid Weekly run without taking a hit**
* **Use 4 different spellbooks across your profile**

Examples of bad phrasing:

* **Play boldly**
* **Become unstoppable**
* **Master tempo**

Flavor can exist in titles, not in unclear requirements.

---

## 12. Tuning Checklist

Before shipping any achievement:

* Is the metric already tracked explicitly?
* Is the result deterministic?
* Can the player understand the condition easily?
* Can it be explained in one sentence without ambiguity?
* Does it reward skill, variety, or healthy long-term engagement?
* Can it be cheesed by restart spam, fake inputs, or edge-case state?
* Does the reward avoid competitive power?

If any answer is weak, cut or defer the achievement.

---

## 13. Final V1 Scope Summary

### Ship now

* **24 achievements** total
* fully data-driven definitions
* deterministic run-summary and explicit-event resolution
* server-authoritative Weekly achievements
* only non-power rewards

### Do not ship in V1

* fuzzy achievements requiring interpretation-heavy telemetry
* achievements tied to unsupported or non-core roster fantasies
* attendance gimmicks disguised as prestige
* over-grindy thresholds that take months before feeling relevant

---

## Final Recommendation

This achievement system should launch as a **clean, trustworthy, narrow V1 layer**.

The win condition is not content count. The win condition is:

* players understand what they are chasing
* the backend resolves it correctly
* rewards feel good without breaking balance
* the system can expand later without rewrites

That is the correct base for this game.
