# Eloise Projectile Rework (EV-Balanced)

## Purpose

Replace current projectile ability tuning with a power-equivalent model where abilities are not mechanically identical, but remain equivalent in expected value (EV) under optimal use.

## Contract Linkage

This document is the projectile-category implementation of the global power-equivalence contract in `docs/gdd/02_ability_system.md`.

Scope of this file:

* Defines same-category equivalence for Eloise projectile abilities.
* Locks projectile-specific invariant and validation scenarios.

Out of scope for this file:

* Cross-category mirrored pairs (for example `shield_bash` vs `sword_strike`, `shield_block` vs `sword_parry`), which are documented in `docs/gdd/10_eloise_abilities.md`.

## Balancing Principle (Locked)

- Do not equalize all axes (cost, timing, damage) per ability.
- Equalize **expected value over time** under realistic combat usage.
- Preserve differentiated risk profiles and execution requirements.

### Invariant

Use **Damage per Resource per Second (DPRS)** over realistic combat windows (not lab-perfect conditions) as the primary balancing invariant.

### Secondary Guardrails

Track these alongside DPRS:

- Time-to-kill (TTK) fairness
- Burst-window fairness
- Opportunity-cost parity

## Design Tradeoff Triangle (Locked)

| Ability | Gains | Pays |
|---|---|---|
| Auto-Aim Shot | Reliability | Efficiency |
| Quick Shot | Speed / responsiveness | Damage per action |
| Piercing Shot | Multi-target ceiling | Consistency |
| Charged Shot | Burst scaling | Time commitment and interrupt risk |

Rule: if any ability gains power without a meaningful tax, it becomes dominant and must be retuned.

## First-Pass Ability Matrix (v0.1)

Simulation baseline: 60 Hz Core tick rate, fixed-point damage/cost (`100 = 1.0`).

| Ability | Targeting | Windup / Active / Recovery (ticks) | Cooldown | Mana Cost | Base Damage (`amount100`) | Proc Coefficient | Constraint |
|---|---|---:|---:|---:|---:|---:|---|
| Auto-Aim Shot | `homing` | `6 / 2 / 10` | `24` ticks (0.40s) | `800` | `1300` | `0.75` | Lower efficiency for high reliability |
| Quick Shot | `aimed` | `3 / 1 / 5` | `15` ticks (0.25s) | `600` | `900` | `0.60` | Low damage per action; best responsiveness |
| Piercing Shot | `aimed_line` | `8 / 2 / 8` | `30` ticks (0.50s) | `1000` | `1800` | `1.00` | Narrow line; requires alignment |
| Charged Shot | `aimed_charge` | `24 / 2 / 10` | `36` ticks (0.60s) | `1300` | `2300` (pre-tier) | `1.80` | Interruptible time commitment + tiered hold scaling |

### Charged Shot Tier Policy (Locked)

- Tier thresholds are derived from runtime-scaled windup:
  - `halfTierTicks = max(1, floor(scaledWindupTicks / 2))`
  - `fullTierTicks = scaledWindupTicks`
- Tier outputs:
  - Tap: `0.82x` damage, `0.90x` projectile speed, no extra effect
  - Half: `1.00x` damage, `1.05x` speed, `+5%` crit chance
  - Full: `1.225x` damage, `1.20x` speed, `+10%` crit chance, projectile pierce up to 2 targets
- UI communicates tier progression with charge bar + haptic pulse at half/full thresholds.

Balance lock for this model:
- Maintain EV parity against Auto-Aim / Quick / Piercing under realistic scenarios (DPRS, TTK, opportunity-cost parity).
- Charged Shot keeps explicit tax axis: time commitment and interruption risk.
- Core implementation detail: non-zero damage taken by the caster during Charged Shot interrupts the cast and clears its pending projectile launch.
- If Charged Shot becomes top performer across all standard scenarios, retune tier multipliers before changing other abilities.

### Cycle Time Rule

Use:

`cycleTicks = max(cooldownTicks, windupTicks + activeTicks + recoveryTicks)`

for DPS and DPRS calculations.

## Calibration Assumptions (Realistic Combat)

These assumptions define “optimal use” for EV balancing and should be used consistently in tuning sims.

| Ability | Hit Rate | Completion Rate | Avg Targets Hit | Expected DPS |
|---|---:|---:|---:|---:|
| Auto-Aim Shot | `0.92` | `1.00` | `1.00` | `29.9` |
| Quick Shot | `0.78` | `1.00` | `1.00` | `28.1` |
| Piercing Shot | `0.68` | `1.00` | `1.20` | `29.4` |
| Charged Shot | `0.88` | `0.85` | `1.00` | `28.8` |

EV spread target in this pass: approximately `+-3%`.

## Matchup Expectations (Wins Here / Loses Here)

### Auto-Aim Shot

- Wins when enemy evasion and target-switching pressure are high.
- Loses in efficiency-driven sustained DPS races.

### Quick Shot

- Wins when safe commit windows are short (`< 0.3s`) and weaving is required.
- Loses in long stationary uptime scenarios.

### Piercing Shot

- Wins when expected aligned targets are high (`>= 1.6`).
- Loses in isolated single-target duels.

### Charged Shot

- Wins in planned burst windows with low interruption probability.
- Loses under high disruption or frequent forced movement.

## Acceptance Criteria

1. In 60–90s encounter simulations, expected DPS spread remains within `+-5%` to `+-8%`.
2. No projectile ability is top performer across all standard scenarios.
3. Each ability retains one explicit tax axis (efficiency, per-action damage, consistency, or time-risk).
4. Deterministic replay/ghost runs produce identical projectile outcomes for identical input streams.

## Validation Scenario Set (Minimum)

Run all four abilities through at least these scenarios before approving tuning changes:

1. Single-target duel (stable lane, low movement)
2. Single-target duel (high movement + short punish windows)
3. Multi-target lane (frequent line-up opportunities)
4. Pressure scenario (interrupt/chip risk elevated)

## Integration Notes

- This file defines balancing targets and assumptions only.
- Core `AbilityDef` and runtime tuning should be updated separately.
- UI copy should reflect role clarity (reliability, speed, line reward, burst risk) without exposing internal coefficients.
