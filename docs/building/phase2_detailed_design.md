# Phase 2: Weapon Payload Refactor — **Locked Spec (No Runtime Behavior Change)**

## Goal

Extend `WeaponDef` and `RangedWeaponDef` so that **weapons provide payload** (damage type, procs, passive stats, capability tags)
while **abilities own structure** (timing, targeting, base damage, costs, cooldown).

**Hard constraint:** Phase 2 must not change runtime behavior. Existing systems continue reading legacy fields until Phase 4+.

---

## Design Rules

### R1 — Capability gating is **subset-based**
Weapons grant **capabilities**. Abilities declare **requirements**.

- Weapon: `grantedAbilityTags` (capabilities it provides)
- Ability: `requiredTags` (capabilities it needs)

**Legality:** `ability.requiredTags ⊆ equippedWeapon.grantedAbilityTags`

**Safe default:** if `grantedAbilityTags` is empty, the weapon grants **nothing** (so only abilities with empty `requiredTags` are usable).

> This avoids “empty means allow all”, which is unsafe and makes gating meaningless.

### R2 — Projectile type stays weapon-owned (for thrown weapons)
For projectile weapons (throwing knives/axes), the **weapon** owns:
- `projectileId`
- ballistic flags / gravity scale
- origin offsets

Throw abilities will later reference “use equipped projectile weapon”, not hardcode projectileId (unless explicitly designed to override).

### R3 — Backward compatibility for status effects
Current runtime uses `StatusProfileId` (single) on weapon/projectiles.
Phase 2 introduces `procs[]` but keeps `statusProfileId` as legacy until Phase 5+.

**Bridge rule (for future consumers):**
- If `procs.isEmpty` and `statusProfileId != none`, treat it as `procs = [onHit: statusProfileId]` when building a payload.
- Runtime systems remain unchanged in Phase 2.

### R4 — Numeric domain consistency (Phase 2)
To match the existing codebase and avoid mixed numeric domains mid-migration:
- `WeaponStats` uses `double`
- `WeaponProc.chance` uses `double` in range `[0.0, 1.0]`

(You can move to fixed-point later in a single deliberate refactor if needed.)

---

## Current State (Reference)

### Melee `WeaponDef` today (simplified)
- Has `damageType`
- Has a single `statusProfileId`
- No category / no capability tags / no proc list / no stats

### `RangedWeaponDef` today (simplified)
- Owns `projectileId` and physics fields (keep)
- Also owns `damage`, `staminaCost`, `cooldownSeconds` (legacy; will move to AbilityDef in Phase 4)

---

## Target State — Phase 2 Data Model

### WeaponCategory
```dart
enum WeaponCategory {
  primary,    // swords, axes, spears…
  offHand,    // shields, daggers, torches…
  projectile, // throwing weapons (knife, axe…)
}
```

### WeaponStats
Passive modifiers provided by weapon (not consumed by runtime yet in Phase 2).
```dart
class WeaponStats {
  const WeaponStats({
    this.powerBonus = 0.0,       // +% or scalar, decide later in Phase 5
    this.critChanceBonus = 0.0,  // +0.05 = +5%
    this.critDamageBonus = 0.0,  // +0.50 = +50%
    this.rangeScalar = 1.0,      // 1.0 = unchanged
  }) : assert(rangeScalar > 0.0, 'rangeScalar must be > 0');

  final double powerBonus;
  final double critChanceBonus;
  final double critDamageBonus;
  final double rangeScalar;
}
```

### WeaponProc
Phase 2 proc effect is represented via `StatusProfileId` (matches current runtime).
```dart
enum ProcHook { onHit, onBlock, onKill, onCrit }

class WeaponProc {
  const WeaponProc({
    required this.hook,
    required this.statusProfileId,
    this.chance = 1.0, // 1.0 = 100%
  }) : assert(chance >= 0.0 && chance <= 1.0, 'chance must be in [0..1]');

  final ProcHook hook;
  final StatusProfileId statusProfileId;
  final double chance;
}
```

---

## WeaponDef (Melee) — Phase 2

```dart
class WeaponDef {
  const WeaponDef({
    required this.id,
    required this.category,
    this.grantedAbilityTags = const {},
    this.damageType = DamageType.physical,

    // Legacy (kept until Phase 5)
    this.statusProfileId = StatusProfileId.none,

    // New
    this.procs = const [],
    this.stats = const WeaponStats(),
    this.isTwoHanded = false,
  });

  final WeaponId id;

  /// Equipment slot category (primary/offHand/projectile).
  final WeaponCategory category;

  /// Capabilities provided by this weapon.
  /// Safe default: empty grants nothing.
  final Set<AbilityTag> grantedAbilityTags;

  /// Default damage type applied to hits (until ability overrides exist).
  final DamageType damageType;

  /// LEGACY: single on-hit status profile, kept for current runtime.
  /// Bridge rule: if procs empty and statusProfileId != none -> treat as [onHit: statusProfileId] for future payload builders.
  final StatusProfileId statusProfileId;

  /// New, extensible proc list.
  final List<WeaponProc> procs;

  /// Passive stats (future).
  final WeaponStats stats;

  /// If true, occupies both Primary + Secondary equipment slots.
  /// Enforcement is equip-time validation (Phase 3/4), not runtime in Phase 2.
  final bool isTwoHanded;
}
```

**Notes**
- `category` is about **equipment slots**, not ability slots.
- `grantedAbilityTags` is the weapon capability set; abilities check `requiredTags ⊆ grantedAbilityTags`.

---

## RangedWeaponDef (Projectile Weapons) — Phase 2

```dart
class RangedWeaponDef {
  const RangedWeaponDef({
    required this.id,

    // Weapon-owned projectile identity + physics
    required this.projectileId,
    this.originOffset = 0.0,
    this.ballistic = true,
    this.gravityScale = 1.0,

    // Payload
    this.damageType = DamageType.physical,

    // Legacy (kept until Phase 5)
    this.statusProfileId = StatusProfileId.none,

    // New
    this.procs = const [],
    this.stats = const WeaponStats(),

    // Legacy fields kept for current runtime until Phase 4
    this.legacyDamage = 0.0,
    this.legacyStaminaCost = 0.0,
    this.legacyCooldownSeconds = 0.25,
  });

  final RangedWeaponId id;

  // Weapon-owned projectile identity + physics
  final ProjectileId projectileId;
  final double originOffset;
  final bool ballistic;
  final double gravityScale;

  // Payload
  final DamageType damageType;

  // Legacy single on-hit status profile (Phase 2 keeps it)
  final StatusProfileId statusProfileId;

  // New
  final List<WeaponProc> procs;
  final WeaponStats stats;

  // Legacy runtime-owned values (Phase 4 moves these to AbilityDef)
  @Deprecated('Phase 4: AbilityDef owns damage')
  final double legacyDamage;

  @Deprecated('Phase 4: AbilityDef owns cost')
  final double legacyStaminaCost;

  @Deprecated('Phase 4: AbilityDef owns cooldown')
  final double legacyCooldownSeconds;
}
```

**Why keep legacy fields?**
`PlayerRangedWeaponSystem` currently reads weapon damage/cost/cooldown directly. Phase 2 must not change that.

---

## Catalog Updates (Phase 2)

### WeaponCatalog (Melee)
Populate:
- `category`
- `grantedAbilityTags`
- `damageType`
- legacy `statusProfileId` (keep)
- optional `procs` (can be empty initially to avoid behavioral change)
- optional `stats`

### RangedWeaponCatalog
Populate:
- `projectileId` and physics values (existing)
- `damageType`
- legacy `statusProfileId`
- legacy fields (`legacyDamage`, `legacyStaminaCost`, `legacyCooldownSeconds`) copied from current values
- optional `procs/stats` (can be empty initially)

---

## Compatibility Bridge Helper (for Phase 4/5 consumers)

This helper is **not used by runtime systems in Phase 2**, but gives you a single definition of “effective procs”.

```dart
List<WeaponProc> effectiveWeaponProcs({
  required List<WeaponProc> procs,
  required StatusProfileId legacyStatusProfileId,
}) {
  if (procs.isNotEmpty) return procs;
  if (legacyStatusProfileId == StatusProfileId.none) return const [];
  return [WeaponProc(hook: ProcHook.onHit, statusProfileId: legacyStatusProfileId, chance: 1.0)];
}
```

---

## Validation / Invariants (Meaningful Only)

- `WeaponStats.rangeScalar > 0`
- `WeaponProc.chance in [0..1]`
- `WeaponDef.grantedAbilityTags` must not contain invalid tags (catalog validation)
- (Optional) if `isTwoHanded == true`, enforce at equip-time that offhand slot is empty/disabled (Phase 3/4)

Avoid meaningless null asserts (`required` fields are non-nullable).

---

## Migration Strategy

### Phase 2 Scope (This Phase)
1. Add new fields + types (`WeaponCategory`, `WeaponStats`, `WeaponProc`, `ProcHook`)
2. Keep legacy fields intact (no runtime change)
3. Update catalogs to provide new fields (defaults OK)
4. Add catalog-level validation (unique IDs, sanity checks)

### Phase 4+ Scope (Future)
- Move ranged `legacyDamage/legacyStaminaCost/legacyCooldownSeconds` to `AbilityDef`
- Build `HitPayload` on commit from:
  - `AbilityDef` structure
  - weapon `damageType`, effective procs, stats
- Remove legacy fields after migration

---

## Phase 2 Action Items (Implementation)

### New Files
- `lib/core/weapons/weapon_category.dart`
- `lib/core/weapons/weapon_stats.dart`
- `lib/core/weapons/weapon_proc.dart`

### Modified Files
- `lib/core/weapons/weapon_def.dart`
- `lib/core/weapons/ranged_weapon_def.dart`
- `lib/core/weapons/weapon_catalog.dart`
- `lib/core/weapons/ranged_weapon_catalog.dart`

### Verification
- `dart analyze` passes
- All existing gameplay unchanged (manual smoke test)
- Unit tests (if present) unchanged / pass

---

## Success Criteria

- [ ] New types compile and are referenced by defs
- [ ] Catalogs populated with `category`, `grantedAbilityTags`, `procs`, `stats`
- [ ] Legacy fields remain and systems still use them
- [ ] No runtime behavior changes in Phase 2
