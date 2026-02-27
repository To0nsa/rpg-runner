# Eloise Spell Slot: Self Utility Spells

Spell-slot Eloise abilities (`AbilitySlot.spell`) as currently implemented.

All abilities in this file are:

- `inputLifecycle: tap`
- `targetingModel: none`
- `hitDelivery: SelfHitDelivery`
- `payloadSource: AbilityPayloadSource.spellBook`
- `requiredWeaponTypes: {spell}`

## Ability Matrix

| Ability ID | W/A/R | Cost | Cooldown | Primary Effect |
|---|---|---|---:|---|
| `eloise.arcane_haste` | `0/0/10` | mana `1000` | `300` | apply `StatusProfileId.speedBoost` |
| `eloise.focus` | `0/0/10` | mana `1200` | `420` | apply `StatusProfileId.focus` |
| `eloise.arcane_ward` | `0/0/10` | mana `1200` | `420` | apply `StatusProfileId.arcaneWard` |
| `eloise.cleanse` | `0/0/10` | mana `1400` | `480` | apply `PurgeProfileId.cleanse` |
| `eloise.vital_surge` | `0/0/10` | mana `1500` | `420` | apply `StatusProfileId.restoreHealth` |
| `eloise.mana_infusion` | `0/0/10` | stamina `1500` | `420` | apply `StatusProfileId.restoreMana` |
| `eloise.second_wind` | `0/0/10` | mana `1500` | `420` | apply `StatusProfileId.restoreStamina` |

## Effect Notes

- `speedBoost`: haste `+50%` move speed for `5.0s`
- `focus`: `+25%` outgoing power and `+15%` crit chance for `5.0s`
- `arcaneWard`: reduce direct-hit damage by `40%` and cancel all DoT ticks for `4.0s`
- `cleanse`: remove active debuffs (`stun`, `silence`, `slow`, `vulnerable`, `weaken`, `drench`, and DoT channels)
- `restoreHealth`: restore `35%` max HP over `5.0s`
- `restoreMana`: restore `35%` max mana over `5.0s`
- `restoreStamina`: restore `35%` max stamina over `5.0s`

Restore effects are continuous over duration (not instant burst).

`cleanse` is authored with `canCommitWhileStunned: true` so it can be used to break stun.

## Spell List Ownership

Spell-slot abilities are owned per character via Spell List and validated by
loadout normalization.

- Eloise starter Spell List is defined in character catalog fields and currently
  includes all authored Eloise spell-slot abilities in this document.

## Projectile Spell Selection (Related)

Projectile-slot spell options also come from Spell List ownership:

- Eloise starter Spell List is defined in character catalog fields and currently
  includes all authored spell projectile IDs.
- Any learned spell projectile can be selected regardless of equipped spellbook.
