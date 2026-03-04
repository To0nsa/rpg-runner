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

When a sword gains extra EV through proc utility, it must pay using one or more taxes:

- lower `globalPowerBonusBp`
- lower `globalCritChanceBonusBp`
- a dump stat in an allowed sword dump family

## Validation Loop

Run each sword through a fast, deterministic test loop:

- `60s dummy test`: no movement, pure EV damage check
- `dangerous seed x3`: average survivability and clear consistency
- tuning step: nerf outliers by `10-15%` on one primary knob, buff underperformers similarly

Primary knobs:

- `globalPowerBonusBp`
- `globalCritChanceBonusBp`
- `staminaBonusBp`
- `staminaRegenBonusBp`
- downside magnitude (`health`, `defense`, `manaRegen` dumps)

## Sword Roster

| # | Sword | Role | Positive Stats (bp) | Dump (bp) | Proc | Tradeoff |
|---|---|---|---|---|---|---|
| 1 | `Plainsteel` | baseline consistency | `globalPower +1500`, `globalCrit +500`, `stamina +1000` | `defense -500` | none | no proc upside; accepts a small defense dump for stable offense |
| 2 | `Waspfang` | bleed pressure | `globalPower +1000`, `stamina +1500` | `health -500` | `onHit -> bleed` at `35%` | lower raw stat density than no-proc swords |
| 3 | `Cinderedge` | crit-gated control spike | `globalPower +500`, `globalCrit +1000` | `manaRegen -500` | `onCrit -> stun` at `20%` | control value is crit-dependent and carries regen tax |
| 4 | `Basilisk Kiss` | sustained duel profile | `globalPower +1500`, `globalCrit +500`, `staminaRegen +1000` | `health -1000` | none | large health dump for high sustained stats |
| 5 | `Frostbrand` | stamina-heavy tempo baseline | `globalPower +1000`, `stamina +2000`, `staminaRegen +500` | `defense -500` | none | no reactive/control proc utility |
| 6 | `Stormneedle` | crit-forward mobility loop support | `globalCrit +1000`, `stamina +1500`, `staminaRegen +500` | `health -500` | none | lower direct power scaling than power-heavy swords |
| 7 | `Nullblade` | high-crit skirmish blade | `globalPower +500`, `globalCrit +1000`, `stamina +1000` | `defense -1000` | none | steep defense dump to hold offense stats |
| 8 | `Sunlit Vow` | kill-chain momentum | `globalPower +1000`, `staminaRegen +1000` | `health -500` | `onKill -> haste` at `100%` | kill-gated value with lower baseline stat breadth |
| 9 | `Graveglass` | high-risk amplifier | `globalPower +1500`, `globalCrit +1000`, `stamina +500` | `defense -1000` | none | strong offense profile with heavy defense tax |
| 10 | `Duelist's Oath` | crit/stamina endurance profile | `globalCrit +1000`, `stamina +2000`, `staminaRegen +500` | `manaRegen -500` | none | no proc ceiling; carries regen dump |

## Identity Coverage Check

The roster intentionally covers the major build identities:

- Baseline consistency: `Plainsteel`
- Proc pressure/control: `Waspfang`, `Cinderedge`, `Sunlit Vow`
- No-proc stat anchors: `Basilisk Kiss`, `Frostbrand`, `Stormneedle`
- Risk-reward offense: `Nullblade`, `Graveglass`
- Crit/stamina endurance: `Duelist's Oath`

## Implementation Notes

- Keep sword identity in data (`GearDef` stats + proc hooks), not hardcoded behavior branches.
- Proc hooks are intentionally sparse in V1 to satisfy hard authoring constraints.
- Reuse existing status profiles (`bleed`, `stun`, `haste`) for deterministic behavior.
