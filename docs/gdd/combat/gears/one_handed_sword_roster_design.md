# One-Handed Sword Roster Design (V1)

## Purpose

Define an 8-sword, one-handed roster for the vertical slice with clear build identities and explicit tradeoffs so no single sword becomes universal best-in-slot.

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
| 1 | `Plainsteel` | baseline consistency | `globalPower +1500`, `globalCrit +1000`, `stamina +1000` | `defense -500` | none | no proc upside; accepts a small defense dump for stable offense |
| 2 | `Waspfang` | bleed pressure | `globalPower +500` | `health -500` | `onHit -> bleed` at `20%` | lower raw stat density than no-proc swords |
| 3 | `Cinderedge` | crit-gated burn pressure | `globalCrit +1000` | `manaRegen -500` | `onCrit -> burn` at `100%` | proc value is crit-gated and carries regen tax |
| 4 | `Basilisk Kiss` | anti-tank corrosion pressure | `staminaRegen +1000` | `health -500` | `onHit -> acid` at `20%` | lower max health for sustained vulnerability pressure |
| 5 | `Frostbrand` | control skirmish profile | `globalPower +1000` | `defense -500` | `onHit -> slow` at `20%` | lighter stat package than non-proc offense swords |
| 6 | `Stormneedle` | crit/stamina sustain profile | `globalCrit +1000`, `stamina +1500`, `staminaRegen +500` | `health -500` | none | no proc utility despite strong sustained stat loop |
| 7 | `Nullblade` | anti-caster disruptor | `globalCrit +1000` | `stamina -500` | `onHit -> silence` at `20%` | control utility comes at stamina comfort cost |
| 8 | `Sunlit Vow` | kill-chain offense spike | `globalPower +1000`, `staminaRegen +1000` | `health -500` | `onKill -> focus` at `35%` | kill-gated offensive spike with lower baseline durability |

## Identity Coverage Check

The roster intentionally covers the major build identities:

- Baseline consistency: `Plainsteel`
- Proc pressure/control: `Waspfang`, `Cinderedge`, `Basilisk Kiss`, `Frostbrand`, `Nullblade`, `Sunlit Vow`
- No-proc stat anchor: `Stormneedle`
- Kill-chain offense spike: `Sunlit Vow`

## Implementation Notes

- Keep sword identity in data (`GearDef` stats + proc hooks), not hardcoded behavior branches.
- Proc hooks are intentionally sparse in V1 to satisfy hard authoring constraints.
- Reuse existing status profiles (`bleed`, `burn`, `acid`, `slow`, `silence`, `focus`) for deterministic behavior.
