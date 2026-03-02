# Spellbook Roster Design (V1)

## Purpose

Define an 8-spellbook roster for the vertical slice with distinct caster identities, clear tradeoffs, and deterministic tuning hooks so no single book becomes universal best-in-slot.

## Design Targets

- Every spellbook should change how a spell loadout is piloted.
- Every spellbook should have a clear weakness (tempo, survivability, consistency, or burst).
- Spell throughput and control gains must pay a visible cost.
- Spellbook choice should meaningfully affect route safety and boss pacing.

## Balancing Framework

Normalize a baseline spellbook to a spell throughput budget of `+1.0` ST.

`Apprentice Primer` is the control group and sets baseline spellbook expectations.

When a spellbook gains extra ST through procs, cooldown efficiency, or crit scaling, it must pay through one or more taxes:

- lower `globalPowerBonusBp`
- lower `globalCritChanceBonusBp`
- reduced defenses (`defense`, `health`)
- explicit consistency downside (kill-gated or crit-gated value)

Control-heavy effects (`drench`, `slow`, `silence`, `weaken`) should pay with lower direct throughput.

## Validation Loop

Run each spellbook through deterministic validation passes:

- `90s spell DPS dummy`: pure throughput profile
- `mixed lane x3 seeds`: clear stability under real movement pressure
- `elite duel x3`: single-target uptime and clutch survivability
- tuning step: adjust one dominant knob by `10-15%` per pass

Primary knobs:

- `globalPowerBonusBp`
- `globalCritChanceBonusBp`
- `cooldownReductionBp`
- resource bonuses (`mana`, `stamina`, `health`)
- proc chance and proc hook gating

## Spellbook Roster

### 1) Apprentice Primer

- Role: baseline all-rounder
- Stats: `globalPower +200bp`, `mana +1000bp`
- Proc: none
- Tradeoff: low specialization ceiling

### 2) Bastion Codex

- Role: safe sustain casting
- Stats: `defense +1200bp`, `health +1000bp`, `cooldownReduction -400bp`
- Proc: `onKill -> arcaneWard` at `100%`
- Tradeoff: slower rotation, kill-gated defensive spike

### 3) Ember Grimoire

- Role: aggressive DoT pressure
- Stats: `globalPower +700bp`, `cooldownReduction +300bp`, `defense -500bp`
- Proc: `onHit -> burn` at `35%`
- Tradeoff: high clear tempo, weak survivability

### 4) Tide Almanac

- Role: control and anti-caster pacing
- Stats: `mana +2500bp`, `cooldownReduction +500bp`, `globalPower -300bp`
- Proc: `onHit -> drench` at `25%`
- Tradeoff: lower direct damage for stronger control windows

### 5) Hexbound Lexicon

- Role: anti-elite debuff utility
- Stats: `globalCrit +1000bp`, `globalPower -200bp`
- Proc: `onCrit -> weaken` at `100%`
- Tradeoff: value depends on crit consistency; lower base throughput

### 6) Gale Folio

- Role: kite support and tempo safety
- Stats: `moveSpeed +600bp`, `stamina +1200bp`, `globalPower -200bp`
- Proc: `onHit -> slow` at `30%`
- Tradeoff: safer spacing but lower burst ceiling

### 7) Null Testament

- Role: anti-caster disruption
- Stats: `darkRes +2000bp`, `holyRes +2000bp`, `globalPower +300bp`
- Proc: `onCrit -> silence` at `60%`
- Tradeoff: matchup-skewed value, weaker in physical-heavy encounters

### 8) Crown of Focus

- Role: high-risk snowball carry
- Stats: `globalPower +1500bp`, `globalCritChance +1000bp`, `defense -1500bp`, `health -1000bp`
- Proc: `onKill -> focus` at `100%`
- Tradeoff: strongest offense when chaining kills, highest death risk

## Identity Coverage Check

The roster intentionally covers key spellbook identities:

- Baseline consistency: `Apprentice Primer`
- Defensive stability: `Bastion Codex`
- DoT pressure: `Ember Grimoire`
- Control pacing: `Tide Almanac`, `Gale Folio`
- Debuff utility: `Hexbound Lexicon`, `Null Testament`
- Snowball carry: `Crown of Focus`

## Implementation Notes

- Keep spellbook identity data-driven (stats + proc profiles), not hardcoded branches.
- Reuse existing status profiles where possible (`burn`, `drench`, `slow`, `silence`, `weaken`, `arcaneWard`, `focus`).
- Use existing proc hooks (`onHit`, `onCrit`, `onKill`) to avoid new trigger surface area.
- `onKill` remains payload-based and should only trigger when a spell payload authored by the equipped spellbook source scores the kill.
- Runtime IDs/catalog now use this 8-book roster (`apprenticePrimer` through `crownOfFocus`).
