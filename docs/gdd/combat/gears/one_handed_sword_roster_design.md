# One-Handed Sword Roster Design (V1)

## Purpose

Define a 10-sword, one-handed roster for the vertical slice with clear build identities and explicit tradeoffs so no single sword becomes universal best-in-slot.

## Design Targets

- Every sword should have a clear reason to pick it.
- Every sword should have a clear failure case.
- Damage/safety/control gains must always pay a budget tax.
- Balance should converge quickly with small, repeatable tuning passes.

## Balancing Framework

Normalize a basic sword to an offense budget of `+1.0` EV.

`Plainsteel` is the control group and sets baseline expectations.

When a sword gains extra EV through DoT, vulnerable, or strong control, it must pay using one or more taxes:

- lower `powerBonusBp`
- lower `critChanceBonusBp`
- cooldown penalty
- move speed penalty
- defense penalty

Control-heavy effects (stun, silence, strong slow) must pay through lower direct damage EV and/or low chance/short duration.

## Validation Loop

Run each sword through a fast, deterministic test loop:

- `60s dummy test`: no movement, pure EV damage check
- `dangerous seed x3`: average survivability and clear consistency
- tuning step: nerf outliers by `10-15%` on one primary knob, buff underperformers similarly

Primary knobs:

- `powerBonusBp`
- `critChanceBonusBp`
- proc chance
- proc duration/magnitude
- downside magnitude (`defense`, mobility, cooldown penalties)

## Sword Roster

### 1) Plainsteel

- Role: baseline consistency
- Stats: `power +100bp`
- Proc: none
- Tradeoff: no specialization ceiling

### 2) Waspfang

- Role: fast pressure, bleed attrition
- Stats: `power +50bp`
- Proc: `onHit -> bleed` at `25-35%`
- Tradeoff: lower upfront burst for better sustained pressure

### 3) Cinderedge

- Role: crit-trigger burn, spiky output
- Stats: `crit +200bp`, `power +0bp`
- Proc: `onCrit -> burn` at `100%`
- Tradeoff: volatile performance, weaker when crit stack is low

### 4) Basilisk Kiss

- Role: acid shred, anti-tank
- Stats: `power +50bp`, `crit -100bp`
- Proc: `onHit -> acid` at `20-30%`
- Tradeoff: lower burst in exchange for strong long-fight scaling

### 5) Frostbrand

- Role: tempo control through slows
- Stats: `power +80bp`
- Proc: `onHit -> slow` at `25-40%`
- Tradeoff: slightly reduced raw DPS for safer engagements

### 6) Stormneedle

- Role: rare clutch stun control
- Stats: `power +70bp`
- Proc: `onHit -> stun` at `6-10%`
- Tradeoff: control wins runs, so direct damage is intentionally taxed

### 7) Nullblade

- Role: anti-caster silence utility
- Stats: `power +80bp`
- Proc: `onHit -> silence` at `10-20%`
- Tradeoff: situationally dominant versus casters, below-average in non-caster fights

### 8) Sunlit Vow

- Role: sustain and wave stability
- Stats: `power +70bp`, `defense +100bp`
- Proc: `onKill -> haste (short)` at `100%` (or small heal status if sustain profile is preferred)
- Tradeoff: excellent in wave clear, reduced boss value due to kill-gated trigger

### 9) Graveglass

- Role: high-risk global amplifier
- Stats: `globalPower +120bp`, `defense -150bp`
- Proc: none, or optional `onHit -> vulnerable` at `5-10%`
- Tradeoff: fastest clear potential with the highest death risk

### 10) Duelist's Oath

- Role: skill sword rewarding crit consistency
- Stats: `crit +150bp`, `power +50bp`
- Proc: `onCrit -> weaken` at `100%` (short duration)
- Tradeoff: requires crit uptime and execution; adds safety windows rather than direct proc damage

## Identity Coverage Check

The roster intentionally covers the major build identities:

- Baseline consistency: `Plainsteel`
- DoT pressure: `Waspfang`, `Cinderedge`
- Anti-tank shred: `Basilisk Kiss`
- Tempo/control: `Frostbrand`, `Stormneedle`, `Nullblade`
- Sustain/stability: `Sunlit Vow`
- Risk-reward amplifier: `Graveglass`
- Crit mastery: `Duelist's Oath`

## Implementation Notes

- Keep sword identity in data (`GearDef` stats + proc profile hooks), not hardcoded behavior branches.
- Reuse existing status profiles where possible (`bleed`, `burn`, `acid/vulnerable`, `slow`, `stun`, `silence`, `haste`, `weaken`).
- If optional effects are enabled (`Graveglass vulnerable`, `Sunlit Vow heal`), treat them as explicit balance variants and test both configurations.
