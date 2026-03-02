# Shield Roster Design (V1)

## Purpose

Define a 10-shield offhand roster for the vertical slice with distinct defensive identities, clear utility niches, and explicit tradeoffs so no shield becomes universal best-in-slot.

## Design Targets

- Every shield should solve a specific survivability problem.
- Every shield should have a clear failure case or matchup weakness.
- Mitigation, control, and sustain gains must always pay a budget tax.
- Shield choice should materially change route planning, pacing, and risk tolerance.

## Balancing Framework

Normalize a basic shield to a survivability budget of `+1.0` SV.

`Roadguard` is the control group and sets baseline offhand expectations.

When a shield gains extra SV through resist stacking, reactive control, or clutch sustain, it must pay using one or more taxes:

- lower `globalPowerBp`
- lower `globalCritChanceBonusBp`
- move speed penalty
- cooldown efficiency penalty
- explicit matchup hole (narrow resistance profile)

Control-heavy shield effects (stun, silence, strong slow) must pay through lower raw mitigation and/or low chance plus short duration.

## Validation Loop

Run each shield through a deterministic validation loop:

- `90s mixed gauntlet`: physical + elemental incoming damage profile
- `dangerous seed x3`: survivability consistency under real pacing
- `elite duel x3`: single-target pressure and clutch check
- tuning step: nerf outliers by `10-15%` on one primary knob, buff weak picks similarly

Primary knobs:

- `defense` and max-resource bonuses
- typed resistance magnitude
- proc chance and duration
- downside magnitude (`moveSpeed`, offense penalties, cooldown penalties)

## Shield Roster

### 1) Roadguard

- Role: baseline all-rounder
- Stats: `defense +1500bp`, `health +1000bp`
- Proc: none
- Tradeoff: no specialization ceiling in control, burst denial, or tempo

### 2) Thornbark

- Role: melee attrition punish
- Stats: `defense +1200bp`
- Proc: `onDamaged -> bleed` at `35%`
- Tradeoff: limited value versus ranged/caster pressure and burst windows

### 3) Cinder Ward

- Role: fire encounter counterpick
- Stats: `fireRes +3000bp`, `defense +600bp`
- Proc: `onDamaged -> burn` at `25%`
- Tradeoff: noticeably weaker outside fire-heavy matchups

### 4) Tideguard Shell

- Role: caster pressure stabilizer
- Stats: `mana +2000bp`, `waterRes +2000bp`, `defense +500bp`
- Proc: `onDamaged -> silence` at `15%`
- Tradeoff: low raw armor; utility is matchup-dependent

### 5) Frostlock Buckler

- Role: kite and peel support
- Stats: `iceRes +2000bp`, `moveSpeed +600bp`, `defense +800bp`
- Proc: `onDamaged -> slow` at `35%`
- Tradeoff: lower effective HP than heavy tank picks

### 6) Iron Bastion

- Role: pure face-tank choice
- Stats: `defense +3200bp`, `health +1500bp`, `moveSpeed -900bp`
- Proc: none
- Tradeoff: strongest soak, worst reposition/chase profile

### 7) Storm Aegis

- Role: anti-burst recovery windows
- Stats: `thunderRes +2500bp`, `cooldownReduction +700bp`, `defense +700bp`
- Proc: `onDamaged -> haste (short)` at `20%`
- Tradeoff: relies on active ability timing; weaker passive mitigation

### 8) Null Prism

- Role: anti-caster disruption
- Stats: `darkRes +2500bp`, `holyRes +1500bp`, `defense +600bp`
- Proc: `onDamaged -> silence` at `20%`
- Tradeoff: underperforms into physical swarm pressure

### 9) Warbanner Guard

- Role: aggressive tempo shield
- Stats: `defense +1000bp`, `globalPower +700bp`
- Proc: `onKill -> haste (short)` at `100%`
- Tradeoff: kill-gated value collapses in boss-only phases

### 10) Oathwall Relic

- Role: high-risk clutch survivability
- Stats: `defense +2200bp`, `globalPower -500bp`, `globalCritChance -1000bp`
- Proc: `onLowHealth -> haste (short)` at `100%` (`30s` internal cooldown)
- Tradeoff: highest panic safety at a permanent clear-speed tax

## Identity Coverage Check

The roster intentionally covers major shield identities:

- Baseline consistency: `Roadguard`
- Attrition punishment: `Thornbark`
- Elemental counterpicks: `Cinder Ward`, `Tideguard Shell`, `Storm Aegis`, `Null Prism`
- Mobility/peel control: `Frostlock Buckler`
- Pure tanking: `Iron Bastion`
- Tempo aggression: `Warbanner Guard`
- Clutch survival: `Oathwall Relic`

## Implementation Notes

- Keep shield identity in data (`GearDef` stat profile + proc profile hooks), not hardcoded branching.
- Reuse existing status profiles where possible (`bleed`, `burn`, `slow`, `silence`, `haste`).
- Reactive hooks (`onDamaged`, `onLowHealth`) are now part of the Core proc pipeline with deterministic cooldown/chance evaluation.
- `onKill` remains payload-based (only rolls when the kill comes from the equipped payload source).
