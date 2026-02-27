# Gear System Design

## Purpose

Gear defines loadout constraints and stat/payload modifiers without rewriting ability structure.

Separation rule:

- abilities own action structure (timing, targeting, hit delivery, base damage model)
- gear owns payload context (damage type/procs/stat bonuses and equip legality)

## Current Gear Slots

| Slot | Runtime meaning |
|---|---|
| `mainWeapon` | Primary-hand weapon payload + stats |
| `offhandWeapon` | Secondary-hand payload + stats |
| `throwingWeapon` | Physical projectile fallback source |
| `spellBook` | Spell projectile grants + spell-slot ability grants + stats |
| `accessory` | Passive stat item |

## Loadout and Ability Gating

- Primary abilities gate on main weapon type.
- Secondary abilities gate on off-hand (or main if future two-handed support is authored).
- Projectile abilities resolve payload from selected projectile source:
  - selected spell projectile from spellbook grants, or
  - equipped throwing weapon fallback.
- Spell-slot abilities are gated by spellbook spell-ability grants.

Validation is enforced at equip/loadout normalization time (`LoadoutValidator` + app-state normalization).

## What Gear Owns

### Stats

Current stat contribution path supports:

- resource max bonuses (health/mana/stamina)
- defense
- global power / global crit chance
- payload-source power / crit chance
- move speed
- cooldown reduction
- typed resistances (`physical`, `fire`, `ice`, `water`, `thunder`, `acid`, `dark`, `bleed`, `earth`, `holy`)

### Payload

Weapon/projectile/spellbook payload can provide:

- damage type
- on-hit procs/status profiles
- projectile motion/collider tuning (for projectile items)

### Compatibility

Legality is data-driven through:

- required weapon types in ability defs
- slot legality in ability defs
- spellbook grant checks for projectile spells and spell-slot abilities

## Deterministic Order

Modifier order remains:

1. Ability-authored structure/base
2. Gear payload/stats
3. Passive/global modifiers

## UI Text Ownership

Core catalogs keep stable IDs only.
Display text is resolved in UI text mappings for localization readiness.
