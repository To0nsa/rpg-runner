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
| `eloise.arcane_haste` | `0/0/10` | mana `1200` | `480` | apply `StatusProfileId.speedBoost` |
| `eloise.focus` | `0/0/10` | mana `1200` | `480` | apply `StatusProfileId.focus` |
| `eloise.arcane_ward` | `0/0/10` | mana `1400` | `540` | apply `StatusProfileId.arcaneWard` |
| `eloise.cleanse` | `0/0/10` | mana `1200` | `480` | apply `PurgeProfileId.cleanse` |
| `eloise.vital_surge` | `0/0/10` | mana `2000` | `720` | apply `StatusProfileId.restoreHealth` |
| `eloise.mana_infusion` | `0/0/10` | stamina `1500` | `420` | apply `StatusProfileId.restoreMana` |
| `eloise.second_wind` | `0/0/10` | mana `1800` | `600` | apply `StatusProfileId.restoreStamina` |

## Effect Notes

- Éloïse Haste: `+40%` move speed for `3.0s`
- `focus`: `+25%` outgoing power and `+15%` crit chance for `4.0s`
- `arcaneWard`: reduce direct-hit damage by `40%` and cancel all DoT ticks for `3.0s`
- `cleanse`: remove active debuffs (`stun`, `silence`, `slow`, `vulnerable`, `weaken`, `drench`, and DoT channels)
- `restoreHealth`: restore `25%` max HP over `5.0s`
- `restoreMana`: restore `35%` max mana over `5.0s`
- `restoreStamina`: restore `25%` max stamina over `5.0s`

Restore effects are continuous over duration (not instant burst).

`cleanse` is authored with `canCommitWhileStunned: true` so it can be used to break stun.

## Spell List Ownership

Spell-slot abilities are owned per character via Spell List and validated by
loadout normalization.

- Eloise starter Spell List is defined in character catalog fields and currently
  includes Arcane Haste and Focus. Other utility abilities are earned through ownership.

## Projectile Spell Selection (Related)

Projectile-slot spell options also come from Spell List ownership:

- Eloise starter Spell List is defined in character catalog fields and currently
  includes Acid Bolt and Holy Bolt. Other projectile spells are earned through ownership.
- Any learned spell projectile can be selected regardless of equipped spellbook.

Nonpiercing projectiles strike the first eligible actor touched along their
travel during a simulation tick, including when a fast projectile crosses an
actor completely between ticks. Friendly actors remain excluded from ordinary
spell hits. Equal-contact ties use stable actor identity.

Local `selfStatusTuning` owns these values; shared profiles and Willow remain unchanged.
Haste has five seconds of base downtime, Focus four, Ward six. Vital Surge
restores at most 25% HP per twelve-second base cycle; Second Wind restores 25%
stamina per ten-second base cycle. Gear changes cooldowns and resource maxima.
Only one utility is equipped. Focus and Sunlit Vow share a non-stacking offensive
status: equal-strength reapplication extends only if its remaining duration is longer.
Ward suppresses DoT ticks temporarily; Cleanse removes debuffs and breaks stun.
