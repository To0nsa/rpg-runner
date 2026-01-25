# Phase 1: Data Model Detail & Edge Cases (Locked Spec) — **Namespaced Ability Keys**

This version replaces the global `enum AbilityId` with a **stable, namespaced string key** (`AbilityKey`) so abilities can be duplicated per character cleanly without a “god enum”.

---

## 1. Identity

### `AbilityKey` (Stable ID)
*Type:* `String`  
*Format contract:* `<characterId>.<abilityName>` (lower_snake_case recommended)

Examples:
- `eloise.sword_strike`
- `eloise.sword_parry`
- `eloise.dash`
- `eloise.jump`
- `grom.shield_bash`

```dart
typedef AbilityKey = String;

bool isValidAbilityKey(AbilityKey key) {
  // Format: "character.ability_name" (no spaces, lower snake case)
  // At least one dot, segments must be non-empty [a-z0-9_].
  final RegExp validKey = RegExp(r'^[a-z0-9_]+\.[a-z0-9_]+$');
  return validKey.hasMatch(key);
}
```

**Persistence contract:** `AbilityKey` is the only value used for save/load/analytics/debug.

> Optional later optimization (not Phase 1): compile `AbilityKey -> int index` once at catalog-build time and store the resolved index in runtime state (`ActiveAbilityState`) to avoid map lookups in per-tick logic.

---

## 2. Class Definitions

### `AbilitySlot` (Enum)
Defines the "buttons/inputs".
```dart
enum AbilitySlot {
  primary,    // Button A (Melee)
  secondary,  // Button B (Off-hand/Defensive)
  projectile, // Button C (Cast/Throw)
  mobility,   // Button D (Dash)
  bonus,      // Button E (Any)
  jump,       // Fixed slot (reserved)
}
```

### `InterruptPriority` (Enum & Contract)
Defines preemption hierarchy.

**Contract:**
- Priority is totally ordered by ordinal (index `0` lowest).
- **Collision Rule:** If `Incoming.priority > Current.priority` -> Interrupt.
- **Same Priority:** `Current` wins (cannot be preempted by equal priority, must finish).
- `forced` is reserved for **system events** (stun/death) and is not allowed in `AbilityDef`.

```dart
enum InterruptPriority {
  // Lowest
  low,      // e.g. passive stance
  combat,   // standard attacks (strike/cast)
  mobility, // dash/jump/roll
  forced,   // stun/death (highest) — system-only
}
```

### `AbilityDef` (Class)
Authoritative definition of an ability's **structure**.
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
  }) : assert(isValidAbilityKey(id), 'AbilityKey must be in format "<character>.<name>"'),
       assert(allowedSlots.isNotEmpty, 'Ability must be equipable in at least one slot'),
       assert(windupTicks >= 0 && activeTicks >= 0 && recoveryTicks >= 0, 'Ticks cannot be negative'),
       assert(cooldownTicks >= 0, 'Cooldown cannot be negative'),
       assert(staminaCost >= 0 && manaCost >= 0, 'Costs cannot be negative'),
       assert(!canBeInterruptedBy.contains(interruptPriority), 'Ability should not list its own priority in canBeInterruptedBy (old wins implicitly).'),
       assert(interruptPriority != InterruptPriority.forced, 'Forced priority is reserved for system events (stun/death).');

  final AbilityKey id;

  // UI grouping only (must not drive legality)
  final AbilityCategory category;

  // Explicit equip legality
  final Set<AbilitySlot> allowedSlots;

  // Targeting & execution model
  final TargetingModel targetingModel;

  // Hit delivery spec
  final HitDeliveryDef hitDelivery;

  // Timing (ticks @ 60hz)
  final int windupTicks;
  final int activeTicks;
  final int recoveryTicks;

  // Costs (fixed point int): 100 = 1.0
  final int staminaCost;
  final int manaCost;

  // Cooldown
  final int cooldownTicks;

  // Interrupt rules
  final InterruptPriority interruptPriority;
  final Set<InterruptPriority> canBeInterruptedBy;

  // Presentation
  final AnimKey animKey;

  // Tags
  final Set<AbilityTag> tags;
  final Set<AbilityTag> requiredTags;
}
```

---

## 3. Hit Delivery

Standardized units: all dimensions/offsets are in **World Units** (same units as physics bodies).

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
  }) : assert(chainCount >= 0, 'Chain count must be non-negative'),
       assert(!chain || chainCount > 0, 'If chain is true, count must be > 0');
       // Chain Precedence Rule:
       // On Hit:
       // 1. If Chain enabled and count > 0: Retarget and chain (decrement count).
       // 2. Else if Pierce enabled: Pass through (continue trajectory).
       // 3. Else: Destroy projectile.

  final ProjectileId projectileId;
  final bool pierce;
  final bool chain;
  final int chainCount;
  final HitPolicy hitPolicy;
}
```

---

## 4. Aim

```dart
class AimSnapshot {
  const AimSnapshot({
    required this.angleRad,
    this.hasAngle = true,
    required this.capturedTick,
  });

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

---

## 5. Runtime State

### `ActiveAbilityState` (Mutable Component)
Tracks the runtime execution; mutable for ECS performance.

```dart
class ActiveAbilityState {
  AbilityKey? abilityId; // null when idle (no default fallback needed)
  AbilitySlot slot = AbilitySlot.primary;

  AbilityPhase phase = AbilityPhase.idle;
  int phaseTicksRemaining = 0;
  int totalDurationTicks = 0;

  int commitTick = 0;
  AimSnapshot aim = AimSnapshot.empty;
}
```


### `BufferedInputState` (Mutable Component)
Pooled/mutable to avoid GC.

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
  }
}
```

---

## 6. Equipped Loadout (Extension)

```dart
// Store AbilityKey (stable persistence identity)
AbilityKey abilityPrimary;
AbilityKey abilitySecondary;
AbilityKey abilityProjectile;
AbilityKey abilityMobility;
AbilityKey abilityBonus;
```

**Per-character duplication rule:** each character owns its own fallbacks too:
- `eloise.unarmed_strike`, `eloise.braced_block`, `eloise.jump`
- `grom.unarmed_strike`, `grom.braced_block`, `grom.jump`

So “default kit” is just equipping those keys on spawn.

---

## 7. Catalog (Phase 1)
`AbilityCatalog` builds a `Map<AbilityKey, AbilityDef>` and validates:
- keys unique
- `isValidAbilityKey`
- asserts in `AbilityDef` and hit deliveries
- conversion of tuning doubles -> fixed-point ints happens **once at build time** (x100)

---

## 8. Revised Phase 1 Action Items (Updated)

1. **Define Enums:**
   - `AbilitySlot`, `AbilityCategory`, `AbilityPhase`
   - `TargetingModel`, `HitPolicy`, `InterruptPriority` (ordered), `AbilityTag`
2. **Define Structs:**
   - `HitDeliveryDef` (world-unit doubles)
   - `AimSnapshot` (with `.empty`)
   - `AbilityDef` (with asserts + `AbilityKey` ID)
   - `ActiveAbilityState` & `BufferedInputState`
3. **Create Catalog:**
   - `AbilityCatalog` with **Eloise-only** abilities as `AbilityKey`s (`eloise.*`)
   - Convert tuning doubles -> fixed-point ints at load/build time
4. **Update Loadout:**
   - Swap loadout fields from `AbilityId` to `AbilityKey`
