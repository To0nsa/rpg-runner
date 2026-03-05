# Accessory Roster Design

## Purpose

Define an 8-accessory roster for the vertical slice that keeps accessories as
passive, deterministic stat modifiers with one optional low-health sustain proc
anchor.

This roster is fully implemented in Core/UI and maps directly to the accessory
IDs listed in `assets/images/icons/mapToIcon.md`.

## Design Targets

- Every accessory should solve one clear problem (tempo, survivability,
  resource sustain, or offense pacing).
- Accessory value should primarily come from passive stats, with at most one
  low-health sustain proc in the slot roster.
- No accessory should be universal best-in-slot across all levels and enemy mixes.
- The roster should be icon-complete so catalog expansion can happen without UI remapping work.

## Balancing Framework

Normalize a baseline accessory to an accessory-value budget of `+1.0 AV`.

`Speed Boots` is the control group for tempo-oriented picks.

When an accessory gains more than baseline AV (for example offense plus strong
survivability), it should pay through one or more taxes:

- lower primary stat magnitude
- narrow matchup profile (typed resistance)
- explicit dump (`manaBonusBp`, `cooldownReductionBp`, or typed resistance)

Accessory tuning should bias toward small basis-point deltas and fast
iterations.

## Validation Loop

Run each accessory through deterministic passes:

- `90s mixed clear x3 seeds`: pacing and route safety
- `elite duel x3`: single-target pressure and survival stability
- `movement segment`: mobility-sensitive hazard traversal
- tuning step: adjust one primary stat knob by `10-15%` per pass

Primary knobs:

- `moveSpeedBonusBp`
- resource lines (`health`, `mana`, `stamina`, regen)
- `defenseBonusBp`
- `globalPowerBonusBp` / `globalCritChanceBonusBp`
- typed resistance basis points

## Accessory Roster

| # | Accessory | Runtime ID | Status | Role | Positive Stats (bp) | Dump (bp) | Proc | Tradeoff |
|---|---|---|---|---|---|---|---|---|
| 1 | `Speed Boots` | `speedBoots` | implemented | movement tempo baseline | `moveSpeed +1000`, `stamina +1500`, `staminaRegen +500` | `mana -500` | none | no direct proc utility |
| 2 | `Golden Ring` | `goldenRing` | implemented | survivability floor and clutch sustain | `health +2000`, `defense +1000` | `cooldownReduction -500` | `onLowHealth -> restoreHealth` at `100%` (`30s` internal cooldown) | gives up cooldown pace for survivability spike |
| 3 | `Teeth Necklace` | `teethNecklace` | implemented | stamina-heavy durability | `stamina +2000`, `healthRegen +1000`, `defense +500` | `mana -500` | none | no direct offense or proc pressure |
| 4 | `Diamond Ring` | `diamondRing` | implemented | caster economy with crit support | `mana +2000`, `manaRegen +1000`, `globalCrit +1000` | `fireRes -500` | none | fire matchup hole from typed-resistance dump |
| 5 | `Iron Boots` | `ironBoots` | implemented | front-line offense/defense blend | `defense +1500`, `moveSpeed +500`, `globalPower +1000` | `cooldownReduction -500` | none | slower rotation cadence due to cooldown dump |
| 6 | `Oath Beads` | `oathBeads` | implemented | rotation consistency with power bump | `cooldownReduction +500`, `globalPower +1500`, `manaRegen +500` | `waterRes -500` | none | water matchup hole from typed-resistance dump |
| 7 | `Resilience Cape` | `resilienceCape` | implemented | status-heavy encounter counterpick | `bleedRes +2500`, `darkRes +2000`, `health +1000` | `mana -500` | none | value narrows outside bleed/dark pressure |
| 8 | `Strength Belt` | `strengthBelt` | implemented | offense-forward speed clear option | `globalPower +1500`, `globalCrit +1000`, `stamina +1000` | `iceRes -500` | none | ice matchup hole from typed-resistance dump |

## Identity Coverage Check

The roster intentionally covers core accessory identities:

- Tempo: `Speed Boots`
- Durable clutch anchor: `Golden Ring`
- Resource sustain: `Teeth Necklace`, `Diamond Ring`
- Mitigation/offense blends: `Iron Boots`, `Strength Belt`
- Cooldown pacing: `Oath Beads`
- Matchup counterpick: `Resilience Cape`

## Icon Mapping (From `mapToIcon.md`)

All accessories map to the shared UI sprite sheet:
`assets/images/icons/gear-icons/sword/transparentIcons.png`.

| Runtime ID | Display Name | Coordinates (Row, Col) | Source |
| :--- | :--- | :---: | :--- |
| `speedBoots` | Speed Boots | (8, 2) | `assets/images/icons/gear-icons/sword/transparentIcons.png` |
| `goldenRing` | Golden Ring | (8, 4) | `assets/images/icons/gear-icons/sword/transparentIcons.png` |
| `teethNecklace` | Teeth Necklace | (8, 8) | `assets/images/icons/gear-icons/sword/transparentIcons.png` |
| `diamondRing` | Diamond Ring | (8, 5) | `assets/images/icons/gear-icons/sword/transparentIcons.png` |
| `ironBoots` | Iron Boots | (8, 3) | `assets/images/icons/gear-icons/sword/transparentIcons.png` |
| `oathBeads` | Oath Beads | (8, 7) | `assets/images/icons/gear-icons/sword/transparentIcons.png` |
| `resilienceCape` | Resilience Cape | (7, 14) | `assets/images/icons/gear-icons/sword/transparentIcons.png` |
| `strengthBelt` | Strength Belt | (7, 15) | `assets/images/icons/gear-icons/sword/transparentIcons.png` |

## Implementation Notes

- Keep accessory identity data-driven in `AccessoryCatalog` via
  `GearStatBonuses`; avoid branching behavior.
- Runtime/catalog coverage includes all 8 accessories.
- Startup/meta normalization keeps all accessories unlocked by default.
