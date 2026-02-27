# Status Effects

## Purpose

Status effects add deterministic pressure/control/tempo changes through authored `StatusProfileId` bundles.

## Current Taxonomy

`StatusEffectType` currently includes:

- `dot`
- `slow`
- `stun`
- `haste`
- `vulnerable`
- `weaken`
- `drench`
- `silence`
- `resourceOverTime`

`StatusProfileId` currently includes:

- `none`
- `slowOnHit`
- `burnOnHit`
- `acidOnHit`
- `weakenOnHit`
- `drenchOnHit`
- `silenceOnHit`
- `meleeBleed`
- `stunOnHit`
- `speedBoost`
- `restoreHealth`
- `restoreMana`
- `restoreStamina`

## Current Profile Reference

| Profile | Effects |
|---|---|
| `slowOnHit` | slow `25%` for `3.0s` |
| `burnOnHit` | DoT `5.0 DPS` fire for `5.0s` |
| `meleeBleed` | DoT `3.0 DPS` physical for `5.0s` |
| `stunOnHit` | stun `1.0s` |
| `acidOnHit` | vulnerable `+50%` incoming for `5.0s` |
| `weakenOnHit` | weaken `-35%` outgoing for `5.0s` |
| `drenchOnHit` | drench `-50%` action speed for `5.0s` |
| `silenceOnHit` | cast lock (`silence`) for `3.0s` |
| `speedBoost` | haste `+50%` move speed for `5.0s` |
| `restoreHealth` | restore `35%` max HP over `5.0s` |
| `restoreMana` | restore `35%` max mana over `5.0s` |
| `restoreStamina` | restore `35%` max stamina over `5.0s` |

## Authoritative Pipeline

### Sources

- `WeaponProc` on hit (`DamageSystem`)
- self abilities (`SelfAbilitySystem`) via `selfStatusProfileId`
- mobility contact effects (`MobilityImpactSystem`) via `statusProfileId`

### Tick order in `GameCore`

1. `StatusSystem.tickExisting`
2. `DamageMiddlewareSystem.step`
3. `DamageSystem.step`
4. `StatusSystem.applyQueued`

## Stacking and Refresh Rules

### DoT (`DotStore`)

- channels are keyed by damage type
- stronger DPS replaces weaker channel
- equal DPS refreshes duration to max remaining
- lower DPS ignored

### Resource over time

- channels keyed by resource type
- stronger `amountBp` replaces weaker channel
- equal `amountBp` refreshes duration

### Slow/Haste/Vulnerable/Weaken/Drench

- stronger magnitude replaces and refreshes
- equal magnitude extends to max remaining
- weaker ignored

### Stun

- applies `LockFlag.stun`
- overlapping stuns extend lock with max-until behavior
- interrupts active intents and active dash

### Silence

- applies `LockFlag.cast`
- interrupts only enemy projectile casts still in windup

## Immunity, Scaling, and Gating

- Per-entity immunity via `StatusImmunityStore` bitmask.
- `scaleByDamageType` scales magnitude up only when combined typed modifier is positive.
- Apply-time gating skips status when target is dead, missing health, or currently invulnerable.

## Derived Runtime Effects

- slow/haste modify `StatModifierStore.moveSpeedMul`
- drench modifies `StatModifierStore.actionSpeedBp`
- action speed affects attack/cast timing and cooldown scaling at commit for combat slots

## Determinism Rules

1. integer magnitudes + tick-based durations
2. deterministic proc RNG
3. deterministic store iteration
4. explicit queue + store writes only

## Known Gaps

1. No generic cleanse/dispel yet
2. No diminishing returns system yet
3. Beneficial statuses are currently blocked by invulnerability gating
