# Gear System Design

## Purpose

Gear defines loadout constraints and stat/payload modifiers without rewriting ability structure.

Separation rule:

- abilities own action structure (timing, targeting, hit delivery, base damage model)
- gear owns payload context (damage type/procs/stat bonuses and equip legality)

## Scope

- Current Core runtime behavior for Eloise gear/loadout flow
- Authoring constraints for slot identity and dump control

## Runtime Model

### Gear Slots (Eloise)

| Slot | Runtime meaning |
|---|---|
| `mainWeapon` (`mainWeaponId`) | Primary-hand payload + stats |
| `offhandWeapon` (`offhandWeaponId`) | Secondary-hand payload + stats |
| `spellBook` (`spellBookId`) | Spell-tag stats and payload context |
| `accessory` (`accessoryId`) | Passive stats + optional reactive low-health sustain proc |

Eloise currently exposes 4 gear slots.

Runtime still tracks projectile payload context outside this slot list:

- `projectileSlotSpellId`: selected learned projectile spell for projectile-slot payload

### Loadout and Ability Gating

- Primary abilities gate on main weapon type.
- Secondary abilities gate on off-hand, or on main weapon when main is two-handed.
- For Eloise, projectile-slot payload is expected to come from selected learned spell projectile (`projectileSlotSpellId`).
- If Eloise has no valid selected projectile spell, projectile-slot commit is rejected (no fallback payload source).
- Spell-slot abilities are gated by learned Spell List ownership.

Validation is enforced at:

- equip/loadout normalization time (`LoadoutValidator` + app-state normalization)
- runtime commit checks in `AbilityActivationSystem`

### Gear Contribution Surface

#### Stats

Current stat contribution path supports:

- resource max bonuses (health/mana/stamina)
- resource regen bonuses (health/mana/stamina)
- defense
- global power / global crit chance
- move speed
- cooldown reduction
- typed resistances (`physical`, `fire`, `ice`, `water`, `thunder`, `acid`, `dark`, `bleed`, `earth`, `holy`)

#### Payload and Procs

Weapon/projectile payload can provide:

- damage type
- weapon procs/status profiles (`OnHit`, `OnCrit`, `OnKill`)
- projectile motion/collider tuning (for projectile items)

Spellbooks currently contribute stats only (no authored proc entries).

Outgoing proc hook semantics in `DamageSystem`:

| Hook | Trigger condition | Status target |
|---|---|---|
| `OnHit` | damage request has `amount100 > 0` | damaged target |
| `OnCrit` | `OnHit` conditions + crit occurred | damaged target |
| `OnKill` | `OnHit` conditions + this hit killed target | source entity |

Each proc also applies its own deterministic chance roll (`chanceBp`).
`OnBlock` exists in proc enums but is not currently used in outgoing proc resolution.

#### Proc Hook Effect Matrix

Proc definitions carry `statusProfileId`, so runtime can apply any non-`none`
`StatusProfileId` on a valid hook. The table below lists currently authored
effect families by hook in weapon/shield/accessory catalogs.

| Hook | Runtime receiver | Runtime allowed status profiles | Currently authored effects |
|---|---|---|---|
| `OnHit` | damaged target | any non-`none` `StatusProfileId` | `meleeBleed` (Bleed DoT), `slowOnHit` (Slow) |
| `OnCrit` | damaged target | any non-`none` `StatusProfileId` | `acidOnHit` (Vulnerable), `weakenOnHit` (Weaken), `stunOnHit` (Stun), `silenceOnHit` (Silence) |
| `OnKill` | source entity | any non-`none` `StatusProfileId` | `speedBoost` (Haste) |
| `onDamaged` (`ReactiveProcHook.onDamaged`) | `self` or `attacker` (reactive target policy) | any non-`none` `StatusProfileId` | `meleeBleed` (Bleed DoT), `burnOnHit` (Burn DoT), `slowOnHit` (Slow), `drenchOnHit` (Drench) |
| `onLowHealth` (`ReactiveProcHook.onLowHealth`) | `self` or `attacker` (reactive target policy) | any non-`none` `StatusProfileId` | `speedBoost` (Haste, offhand), `restoreHealth` / `restoreMana` / `restoreStamina` (Sustain, accessory) |

### Compatibility Rules

Legality is data-driven through:

- required weapon types in ability defs
- slot legality in ability defs
- Spell List ownership checks for projectile spell selection and spell-slot ability selection
- two-handed conflict rule: two-handed main weapon blocks separate offhand loadout

### Deterministic Resolution Order

Modifier order remains:

1. Ability-authored structure/base payload
2. Gear payload source context (damage type/procs) + resolved gear stats
3. Passive/global/status modifiers
4. Deterministic proc dedupe and final clamps

### Resolved Stats Aggregation

`total = mainWeapon.stats`

`if (mask has offHand && mainWeapon is not two-handed) total += offhandWeapon.stats`

`if (mask has projectile) total += spellBook.stats`

`total += accessory.stats`

`resolved = clampPerStat(total)` in `CharacterStatsResolver`

## Authoring Constraints

### Slot Identity Matrix

| Slot | Role | Allowed stats | Allowed procs | Allowed dump families |
|---|---|---|---|---|
| `mainWeapon` (Sword) | Primary offense + stamina combat loop | `globalPowerBonusBp`, `globalCritChanceBonusBp`, `staminaBonusBp`, `staminaRegenBonusBp` | Outgoing `OnHit`, `OnCrit`, `OnKill` | `healthBonusBp`, `defenseBonusBp`, `manaRegenBonusBp` |
| `offhandWeapon` (Shield) | Defense and counterplay | `defenseBonusBp`, typed resistance fields, `staminaBonusBp`, `staminaRegenBonusBp` | Reactive `onDamaged`, `onLowHealth` | `moveSpeedBonusBp`, `globalPowerBonusBp`, `globalCritChanceBonusBp` |
| `spellBook` | Casting economy + spell cadence | `manaBonusBp`, `manaRegenBonusBp`, `cooldownReductionBp`, `globalCritChanceBonusBp` | None (default target) | `staminaBonusBp`, `staminaRegenBonusBp`, `healthRegenBonusBp` |
| `accessory` | Flexible build accent | Any non-proc stat family | Reactive `onLowHealth` sustain only | `manaBonusBp`, `cooldownReductionBp`, typed resistance (`*ResistanceBp`) |

#### Hard Ceilings for Positive Stats (Per Item)

These are authoring ceilings for a single item instance.
A stat line cannot exceed these values, even if budget/dump rules would allow more.

| Stat family | Maximum allowed value |
|---|---:|
| `healthBonusBp` | `+2000` |
| `manaBonusBp` | `+2000` |
| `staminaBonusBp` | `+2000` |
| `healthRegenBonusBp` | `+1200` |
| `manaRegenBonusBp` | `+1200` |
| `staminaRegenBonusBp` | `+1200` |
| `defenseBonusBp` | `+1800` |
| `globalPowerBonusBp` | `+1800` |
| `globalCritChanceBonusBp` | `+1200` |
| `moveSpeedBonusBp` | `+1000` |
| `cooldownReductionBp` | `+800` |
| typed resistance (`*ResistanceBp`, each type) | `+2500` |

### Proc Effect Restrictions

#### Status Effect Families

| Family | Status profiles | Runtime effect type(s) |
|---|---|---|
| `Neutral` | `none` | none (no status application) |
| `DoT` | `meleeBleed`, `burnOnHit` | `dot` |
| `SoftControl` | `slowOnHit`, `drenchOnHit` | `slow`, `drench` |
| `HardCC` | `stunOnHit`, `silenceOnHit` | `stun`, `silence` |
| `Debuff` | `acidOnHit`, `weakenOnHit` | `vulnerable`, `weaken` |
| `SelfBuff` | `speedBoost`, `focus`, `arcaneWard` | `haste`, `offenseBuff`, `damageReduction` |
| `Sustain` | `restoreHealth`, `restoreMana`, `restoreStamina` | `resourceOverTime` |

#### Allowed Families by Hook

| Hook | Allowed families | Disallowed highlights |
|---|---|---|
| `OnHit` | `DoT`, `SoftControl` | `Debuff`, `HardCC`, `SelfBuff`, `Sustain` |
| `OnCrit` | `Debuff`, `HardCC` | `SelfBuff`, `Sustain` |
| `OnKill` | `SelfBuff` | enemy debuff/control families (`DoT`, `SoftControl`, `HardCC`, `Debuff`), `Sustain` |
| `onDamaged` | attacker-targeted `DoT`, `SoftControl` | `Debuff`, `HardCC`, `SelfBuff`, `Sustain` |
| `onLowHealth` | self-targeted `SelfBuff`; `Sustain` (accessory only) | attacker-targeted effects; `Sustain` on non-accessory items |

#### Hard Authoring Rules

1. One proc per item maximum.
   This means at most one total proc entry across both `procs` and `reactiveProcs` on a single item definition.
2. An item cannot define both outgoing and reactive proc lists at the same time.

#### Hard Caps for Proc Effects (Per Item)

These caps constrain one authored proc entry on one item.
They apply in addition to hook-family restrictions and slot identity constraints.

##### Trigger Caps by Hook

| Hook | Proc chance cap (`chanceBp`) | Extra trigger caps |
|---|---:|---|
| `OnHit` | `<= 3500` | none |
| `OnCrit` | `<= 10000` | none |
| `OnKill` | `= 10000` | none |
| `onDamaged` | `<= 3500` | `internalCooldownTicks >= 0` (`0` allowed) |
| `onLowHealth` | `= 10000` | `lowHealthThresholdBp` in `[2500..3500]`; `internalCooldownTicks >= 1800` |

##### Effect Caps by Status Family

| Family | Per-proc cap |
|---|---|
| `DoT` | `magnitude <= 500`; `durationSeconds <= 5.0` |
| `SoftControl` | `magnitude <= 5000`; `durationSeconds <= 5.0` |
| `HardCC` | `stun` duration `<= 1.0s`; `silence` duration `<= 3.0s` |
| `Debuff` | `magnitude <= 5000`; `durationSeconds <= 5.0` |
| `SelfBuff` | `magnitude <= 5000`; `durationSeconds <= 5.0`; `offenseBuff` crit bonus `<= 1500` |
| `Sustain` | `resourceOverTime` `magnitude <= 3500`; `durationSeconds <= 5.0`; allowed only on `onLowHealth` and only for `accessory` |

### Per-Slot Dump Constraints

#### Dump Definition

A "dump" is any negative stat value intentionally used as a tradeoff to buy power in other stat/proc lines.

#### Allowed Dump Families by Slot

Only these negative stat families are allowed per slot.
If a stat family is not listed as positive in "Slot Identity Matrix" and not listed below as a dump family, it must remain `0`.

| Slot | Allowed dump families |
|---|---|
| `mainWeapon` (Sword) | `healthBonusBp`, `defenseBonusBp`, `manaRegenBonusBp` |
| `offhandWeapon` (Shield) | `moveSpeedBonusBp`, `globalPowerBonusBp`, `globalCritChanceBonusBp` |
| `spellBook` | `staminaBonusBp`, `staminaRegenBonusBp`, `healthRegenBonusBp` |
| `accessory` | `manaBonusBp`, `cooldownReductionBp`, typed resistance (`*ResistanceBp`) |

#### Minimum Authoring Magnitude (No Tiny Values)

To avoid fake variety via negligible numbers, non-zero stat lines must be meaningful.

Rule:

- any authored non-zero stat line must satisfy `abs(valueBp) >= 500`

#### Hard Floors for Negative Stats (Per Item)

These are authoring floors for a single item instance.
An item cannot go below these values even if dump cap still allows more.

| Stat family | Minimum allowed value |
|---|---:|
| `healthBonusBp` | `-1000` |
| `manaBonusBp` | `-1000` |
| `staminaBonusBp` | `-1000` |
| `healthRegenBonusBp` | `-800` |
| `manaRegenBonusBp` | `-800` |
| `staminaRegenBonusBp` | `-800` |
| `defenseBonusBp` | `-1000` |
| `globalPowerBonusBp` | `-1000` |
| `globalCritChanceBonusBp` | `-1000` |
| `moveSpeedBonusBp` | `-1000` |
| `cooldownReductionBp` | `-1000` |
| typed resistance (`*ResistanceBp`, each type) | `-1000` |

## Balancing Framework

### Goal
All gear items should be power-equivalent inside their slot identity.

### Item Power Score (IPS)
`IPS = StatScore + ProcScore + DumpCredit`

- `StatScore = sum((valueBp / 100) * statWeight)` for positive lines.
- `DumpCredit = sum((abs(valueBp) / 100) * statWeight * 0.6)` for negative lines.
- `DumpCredit` cap: max `30%` of target slot budget.
- `ProcScore = hookBase * familyMultiplier * (chanceBp / 10000) * uptimeFactor`.

### Target Budgets
| Slot | Target IPS | Allowed band |
|---|---:|---:|
| `mainWeapon` | `100` | `95..105` |
| `offhandWeapon` | `100` | `95..105` |
| `spellBook` | `100` | `95..105` |
| `accessory` | `100` | `95..105` |

### Starter Stat Weights (per 100 bp)
| Stat family | Weight |
|---|---:|
| `globalPowerBonusBp` | `2.0` |
| `globalCritChanceBonusBp` | `2.2` |
| `defenseBonusBp` | `1.7` |
| `cooldownReductionBp` | `2.4` |
| `moveSpeedBonusBp` | `2.0` |
| resource max (`health/mana/stamina`) | `1.2` |
| resource regen (`health/mana/stamina`) | `1.4` |
| typed resistance (`*ResistanceBp`) | `1.5` |

### Proc Valuation Baseline
| Hook | Base points |
|---|---:|
| `OnHit` | `26` |
| `OnCrit` | `32` |
| `OnKill` | `22` |
| `onDamaged` | `24` |
| `onLowHealth` | `28` |

| Family | Multiplier |
|---|---:|
| `DoT` | `1.0` |
| `SoftControl` | `1.05` |
| `HardCC` | `1.2` |
| `Debuff` | `1.1` |
| `SelfBuff` | `1.0` |
| `Sustain` | `1.0` |

### Acceptance Gates
1. IPS must be inside target band (`95..105`).
2. One stat line cannot exceed `40%` of item IPS.
3. Proc contribution cannot exceed `40%` of item IPS.
4. Keep all existing caps/floors/hook-family/slot-dump constraints.
5. No tiny values (`abs(valueBp) >= 500`).

### Fast Tuning Loop
1. Author item.
2. Compute IPS in a sheet.
3. If out of band, adjust largest line first in `100 bp` steps.
4. Re-test in 3 scenarios: single target, multi target, low-health clutch.
5. Lock once all scenarios are within ±5% performance of slot baseline.
