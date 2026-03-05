# Eloise Secondary: Shield

Abilities requiring `WeaponType.shield` and equippable in `AbilitySlot.secondary`.

## Ability Matrix

| Ability ID | Lifecycle | Targeting | W/A/R | Cost | Cooldown | Payload Source |
|---|---|---|---|---|---:|---|
| `eloise.aegis_riposte` | `holdMaintain` | `none` | `2/180/2` | hold drain `700/s` | `30` | `secondaryWeapon` |
| `eloise.shield_block` | `holdMaintain` | `none` | `2/180/2` | hold drain `700/s` | `30` | `secondaryWeapon` |

## Defensive Shield Abilities

### `eloise.aegis_riposte`

- hold-maintain guard (`holdToMaintain`)
- max active window: `180` ticks
- hold drain: `700` stamina/sec
- hit mitigation: `5000 bp` (`50%`)
- grants one riposte bonus on first guarded hit per activation

### `eloise.shield_block`

- hold-maintain guard (`holdToMaintain`)
- max active window: `180` ticks
- hold drain: `700` stamina/sec
- hit mitigation: `10000 bp` (`100%`)
- no riposte bonus

## Constraints

- All abilities in this file require `WeaponType.shield`.
- `AbilityPayloadSource.secondaryWeapon` is used for payload-slot gating.
- Guard mitigation/riposte behavior is ability-authored (`damageIgnoredBp`,
  `grantsRiposteOnGuardedHit`) and does not consume weapon procs.
- Cooldown (`30`) starts when hold ends (release, timeout, or stamina depletion),
  not at commit.
