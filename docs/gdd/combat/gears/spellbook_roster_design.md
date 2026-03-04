# Spellbook Roster Design (V1)

## Purpose

Define an 8-spellbook roster for the vertical slice with distinct caster identities, clear tradeoffs, and deterministic tuning hooks so no single book becomes universal best-in-slot.

## Design Targets

- Every spellbook should change how a spell loadout is piloted.
- Every spellbook should have a clear weakness (tempo, survivability, or consistency).
- Spell throughput and control gains must pay a visible dump cost.
- Spellbook choice should meaningfully affect route safety and boss pacing.

## Balancing Framework

Normalize a baseline spellbook to a spell throughput budget of `+1.0` ST.

`Apprentice Primer` is the control group and sets baseline spellbook expectations.

Spellbooks in V1 are stat-only (no spellbook-owned procs). Differentiation comes from:

- mana economy (`manaBonusBp`, `manaRegenBonusBp`)
- rotation cadence (`cooldownReductionBp`)
- crit posture (`globalCritChanceBonusBp`)
- explicit dump (`staminaBonusBp`, `staminaRegenBonusBp`, or `healthRegenBonusBp`)

## Validation Loop

Run each spellbook through deterministic validation passes:

- `90s spell DPS dummy`: pure throughput profile
- `mixed lane x3 seeds`: clear stability under real movement pressure
- `elite duel x3`: single-target uptime and clutch survivability
- tuning step: adjust one dominant knob by `10-15%` per pass

Primary knobs:

- `manaBonusBp`
- `manaRegenBonusBp`
- `cooldownReductionBp`
- `globalCritChanceBonusBp`
- dump magnitude (`stamina`, `staminaRegen`, `healthRegen`)

## Spellbook Roster

| # | Spellbook | Positive Stats (bp) | Dump (bp) | Proc |
|---|---|---|---|---|---|---|
| 1 | `Apprentice Primer` | `mana +1500`, `manaRegen +1000` | `stamina -500` | none |
| 2 | `Bastion Codex` | `mana +1500`, `cooldownReduction +1000` | `staminaRegen -500` | none |
| 3 | `Ember Grimoire` | `mana +1500`, `globalCrit +1000` | `healthRegen -500` | none |
| 4 | `Tide Almanac` | `cooldownReduction +1500`, `globalCrit +1000` | `staminaRegen -500` | none |
| 5 | `Hexbound Lexicon` | `manaRegen +1500`, `cooldownReduction +1000` | `healthRegen -500` | none |
| 6 | `Gale Folio` | `globalCrit +1500`, `manaRegen +1000` | `stamina -500` | none |
| 7 | `Null Testament` | `cooldownReduction +1500`, `mana +1000` | `staminaRegen -500` | none |
| 8 | `Crown of Focus` | `mana +1000`, `globalCrit +500`, `cooldownReduction +500` | `stamina -500`, `staminaRegen -500` | none |

## Identity Coverage Check

The roster intentionally covers key spellbook identities:

- Baseline consistency: `Apprentice Primer`
- Mana wall / economy anchors: `Bastion Codex`, `Tide Almanac`, `Gale Folio`
- Crit-forward picks: `Ember Grimoire`, `Hexbound Lexicon`, `Crown of Focus`
- Regen-oriented consistency: `Null Testament`

## Implementation Notes

- Keep spellbook identity data-driven (`GearStatBonuses` only), not hardcoded branches.
- Spellbook-owned proc entries remain disabled in V1 to preserve slot identity constraints.
- Runtime IDs/catalog continue to use this 8-book roster (`apprenticePrimer` through `crownOfFocus`).
