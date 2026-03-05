# Accessory Roster Design

## Purpose

Define an 8-accessory roster for the vertical slice that keeps accessories as
passive, deterministic stat modifiers with optional low-health sustain proc
variants.

This roster is fully implemented in Core/UI and maps directly to the accessory
IDs listed in `assets/images/icons/mapToIcon.md`.

## Design Targets

- Every accessory should solve one clear problem (tempo, survivability,
  resource sustain, or offense pacing).
- Every accessory should have a unique stat/proc signature (no duplicate
  identity templates).
- Accessory value should primarily come from passive stats, and any proc usage
  should stay on deterministic low-health sustain hooks.
- No accessory should be universal best-in-slot across all levels and enemy mixes.
- The roster should be icon-complete so catalog expansion can happen without UI remapping work.

## Balancing Framework

Normalize a baseline accessory to an accessory-value budget of `+1.0 AV`.

`Speed Boots` is the control group for tempo-oriented picks.

When an accessory gains more than baseline AV (for example offense plus strong
survivability), it should pay through one or more taxes:

- lower primary stat magnitude
- narrow matchup profile (typed resistance)
- explicit dump (one negative stat line)

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
| 1 | `Speed Boots` | `speedBoots` | implemented | pure tempo and route control | `moveSpeed +1000`, `staminaRegen +1000`, `cooldownReduction +500` | `mana -1000` | none | mobility/cadence gains come with weaker mana economy |
| 2 | `Golden Ring` | `goldenRing` | implemented | survivability floor and clutch sustain | `health +1500` | `cooldownReduction -500` | `onLowHealth -> restoreHealth` at `100%` (`30s` internal cooldown) | strongest health safety pick but slows ability rotation |
| 3 | `Teeth Necklace` | `teethNecklace` | implemented | stamina clutch sustain | `stamina +1500` | `health -500` | `onLowHealth -> restoreStamina` at `100%` (`30s` internal cooldown) | stamina rescue option that lowers max health |
| 4 | `Diamond Ring` | `diamondRing` | implemented | mana clutch sustain | `mana +1500` | `stamina -500` | `onLowHealth -> restoreMana` at `100%` (`30s` internal cooldown) | mana rescue option that lowers max stamina |
| 5 | `Iron Boots` | `ironBoots` | implemented | physical soak anchor | `defense +1500`, `physicalRes +1500`, `health +500` | `globalPower -500` | none | front-line mitigation with reduced offense |
| 6 | `Oath Beads` | `oathBeads` | implemented | spell cadence + offense bridge | `cooldownReduction +500`, `manaRegen +1000`, `globalPower +1000` | `defense -500` | none | higher spell pressure with lower durability |
| 7 | `Resilience Cape` | `resilienceCape` | implemented | elemental/dark counterpick | `fireRes +2500`, `darkRes +2000`, `defense +1000` | `mana -500` | none | defensive counterpick with reduced mana headroom |
| 8 | `Strength Belt` | `strengthBelt` | implemented | burst damage finisher | `globalPower +1500`, `globalCrit +1000`, `stamina +1000` | `cooldownReduction -500` | none | highest burst package, but weaker rotation cadence |

## Identity Coverage Check

The roster intentionally covers core accessory identities:

- Tempo: `Speed Boots`
- Health clutch sustain: `Golden Ring`
- Stamina clutch sustain: `Teeth Necklace`
- Mana clutch sustain: `Diamond Ring`
- Physical mitigation anchor: `Iron Boots`
- Rotation/power bridge: `Oath Beads`
- Matchup counterpick: `Resilience Cape`
- Burst finisher: `Strength Belt`

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
