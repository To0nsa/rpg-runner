# Ability Composition Contract

Date: 2026-02-11

## Intent

Enable authored abilities (especially `primary`, `secondary`, `mobility`) to be composable from independent behavior dimensions instead of being hard-wired to one interaction pattern.

Target outcome:
- Any slot can host any valid combination of:
  - input lifecycle
  - targeting behavior
  - charge behavior

## Scope

- In scope: `AbilitySlot.primary`, `AbilitySlot.secondary`, `AbilitySlot.mobility`
- Compatible but not required for this milestone: `projectile`, `bonus`, `jump`
- This is a Core/Game/UI contract document; implementation can be phased.

## Composition Axes

### 1) Input Lifecycle

- `tap`: commit on press edge
- `holdRelease`: hold to prepare/aim/charge, commit on release edge
- `holdMaintain`: commit on hold start, maintain while held, end on release/timeout/deplete

### 2) Targeting Behavior

- `self`: no direction required
- `directional`: direction derived from movement axis/facing
- `aimed`: uses authoritative global aim vector
- `homing`: deterministic nearest-hostile lock at commit (with fallback policy)

### 3) Charge Behavior

- `none`: no tier scaling
- `tiered`: commit-time tuning chosen from authoritative hold ticks

## Canonical Combination Matrix

These are the combinations that should be representable for `primary`, `secondary`, and `mobility`.

1. `tap + self + none`
2. `tap + directional + none`
3. `tap + aimed + none`
4. `tap + homing + none`
5. `holdRelease + directional + none`
6. `holdRelease + aimed + none`
7. `holdRelease + homing + none`
8. `holdMaintain + self + none`
9. `holdMaintain + directional + none`
10. `holdMaintain + aimed + none`
11. `holdMaintain + homing + none`
12. `holdRelease + directional + tiered`
13. `holdRelease + aimed + tiered`
14. `holdRelease + homing + tiered`
15. `holdMaintain + directional + tiered`
16. `holdMaintain + aimed + tiered`
17. `holdMaintain + homing + tiered`

Notes:
- `tap + * + tiered` is intentionally excluded for now (no hold window means no meaningful charge sample).
- `holdRelease + self` is intentionally excluded (release-commit self-cast has weak UX value and overlaps maintain semantics).

## Deterministic Resolution Rules

### Direction/Fallback Order

Use a single deterministic fallback chain:

1. Targeting-specific source (`homing` lock, explicit `aimed` vector, etc.)
2. If unresolved, use current global aim vector if non-zero
3. If still unresolved, use directional fallback from movement facing/axis
4. If still unresolved, use `(1, 0)` as final stable fallback

### Charge Authority

- Charge ticks are sampled from Core authoritative hold state (`AbilityChargeStateStore`)
- UI timers are advisory only
- Tier selection is commit-time only
- For `holdMaintain`, the default hold-start commit flow samples charge at commit
  start (first tier). Higher tiers are only reachable if commit is intentionally
  delayed after hold has already accumulated ticks.

### Hold Ownership

- Hold state transitions are edge-based (`AbilitySlotHeldCommand`)
- Slot holds remain exclusive (latest hold wins)
- Release/timeout/depletion semantics remain simulation-authoritative

## Current Gaps vs This Contract

1. Input mode is inferred from targeting in snapshot code; it is not authored independently.
2. Mobility still uses a dash-specific gate/path that limits aim-driven combinations.
3. Mobility intent/execution is mostly horizontal (`dirX`) and not fully vector-based.
4. HUD charge preview prioritizes primary/secondary/projectile; mobility charge visualization is not first-class.
5. `homing + tiered` is not yet represented by an authored melee or mobility ability.

## Required Contract Evolution

1. Author explicit per-ability input lifecycle (do not infer solely from targeting model).
2. Keep targeting model independent from input lifecycle.
3. Keep charge profile independent from both (except explicit disallow rules above).
4. Extend mobility commit/execution to consume the same targeting and charge contract as combat slots.
5. Expose slot input mode + charge preview in HUD for mobility as needed by UX.

## Suggested Delivery Phases

1. Contract and data-model alignment
   - Add explicit authored input lifecycle to ability defs.
   - Keep existing behavior as defaults for backward compatibility.
2. Core execution alignment
   - Unify commit resolution and charge sampling rules across primary/secondary/mobility.
   - Upgrade mobility direction handling to shared targeting resolution.
3. UI/HUD alignment
   - Surface mobility input mode and charge state where relevant.
   - Reuse existing release/hold controls, avoid slot-specific one-off logic.
4. Cleanup
   - Remove legacy inferred behavior paths once all call sites migrate.

## Acceptance Criteria

1. A single authored ability can express `input lifecycle`, `targeting`, and `charge` independently.
2. `primary`, `secondary`, and `mobility` all support the matrix combinations listed above (except explicitly excluded ones).
3. Same seed + same commands yields identical commit direction/tier outcomes.
4. No layer violation: Core authoritative, Game/UI command-driven.
