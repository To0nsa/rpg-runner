# Phase 1: Data Model Detail & Edge Cases (Locked Spec)

This document details the exact data structures for Phase 1 and analyzes potential edge cases, incorporating all critical feedback (Slots, Aim, State, Interrupts, Asserts, Units).

## 1. Class Definitions

### `AbilityId` (Enum)
Stable identifiers. No `none`.
```dart
enum AbilityId {
  // Fallbacks
  unarmedStrike, 
  bracedBlock,   
  
  // Eloise
  swordStrike, swordParry,
  shieldBash, shieldBlock,
  throwingKnife, iceBolt, fireBolt, thunderBolt,
  dash, roll,
  
  // Intrinsic
  jump
}
```

### `AbilitySlot` (Enum)
Defines the "buttons/inputs".
```dart
enum AbilitySlot {
  primary,    // Button A (Melee)
  secondary,  // Button B (Off-hand/Defensive)
  projectile, // Button C (Cast/Throw)
  mobility,   // Button D (Dash)
  bonus,      // Button E (Any)
}
```

### `InterruptPriority` (Enum & Contract)
Defines preemption hierarchy.
**Contract:** 
*   Priority is totally ordered by ordinal (index `0` lowest).
*   **Collision Rule:** If `Incoming.priority > Current.priority` -> Interrupt.
*   **Same Priority:** `Current` wins (cannot be preempted by equal priority, must finish). *Exception:* `forced` logic might override this specific check externally.

```dart
enum InterruptPriority {
  // Lowest
  low,      // e.g. Passive regen stance?
  combat,   // Standard attacks (Strike, Cast)
  mobility, // Dash, Jump, Roll
  forced,   // Hitstun, Death (Highest)
}
```

### `AbilityDef` (Class)
Authoritative definition of an ability's "Structure".

```dart
class AbilityDef {
  const AbilityDef({
    required this.id,
    required this.category,
    required this.allowedSlots,
    required this.targetingModel,
    required this.hitDelivery,
    required this.windupTicks,
    required this.activeTicks,
    required this.recoveryTicks,
    required this.staminaCost,
    required this.manaCost,
    required this.cooldownTicks,
    required this.interruptPriority,
    required this.canBeInterruptedBy,
    required this.animKey,
    required this.tags,
    required this.requiredTags,
  }) : assert(allowedSlots.isNotEmpty, 'Ability must be equipable in at least one slot'),
       assert(windupTicks >= 0 && activeTicks >= 0 && recoveryTicks >= 0, 'Ticks cannot be negative'),
       assert(cooldownTicks >= 0, 'Cooldown cannot be negative'),
       assert(staminaCost >= 0 && manaCost >= 0, 'Costs cannot be negative'),
       assert(!canBeInterruptedBy.contains(interruptPriority), 'Ability should not list its own priority in canBeInterruptedBy (old wins implicitly).'),
       assert(interruptPriority != InterruptPriority.forced, 'Forced priority is reserved for system events (stun/death).');

  final AbilityId id;
  // UI Grouping Only
  final AbilityCategory category; 
  
  // -- Slot Legality --
  // Explicitly defines where this can be equipped.
  final Set<AbilitySlot> allowedSlots;
  
  // -- Targeting & Execution --
  final TargetingModel targetingModel; 
  
  // -- Hit Delivery Spec --
  final HitDeliveryDef hitDelivery; 
  
  // -- Timing (Ticks @ 60hz) --
  final int windupTicks;
  final int activeTicks;
  final int recoveryTicks;
  
  // -- Costs (Fixed Point Int) --
  // 100 = 1.0 unit. avoids float drift.
  final int staminaCost; 
  final int manaCost;
  
  // -- Cooldown --
  final int cooldownTicks;
  
  // -- Interrupt Rules --
  final InterruptPriority interruptPriority;
  final Set<InterruptPriority> canBeInterruptedBy;
  
  // -- Presentation --
  final AnimKey animKey; 
  
  // -- Tags --
  final Set<AbilityTag> tags;           
  final Set<AbilityTag> requiredTags;   
}
```

### `HitDeliveryDef` (Struct)
Standardized Units: All dimensions/offsets are in **World Units** (pixels/game points), same as Physics body sizes.

```dart
abstract class HitDeliveryDef {}

enum HitPolicy { once, oncePerTarget, everyTick }

class MeleeHitDelivery extends HitDeliveryDef {
  const MeleeHitDelivery({
    required this.sizeX,
    required this.sizeY,
    required this.offsetX,
    required this.offsetY,
    required this.hitPolicy,
  });

  final double sizeX; 
  final double sizeY;
  final double offsetX;
  final double offsetY;
  final HitPolicy hitPolicy;
}

class ProjectileHitDelivery extends HitDeliveryDef {
  const ProjectileHitDelivery({
    required this.projectileId,
    this.pierce = false,
    this.chain = false,
    this.chainCount = 0,
    this.hitPolicy = HitPolicy.oncePerTarget,
  }) : assert(chain || chainCount == 0, 'If chain overrides is false, count must be 0');

  final ProjectileId projectileId; 
  final bool pierce;
  final bool chain;
  final int chainCount; 
  final HitPolicy hitPolicy;
}
```

### `AimSnapshot` (Struct)
Encapsulates aiming state.
```dart
class AimSnapshot {
  const AimSnapshot({
    required this.angleRad,
    this.hasAngle = true,
    required this.capturedTick,
  });

  // Canonical "Empty/No Aim" constant
  static const AimSnapshot empty = AimSnapshot(
    angleRad: 0.0,
    hasAngle: false,
    capturedTick: 0,
  );

  final double angleRad;
  final bool hasAngle;
  final int capturedTick;
}
```

### `ActiveAbilityState` (Mutable Component)
Tracks the runtime execution. **Mutable for ECS performance.**
```dart
class ActiveAbilityState {
  AbilityId abilityId = AbilityId.unarmedStrike;
  AbilitySlot slot = AbilitySlot.primary;
  
  AbilityPhase phase = AbilityPhase.idle;
  int phaseTicksRemaining = 0;
  int totalDurationTicks = 0;
  
  int commitTick = 0;
  
  // Snapshot of aim at the moment of commit.
  AimSnapshot aim = AimSnapshot.empty; 
}
```

### `BufferedInputState` (Mutable Component)
Tracks pending inputs. **Mutable/Pooled to avoid GC.**

```dart
class BufferedInputState {
  bool hasValue = false;
  AbilitySlot slot = AbilitySlot.primary;
  int pressedTick = 0;
  AimSnapshot aim = AimSnapshot.empty;

  void set(AbilitySlot s, int tick, AimSnapshot a) { 
    hasValue = true; 
    slot = s; 
    pressedTick = tick; 
    aim = a; 
  }
  
  void clear() { 
    hasValue = false; 
    aim = AimSnapshot.empty; 
    // slot/tick don't matter when hasValue is false
  }
}
```



### `ProjectileHitDelivery` (Refined Asserts)

```dart
class ProjectileHitDelivery extends HitDeliveryDef {
  const ProjectileHitDelivery({
    ...
  }) : assert(chainCount >= 0, 'Chain count must be non-negative'),
       assert(!chain || chainCount > 0, 'If chain is true, count must be > 0'),
       // Design decision: Pierce + Chain allowed. Pierce priority (hits->pierces->...->hits->chains)
       ...;
}
```

### `EquippedLoadoutStore` (Extension)
```dart
AbilityId abilityPrimary;
AbilityId abilitySecondary;
AbilityId abilityProjectile;
AbilityId abilityMobility;
AbilityId abilityBonus;
```

---

## 2. Refined Decision Log (Final Polish)

### A. Slot Legality
*   **Decision:** `AbilityDef.allowedSlots` set explicit legality. Invariant: Must not be empty.

### B. Aim Snapshot
*   **Decision:** defined `AimSnapshot.empty`.
*   **Behavior Check:** If `ActiveAbilityState` uses mutable fields, `aim` field might be reassigned to `AimSnapshot.empty` on idle transition to clear state.

### C. Mutable State
*   **Decision:** `ActiveAbilityState` fields are non-final. Logic systems mutate in place.

### D. Interrupt Model (Deterministic)
*   **Decision:**
    *   Enum Order: Low < Combat < Mobility < Forced.
    *   **Collision Rule:** New > Old only if New.priority > Old.priority.
    *   **Same Priority:** Old wins (Current action completes). "First commit wins".

### E. Hit Policy & Units
*   **Decision:** `HitPolicy` enum. `chainCount == 0` assert.
*   **Units:** All doubles are World Units (standard physics size).

### F. Fixed Point Costs
*   **Decision:** `int` fixed point (100 = 1.0).
*   **Conversion Rule:** Tuning values (doubles) are converted to fixed-point `int` **once at Load Time** (constructing the Catalog/Defs). Runtime logic uses ints exclusively. No runtime double operations for resource consumption.

---

## 3. Revised Phase 1 Action Items

1.  **Define Enums:**
    *   `AbilityId`, `AbilitySlot`, `AbilityCategory`, `AbilityPhase`
    *   `TargetingModel`, `HitPolicy`, `InterruptPriority` (ordered), `AbilityTag`
2.  **Define Structs:**
    *   `AbilityTiming` (ticks), `AbilityCost` (int)
    *   `HitDeliveryDef` (Hitbox doubles in World Units)
    *   `AimSnapshot` (with `.empty`)
    *   `AbilityDef` (Asserts: valid slots, non-negative ticks/cost)
    *   `ActiveAbilityState` & `BufferedInputState` (Data definitions)
3.  **Create Catalog:**
    *   `AbilityCatalog` with Eloise's abilities.
    *   **Tick Sync:** Manually set INT values.
    *   **Cost Sync:** Manually convert double tuning -> INT (x100).
4.  **Update Loadout:** Add fields to `EquippedLoadoutStore`.

