# Accessory Roster Design (V1)

## Purpose

Define an 8-accessory roster for the vertical slice that keeps accessories as
passive, deterministic stat modifiers while still creating meaningful build
identity and equip tradeoffs.

This roster is fully implemented in Core/UI and maps directly to the accessory
IDs listed in `assets/images/icons/mapToIcon.md`.

## Design Targets

- Every accessory should solve one clear problem (tempo, survivability,
  resource sustain, or offense pacing).
- Accessory value should come from passive stats only (no accessory-owned procs in V1).
- No accessory should be universal best-in-slot across all levels and enemy mixes.
- The roster should be icon-complete so catalog expansion can happen without UI remapping work.

## Balancing Framework

Normalize a baseline accessory to an accessory-value budget of `+1.0 AV`.

`Speed Boots` is the control group for tempo-oriented picks.

When an accessory gains more than baseline AV (for example offense plus strong
survivability), it should pay through one or more taxes:

- lower primary stat magnitude
- narrow matchup profile (typed resistance, resource-specific bonus)
- small secondary downside (if needed) such as mobility or resource tax

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
- `healthBonusBp` / `manaBonusBp` / `staminaBonusBp`
- `defenseBonusBp`
- `globalPowerBonusBp`
- typed resistance basis points

## Accessory Roster

### 1) Speed Boots

- Runtime ID: `speedBoots`
- Status: implemented
- Role: movement tempo baseline
- Stats: `moveSpeed +1000bp`, `stamina +1000bp`, `health -500bp`
- Tradeoff: no direct offense or durability scaling

### 2) Golden Ring

- Runtime ID: `goldenRing`
- Status: implemented
- Role: general survivability floor
- Stats: `health +1000bp`, `defense +1000bp`, `stamina -500bp`
- Tradeoff: lower mobility pressure than tempo accessories

### 3) Teeth Necklace

- Runtime ID: `teethNecklace`
- Status: implemented
- Role: stamina sustain for mobility/melee uptime
- Stats: `stamina +2000bp`, `health -500bp`
- Tradeoff: no direct damage or mitigation gain

### 4) Diamond Ring

- Runtime ID: `diamondRing`
- Status: implemented
- Role: caster sustain baseline
- Stats: `mana +2000bp`, `stamina -500bp`
- Tradeoff: no movement or defensive gain

### 5) Iron Boots

- Runtime ID: `ironBoots`
- Status: implemented
- Role: physical pressure stabilizer
- Stats: `defense +1000bp`, `globalPowerBonusBp +1000bp`, `moveSpeed -300bp`
- Tradeoff: lower route speed than mobility-focused picks

### 6) Oath Beads

- Runtime ID: `oathBeads`
- Status: implemented
- Role: rotation consistency
- Stats: `cooldownReduction +1000bp`, `globalPowerBonusBp +500bp`, `health -500bp`
- Tradeoff: no raw damage amplification

### 7) Resilience Cape

- Runtime ID: `resilienceCape`
- Status: implemented
- Role: status-heavy encounter counterpick
- Stats: `bleedRes +1200bp`, `darkRes +800bp`, `health -500bp`
- Tradeoff: narrow value outside status/dark-heavy fights

### 8) Strength Belt

- Runtime ID: `strengthBelt`
- Status: implemented
- Role: offense-forward speed clear option
- Stats: `globalPower +500bp`, `critChance +500bp`, `stamina -100bp`
- Tradeoff: stronger damage pacing at a small stamina comfort tax

## Identity Coverage Check

The roster intentionally covers core accessory identities:

- Tempo: `Speed Boots`
- Durable baseline: `Golden Ring`
- Resource sustain: `Teeth Necklace`, `Diamond Ring`
- Mitigation anchor: `Iron Boots`
- Cooldown pacing: `Oath Beads`
- Matchup counterpick: `Resilience Cape`
- Risk-reward offense: `Strength Belt`

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
- Runtime/catalog coverage now includes all 8 accessories.
- Startup/meta normalization now keep all accessories unlocked by default.
