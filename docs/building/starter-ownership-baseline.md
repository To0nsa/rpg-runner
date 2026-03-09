# Starter Ownership Baseline

Date: March 9, 2026
Status: Implemented

## Goal

Remove auto-unlock behavior and keep a strict starter-owned baseline for gear
and skills while server-authoritative progression is being prepared.

## Starter-Owned Gear

- Main weapon: `WeaponId.plainsteel`
- Off-hand: `WeaponId.roadguard`
- Spellbook: `SpellBookId.apprenticePrimer`
- Accessory: `AccessoryId.strengthBelt`

All other gear remains visible in pickers as locked candidates.

## Starter-Owned Skills

Non-spell slots are starter-locked to one owned skill per slot:

- Primary: `eloise.seeker_slash`
- Secondary: `eloise.shield_block`
- Projectile: `eloise.snap_shot`
- Mobility: `eloise.dash`
- Jump: `eloise.jump`

Spell-slot ownership remains `SpellList`-driven.

## Starter-Owned Spells

- Projectile spells: `ProjectileId.acidBolt`, `ProjectileId.holyBolt`
- Spell-slot abilities: `eloise.focus`, `eloise.arcane_haste`

## Notes

- Spell ownership remains decoupled from spellbook ownership.
- Legacy saves are normalized into the starter-owned baseline.
