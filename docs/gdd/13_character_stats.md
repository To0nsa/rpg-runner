# Character Stats (V1 Design + Current Implementation)

This document defines the V1 character stat model and records the **actual implemented behavior** in Core as of **February 6, 2026**.

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
| Power | Implemented on outgoing payload stats (weapon/projectile/spellbook stats). A global resolver API exists but is not yet applied globally in the damage pipeline. |
| Move Speed | Implemented as a multiplier from resolved loadout stats, then combined with status speed modifiers. |
| Cooldown Reduction | Implemented on all ability commit cooldown start paths. |
| Crit Chance | Implemented end-to-end (payload assembly -> deterministic roll -> crit damage application). |

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

- Payload damage scaling uses outgoing item stats:
  - `scaledDamage = baseDamage * (10000 + powerBonusBp) / 10000`
  - Clamped at minimum `0`.
- Final crit chance is aggregated then clamped to `[0, 10000]`.
- Crit damage bonus is currently fixed to `+5000 bp` (`+50%`).

### 4.5 Incoming damage order

Damage application order in Core:

1. Resolve crit outcome and crit-adjusted amount.
2. Apply global defense.
3. Apply per-damage-type resistance/vulnerability modifier.
4. Clamp final damage to `>= 0`.

---

## 5. Stat Caps (Current Core Values)

| Stat | Min | Max |
|---|---:|---:|
| Health bonus | `-9000 bp` (-90%) | `+20000 bp` (+200%) |
| Mana bonus | `-9000 bp` (-90%) | `+20000 bp` (+200%) |
| Stamina bonus | `-9000 bp` (-90%) | `+20000 bp` (+200%) |
| Defense | `-9000 bp` (-90%) | `+7500 bp` (+75%) |
| Power | `-9000 bp` (-90%) | `+10000 bp` (+100%) |
| Move Speed | `-9000 bp` (-90%) | `+5000 bp` (+50%) |
| Cooldown Reduction | `-5000 bp` (-50% effectiveness, longer cooldowns) | `+5000 bp` (+50% reduction) |
| Crit Chance | `0 bp` (0%) | `+6000 bp` (+60%) |

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
- Projectile items currently contribute primarily through damage type/procs/ballistics.

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

- Resolver includes `applyPower(...)`, but global resolved power is not yet applied as a separate global pass in runtime damage.
- Crit chance pipeline is implemented, but no default catalog gear currently grants crit chance.
- Defense pipeline is implemented, but default catalog gear currently does not grant defense.

---

## 9. Future Expansion Policy

Add a new permanent stat only if all checks pass:

1. Creates a new decision, not a renamed multiplier.
2. Is understandable in one short UI line.
3. Has clear tradeoffs/counterplay.
4. Preserves deterministic clarity.

Prefer proc/trait/status mechanics over new global stats when possible.
