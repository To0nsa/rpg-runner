# Phase 5: Unified Hit Pipeline & Stat Scaling (Revised)

## Goal

Establish a single, deterministic pipeline for constructing **Hit Payloads** from Abilities and Weapons.
This phase enforces **Integer-based Fixed-Point Math** for all simulation logic and introduces a **Canonical Payload Builder** to ensure consistency between UI prediction and actual combat execution.

---

## Design Pillars

### P1 — Integer Determinism
**Simulation must never use floats/doubles.**
- All damage values are `int` (Fixed-point: `100` = `1.0` Visual Damage).
- All multipliers are `int` (Basis Points: `100` = `1%`).
- Proc chances are `int` (Basis Points: `100` = `1%`).
- `double` is permitted **only** at the UI edge (Popups, HUD) or for physics delta-time integration (movement).

### P2 — Canonical Build Pipeline
A single static helper (`HitPayloadBuilder`) constructs the payload.
- **Producers** (Player/Enemy Systems) call this builder to create a **Frozen Snapshot** in the Intent.
- **Consumers** (Projectile/Melee Systems) execute the Snapshot.
- **UI** calls the same builder for tooltips/prediction.

### P3 — Explicit Semantics
- No "Magic Tag Inference". `AbilityDef` must explicitly define its `baseDamageType`.
- Modifier order is strict: Ability (Base) -> Weapon (Scaling/Override) -> Buffs.

---

## Schema Changes

### 1. `HitPayload` (The Frozen Snapshot)
The transport struct for resolved hit data.

```dart
class HitPayload {
  // 100 = 1.0 visual damage
  final int damage100;
  
  final DamageType damageType;
  final List<WeaponProc> procs;
  final EntityId sourceId;
  
  // Debug info
  final AbilityKey? abilityId;
  final WeaponId? weaponId;
}
```

### 2. `AbilityDef` (Refinement)
Add explicit `baseDamageType`. No more guessing from tags.

```dart
class AbilityDef {
  // ... existing fields ...
  
  // New Field
  final DamageType baseDamageType; // Default: DamageType.physical
  
  // Note: baseDamage is already 'int' from Phase 4.
}
```

### 3. `WeaponStats` & `WeaponProc` (Strict Ints)
Convert existing `double` fields to `int` basis points (bp).

```dart
class WeaponStats {
  // 100 = 1% bonus. 1000 = 10% bonus.
  final int powerBonusBp; 
  // ...
}

class WeaponProc {
  // 100 = 1% chance. 10000 = 100% chance.
  final int chanceBp;
  // ...
}
```

---

## The Canonical Builder

```dart
class HitPayloadBuilder {
  static HitPayload build({
    required AbilityDef ability,
    required WeaponDef? weapon, // Null for innate/monster abilities
    required EntityId source,
  }) {
    // 1. Start with Ability Base
    int finalDamage100 = ability.baseDamage; // e.g., 1500 (15.0)
    DamageType finalDamageType = ability.baseDamageType;
    var finalProcs = <WeaponProc>[];

    // 2. Apply Weapon Modifiers (if equipped/valid)
    if (weapon != null) {
      // A. Power Scaling (Integer Math)
      // damage = base * (1 + bonusBp/10000)
      // impl: (base * (10000 + bonusBp)) ~/ 10000
      if (weapon.stats.powerBonusBp > 0) {
        finalDamage100 = (finalDamage100 * (10000 + weapon.stats.powerBonusBp)) ~/ 10000;
        
        // Edge case: Floor of 1 (0.01) if base > 0? 
        // For now, standard integer truncation is fine.
      }
      
      // B. Damage Type Override
      // Rule: Weapon overrides Physical ability. Elemental ability keeps its element.
      if (finalDamageType == DamageType.physical) {
        finalDamageType = weapon.damageType;
      }
      
      // C. Procs
      // Note: We COPY the procs here. Selection/Roll happens at APPLICATION time (OnHit), 
      // or we roll here?
      // DECISION: Roll Randomness at APPLICATION (Hit Resolver), not Intent. 
      // Intent should carry "Potential Procs".
      // However, Payload usually implies "Result". 
      // For determinism, if we roll later, we just pass the list.
      finalProcs.addAll(weapon.procs);
    }

    return HitPayload(
      damage100: finalDamage100,
      damageType: finalDamageType,
      procs: finalProcs,
      sourceId: source,
      abilityId: ability.id,
      weaponId: weapon?.id,
    );
  }
}
```

---

## Migration Plan

### Step 1: Schema Hardening
1.  **AbilityDef**: Add `baseDamageType`. Update `AbilityCatalog` (Manual mapping: IceBolt->Ice, etc).
2.  **WeaponStats**: Rename/Convert `powerBonus` (double) -> `powerBonusBp` (int).
3.  **WeaponProc**: Rename/Convert `chance` (double) -> `chanceBp` (int).

### Step 2: Builder & Pipeline
1.  Implement `HitPayloadBuilder`.
2.  **Refactor Producers (PlayerCast/Ranged)**:
    -   Call `HitPayloadBuilder.build(...)`.
    -   Store result in Intent.
    -   *Note*: `RangedWeaponIntentDef` and `CastIntentDef` already have fields for `damage`, `damageType`. Update them to use `int damage100`.

### Step 3: Consumer Execution
1.  **Ranged/Spell Systems**: Read `damage100` from intent and execute.
2.  **Update UI**: Convert `damage100 / 100.0` for display.

### Step 4: Legacy Cleanup
- Remove deprecated legacy fields (`legacyDamage` etc) from Phase 4.

---

## Validation Rules

1.  **Identity Test**: Unarmed (Power 0) + Strike (1500) = 1500 damage.
2.  **Scaling Test**: Gold Sword (Power 2000 = +20%) + Strike (1500) = 1500 * 1.2 = 1800 damage.
3.  **Type Priority**: 
    - Physical Ability + Fire Weapon = Fire.
    - Ice Ability + Fire Weapon = Ice.
4.  **Determinism**: Run simulation 2x with same seed. `damage100` values must match exactly.
