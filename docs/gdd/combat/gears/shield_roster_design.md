# Shield Roster Design (V1)

## Purpose

Define a 10-shield offhand roster for the vertical slice with distinct defensive identities, clear utility niches, and explicit tradeoffs so no shield becomes universal best-in-slot.

## Design Targets

- Every shield should solve a specific survivability problem.
- Every shield should have a clear failure case or matchup weakness.
- Mitigation gains must always pay a dump tax.
- Shield choice should materially change route planning, pacing, and risk tolerance.

## Balancing Framework

Normalize a basic shield to a survivability budget of `+1.0` SV.

`Roadguard` is the control group and sets baseline offhand expectations.

When a shield gains extra SV through resist stacking or reactive utility, it must pay using one or more taxes:

- lower outgoing offense via dump (`globalPowerBonusBp` / `globalCritChanceBonusBp`)
- move speed penalty
- narrower resistance profile

## Validation Loop

Run each shield through a deterministic validation loop:

- `90s mixed gauntlet`: physical + elemental incoming damage profile
- `dangerous seed x3`: survivability consistency under real pacing
- `elite duel x3`: single-target pressure and clutch check
- tuning step: nerf outliers by `10-15%` on one primary knob, buff weak picks similarly

Primary knobs:

- `defense` and stamina lines
- typed resistance magnitude
- downside magnitude (`moveSpeed`, offense penalties)

## Shield Roster

| # | Shield | Role | Positive Stats (bp) | Dump (bp) | Proc | Tradeoff |
|---|---|---|---|---|---|---|
| 1 | `Roadguard` | baseline all-rounder | `defense +1500`, `stamina +1500`, `physicalRes +1000` | `moveSpeed -500` | none | steady baseline with no reactive spike |
| 2 | `Thornbark` | melee attrition punish | `defense +1000` | `globalPower -500` | `onDamaged -> bleed` at `35%` | lower outgoing pressure from permanent power dump |
| 3 | `Cinder Ward` | fire encounter counterpick | `fireRes +2500`, `defense +1000` | `globalCritChance -500` | none | no reactive utility and reduced crit scaling |
| 4 | `Tideguard Shell` | stamina-backed elemental stabilizer | `waterRes +2000`, `stamina +1500`, `defense +500` | `globalPower -500` | none | lower direct offense with moderate armor |
| 5 | `Frostlock Buckler` | balanced cold matchup pick | `iceRes +2000`, `defense +1000`, `stamina +1000` | `globalCritChance -500` | none | no clutch proc and crit tax |
| 6 | `Iron Bastion` | pure soak anchor | `defense +1500`, `physicalRes +1500`, `staminaRegen +1000` | `moveSpeed -1000` | none | strongest soak tax comes from heavy mobility loss |
| 7 | `Storm Aegis` | thunder-heavy counterpick | `thunderRes +2500`, `defense +500`, `staminaRegen +1000` | `globalCritChance -500` | none | moderate crit dump and no reactive clutch effect |
| 8 | `Null Prism` | dual dark/holy resist pick | `darkRes +2000`, `holyRes +1500`, `defense +500` | `moveSpeed -500` | none | mobility tax for dual-resist coverage |
| 9 | `Warbanner Guard` | stamina-forward frontline guard | `defense +1000`, `stamina +2000`, `bleedRes +500` | `globalCritChance -1000` | none | large crit dump, no reactive upside |
| 10 | `Oathwall Relic` | high-risk clutch survivability | `defense +1500` | `globalPower -1000` | `onLowHealth -> haste` at `100%` (`30s` internal cooldown) | strongest panic safety at a permanent power tax |

## Identity Coverage Check

The roster intentionally covers major shield identities:

- Baseline consistency: `Roadguard`
- Reactive punishment and clutch safety: `Thornbark`, `Oathwall Relic`
- Elemental/typed counterpicks: `Cinder Ward`, `Tideguard Shell`, `Storm Aegis`, `Null Prism`
- Pure tanking/mobility tradeoffs: `Frostlock Buckler`, `Iron Bastion`, `Warbanner Guard`

## Implementation Notes

- Keep shield identity in data (`GearDef` stat profile + optional reactive hook), not hardcoded branching.
- Reactive hooks are intentionally limited in V1 (`onDamaged` and `onLowHealth`) to satisfy hard authoring constraints.
