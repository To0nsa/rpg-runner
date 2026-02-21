# Eloise Spell Slot: Self Spells

## Scope

This document defines Eloise spell slot self spells (`AbilitySlot.spell`) as
currently implemented.

All abilities in this file are:

- `inputLifecycle: tap`
- `targetingModel: none`
- `hitDelivery: SelfHitDelivery`
- `payloadSource: AbilityPayloadSource.spellBook`
- `requiredWeaponTypes: {projectileSpell}`

Core units:

- Resource/cost: fixed-point (`100 = 1.0`)
- Percent restores/buffs: basis points (`100 = 1%`)
- Ticks authored at 60 Hz

## Ability Matrix (Current Core)

| Ability ID | Timing (W/A/R) | Cost | Cooldown | Primary Effect |
|---|---|---:|---:|---|
| `eloise.arcane_haste` | `0 / 0 / 10` | mana `1000` | `300` | apply `StatusProfileId.speedBoost` |
| `eloise.restore_health` | `0 / 0 / 10` | mana `1500` | `420` | restore `35%` max HP over `5.0s` |
| `eloise.restore_mana` | `0 / 0 / 10` | stamina `1500` | `420` | restore `35%` max mana over `5.0s` |
| `eloise.restore_stamina` | `0 / 0 / 10` | mana `1500` | `420` | restore `35%` max stamina over `5.0s` |

## Effect Notes

### `eloise.arcane_haste`

- Applies self status profile `speedBoost`
- Profile currently grants haste (`+50% move speed`, 5.0s)
- See `docs/gdd/combat/status/status_system_design.md` for status details

### Restore spells

- `restore_health`: `selfRestoreHealthBp = 3500`
- `restore_mana`: `selfRestoreManaBp = 3500`
- `restore_stamina`: `selfRestoreStaminaBp = 3500`

Restore values are percentages of max resource and clamp to each resource max.
Restore is distributed smoothly over the authored duration (no immediate burst).

## Contract Notes

1. Spell slot is intentionally self-spell only in current vertical slice.
2. These abilities are deterministic utility actions (no hit payload damage).
3. Cooldown lane uses spell group by default (unless explicitly overridden).
4. Spell-slot self-spell equip eligibility is spellbook-gated.
5. On loadout normalization (including spellbook swap), stale invalid spell-slot selection is auto-repaired to the first valid granted spell-slot spell.
6. On loadout normalization (including spellbook swap), stale invalid `projectileSlotSpellId` selection is auto-repaired to the first valid spell granted by the equipped spellbook.

## Spellbook Grants (Current Core)

| Spellbook | Granted spell-slot self-spells |
|---|---|
| `basicSpellBook` | `eloise.arcane_haste` |
| `solidSpellBook` | `eloise.arcane_haste`, `eloise.restore_health` |
| `epicSpellBook` | `eloise.arcane_haste`, `eloise.restore_health`, `eloise.restore_mana`, `eloise.restore_stamina` |
