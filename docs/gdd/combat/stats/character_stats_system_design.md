# Character Stats (V1 Design + Current Implementation)

This document defines the V1 character stat model and records the **actual implemented behavior** in Core as of **February 12, 2026**.

It is a design companion to `docs/gdd/11_gear.md`.

---

## 1. Goals

- Keep buildcraft readable in a fast runner context.
- Keep balancing tractable while content volume is still growing.
- Preserve deterministic, multiplayer-ready resolution.
- Allow meaningful gear identity without creating a bloated stat sheet.

---

## 2. V1 Stat Set

The game uses a small universal stat set:

- Health
- Mana
- Stamina
- Defense
- Power
- Move Speed
- Cooldown Reduction
- Crit Chance

### 2.1 Implementation status

| Stat | Current runtime behavior |
|---|---|
| Health | Implemented as max-pool scaling from equipped loadout at player spawn. |
| Mana | Implemented as max-pool scaling from equipped loadout at player spawn. |
| Stamina | Implemented as max-pool scaling from equipped loadout at player spawn. |
| Defense | Implemented globally on incoming damage before per-type resistance. |
| Power | Implemented as a hybrid model: global outgoing power (`globalPowerBonusBp`) plus payload-source power (`powerBonusBp`). |
| Move Speed | Implemented as a multiplier from resolved loadout stats, then combined with status speed modifiers. |
| Cooldown Reduction | Implemented on all ability commit cooldown start paths. |
| Crit Chance | Implemented as a hybrid model: global crit chance (`globalCritChanceBonusBp`) plus payload-source crit chance (`critChanceBonusBp`) with final clamping. |
| Typed Resistance | Implemented from both archetype/store resistance and gear resistance (`physical/fire/ice/thunder/bleed`). |

---

## 3. Numeric Units

### 3.1 Basis points

- Percent-type stats use basis points (bp).
- `100 bp = 1%`
- `10000 bp = 100%`

### 3.2 Fixed-100 resources

- Resource pools and damage use fixed-100 where `100 = 1.0`.
- Example: `10000 = 100.0`.

---

## 4. Formulas and Order of Operations

### 4.1 Resource max scaling

- `scaledMax = applyBp(baseMax100, resourceBonusBp)`
- Current value is clamped to new max on spawn initialization.

### 4.2 Move speed

- `moveSpeedMultiplier = (10000 + moveSpeedBonusBp) / 10000`
- Runtime movement multiplier is:
  - `gearMoveSpeedMultiplier * statusMoveSpeedMultiplier`

### 4.3 Cooldown reduction

- `effectiveScaleBp = 10000 - cooldownReductionBp`
- `scaledCooldownTicks = ceil(baseCooldownTicks * effectiveScaleBp / 10000)`
- Cooldown is applied at commit time.

### 4.4 Outgoing damage and crit

- Outgoing scaling uses a hybrid stage:
  - `damageAfterGlobal = applyBp(baseDamage, globalPowerBonusBp)`
  - `finalDamage = applyBp(damageAfterGlobal, payloadSourcePowerBonusBp)`
  - Clamped at minimum `0`.
- Final crit chance:
  - `finalCritChanceBp = clamp(globalCritChanceBonusBp + payloadSourceCritChanceBp, 0, 10000)`.
- Crit damage bonus is currently fixed to `+5000 bp` (`+50%`).

### 4.5 Incoming damage order

Damage application order in Core:

1. Resolve crit outcome and crit-adjusted amount.
2. Apply global defense.
3. Apply combined per-damage-type resistance/vulnerability modifier:
   - `storeTypedModBp + (-gearTypedResistanceBp)`
4. Clamp final damage to `>= 0`.

### 4.6 Resolved stat lifecycle (runtime)

- Gear-derived stats are resolved through `ResolvedStatsCache` (ECS-backed).
- Hot-path systems (`PlayerMovementSystem`, `AbilityActivationSystem`, `DamageSystem`, `StatusSystem`) read cached resolved stats.
- Recompute occurs lazily only when the equipped loadout snapshot changes:
  - `mask`
  - `mainWeaponId`
  - `offhandWeaponId`
  - `projectileId`
  - `spellBookId`
  - `accessoryId`
- If an entity has no loadout, runtime uses neutral resolved stats (all zero bonuses).
- Status effects currently do **not** mutate the gear-resolved stat bundle; they are applied through runtime modifier stores (`StatModifierStore`, status stores) and compose at use sites.

---

## 5. Stat Caps (Current Core Values)

| Stat | Min | Max |
|---|---:|---:|
| Health bonus | `-9000 bp` (-90%) | `+20000 bp` (+200%) |
| Mana bonus | `-9000 bp` (-90%) | `+20000 bp` (+200%) |
| Stamina bonus | `-9000 bp` (-90%) | `+20000 bp` (+200%) |
| Defense | `-9000 bp` (-90%) | `+7500 bp` (+75%) |
| Global Power | `-9000 bp` (-90%) | `+10000 bp` (+100%) |
| Payload-source Power | `-9000 bp` (-90%) | `+10000 bp` (+100%) |
| Move Speed | `-9000 bp` (-90%) | `+5000 bp` (+50%) |
| Cooldown Reduction | `-5000 bp` (-50% effectiveness, longer cooldowns) | `+5000 bp` (+50% reduction) |
| Global Crit Chance | `0 bp` (0%) | `+6000 bp` (+60%) |
| Payload-source Crit Chance | `0 bp` (0%) | `+6000 bp` (+60%) |
| Typed Resistance (per type) | `-9000 bp` (vulnerability) | `+7500 bp` (resistance) |

---

## 6. Current Catalog Values

### 6.1 Weapons (Power)

- `Wooden Sword`: `-100 bp` (-1%)
- `Basic Sword`: `+100 bp` (+1%)
- `Solid Sword`: `+200 bp` (+2%)
- `Wooden Shield`: `-100 bp` (-1%)
- `Basic Shield`: `+100 bp` (+1%)
- `Solid Shield`: `+200 bp` (+2%)

### 6.2 Spell books (Power)

- `Basic Spellbook`: `-100 bp` (-1%)
- `Solid Spellbook`: `+100 bp` (+1%)
- `Epic Spellbook`: `+200 bp` (+2%)

### 6.3 Accessories

- `Speed Boots`: `moveSpeedBonusBp = +500` (+5% move speed)
- `Golden Ring`: `hpBonus100 = +200` (+2% health max)
- `Teeth Necklace`: `staminaBonus100 = +200` (+2% stamina max)

### 6.4 Projectile items

- No direct stat bonus values currently assigned in `ProjectileItemCatalog`.
- Projectile items currently contribute through damage type/procs plus projectile motion/collider tuning.

### 6.5 Global offensive + typed resistance authoring

- Default catalog content currently uses payload-source Power on weapons/spellbooks.
- No default catalog content currently grants global offensive stats.
- No default catalog content currently grants typed gear resistance.

---

## 7. Base Character Reference (Eloise defaults)

Current Eloise baseline (before gear scaling):

- Health max: `100`
- Mana max: `100`
- Stamina max: `100`
- Health regen: `0.5 / sec`
- Mana regen: `2.0 / sec`
- Stamina regen: `1.0 / sec`

These values are converted to fixed-100 in runtime stores.

---

## 8. Known V1 Notes

- Crit damage bonus remains fixed at `+50%`.
- Default catalog content currently does not grant global offensive stats.
- Default catalog content currently does not grant typed gear resistance.

---

## 9. Future Expansion Policy

Add a new permanent stat only if all checks pass:

1. Creates a new decision, not a renamed multiplier.
2. Is understandable in one short UI line.
3. Has clear tradeoffs/counterplay.
4. Preserves deterministic clarity.

Prefer proc/trait/status mechanics over new global stats when possible.
