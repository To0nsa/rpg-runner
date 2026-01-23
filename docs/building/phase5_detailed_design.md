# Phase 5: Unified Hit Pipeline & Stat Scaling

## Goal

Establish a single, authoritative pipeline for constructing **Hit Payloads** from Abilities and Weapons.
This phase integrates **Stat Scaling** (Power Bonus) and **Weapon Modifiers** (Procs) into the damage calculation, finalizing the "Ability Owns Structure, Weapon Owns Payload" architecture.

---

## Design Pillars

### P1 — The Unified Pipeline
All damaging actions (Melee, Ranged, Spells) must go through the same construction logic:
`Ability (Base)` + `Weapon (Stats/Mods)` + `Buffs (Passive)` = `HitPayload`.

### P2 — Stat Scaling (Fixed Point)
Game balance relies on scaling.
- **Power Bonus**: A percentage modifier from the equipped weapon (e.g., `10` = +10% damage).
- **Math**: `FinalDamage = BaseDamage * (100 + PowerBonus) / 100`.
- All operations must remain in **integer fixed-point** domain to preserve determinism.

### P3 — Modifier Order
Resolution order is strict:
1.  **Ability**: Sets base damage, initial element (e.g. Fire), and structural properties.
2.  **Weapon**: Applies Power Bonus, overrides element (if applicable), adds Procs (Bleed, Stun).
3.  **Buffs**: (Future/Phase 6) Multipliers from potions/status effects.

---

## Schema & Data Structures

### 1. `HitPayload` (New/Refined)
The transport struct for all hit data.

```dart
class HitPayload {
  final double damage;          // Final calculated damage (visuals only, logic uses integers likely?) 
                                // WAIT: We are using double in runtime currently, but logic should be integer-derived.
                                // Proposal: Keep double for now to match current systems, but verify determinism via "clicks".
                                
  final DamageType damageType;  // Resolved element.
  final List<WeaponProc> procs; // On-hit effects.
  final EntityId sourceId;      // Attacker.
  
  // Debug/Logging source info
  final AbilityKey? abilityId;
  final WeaponId? weaponId;
}
```

### 2. `WeaponStats` Integration
Weapons already have `WeaponStats(powerBonus: int)`. This must now be *used*.

---

## Implementation Plan

### Step 1: `HitPayloadBuilder` Helper
Create a utility class/function to encapsulate the combining logic.

```dart
// core/combat/hit_payload_builder.dart

class HitPayloadBuilder {
  static HitPayload build({
    required AbilityDef ability,
    required WeaponDef? weapon, // Null for innate abilities/monster casts
    required EntityId source,
  }) {
    // 1. Start with Ability Base
    int rawDamage = ability.baseDamage; // e.g., 1500
    var damageType = DamageType.physical; // Ability usually doesn't specify type for Melee, but "Spells" do.
    
    // Resolve Ability Element (Phase 4 Logic moved here)
    if (ability.tags.contains(AbilityTag.fire)) damageType = DamageType.fire;
    else if (ability.tags.contains(AbilityTag.ice)) damageType = DamageType.ice;
    // ... etc
    
    // 2. Apply Weapon Modifiers
    var procs = <WeaponProc>[];
    
    if (weapon != null) {
      // A. Power Bonus Scaling
      // damage = base * (1.0 + bonus/100)
      // integer math: (base * (100 + bonus)) ~/ 100
      final bonus = weapon.stats.powerBonus;
      rawDamage = (rawDamage * (100 + bonus)) ~/ 100;
      
      // B. Damage Type Override ?
      // Rule: Weapon damage type usually overrides Neutral/Physical ability, 
      // but SPECIFIC ability element (Fire Bolt) usually overrides Weapon (Steel Sword).
      // Design Decision:
      // - If Ability is Physical, use Weapon Type.
      // - If Ability is Elemental, keep Ability Type (Magic weapons don't turn Fireball into Steel).
      if (damageType == DamageType.physical) {
        damageType = weapon.damageType;
      }
      
      // C. Procs
      procs.addAll(weapon.procs);
    }
    
    return HitPayload(
      damage: rawDamage / 100.0, // Convert back to runtime double
      damageType: damageType,
      procs: procs,
      sourceId: source,
      abilityId: ability.id,
      weaponId: weapon?.id,
    );
  }
}
```

### Step 2: System Integration
Refactor the "Producers" or "Consumers"?
- **Ranged/Spell**: The `Intent` is the contract. 
    - **Producer (PlayerSystem)**: Should it build the full payload?
    - **Decision**: No. The Intent should carry *references* (indexes) or *raw structure*?
    - **Correction**: In Phase 4 we put `damage` in the intent.
    - **Optimization**: To avoid duplicating logic in every Player/Enemy system, the **Payload Builder** should be called by the **Producer** (PlayerMeleeSystem, PlayerCastSystem) and the result (final damage, final type) written to the Intent.
    - *Alternative*: The Intent carries `AbilityId` and `WeaponId`, and the *Consumer* (MeleeStrikeSystem) builds the payload.
    - *Winner*: **Producer builds Payload**. 
        - Why? Because UI (damage prediction) needs to see the final numbers too. 
        - Also keeps the "execution" systems (MeleeStrike) dumb: "Deal X damage."

### Step 3: Cleanup Legacy
- Remove `legacyDamage` etc from `RangedWeaponDef` and Catalog.
- Remove deprecated fields.

---

## Validation

### Scenarios
1.  **Scaling Test**:
    - Equip `Wooden Sword` (Power 0). Ability Base 1000. -> Damage 10.0.
    - Equip `Golden Sword` (Power 20). Ability Base 1000. -> Damage 12.0.
2.  **Element Priority**:
    - `Fire Bolt` (Fire) + `Ice Sword` (Ice). -> Result: **Fire**.
    - `Slash` (Physical) + `Ice Sword` (Ice). -> Result: **Ice**.
3.  **Proc Chaining**:
    - Weapon with Bleed. Attack applies Bleed status.

---

## Task Breakdown
- [ ] Create `HitPayloadBuilder`.
- [ ] Update `PlayerMeleeSystem` to use Builder.
- [ ] Update `PlayerRangedWeaponSystem` to use Builder.
- [ ] Update `PlayerCastSystem` to use Builder.
- [ ] Verify Stat Scaling in-game.
- [ ] Remove Legacy Data fields.
